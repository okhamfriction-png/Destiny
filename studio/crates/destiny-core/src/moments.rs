//! Moments forts (§4.9) : rires et cris du public (pics large bande sur l'audio
//! caméra), changements de destin (« Destin ! » dans la transcription).

use realfft::RealFftPlanner;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::asr::Transcript;
use crate::audio;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum MomentKind {
    /// Rire ou applaudissements : bruit large bande soutenu.
    Laugh,
    /// Cri ou exclamation : pic bref et voisé.
    Shout,
    /// « Destin ! » : changement de destin.
    Destiny,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Moment {
    /// Temps de la timeline maîtresse.
    pub start: f64,
    pub end: f64,
    pub kind: MomentKind,
    /// Force relative (dB au-dessus du niveau médian, ou 1 pour un mot-clé).
    pub score: f32,
}

const HOP: f64 = 0.1;

/// Planéité spectrale (0 = tonal, 1 = bruit blanc) d'une trame.
pub fn spectral_flatness(frame: &[f32]) -> f32 {
    let n = frame.len().next_power_of_two();
    let mut planner = RealFftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(n);
    let mut buf: Vec<f32> = frame
        .iter()
        .enumerate()
        .map(|(i, x)| x * (0.5 - 0.5 * (2.0 * std::f32::consts::PI * i as f32 / frame.len() as f32).cos()))
        .collect();
    buf.resize(n, 0.0);
    let mut spec = fft.make_output_vec();
    if fft.process(&mut buf, &mut spec).is_err() {
        return 0.0;
    }
    // On ignore le continu et le très grave (bruit de salle).
    let p: Vec<f64> = spec[n / 64..].iter().map(|c| c.norm_sqr() as f64 + 1e-12).collect();
    let geo = (p.iter().map(|x| x.ln()).sum::<f64>() / p.len() as f64).exp();
    let arith = p.iter().sum::<f64>() / p.len() as f64;
    (geo / arith) as f32
}

/// Rires / cris dans l'audio caméra (`samples` à `sr`, commençant à `t0` maître).
pub fn audience_moments(samples: &[f32], sr: u32, t0: f64) -> Vec<Moment> {
    let hop = (HOP * sr as f64) as usize;
    let db: Vec<f32> = audio::rms_envelope(samples, sr, HOP).into_iter().map(audio::to_db).collect();
    if db.len() < 10 {
        return vec![];
    }
    let mut sorted = db.clone();
    sorted.sort_by(f32::total_cmp);
    let median = sorted[sorted.len() / 2];
    let flat: Vec<f32> = samples.chunks(hop).map(|c| if c.len() >= 256 { spectral_flatness(c) } else { 0.0 }).collect();
    let mut out = Vec::new();
    let mut k = 0;
    while k < db.len() {
        if db[k] < median + 8.0 {
            k += 1;
            continue;
        }
        let s = k;
        while k < db.len() && db[k] >= median + 5.0 {
            k += 1;
        }
        let dur = (k - s) as f64 * HOP;
        let peak = db[s..k].iter().copied().fold(f32::MIN, f32::max) - median;
        let mean_flat = flat[s..k].iter().sum::<f32>() / (k - s) as f32;
        let kind = if dur >= 0.8 && mean_flat > 0.25 {
            MomentKind::Laugh
        } else if dur <= 2.0 && peak >= 12.0 {
            MomentKind::Shout
        } else {
            continue;
        };
        out.push(Moment { start: t0 + s as f64 * HOP, end: t0 + k as f64 * HOP, kind, score: peak });
    }
    out
}

/// « Destin ! » et ses variantes dans la transcription.
pub fn destiny_calls(t: &Transcript) -> Vec<Moment> {
    t.segments
        .iter()
        .filter(|s| {
            let low = s.text.to_lowercase();
            low.split(|c: char| !c.is_alphanumeric()).any(|w| w == "destin" || w == "destiny")
        })
        .map(|s| Moment { start: s.start, end: s.end, kind: MomentKind::Destiny, score: 1.0 })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::asr::Segment;

    fn noise(n: usize, amp: f32, seed: u32) -> Vec<f32> {
        let mut x = seed;
        (0..n)
            .map(|_| {
                x ^= x << 13;
                x ^= x >> 17;
                x ^= x << 5;
                (x as f32 / u32::MAX as f32 - 0.5) * amp
            })
            .collect()
    }

    #[test]
    fn flatness() {
        let tone: Vec<f32> = (0..2048).map(|i| (i as f32 * 0.2).sin()).collect();
        assert!(spectral_flatness(&tone) < 0.05);
        assert!(spectral_flatness(&noise(2048, 1.0, 3)) > 0.4);
    }

    #[test]
    fn finds_laugh() {
        let sr = 8000;
        let mut s = noise(sr as usize * 10, 0.01, 1); // salle calme
        s.extend(noise(sr as usize * 2, 0.5, 2)); // 2 s de rires
        s.extend(noise(sr as usize * 10, 0.01, 3));
        let m = audience_moments(&s, sr, 100.0);
        assert_eq!(m.len(), 1, "{m:?}");
        assert_eq!(m[0].kind, MomentKind::Laugh);
        assert!((m[0].start - 110.0).abs() < 0.2 && (m[0].end - 112.0).abs() < 0.2);
    }

    #[test]
    fn destiny_keyword() {
        let t = Transcript {
            segments: vec![
                Segment { start: 1.0, end: 2.0, text: "Destin !".into(), mic: "m1".into(), db: -10.0 },
                Segment { start: 3.0, end: 4.0, text: "Ma destinée".into(), mic: "m1".into(), db: -10.0 },
            ],
        };
        assert_eq!(destiny_calls(&t).len(), 1);
    }
}
