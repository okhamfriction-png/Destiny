//! Mixage audio en Rust (§7) : voix gatées, musique avec enveloppe et ducking,
//! SFX procéduraux, silence avant la carte finale. Le mastering (compresseur +
//! loudnorm) est fait par ffmpeg au multiplexage.

use std::f32::consts::PI;
use std::path::Path;

use anyhow::{Context, Result};

use crate::audio::{self, interp_env};
use crate::project::{GraphicItem, Preset, Project, SfxKind};
use crate::sync::rec_seconds;

pub const SR: u32 = 48_000;
pub const VOICE_GAIN: f32 = 0.8;
/// Niveau RMS cible de chaque clip voix avant mastering.
pub const VOICE_TARGET_DB: f32 = -20.0;
pub const CUT_FADE: f64 = 0.020;
pub const DUCK_DEPTH: f32 = 0.55;
pub const DUCK_SMOOTH: f64 = 0.120;
pub const PRE_CARD_SILENCE: f64 = 0.5;
pub const END_CARD_BOOST: f64 = 1.15;

/// Choix de la source pour l'audio caméra : le fichier pleine résolution a l'audio
/// d'origine ; le proxy LRF aussi, et il se décode bien plus vite.
fn camera_audio_path(p: &Project, src: &str, prefer_proxy: bool) -> Option<String> {
    let s = p.source(src)?;
    Some(if prefer_proxy { s.proxy.clone().unwrap_or_else(|| s.path.clone()) } else { s.path.clone() })
}

fn fade_edges(buf: &mut [f32], fade: f64) {
    let n = ((fade * SR as f64) as usize).min(buf.len() / 2);
    for i in 0..n {
        let g = i as f32 / n as f32;
        buf[i] *= g;
        let j = buf.len() - 1 - i;
        buf[j] *= g;
    }
}

/// Piste voix seule (avant musique), à la durée `total`.
pub fn voice_track(p: &Project, total: f64, prefer_proxy: bool) -> Result<Vec<f32>> {
    let n = (total * SR as f64).ceil() as usize;
    let mut out = vec![0.0f32; n];
    for v in p.voice_items() {
        let src = p.source(&v.src).context("source voix")?;
        let m0 = rec_seconds(src.rec) + v.t_in;
        let m1 = rec_seconds(src.rec) + v.t_out;
        let mut clip = if v.camera_audio || p.mics.is_empty() {
            let path = camera_audio_path(p, &v.src, prefer_proxy).unwrap();
            crate::ffmpeg::load_audio(path, Some((v.t_in, v.t_out)), SR)?.samples
        } else {
            crate::mics::mix_mics(p, m0, m1, SR, true)?
        };
        // Normalisation RMS par clip — garde-fou : fenêtre vide ou silencieuse → pas de gain.
        if let Some(db) = audio::rms_db(&clip) {
            if db > -70.0 {
                let g = audio::from_db((VOICE_TARGET_DB - db).clamp(-24.0, 24.0));
                clip.iter_mut().for_each(|s| *s *= g);
            }
        }
        fade_edges(&mut clip, CUT_FADE);
        let start = (v.at * SR as f64).round() as usize;
        let g = VOICE_GAIN * v.gain as f32;
        for (i, s) in clip.iter().enumerate() {
            if let Some(o) = out.get_mut(start + i) {
                *o += s * g;
            }
        }
    }
    Ok(out)
}

/// Gain de ducking (1 = pas de ducking) à partir de la piste voix.
pub fn duck_curve(voice: &[f32]) -> Vec<f32> {
    let hop = (0.010 * SR as f64) as usize;
    let env = audio::rms_envelope(voice, SR, 0.010);
    let alpha = (0.010 / DUCK_SMOOTH) as f32;
    let mut state = 0.0f32;
    let mut out = Vec::with_capacity(voice.len());
    for e in env {
        let active = ((audio::to_db(e) + 50.0) / 12.0).clamp(0.0, 1.0);
        state += (active - state) * alpha;
        let g = 1.0 - DUCK_DEPTH * state;
        out.extend(std::iter::repeat_n(g, hop));
    }
    out.truncate(voice.len());
    out.resize(voice.len(), 1.0);
    out
}

/// Synthèse déterministe des SFX (aucun aléa : graine fixe).
pub fn synth_sfx(kind: SfxKind) -> Vec<f32> {
    let mut seed = 0x9E37_79B9u32;
    let mut rnd = move || {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        seed as f32 / u32::MAX as f32 * 2.0 - 1.0
    };
    let sr = SR as f32;
    let gen = |dur: f32, f: &mut dyn FnMut(f32, f32) -> f32| -> Vec<f32> {
        let n = (dur * sr) as usize;
        (0..n).map(|i| f(i as f32 / sr, i as f32 / n as f32)).collect()
    };
    match kind {
        SfxKind::Snap => {
            let mut prev = 0.0;
            gen(0.06, &mut |t, _| {
                let x = rnd();
                let hp = x - prev;
                prev = x;
                hp * (-t * 90.0).exp()
            })
        }
        SfxKind::Whoosh => {
            let mut lp = 0.0;
            gen(0.7, &mut |_, u| {
                let cut = 0.02 + 0.25 * (PI * u).sin();
                lp += (rnd() - lp) * cut;
                lp * (PI * u).sin().powi(2) * 2.5
            })
        }
        SfxKind::Tom => {
            let mut ph = 0.0;
            gen(0.5, &mut |t, _| {
                ph += 2.0 * PI * (80.0 + 60.0 * (-t * 18.0).exp()) / sr;
                ph.sin() * (-t * 7.0).exp()
            })
        }
        SfxKind::Gong => gen(3.5, &mut |t, _| {
            let partials = [(110.0, 1.0), (167.3, 0.6), (231.7, 0.4), (298.1, 0.25), (402.9, 0.15)];
            partials.iter().map(|(f, a)| a * (2.0 * PI * f * t).sin()).sum::<f32>() * (-t * 1.2).exp() * 0.4
        }),
        SfxKind::Braam => gen(2.2, &mut |t, u| {
            let saw = |f: f32| 2.0 * (t * f - (t * f + 0.5).floor());
            let x = saw(55.0) + saw(55.4) * 0.8 + saw(110.2) * 0.4;
            (x * 1.8).tanh() * (1.0 - u).powf(1.5) * (t * 30.0).min(1.0) * 0.5
        }),
        SfxKind::SubDrop => {
            let mut ph = 0.0;
            gen(1.6, &mut |_, u| {
                ph += 2.0 * PI * (65.0 - 35.0 * u) / sr;
                ph.sin() * (1.0 - u) * 0.9
            })
        }
        SfxKind::Impact => {
            let mut ph = 0.0;
            let mut lp = 0.0;
            gen(1.4, &mut |t, _| {
                ph += 2.0 * PI * (50.0 + 40.0 * (-t * 10.0).exp()) / sr;
                lp += (rnd() - lp) * 0.3;
                ph.sin() * (-t * 2.5).exp() * 0.9 + lp * (-t * 14.0).exp() * 0.8
            })
        }
    }
}

/// Instant de la carte finale (s'il y en a une).
pub fn end_card_at(p: &Project) -> Option<f64> {
    p.graphics().find_map(|g| match g {
        GraphicItem::EndCard { at, .. } => Some(*at),
        _ => None,
    })
}

/// Mix complet mono à 48 kHz. `music_root` sert à résoudre les chemins musique relatifs.
pub fn mix(p: &Project, total: f64, music_root: &Path, prefer_proxy: bool) -> Result<Vec<f32>> {
    let voice = voice_track(p, total, prefer_proxy)?;
    let n = voice.len();
    let mut out = voice.clone();
    let card = end_card_at(p);
    let has_music = p.music_items().next().is_some();
    if has_music {
        let duck = duck_curve(&voice);
        for m in p.music_items() {
            let path = if Path::new(&m.file).is_absolute() { m.file.clone().into() } else { music_root.join(&m.file) };
            let dur = m.dur.unwrap_or(total - m.at);
            let pcm = crate::ffmpeg::load_audio(&path, Some((m.offset, m.offset + dur)), SR)?;
            let start = (m.at * SR as f64).round() as usize;
            for (i, s) in pcm.samples.iter().enumerate() {
                let j = start + i;
                if j >= n {
                    break;
                }
                let t = j as f64 / SR as f64;
                let mut g = interp_env(&m.gain_env, t, 1.0);
                if card.is_some_and(|c| t >= c) {
                    g = g.max(1.0) * END_CARD_BOOST;
                }
                out[j] += s * g as f32 * duck[j];
            }
        }
    }
    for s in p.sfx_items() {
        let start = (s.at * SR as f64).round() as usize;
        for (i, x) in synth_sfx(s.kind).iter().enumerate() {
            if let Some(o) = out.get_mut(start + i) {
                *o += x * s.gain as f32;
            }
        }
    }
    // Silence total avant la carte finale (trailers / reels).
    if let (Some(c), true) = (card, p.preset != Preset::ShortScene) {
        let a = ((c - PRE_CARD_SILENCE).max(0.0) * SR as f64) as usize;
        let b = ((c * SR as f64) as usize).min(n);
        let f = (0.010 * SR as f64) as usize;
        for j in a.saturating_sub(f)..b.min(n) {
            let g = if j < a { (a - j) as f32 / f as f32 } else { 0.0 };
            out[j] *= g;
        }
    }
    // Coupe franche à la fin : fondu de 10 ms seulement.
    let f = ((0.010 * SR as f64) as usize).min(n);
    for i in 0..f {
        out[n - 1 - i] *= i as f32 / f as f32;
    }
    for s in &mut out {
        if !s.is_finite() {
            *s = 0.0;
        }
    }
    Ok(out)
}

pub fn write_mix(path: &Path, samples: &[f32]) -> Result<()> {
    audio::write_wav(path, samples, SR, 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sfx_are_deterministic_and_finite() {
        for k in [SfxKind::Snap, SfxKind::Whoosh, SfxKind::Tom, SfxKind::Gong, SfxKind::Braam, SfxKind::SubDrop, SfxKind::Impact] {
            let a = synth_sfx(k);
            assert_eq!(a, synth_sfx(k));
            assert!(a.iter().all(|x| x.is_finite() && x.abs() < 4.0), "{k:?}");
            assert!(audio::rms_db(&a).unwrap() > -40.0, "{k:?} trop faible");
        }
    }

    #[test]
    fn ducking_lowers_music_under_voice() {
        let mut v = vec![0.0f32; SR as usize];
        for (i, s) in v.iter_mut().enumerate().skip(SR as usize / 2) {
            *s = 0.3 * (i as f32 * 0.05).sin();
        }
        let d = duck_curve(&v);
        assert!((d[1000] - 1.0).abs() < 1e-3);
        assert!(d[SR as usize - 10] < 0.5);
    }
}
