//! Analyse musicale : enveloppe d'énergie, onsets, coups forts et creux.

use std::path::Path;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::audio;

/// Fenêtre de l'enveloppe d'énergie.
pub const ENV_HOP: f64 = 0.100;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Onset {
    pub t: f64,
    /// Saut de niveau en dB (dérivée positive).
    pub strength: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct MusicAnalysis {
    pub file: String,
    pub duration: f64,
    pub hop: f64,
    /// Énergie en dB par fenêtre de 100 ms.
    pub env: Vec<f32>,
    pub onsets: Vec<Onset>,
    /// Coups forts (onsets les plus marqués, triés par temps).
    pub hits: Vec<f64>,
    /// Creux / sections calmes `[début, fin]`.
    pub dips: Vec<[f64; 2]>,
    /// Coup le plus fort : là où poser la carte finale.
    pub biggest_hit: Option<f64>,
}

pub fn analyze_file(path: impl AsRef<Path>) -> Result<MusicAnalysis> {
    let path = path.as_ref();
    let pcm = crate::ffmpeg::load_audio(path, None, 22_050)?;
    let mut a = analyze(&pcm.samples, pcm.sr);
    a.file = path.display().to_string();
    Ok(a)
}

pub fn analyze(samples: &[f32], sr: u32) -> MusicAnalysis {
    let env: Vec<f32> = audio::rms_envelope(samples, sr, ENV_HOP).into_iter().map(audio::to_db).collect();
    let duration = samples.len() as f64 / sr as f64;
    let onsets = detect_onsets(&env);
    let mut ranked = onsets.clone();
    ranked.sort_by(|a, b| b.strength.total_cmp(&a.strength));
    let biggest_hit = ranked.first().map(|o| o.t);
    // Coups forts : onsets nettement au-dessus de la médiane (ou proches du plus fort), espacés de 2 s.
    let med = {
        let mut s: Vec<f32> = onsets.iter().map(|o| o.strength).collect();
        s.sort_by(f32::total_cmp);
        s.get(s.len() / 2).copied().unwrap_or(0.0)
    };
    let max = ranked.first().map(|o| o.strength).unwrap_or(0.0);
    let thr = (med * 1.8).min(max * 0.6).max(6.0);
    let mut hits: Vec<f64> = Vec::new();
    for o in &ranked {
        if o.strength >= thr && hits.iter().all(|h| (h - o.t).abs() >= 2.0) {
            hits.push(o.t);
        }
    }
    hits.sort_by(f64::total_cmp);
    let dips = detect_dips(&env);
    MusicAnalysis { file: String::new(), duration, hop: ENV_HOP, env, onsets, hits, dips, biggest_hit }
}

/// Onsets = maxima locaux de la dérivée positive du dB, au-dessus de 3 dB, espacés de 150 ms.
pub fn detect_onsets(env_db: &[f32]) -> Vec<Onset> {
    let d: Vec<f32> = std::iter::once(0.0)
        .chain(env_db.windows(2).map(|w| (w[1] - w[0]).max(0.0)))
        .collect();
    let mut out: Vec<Onset> = Vec::new();
    for i in 1..d.len().saturating_sub(1) {
        if d[i] >= 3.0 && d[i] >= d[i - 1] && d[i] > d[i + 1] && env_db[i] > -50.0 {
            let t = i as f64 * ENV_HOP;
            if out.last().is_some_and(|o| t - o.t < 0.15) {
                continue;
            }
            // On cumule la montée sur deux fenêtres (attaque lente).
            out.push(Onset { t, strength: d[i] + d[i + 1].max(0.0) });
        }
    }
    out
}

/// Creux : au moins 0,8 s plus de 9 dB sous le niveau médian du morceau.
pub fn detect_dips(env_db: &[f32]) -> Vec<[f64; 2]> {
    let mut s: Vec<f32> = env_db.iter().copied().filter(|v| *v > -90.0).collect();
    if s.is_empty() {
        return vec![];
    }
    s.sort_by(f32::total_cmp);
    let med = s[s.len() / 2];
    let mut out = Vec::new();
    let mut start: Option<usize> = None;
    for (i, &v) in env_db.iter().chain(std::iter::once(&f32::MAX)).enumerate() {
        let low = v < med - 9.0;
        match (low, start) {
            (true, None) => start = Some(i),
            (false, Some(s0)) => {
                if (i - s0) as f64 * ENV_HOP >= 0.8 && s0 > 0 {
                    out.push([s0 as f64 * ENV_HOP, i as f64 * ENV_HOP]);
                }
                start = None;
            }
            _ => {}
        }
    }
    out
}

/// Offset de la musique pour que son coup `hit` tombe à `final_at` dans la vidéo.
/// Renvoie `(at, offset)` du `MusicItem`.
pub fn align_hit(hit: f64, final_at: f64) -> (f64, f64) {
    let offset = hit - final_at;
    if offset >= 0.0 {
        (0.0, offset)
    } else {
        (-offset, 0.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_hit_and_dip() {
        let sr = 8000;
        let mut s = Vec::new();
        let seg = |s: &mut Vec<f32>, dur: f64, amp: f32| {
            for i in 0..(dur * sr as f64) as usize {
                s.push(amp * (i as f32 * 0.37).sin());
            }
        };
        seg(&mut s, 5.0, 0.2); // pulsation
        seg(&mut s, 1.5, 0.01); // creux
        seg(&mut s, 3.0, 0.9); // gros coup à 6,5 s
        seg(&mut s, 2.0, 0.2);
        let a = analyze(&s, sr);
        assert!(a.dips.iter().any(|d| d[0] >= 4.9 && d[1] <= 6.6), "{:?}", a.dips);
        let big = a.biggest_hit.unwrap();
        assert!((big - 6.5).abs() <= 0.15, "coup {big}");
        assert!(a.hits.iter().any(|h| (h - 6.5).abs() <= 0.15));
    }

    #[test]
    fn hit_alignment() {
        // Ritual Pulse : coup final 83,6 s, carte finale à 40 s → offset 43,6.
        assert_eq!(align_hit(83.6, 40.0), (0.0, 83.6 - 40.0));
        assert_eq!(align_hit(10.0, 12.0), (2.0, 0.0));
    }
}
