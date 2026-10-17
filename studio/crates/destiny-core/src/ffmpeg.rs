//! ffmpeg / ffprobe en sous-processus.
//!
//! Les processus sont toujours suivis par leur PID (`Child`) : jamais de `pkill -f`,
//! dont le motif apparaît dans sa propre ligne de commande.

use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::audio::Pcm;

/// Résout un outil externe : variable d'environnement, sinon premier chemin absolu existant
/// (sur Mac, une app lancée depuis le Finder n'hérite pas du PATH du shell, d'où les chemins
/// Homebrew en dur ; `~/` est développé), sinon le nom nu cherché dans le PATH.
pub fn tool_bin(env: &str, candidates: &[&str], name: &str) -> String {
    if let Ok(p) = std::env::var(env) {
        return p;
    }
    let home = std::env::var("HOME").unwrap_or_default();
    candidates
        .iter()
        .map(|c| c.strip_prefix("~/").map(|r| format!("{home}/{r}")).unwrap_or_else(|| c.to_string()))
        .find(|c| Path::new(c).is_file())
        .unwrap_or_else(|| name.into())
}

// Homebrew : la formule `ffmpeg` 9 est compilée sans libass ni freetype, donc sans les filtres
// `ass` (moteur A) et `drawtext` (planches contact). `ffmpeg-full` les a mais est keg-only
// (hors PATH) : on la préfère explicitement.
pub fn ffmpeg_bin() -> String {
    tool_bin(
        "DESTINY_FFMPEG",
        &["/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg", "/usr/local/opt/ffmpeg-full/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"],
        "ffmpeg",
    )
}
pub fn ffprobe_bin() -> String {
    tool_bin(
        "DESTINY_FFPROBE",
        &["/opt/homebrew/opt/ffmpeg-full/bin/ffprobe", "/usr/local/opt/ffmpeg-full/bin/ffprobe", "/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"],
        "ffprobe",
    )
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Probe {
    pub duration: f64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fps: Option<f64>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    pub sample_rate: Option<u32>,
    pub channels: Option<u32>,
}

impl Probe {
    pub fn has_video(&self) -> bool {
        self.vcodec.is_some()
    }
}

fn parse_rate(s: &str) -> Option<f64> {
    let (a, b) = s.split_once('/')?;
    let (a, b): (f64, f64) = (a.parse().ok()?, b.parse().ok()?);
    (b > 0.0).then(|| a / b)
}

pub fn probe(path: impl AsRef<Path>) -> Result<Probe> {
    let path = path.as_ref();
    let out = Command::new(ffprobe_bin())
        .args(["-v", "error", "-print_format", "json", "-show_format", "-show_streams"])
        .arg(path)
        .output()
        .context("ffprobe introuvable")?;
    if !out.status.success() {
        bail!("ffprobe {} : {}", path.display(), String::from_utf8_lossy(&out.stderr));
    }
    let v: serde_json::Value = serde_json::from_slice(&out.stdout)?;
    let mut p = Probe {
        duration: v["format"]["duration"].as_str().and_then(|s| s.parse().ok()).unwrap_or(0.0),
        ..Default::default()
    };
    for s in v["streams"].as_array().into_iter().flatten() {
        match s["codec_type"].as_str() {
            Some("video") if p.vcodec.is_none() && s["disposition"]["attached_pic"] != 1 => {
                p.vcodec = s["codec_name"].as_str().map(String::from);
                p.width = s["width"].as_u64().map(|x| x as u32);
                p.height = s["height"].as_u64().map(|x| x as u32);
                p.fps = s["avg_frame_rate"].as_str().and_then(parse_rate)
                    .or_else(|| s["r_frame_rate"].as_str().and_then(parse_rate));
            }
            Some("audio") if p.acodec.is_none() => {
                p.acodec = s["codec_name"].as_str().map(String::from);
                p.sample_rate = s["sample_rate"].as_str().and_then(|x| x.parse().ok());
                p.channels = s["channels"].as_u64().map(|x| x as u32);
            }
            _ => {}
        }
    }
    Ok(p)
}

/// Décode l'audio d'un média quelconque en mono flottant (`range` en secondes fichier).
/// `-ss` est placé avant `-i` : recherche rapide sans décoder ce qui précède.
pub fn decode_audio(path: impl AsRef<Path>, range: Option<(f64, f64)>, sr: u32) -> Result<Pcm> {
    let mut cmd = Command::new(ffmpeg_bin());
    cmd.args(["-v", "error", "-nostdin"]);
    if let Some((a, b)) = range {
        cmd.args(["-ss", &format!("{:.4}", a.max(0.0)), "-t", &format!("{:.4}", (b - a).max(0.0))]);
    }
    cmd.arg("-i").arg(path.as_ref());
    cmd.args(["-vn", "-ac", "1", "-ar", &sr.to_string(), "-f", "f32le", "-"]);
    let out = cmd.output().context("ffmpeg introuvable")?;
    if !out.status.success() {
        bail!("décodage audio {} : {}", path.as_ref().display(), String::from_utf8_lossy(&out.stderr));
    }
    let samples = out
        .stdout
        .chunks_exact(4)
        .map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]]))
        .collect();
    Ok(Pcm { samples, sr })
}

/// Lit l'audio d'un fichier : WAV direct via hound (rapide, sans sous-processus),
/// sinon ffmpeg. Le résultat est à `sr`.
pub fn load_audio(path: impl AsRef<Path>, range: Option<(f64, f64)>, sr: u32) -> Result<Pcm> {
    let path = path.as_ref();
    let is_wav = path.extension().and_then(|e| e.to_str()).is_some_and(|e| e.eq_ignore_ascii_case("wav"));
    if is_wav {
        if let Ok(p) = crate::audio::read_wav_mono(path, range) {
            let samples = crate::audio::resample_linear(&p.samples, p.sr, sr);
            return Ok(Pcm { samples, sr });
        }
    }
    decode_audio(path, range, sr)
}

/// Annulation coopérative d'un job ffmpeg (tue le processus par son PID).
#[derive(Clone, Default)]
pub struct Cancel(Arc<AtomicBool>);
impl Cancel {
    pub fn cancel(&self) {
        self.0.store(true, Ordering::SeqCst)
    }
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::SeqCst)
    }
}

/// Lance ffmpeg avec `-progress pipe:1` et remonte le temps encodé (secondes).
pub fn run_with_progress(
    args: &[String],
    total: f64,
    cancel: Option<&Cancel>,
    mut on_progress: impl FnMut(f64),
) -> Result<()> {
    let mut child: Child = Command::new(ffmpeg_bin())
        .args(["-hide_banner", "-nostdin", "-y", "-progress", "pipe:1", "-nostats"])
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("ffmpeg introuvable")?;
    let mut stderr = child.stderr.take().unwrap();
    let err_thread = std::thread::spawn(move || {
        let mut s = String::new();
        let _ = stderr.read_to_string(&mut s);
        s
    });
    let stdout = child.stdout.take().unwrap();
    for line in BufReader::new(stdout).lines() {
        let line = line?;
        if let Some(v) = line.strip_prefix("out_time_us=") {
            if let Ok(us) = v.trim().parse::<f64>() {
                on_progress(if total > 0.0 { (us / 1e6 / total).clamp(0.0, 1.0) } else { 0.0 });
            }
        }
        if cancel.is_some_and(|c| c.is_cancelled()) {
            child.kill()?;
            let _ = child.wait();
            bail!("rendu annulé");
        }
    }
    let status = child.wait()?;
    let err = err_thread.join().unwrap_or_default();
    if !status.success() {
        let tail: String = err.lines().rev().take(15).collect::<Vec<_>>().into_iter().rev().collect::<Vec<_>>().join("\n");
        bail!("ffmpeg a échoué ({status}) :\n{tail}");
    }
    on_progress(1.0);
    Ok(())
}

pub fn run(args: &[String]) -> Result<()> {
    run_with_progress(args, 0.0, None, |_| {})
}

/// Extrait une image PNG à l'instant `t` d'une vidéo.
pub fn extract_frame(video: &Path, t: f64, out: &Path) -> Result<()> {
    run(&[
        "-v".into(), "error".into(),
        "-ss".into(), format!("{t:.3}"),
        "-i".into(), video.display().to_string(),
        "-frames:v".into(), "1".into(),
        out.display().to_string(),
    ])
}

/// Échappe un chemin pour l'utiliser comme option d'un filtre ffmpeg (`ass=…`).
pub fn filter_path(p: &Path) -> String {
    let s = p.display().to_string();
    let mut o = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        if matches!(c, '\\' | ':' | '\'' | ',' | '[' | ']' | ';' | ' ') {
            o.push('\\');
        }
        o.push(c);
    }
    o
}

pub fn which(bin: &str) -> Option<PathBuf> {
    std::env::var_os("PATH").and_then(|paths| {
        std::env::split_paths(&paths).map(|d| d.join(bin)).find(|p| p.is_file())
    })
}
