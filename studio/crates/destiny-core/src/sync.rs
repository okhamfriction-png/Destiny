//! Timeline maîtresse (frames à 25 i/s) et synchronisation des sources.
//!
//! Temps fichier = `t_timeline − rec / 25`.

use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};

use crate::audio;
use crate::project::{Project, Source, MASTER_FPS};

pub fn rec_seconds(rec: f64) -> f64 {
    rec / MASTER_FPS
}

pub fn master_to_file(rec: f64, t_master: f64) -> f64 {
    t_master - rec_seconds(rec)
}

pub fn file_to_master(rec: f64, t_file: f64) -> f64 {
    t_file + rec_seconds(rec)
}

/// Un morceau d'intervalle maître couvert par un seul fichier source.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Piece {
    pub src: String,
    pub t_in: f64,
    pub t_out: f64,
    /// Début du morceau sur la timeline maîtresse.
    pub master: f64,
}

/// Découpe l'intervalle maître `[a, b]` aux frontières des fichiers sources
/// (la caméra DJI change de fichier toutes les ~27 min). Les trous non couverts
/// sont ignorés ; en cas de recouvrement, le fichier qui commence le plus tôt gagne.
pub fn split_master_range(sources: &[Source], a: f64, b: f64) -> Vec<Piece> {
    let mut srcs: Vec<&Source> = sources.iter().filter(|s| s.duration.is_some()).collect();
    srcs.sort_by(|x, y| x.rec.total_cmp(&y.rec));
    let mut out = Vec::new();
    let mut t = a;
    while t < b - 1e-6 {
        let cur = srcs.iter().find(|s| {
            let s0 = rec_seconds(s.rec);
            t >= s0 - 1e-6 && t < s0 + s.duration.unwrap() - 1e-6
        });
        match cur {
            Some(s) => {
                let s0 = rec_seconds(s.rec);
                let end = (s0 + s.duration.unwrap()).min(b);
                out.push(Piece { src: s.id.clone(), t_in: t - s0, t_out: end - s0, master: t });
                t = end;
            }
            None => {
                // Saute jusqu'au prochain fichier qui commence après t.
                match srcs.iter().map(|s| rec_seconds(s.rec)).filter(|&s0| s0 > t).reduce(f64::min) {
                    Some(next) => t = next,
                    None => break,
                }
            }
        }
    }
    out
}

/// Lit l'horodatage d'enregistrement dans un nom de fichier, en secondes depuis minuit.
/// `DJI_20261008201106_0004_D_P004.MP4` → 20:11:06 ; `TX00_MIC017_20261008_194419_orig.wav` → 19:44:19.
pub fn filename_clock(name: &str) -> Option<(u32, f64)> {
    let digits: Vec<(usize, &str)> = {
        let mut v = Vec::new();
        let b = name.as_bytes();
        let mut i = 0;
        while i < b.len() {
            if b[i].is_ascii_digit() {
                let j = (i..b.len()).find(|&j| !b[j].is_ascii_digit()).unwrap_or(b.len());
                v.push((i, &name[i..j]));
                i = j;
            } else {
                i += 1;
            }
        }
        v
    };
    let hms = |s: &str| -> Option<f64> {
        let (h, m, sec): (u32, u32, u32) = (s[0..2].parse().ok()?, s[2..4].parse().ok()?, s[4..6].parse().ok()?);
        (h < 24 && m < 60 && sec < 60).then(|| (h * 3600 + m * 60 + sec) as f64)
    };
    for (k, (_, d)) in digits.iter().enumerate() {
        if d.len() == 14 {
            let date: u32 = d[0..8].parse().ok()?;
            return Some((date, hms(&d[8..14])?));
        }
        if d.len() == 8 {
            if let Some((_, t)) = digits.get(k + 1) {
                if t.len() == 6 {
                    let date: u32 = d.parse().ok()?;
                    return Some((date, hms(t)?));
                }
            }
        }
    }
    None
}

/// Résultat d'un calage micro ↔ caméra.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResult {
    pub mic: String,
    pub source: String,
    /// Nouveau `rec` du micro (frames fractionnaires).
    pub rec: f64,
    /// Correction appliquée en secondes.
    pub delta: f64,
    /// Score de corrélation normalisé (0–1) ; < 0,3 = calage douteux.
    pub score: f32,
}

/// Fenêtre d'enveloppe pour la corrélation (10 ms).
pub const SYNC_HOP: f64 = 0.010;

/// Estime le décalage entre deux pistes audio par corrélation croisée de leurs
/// enveloppes RMS (fenêtres 10 ms). Renvoie `d` tel que `b(t) ≈ a(t + d)`.
pub fn envelope_offset(a: &[f32], b: &[f32], sr: u32, max_lag: f64) -> Result<(f64, f32)> {
    let ea: Vec<f32> = audio::rms_envelope(a, sr, SYNC_HOP).into_iter().map(|v| audio::to_db(v).max(-80.0)).collect();
    let eb: Vec<f32> = audio::rms_envelope(b, sr, SYNC_HOP).into_iter().map(|v| audio::to_db(v).max(-80.0)).collect();
    let (lag, score) = audio::xcorr_lag(&ea, &eb, (max_lag / SYNC_HOP).ceil() as usize)?;
    Ok((lag * SYNC_HOP, score))
}

/// Cale un micro sur l'audio d'une source caméra qui le recouvre.
/// On compare `window` secondes autour du milieu du recouvrement supposé, avec une
/// recherche de ±`max_lag` s autour du `rec` actuel (estimé depuis les noms de fichiers).
pub fn autosync_mic(project: &Project, mic_id: &str, window: f64, max_lag: f64) -> Result<SyncResult> {
    let mic = project.mic(mic_id).ok_or_else(|| anyhow::anyhow!("micro inconnu {mic_id}"))?;
    let m0 = rec_seconds(mic.rec);
    let m1 = m0 + mic.duration.unwrap_or(window);
    // Source caméra qui recouvre le plus le micro.
    let best = project
        .sources
        .iter()
        .filter_map(|s| {
            let s0 = rec_seconds(s.rec);
            let s1 = s0 + s.duration?;
            let ov = m1.min(s1) - m0.max(s0);
            (ov > 5.0).then_some((s, s0.max(m0), s1.min(m1)))
        })
        .max_by(|a, b| (a.2 - a.1).total_cmp(&(b.2 - b.1)));
    let Some((src, ov0, ov1)) = best else {
        bail!("aucune source caméra ne recouvre le micro {mic_id}");
    };
    const SR: u32 = 8000;
    let half = (window / 2.0).min((ov1 - ov0) / 2.0);
    let mid = most_active_center(&mic.path, mic.rec, ov0 + half, ov1 - half, 2.0 * half).unwrap_or((ov0 + ov1) / 2.0);
    // Extrait caméra élargi de max_lag de chaque côté, extrait micro au centre.
    let cam_a = (mid - half - max_lag).max(rec_seconds(src.rec));
    let cam_b = mid + half + max_lag;
    let audio_path = src.proxy.as_deref().unwrap_or(&src.path);
    let cam = crate::ffmpeg::load_audio(audio_path, Some((master_to_file(src.rec, cam_a), master_to_file(src.rec, cam_b))), SR)?;
    let micpcm = crate::ffmpeg::load_audio(&mic.path, Some((master_to_file(mic.rec, mid - half), master_to_file(mic.rec, mid + half))), SR)?;
    let (lag, score) = envelope_offset(&cam.samples, &micpcm.samples, SR, (mid - half - cam_a) + max_lag)?;
    // L'extrait micro commence (selon le rec actuel) à mid−half ; il correspond en
    // réalité à l'instant caméra cam_a + lag.
    let delta = (cam_a + lag) - (mid - half);
    Ok(SyncResult {
        mic: mic_id.into(),
        source: src.id.clone(),
        rec: mic.rec + delta * MASTER_FPS,
        delta,
        score,
    })
}

/// Centre (temps maître, dans `[lo, hi]`) de la fenêtre de `window` s où le micro
/// varie le plus (répliques) : un passage silencieux ne permet pas de caler.
fn most_active_center(path: &str, rec: f64, lo: f64, hi: f64, window: f64) -> Option<f64> {
    if hi <= lo {
        return None;
    }
    let pcm = crate::ffmpeg::load_audio(path, Some((master_to_file(rec, lo - window / 2.0), master_to_file(rec, hi + window / 2.0))), 4000).ok()?;
    let db: Vec<f64> = audio::rms_envelope(&pcm.samples, pcm.sr, 1.0).into_iter().map(|v| audio::to_db(v).max(-80.0) as f64).collect();
    let w = (window.round() as usize).max(2);
    if db.len() <= w {
        return None;
    }
    let (mut best, mut best_var) = (0usize, f64::MIN);
    for k in 0..=db.len() - w {
        let s = &db[k..k + w];
        let m = s.iter().sum::<f64>() / w as f64;
        let var = s.iter().map(|x| (x - m).powi(2)).sum::<f64>();
        if var > best_var {
            best_var = var;
            best = k;
        }
    }
    Some((lo - window / 2.0 + best as f64 + window / 2.0).clamp(lo, hi))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn src(id: &str, rec: f64, dur: f64) -> Source {
        Source { id: id.into(), path: format!("{id}.mp4"), proxy: None, rec, duration: Some(dur) }
    }

    #[test]
    fn splits_at_file_boundaries() {
        // Deux fichiers DJI consécutifs de 1000 s.
        let s = vec![src("a", 0.0, 1000.0), src("b", 25_000.0, 1000.0)];
        let p = split_master_range(&s, 990.0, 1010.0);
        assert_eq!(p.len(), 2);
        assert_eq!(p[0], Piece { src: "a".into(), t_in: 990.0, t_out: 1000.0, master: 990.0 });
        assert_eq!(p[1], Piece { src: "b".into(), t_in: 0.0, t_out: 10.0, master: 1000.0 });
    }

    #[test]
    fn skips_gaps() {
        let s = vec![src("a", 0.0, 10.0), src("b", 25.0 * 20.0, 10.0)];
        let p = split_master_range(&s, 5.0, 25.0);
        assert_eq!(p.len(), 2);
        assert_eq!(p[1].master, 20.0);
        assert_eq!(p[1].t_out, 5.0);
    }

    #[test]
    fn parses_filename_clocks() {
        assert_eq!(filename_clock("DJI_20261008201106_0004_D_P004.MP4"), Some((20261008, 72666.0)));
        assert_eq!(filename_clock("TX00_MIC017_20261008_194419_orig.wav"), Some((20261008, 71059.0)));
        assert_eq!(filename_clock("Spectacle 8 octbre 2026.mov"), None);
    }

    #[test]
    fn envelope_offset_to_the_hundredth() {
        // Bruit modulé : la piste b est la piste a retardée de 1,237 s.
        let sr = 8000;
        let n = sr as usize * 40;
        let mut x = 12345u32;
        let mut a = Vec::with_capacity(n);
        for i in 0..n {
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            let t = i as f32 / sr as f32;
            let am = ((t * 1.7).sin() * (t * 0.31).cos()).abs() + if (t * 3.0) as u32 % 7 == 0 { 1.0 } else { 0.0 };
            a.push(((x as f32 / u32::MAX as f32) - 0.5) * am);
        }
        let shift = (1.237 * sr as f64) as usize;
        let b: Vec<f32> = a[shift..shift + sr as usize * 20].to_vec();
        let (d, score) = envelope_offset(&a, &b, sr, 5.0).unwrap();
        assert!((d - 1.237).abs() < 0.01, "décalage {d}");
        assert!(score > 0.5, "score {score} d {d}");
    }
}
