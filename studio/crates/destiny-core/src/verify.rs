//! Vérifications automatiques après rendu : durée, son non muet, loudness.
//! Garde-fou (bug réel) : une normalisation sur fenêtre vide donnait NaN → vidéo muette.

use std::path::Path;
use std::process::Command;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Niveau moyen minimal : en dessous, l'export est refusé.
pub const MIN_MEAN_DB: f64 = -40.0;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Report {
    pub duration: f64,
    pub expected_duration: f64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub mean_volume_db: Option<f64>,
    pub integrated_lufs: Option<f64>,
    pub true_peak_db: Option<f64>,
    pub problems: Vec<String>,
}

impl Report {
    pub fn ok(&self) -> bool {
        self.problems.is_empty()
    }
}

fn grab(text: &str, key: &str) -> Option<f64> {
    text.lines().rev().find_map(|l| {
        let i = l.find(key)?;
        l[i + key.len()..].split_whitespace().next()?.parse().ok()
    })
}

pub fn check(video: &Path, expected_duration: f64, expected_wh: Option<(u32, u32)>) -> Result<Report> {
    let pr = crate::ffmpeg::probe(video)?;
    let out = Command::new(crate::ffmpeg::ffmpeg_bin())
        .args(["-hide_banner", "-nostats", "-i"])
        .arg(video)
        .args(["-vn", "-af", "volumedetect,ebur128=peak=true", "-f", "null", "-"])
        .output()
        .context("ffmpeg")?;
    let err = String::from_utf8_lossy(&out.stderr);
    let mut r = Report {
        duration: pr.duration,
        expected_duration,
        width: pr.width,
        height: pr.height,
        mean_volume_db: grab(&err, "mean_volume:"),
        integrated_lufs: grab(&err, "    I:"),
        true_peak_db: grab(&err, "    Peak:"),
        problems: vec![],
    };
    if (r.duration - expected_duration).abs() > 0.25 {
        r.problems.push(format!("durée {:.2} s au lieu de {:.2} s", r.duration, expected_duration));
    }
    match r.mean_volume_db {
        None => r.problems.push("pas de piste audio".into()),
        Some(v) if !v.is_finite() || v < MIN_MEAN_DB => {
            r.problems.push(format!("son quasi muet ({v:.1} dB < {MIN_MEAN_DB} dB) : export refusé"))
        }
        _ => {}
    }
    if let (Some((w, h)), Some(rw), Some(rh)) = (expected_wh, r.width, r.height) {
        if (w, h) != (rw, rh) {
            r.problems.push(format!("résolution {rw}×{rh} au lieu de {w}×{h}"));
        }
    }
    Ok(r)
}
