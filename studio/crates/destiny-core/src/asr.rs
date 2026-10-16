//! Transcription horodatée : VAD puis whisper segment par segment.
//!
//! - VAD : Silero (ONNX via `ort`) avec la feature `asr`, sinon VAD d'énergie en Rust
//!   avec les mêmes réglages (silence 0,3 s, segment min 0,2 s, max 8 s).
//! - ASR : whisper.cpp via `whisper-rs` (feature `asr`), langue `fr`.

use std::collections::BTreeMap;
use std::path::Path;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::audio;
use crate::project::Project;
use crate::sync::{file_to_master, master_to_file};

pub const ASR_SR: u32 = 16_000;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct VadParams {
    /// Silence minimal pour couper un segment.
    pub min_silence: f64,
    pub min_segment: f64,
    pub max_segment: f64,
}

impl Default for VadParams {
    fn default() -> Self {
        VadParams { min_silence: 0.3, min_segment: 0.2, max_segment: 8.0 }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Segment {
    /// Temps de la timeline maîtresse.
    pub start: f64,
    pub end: f64,
    pub text: String,
    pub mic: String,
    /// Niveau RMS du segment sur son micro.
    pub db: f32,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Transcript {
    pub segments: Vec<Segment>,
}

impl Transcript {
    pub fn load(path: &Path) -> Result<Self> {
        Ok(serde_json::from_str(&std::fs::read_to_string(path)?)?)
    }
    pub fn save(&self, path: &Path) -> Result<()> {
        std::fs::write(path, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
    /// Segments qui recouvrent l'intervalle maître `[a, b]`, triés.
    pub fn range(&self, a: f64, b: f64) -> Vec<&Segment> {
        let mut v: Vec<&Segment> = self.segments.iter().filter(|s| s.end > a && s.start < b).collect();
        v.sort_by(|x, y| x.start.total_cmp(&y.start));
        v
    }
    pub fn apply_dictionary(&mut self, dict: &BTreeMap<String, String>) {
        for s in &mut self.segments {
            s.text = crate::captions::apply_dictionary(&s.text, dict);
        }
    }
}

/// Probabilité de parole par trame (30 ms) → segments `[début, fin]` en secondes.
pub fn segments_from_probs(probs: &[f32], hop: f64, threshold: f32, p: VadParams) -> Vec<[f64; 2]> {
    let mut raw: Vec<[f64; 2]> = Vec::new();
    let mut start: Option<usize> = None;
    let mut last_speech = 0usize;
    for (i, &pr) in probs.iter().chain(std::iter::once(&0.0)).enumerate() {
        if pr >= threshold {
            if start.is_none() {
                start = Some(i);
            }
            last_speech = i;
        } else if let Some(s) = start {
            if (i - last_speech) as f64 * hop >= p.min_silence || i == probs.len() {
                raw.push([s as f64 * hop, (last_speech + 1) as f64 * hop]);
                start = None;
            }
        }
    }
    let mut out = Vec::new();
    for [a, b] in raw.into_iter().filter(|s| s[1] - s[0] >= p.min_segment) {
        // Découpe des segments trop longs à intervalles réguliers.
        let n = ((b - a) / p.max_segment).ceil().max(1.0) as usize;
        let step = (b - a) / n as f64;
        for k in 0..n {
            out.push([a + k as f64 * step, a + (k + 1) as f64 * step]);
        }
    }
    out
}

/// VAD d'énergie : parole = 10 dB au-dessus du plancher de bruit (10e centile) et > −55 dB.
pub fn energy_vad(samples: &[f32], sr: u32, p: VadParams) -> Vec<[f64; 2]> {
    const HOP: f64 = 0.03;
    let db: Vec<f32> = audio::rms_envelope(samples, sr, HOP).into_iter().map(audio::to_db).collect();
    if db.is_empty() {
        return vec![];
    }
    let mut sorted = db.clone();
    sorted.sort_by(f32::total_cmp);
    let floor = sorted[sorted.len() / 10];
    let thr = (floor + 10.0).max(-55.0);
    let probs: Vec<f32> = db.iter().map(|d| if *d > thr { 1.0 } else { 0.0 }).collect();
    segments_from_probs(&probs, HOP, 0.5, p)
}

/// Détecte la parole sur un signal 16 kHz (Silero si disponible).
pub fn vad(samples: &[f32], p: VadParams) -> Result<Vec<[f64; 2]>> {
    #[cfg(feature = "asr")]
    if let Some(model) = silero::model_path() {
        return silero::vad(&model, samples, p);
    }
    Ok(energy_vad(samples, ASR_SR, p))
}

/// Transcrit les micros du projet sur l'intervalle maître `[a, b]`.
/// Sans la feature `asr`, renvoie les segments de parole sans texte (utile pour la
/// carte des répliques), avec un avertissement dans `text`.
pub fn transcribe_project(project: &Project, a: f64, b: f64, model: Option<&Path>) -> Result<Transcript> {
    let mut segments = Vec::new();
    #[cfg(feature = "asr")]
    let engine = match model {
        Some(m) => Some(whisper::Engine::new(m)?),
        None => None,
    };
    #[cfg(not(feature = "asr"))]
    let _ = model;
    for mic in &project.mics {
        let f0 = master_to_file(mic.rec, a).max(0.0);
        let f1 = master_to_file(mic.rec, b);
        if f1 <= f0 {
            continue;
        }
        let pcm = crate::ffmpeg::load_audio(&mic.path, Some((f0, f1)), ASR_SR)?;
        for [s, e] in vad(&pcm.samples, VadParams::default())? {
            let i0 = (s * ASR_SR as f64) as usize;
            let i1 = ((e * ASR_SR as f64) as usize).min(pcm.samples.len());
            let chunk = &pcm.samples[i0..i1];
            let db = audio::rms_db(chunk).unwrap_or(audio::DB_FLOOR);
            #[cfg(feature = "asr")]
            let text = match &engine {
                Some(en) => en.transcribe(chunk)?,
                None => String::new(),
            };
            #[cfg(not(feature = "asr"))]
            let text = String::new();
            segments.push(Segment {
                start: file_to_master(mic.rec, f0 + s),
                end: file_to_master(mic.rec, f0 + e),
                text,
                mic: mic.id.clone(),
                db,
            });
        }
    }
    segments.sort_by(|x, y| x.start.total_cmp(&y.start));
    let mut t = Transcript { segments };
    t.apply_dictionary(&project.dictionary);
    Ok(t)
}

#[cfg(feature = "asr")]
mod whisper {
    use std::path::Path;

    use anyhow::{Context, Result};
    use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

    pub struct Engine {
        ctx: WhisperContext,
    }

    impl Engine {
        pub fn new(model: &Path) -> Result<Self> {
            let ctx = WhisperContext::new_with_params(&model.display().to_string(), WhisperContextParameters::default())
                .context("chargement du modèle whisper")?;
            Ok(Engine { ctx })
        }

        pub fn transcribe(&self, samples: &[f32]) -> Result<String> {
            let mut state = self.ctx.create_state()?;
            let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
            params.set_language(Some("fr"));
            params.set_print_progress(false);
            params.set_print_realtime(false);
            params.set_print_timestamps(false);
            params.set_single_segment(true);
            state.full(params, samples)?;
            let mut text = String::new();
            for seg in state.as_iter() {
                text.push_str(&seg.to_string());
            }
            Ok(text.trim().to_string())
        }
    }
}

#[cfg(feature = "asr")]
mod silero {
    //! Silero VAD v5 (entrée 512 échantillons à 16 kHz, état 2×1×128).
    use std::path::{Path, PathBuf};

    use anyhow::Result;
    use ort::session::Session;
    use ort::value::Tensor;

    use super::{segments_from_probs, VadParams};

    pub fn model_path() -> Option<PathBuf> {
        std::env::var_os("DESTINY_SILERO").map(PathBuf::from).filter(|p| p.exists())
    }

    pub fn vad(model: &Path, samples: &[f32], p: VadParams) -> Result<Vec<[f64; 2]>> {
        const WIN: usize = 512;
        let mut session = Session::builder()?.commit_from_file(model)?;
        let mut state = vec![0f32; 2 * 128];
        let mut probs = Vec::with_capacity(samples.len() / WIN + 1);
        for chunk in samples.chunks(WIN) {
            let mut frame = chunk.to_vec();
            frame.resize(WIN, 0.0);
            let input = Tensor::from_array(([1usize, WIN], frame))?;
            let st = Tensor::from_array(([2usize, 1, 128], state.clone()))?;
            let sr = Tensor::from_array(([1usize], vec![16_000i64]))?;
            let out = session.run(ort::inputs!["input" => input, "state" => st, "sr" => sr])?;
            let (_, prob) = out["output"].try_extract_tensor::<f32>()?;
            probs.push(prob[0]);
            let (_, ns) = out["stateN"].try_extract_tensor::<f32>()?;
            state.copy_from_slice(ns);
        }
        Ok(segments_from_probs(&probs, WIN as f64 / 16_000.0, 0.5, p))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vad_segments() {
        let sr = 16_000;
        let mut s = vec![0.0005f32; sr as usize]; // 1 s de bruit faible
        s.extend((0..sr as usize).map(|i| 0.3 * (i as f32 * 0.07).sin())); // 1 s de « voix »
        s.extend(vec![0.0005f32; sr as usize / 10]); // 0,1 s de pause (< 0,3 s)
        s.extend((0..sr as usize / 2).map(|i| 0.3 * (i as f32 * 0.05).sin()));
        s.extend(vec![0.0005f32; sr as usize]);
        let seg = energy_vad(&s, sr, VadParams::default());
        assert_eq!(seg.len(), 1, "{seg:?}");
        assert!((seg[0][0] - 1.0).abs() < 0.05 && (seg[0][1] - 2.6).abs() < 0.05, "{seg:?}");
    }

    #[test]
    fn long_segments_are_split() {
        let probs = vec![1.0f32; 600]; // 18 s
        let seg = segments_from_probs(&probs, 0.03, 0.5, VadParams::default());
        assert_eq!(seg.len(), 3);
        assert!(seg.iter().all(|s| s[1] - s[0] <= 8.0));
    }
}
