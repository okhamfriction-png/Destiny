//! DSP audio : lecture WAV, enveloppes RMS, décibels, corrélation croisée FFT.

use std::path::Path;

use anyhow::{bail, Context, Result};
use realfft::RealFftPlanner;

/// Plancher des niveaux en dB (évite −∞ sur le silence numérique).
pub const DB_FLOOR: f32 = -120.0;

pub struct Pcm {
    pub samples: Vec<f32>,
    pub sr: u32,
}

impl Pcm {
    pub fn duration(&self) -> f64 {
        self.samples.len() as f64 / self.sr as f64
    }
}

/// Lit un WAV (16/24/32 bits entiers ou flottant) et le réduit en mono.
/// `range` en secondes fichier, pour ne pas charger 30 min de micro inutilement.
pub fn read_wav_mono(path: impl AsRef<Path>, range: Option<(f64, f64)>) -> Result<Pcm> {
    let path = path.as_ref();
    let mut r = hound::WavReader::open(path).with_context(|| format!("WAV {}", path.display()))?;
    let spec = r.spec();
    let ch = spec.channels as usize;
    let sr = spec.sample_rate;
    let total = r.duration() as usize;
    let (first, count) = match range {
        Some((a, b)) => {
            let a = ((a.max(0.0) * sr as f64) as usize).min(total);
            let b = ((b.max(0.0) * sr as f64) as usize).min(total);
            (a, b.saturating_sub(a))
        }
        None => (0, total),
    };
    r.seek(first as u32)?;
    let n = count * ch;
    let interleaved: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => r.samples::<f32>().take(n).collect::<Result<_, _>>()?,
        hound::SampleFormat::Int => {
            let scale = 1.0 / (1u64 << (spec.bits_per_sample - 1)) as f32;
            r.samples::<i32>()
                .take(n)
                .map(|s| s.map(|v| v as f32 * scale))
                .collect::<Result<_, _>>()?
        }
    };
    let samples = interleaved
        .chunks(ch)
        .map(|f| f.iter().sum::<f32>() / ch as f32)
        .collect();
    Ok(Pcm { samples, sr })
}

pub fn write_wav(path: impl AsRef<Path>, samples: &[f32], sr: u32, channels: u16) -> Result<()> {
    let spec = hound::WavSpec {
        channels,
        sample_rate: sr,
        bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    let mut w = hound::WavWriter::create(path, spec)?;
    for &s in samples {
        w.write_sample(if s.is_finite() { s } else { 0.0 })?;
    }
    w.finalize()?;
    Ok(())
}

/// Enveloppe RMS linéaire par fenêtres de `win` secondes (sans recouvrement).
pub fn rms_envelope(samples: &[f32], sr: u32, win: f64) -> Vec<f32> {
    let n = ((win * sr as f64).round() as usize).max(1);
    samples
        .chunks(n)
        .map(|c| (c.iter().map(|s| s * s).sum::<f32>() / c.len() as f32).sqrt())
        .collect()
}

pub fn to_db(lin: f32) -> f32 {
    if lin <= 0.0 {
        DB_FLOOR
    } else {
        (20.0 * lin.log10()).max(DB_FLOOR)
    }
}

pub fn from_db(db: f32) -> f32 {
    10f32.powf(db / 20.0)
}

/// RMS global en dB ; `None` si la fenêtre est vide (garde-fou anti-NaN).
pub fn rms_db(samples: &[f32]) -> Option<f32> {
    if samples.is_empty() {
        return None;
    }
    let ms = samples.iter().map(|s| (*s as f64) * (*s as f64)).sum::<f64>() / samples.len() as f64;
    Some(to_db(ms.sqrt() as f32))
}

/// Rééchantillonnage linéaire (suffisant pour les enveloppes et l'ASR 16 kHz).
pub fn resample_linear(samples: &[f32], from: u32, to: u32) -> Vec<f32> {
    if from == to || samples.is_empty() {
        return samples.to_vec();
    }
    let ratio = from as f64 / to as f64;
    let n = (samples.len() as f64 / ratio).floor() as usize;
    (0..n)
        .map(|i| {
            let x = i as f64 * ratio;
            let i0 = x.floor() as usize;
            let i1 = (i0 + 1).min(samples.len() - 1);
            let f = (x - i0 as f64) as f32;
            samples[i0] * (1.0 - f) + samples[i1] * f
        })
        .collect()
}

/// Corrélation croisée normalisée de deux signaux (moyenne retirée), par FFT.
/// Renvoie `(lag, score)` où `lag` est le décalage (en échantillons, sous-échantillon
/// par interpolation parabolique) tel que `b[i] ≈ a[i + lag]`, cherché dans `±max_lag`.
pub fn xcorr_lag(a: &[f32], b: &[f32], max_lag: usize) -> Result<(f64, f32)> {
    if a.len() < 4 || b.len() < 4 {
        bail!("signaux trop courts pour la corrélation");
    }
    let norm = |x: &[f32]| -> Vec<f32> {
        let m = x.iter().sum::<f32>() / x.len() as f32;
        let v: Vec<f32> = x.iter().map(|s| s - m).collect();
        let e = v.iter().map(|s| s * s).sum::<f32>().sqrt().max(1e-12);
        v.into_iter().map(|s| s / e).collect()
    };
    let a = norm(a);
    let b = norm(b);
    let n = (a.len() + b.len()).next_power_of_two();
    let mut planner = RealFftPlanner::<f32>::new();
    let fwd = planner.plan_fft_forward(n);
    let inv = planner.plan_fft_inverse(n);
    let mut pa = a.clone();
    pa.resize(n, 0.0);
    let mut pb = b.clone();
    pb.resize(n, 0.0);
    let mut fa = fwd.make_output_vec();
    let mut fb = fwd.make_output_vec();
    fwd.process(&mut pa, &mut fa)?;
    fwd.process(&mut pb, &mut fb)?;
    // corr[k] = Σ a[i+k]·b[i]  ⇔  A · conj(B)
    for (x, y) in fa.iter_mut().zip(fb.iter()) {
        *x *= y.conj();
    }
    let mut corr = inv.make_output_vec();
    inv.process(&mut fa, &mut corr)?;
    let scale = 1.0 / n as f32;
    let at = |k: isize| -> f32 {
        let idx = if k >= 0 { k as usize } else { (n as isize + k) as usize };
        corr[idx] * scale
    };
    let max_lag = max_lag.min(n / 2 - 1) as isize;
    let (mut best_k, mut best) = (0isize, f32::MIN);
    for k in -max_lag..=max_lag {
        let v = at(k);
        if v > best {
            best = v;
            best_k = k;
        }
    }
    let (y0, y1, y2) = (at(best_k - 1), best, at(best_k + 1));
    let denom = y0 - 2.0 * y1 + y2;
    let frac = if denom.abs() > 1e-12 { 0.5 * (y0 - y2) / denom } else { 0.0 };
    Ok((best_k as f64 + frac.clamp(-0.5, 0.5) as f64, best))
}

/// Interpolation linéaire d'une enveloppe `[t, valeur]` triée.
pub fn interp_env(env: &[[f64; 2]], t: f64, default: f64) -> f64 {
    match env {
        [] => default,
        [only] => only[1],
        _ => {
            if t <= env[0][0] {
                return env[0][1];
            }
            for w in env.windows(2) {
                if t <= w[1][0] {
                    let span = w[1][0] - w[0][0];
                    let f = if span > 0.0 { (t - w[0][0]) / span } else { 1.0 };
                    return w[0][1] + (w[1][1] - w[0][1]) * f;
                }
            }
            env[env.len() - 1][1]
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn noise(n: usize, seed: u32) -> Vec<f32> {
        let mut x = seed;
        (0..n)
            .map(|_| {
                x ^= x << 13;
                x ^= x >> 17;
                x ^= x << 5;
                (x as f32 / u32::MAX as f32) - 0.5
            })
            .collect()
    }

    #[test]
    fn xcorr_finds_shift() {
        let a = noise(4000, 7);
        let b: Vec<f32> = a[123..3123].to_vec();
        let (lag, score) = xcorr_lag(&a, &b, 500).unwrap();
        assert!((lag - 123.0).abs() < 0.01, "lag {lag}");
        assert!(score > 0.5);
    }

    #[test]
    fn env_interp() {
        let e = [[0.0, 0.45], [10.0, 0.65]];
        assert!((interp_env(&e, 5.0, 1.0) - 0.55).abs() < 1e-9);
        assert_eq!(interp_env(&e, 20.0, 1.0), 0.65);
        assert_eq!(interp_env(&[], 3.0, 1.0), 1.0);
    }

    #[test]
    fn empty_window_is_none() {
        assert!(rms_db(&[]).is_none());
    }
}
