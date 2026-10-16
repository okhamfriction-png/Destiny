//! Carte des micros, gates (on ne mixe que les comédiens en scène) et détection
//! des chuchotements de coulisses.

use std::collections::BTreeMap;

use anyhow::Result;
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::audio;
use crate::project::Project;
use crate::sync::{master_to_file, rec_seconds};

/// Pas de la carte des micros.
pub const MAP_HOP: f64 = 0.5;
/// Fondu aux bords des gates.
pub const GATE_FADE: f64 = 0.040;
/// En dessous : micro considéré silencieux.
pub const SILENT_DB: f32 = -50.0;
/// Durée minimale d'un segment suspect (évite les fins de répliques isolées).
pub const MIN_SUSPECT: f64 = 1.0;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct MicMap {
    /// Début de la carte sur la timeline maîtresse.
    pub t0: f64,
    pub hop: f64,
    pub mics: Vec<String>,
    /// `levels[m][k]` : niveau RMS (dB) du micro `m` dans la fenêtre `k`.
    pub levels: Vec<Vec<f32>>,
    /// Indice du micro dominant par fenêtre (`None` si tout est silencieux).
    pub dominant: Vec<Option<usize>>,
    /// Voisement par micro et fenêtre (0–1, pic d'autocorrélation dans la plage de hauteur).
    pub voicing: Vec<Vec<f32>>,
}

/// Mesure de voisement : pic d'autocorrélation normalisée entre 70 et 400 Hz.
/// La voix chantée/parlée est périodique (> 0,5) ; un chuchotement est un bruit (< 0,3).
pub fn voicing(frame: &[f32], sr: u32) -> f32 {
    let min_lag = (sr / 400) as usize;
    let max_lag = (sr / 70) as usize;
    if frame.len() <= max_lag * 2 {
        return 0.0;
    }
    let e0: f32 = frame.iter().map(|x| x * x).sum();
    if e0 <= 1e-9 {
        return 0.0;
    }
    let mut best = 0.0f32;
    // Sous-échantillonnage des retards pour rester rapide sur 30 min de micros.
    for lag in (min_lag..=max_lag).step_by(2) {
        let n = frame.len() - lag;
        let mut c = 0.0f32;
        let mut e1 = 0.0f32;
        let mut e2 = 0.0f32;
        for i in 0..n {
            c += frame[i] * frame[i + lag];
            e1 += frame[i] * frame[i];
            e2 += frame[i + lag] * frame[i + lag];
        }
        let r = c / (e1 * e2).sqrt().max(1e-9);
        best = best.max(r);
    }
    best
}

/// Sous-trame de `len` échantillons la plus énergique (pas de `len/2`) : le voisement
/// se mesure là où l'on parle, pas sur un début de fenêtre silencieux.
fn loudest_frame(chunk: &[f32], len: usize) -> &[f32] {
    if chunk.len() <= len {
        return chunk;
    }
    let mut best = (0usize, -1.0f32);
    for start in (0..=chunk.len() - len).step_by(len / 2) {
        let e: f32 = chunk[start..start + len].iter().map(|x| x * x).sum();
        if e > best.1 {
            best = (start, e);
        }
    }
    &chunk[best.0..best.0 + len]
}

/// Calcule la carte des micros sur l'intervalle maître `[a, b]`.
pub fn mic_map(project: &Project, a: f64, b: f64) -> Result<MicMap> {
    const SR: u32 = 16_000;
    let n = ((b - a) / MAP_HOP).ceil().max(0.0) as usize;
    let results: Vec<Result<(Vec<f32>, Vec<f32>)>> = project
        .mics
        .par_iter()
        .map(|m| {
            let pcm = crate::ffmpeg::load_audio(&m.path, Some((master_to_file(m.rec, a), master_to_file(m.rec, b))), SR)?;
            // Le micro peut commencer après `a` : on aligne sur la grille maître.
            let lead = (rec_seconds(m.rec) - a).max(0.0);
            let lead_n = (lead / MAP_HOP).round() as usize;
            let hop = (MAP_HOP * SR as f64) as usize;
            let mut lv = vec![audio::DB_FLOOR; n];
            let mut vc = vec![0.0; n];
            for (k, chunk) in pcm.samples.chunks(hop).enumerate() {
                if let Some(slot) = lv.get_mut(k + lead_n) {
                    *slot = audio::rms_db(chunk).unwrap_or(audio::DB_FLOOR);
                    vc[k + lead_n] = voicing(loudest_frame(chunk, 1600), SR);
                }
            }
            Ok((lv, vc))
        })
        .collect();
    let mut levels = Vec::new();
    let mut voicings = Vec::new();
    for r in results {
        let (l, v) = r?;
        levels.push(l);
        voicings.push(v);
    }
    let dominant = (0..n)
        .map(|k| {
            levels
                .iter()
                .enumerate()
                .map(|(m, l)| (m, l[k]))
                .filter(|(_, db)| *db > SILENT_DB)
                .max_by(|x, y| x.1.total_cmp(&y.1))
                .map(|(m, _)| m)
        })
        .collect();
    Ok(MicMap {
        t0: a,
        hop: MAP_HOP,
        mics: project.mics.iter().map(|m| m.id.clone()).collect(),
        levels,
        dominant,
        voicing: voicings,
    })
}

/// Segment suspect (surligné en orange dans la timeline).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Suspect {
    pub mic: String,
    pub start: f64,
    pub end: f64,
    pub db: f32,
}

/// Heuristique « chuchotement de coulisses » : micro dominant mais faible
/// (−45…−30 dB), voisement faible, alors que les autres micros sont silencieux.
pub fn detect_whispers(map: &MicMap) -> Vec<Suspect> {
    let mut out: Vec<Suspect> = Vec::new();
    for (k, dom) in map.dominant.iter().enumerate() {
        let Some(m) = *dom else { continue };
        let db = map.levels[m][k];
        let weak = (-45.0..=-30.0).contains(&db);
        let unvoiced = map.voicing[m][k] < 0.45;
        let others_silent = map.levels.iter().enumerate().all(|(o, l)| o == m || l[k] < SILENT_DB);
        if weak && unvoiced && others_silent {
            let start = map.t0 + k as f64 * map.hop;
            let end = start + map.hop;
            match out.last_mut() {
                Some(last) if last.mic == map.mics[m] && (start - last.end).abs() < 1e-6 => {
                    last.end = end;
                    last.db = last.db.max(db);
                }
                _ => out.push(Suspect { mic: map.mics[m].clone(), start, end, db }),
            }
        }
    }
    out.retain(|s| s.end - s.start >= MIN_SUSPECT);
    out
}

/// Gain de gate (0–1) d'un micro à l'instant maître `t`, avec fondus de `GATE_FADE`.
/// Un micro sans entrée dans `mic_gates` est ouvert partout.
pub fn gate_gain(gates: Option<&Vec<[f64; 2]>>, t: f64) -> f32 {
    let Some(gates) = gates else { return 1.0 };
    let mut g = 0.0f64;
    for iv in gates {
        let (a, b) = (iv[0], iv[1]);
        if t < a - GATE_FADE || t > b + GATE_FADE {
            continue;
        }
        let up = ((t - (a - GATE_FADE)) / GATE_FADE).clamp(0.0, 1.0);
        let down = (((b + GATE_FADE) - t) / GATE_FADE).clamp(0.0, 1.0);
        g = g.max(up.min(down));
    }
    g as f32
}

/// Mixe les micros gatés sur l'intervalle maître `[a, b]` à `sr` Hz.
/// `apply_gates = false` donne le mix « tout ouvert » (référence pour la mesure).
pub fn mix_mics(project: &Project, a: f64, b: f64, sr: u32, apply_gates: bool) -> Result<Vec<f32>> {
    let n = ((b - a) * sr as f64).round().max(0.0) as usize;
    let tracks: Vec<Result<Vec<f32>>> = project
        .mics
        .par_iter()
        .map(|m| {
            let mut out = vec![0.0f32; n];
            let f0 = master_to_file(m.rec, a);
            let pcm = crate::ffmpeg::load_audio(&m.path, Some((f0.max(0.0), master_to_file(m.rec, b))), sr)?;
            let lead = ((-f0).max(0.0) * sr as f64).round() as usize;
            let gates = if apply_gates { project.mic_gates.get(&m.id) } else { None };
            for (i, s) in pcm.samples.iter().enumerate() {
                let j = i + lead;
                if j >= n {
                    break;
                }
                let t = a + j as f64 / sr as f64;
                out[j] = s * gate_gain(gates, t);
            }
            Ok(out)
        })
        .collect();
    let mut mix = vec![0.0f32; n];
    for t in tracks {
        for (o, s) in mix.iter_mut().zip(t?) {
            *o += s;
        }
    }
    Ok(mix)
}

/// Mesure l'effet des gates sur les segments suspects : niveau du mix sans gates
/// moins niveau avec gates (objectif observé : ≈ 15 dB de réduction).
pub fn gate_reduction_db(project: &Project, suspects: &[Suspect]) -> Result<BTreeMap<String, f32>> {
    const SR: u32 = 16_000;
    let mut res = BTreeMap::new();
    for s in suspects {
        let open = mix_mics(project, s.start, s.end, SR, false)?;
        let gated = mix_mics(project, s.start, s.end, SR, true)?;
        let (Some(o), Some(g)) = (audio::rms_db(&open), audio::rms_db(&gated)) else { continue };
        res.insert(format!("{}@{:.1}", s.mic, s.start), o - g);
    }
    Ok(res)
}

/// Construit des gates à partir d'intervalles de présence en scène
/// (`presence[mic] = [[entrée, sortie], …]`, timeline maîtresse) : fusionne et trie.
pub fn gates_from_presence(presence: &BTreeMap<String, Vec<[f64; 2]>>) -> BTreeMap<String, Vec<[f64; 2]>> {
    presence
        .iter()
        .map(|(m, ivs)| {
            let mut v = ivs.clone();
            v.sort_by(|a, b| a[0].total_cmp(&b[0]));
            let mut merged: Vec<[f64; 2]> = Vec::new();
            for iv in v {
                match merged.last_mut() {
                    Some(last) if iv[0] <= last[1] => last[1] = last[1].max(iv[1]),
                    _ => merged.push(iv),
                }
            }
            (m.clone(), merged)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gate_fades() {
        let g = vec![[10.0, 20.0]];
        assert_eq!(gate_gain(Some(&g), 15.0), 1.0);
        assert_eq!(gate_gain(Some(&g), 5.0), 0.0);
        assert!((gate_gain(Some(&g), 10.0 - 0.02) - 0.5).abs() < 1e-3);
        assert_eq!(gate_gain(None, 5.0), 1.0);
        assert_eq!(gate_gain(Some(&vec![]), 5.0), 0.0);
    }

    #[test]
    fn voicing_separates_tone_and_noise() {
        let sr = 16_000;
        let tone: Vec<f32> = (0..1600).map(|i| (i as f32 * 2.0 * std::f32::consts::PI * 150.0 / sr as f32).sin()).collect();
        let mut x = 99u32;
        let noise: Vec<f32> = (0..1600)
            .map(|_| {
                x ^= x << 13;
                x ^= x >> 17;
                x ^= x << 5;
                x as f32 / u32::MAX as f32 - 0.5
            })
            .collect();
        assert!(voicing(&tone, sr) > 0.9);
        assert!(voicing(&noise, sr) < 0.3);
    }

    #[test]
    fn whisper_heuristic() {
        let map = MicMap {
            t0: 100.0,
            hop: 0.5,
            mics: vec!["m1".into(), "m2".into()],
            //            parle    chuchote  chuchote  silence  chuchote seul (trop court)
            levels: vec![vec![-20.0, -70.0, -70.0, -70.0, -70.0], vec![-60.0, -38.0, -40.0, -70.0, -40.0]],
            dominant: vec![Some(0), Some(1), Some(1), None, Some(1)],
            voicing: vec![vec![0.9, 0.0, 0.0, 0.0, 0.0], vec![0.1, 0.2, 0.15, 0.0, 0.1]],
        };
        let s = detect_whispers(&map);
        assert_eq!(s, vec![Suspect { mic: "m2".into(), start: 100.5, end: 101.5, db: -38.0 }]);
    }

    #[test]
    fn presence_merge() {
        let mut p = BTreeMap::new();
        p.insert("m1".to_string(), vec![[5.0, 8.0], [0.0, 6.0], [10.0, 12.0]]);
        assert_eq!(gates_from_presence(&p)["m1"], vec![[0.0, 8.0], [10.0, 12.0]]);
    }
}
