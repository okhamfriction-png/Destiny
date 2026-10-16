//! Ingest d'un dossier de spectacle : classement des fichiers, ffprobe, proxies
//! manquants, planches contact, et squelette de `project.json` pré-synchronisé.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::ffmpeg::{self, Probe};
use crate::project::{Mic, Preset, Project, Source, MASTER_FPS};
use crate::sync::filename_clock;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum MediaKind {
    /// Caméra plan large (DJI 4K).
    Camera,
    /// Proxy DJI `.LRF` synchrone d'un fichier caméra.
    Proxy,
    /// Micro-cravate individuel.
    Mic,
    /// Export DaVinci de toute la soirée.
    Edit,
    Music,
    /// Captures d'avis (Billet Réduc).
    Image,
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct MediaFile {
    pub path: String,
    pub kind: MediaKind,
    pub duration: f64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fps: Option<f64>,
    /// Horodatage lu dans le nom (secondes depuis minuit).
    pub clock: Option<f64>,
    /// Proxy associé (LRF ou généré).
    pub proxy: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct MediaIndex {
    pub root: String,
    pub files: Vec<MediaFile>,
}

pub fn classify(path: &Path) -> MediaKind {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or_default();
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or_default().to_ascii_lowercase();
    let in_music = path.components().any(|c| c.as_os_str().eq_ignore_ascii_case("music"));
    match ext.as_str() {
        "lrf" => MediaKind::Proxy,
        "wav" if name.contains("MIC") || name.starts_with("TX") => MediaKind::Mic,
        "m4a" | "mp3" | "aac" | "flac" | "wav" if in_music => MediaKind::Music,
        "m4a" | "mp3" | "flac" => MediaKind::Music,
        "mp4" if name.starts_with("DJI_") => MediaKind::Camera,
        "mov" | "mp4" | "mxf" => MediaKind::Edit,
        "png" | "jpg" | "jpeg" | "webp" => MediaKind::Image,
        "wav" => MediaKind::Mic,
        _ => MediaKind::Other,
    }
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> Result<()> {
    for e in std::fs::read_dir(dir).with_context(|| format!("lecture {}", dir.display()))? {
        let p = e?.path();
        let name = p.file_name().and_then(|n| n.to_str()).unwrap_or_default();
        if name.starts_with('.') {
            continue;
        }
        if p.is_dir() {
            walk(&p, out)?;
        } else {
            out.push(p);
        }
    }
    Ok(())
}

/// Indexe un dossier (lecture seule : rien n'est écrit sur le NAS).
pub fn scan(root: &Path) -> Result<MediaIndex> {
    // Chemins absolus : le projet vit ailleurs (disque local) que les rushes (NAS).
    let root = &root.canonicalize().with_context(|| format!("dossier introuvable : {}", root.display()))?;
    let mut paths = Vec::new();
    walk(root, &mut paths)?;
    paths.sort();
    let mut files: Vec<MediaFile> = paths
        .par_iter()
        .map(|p| {
            let kind = classify(p);
            let probe = match kind {
                MediaKind::Other | MediaKind::Image => Probe::default(),
                _ => ffmpeg::probe(p).unwrap_or_default(),
            };
            let name = p.file_name().and_then(|n| n.to_str()).unwrap_or_default();
            MediaFile {
                path: p.display().to_string(),
                kind,
                duration: probe.duration,
                width: probe.width,
                height: probe.height,
                fps: probe.fps,
                clock: filename_clock(name).map(|(_, t)| t),
                proxy: None,
            }
        })
        .collect();
    // Association caméra ↔ LRF (même nom sans extension).
    let lrf: BTreeMap<String, String> = files
        .iter()
        .filter(|f| f.kind == MediaKind::Proxy)
        .map(|f| (stem(&f.path), f.path.clone()))
        .collect();
    for f in files.iter_mut().filter(|f| f.kind == MediaKind::Camera) {
        f.proxy = lrf.get(&stem(&f.path)).cloned();
    }
    Ok(MediaIndex { root: root.display().to_string(), files })
}

fn stem(p: &str) -> String {
    let p = Path::new(p);
    p.with_extension("").display().to_string()
}

/// Proxy 720p généré dans le cache pour les vidéos sans LRF.
pub fn proxy_path(cache: &Path, src: &str) -> PathBuf {
    let name = Path::new(src).file_stem().and_then(|s| s.to_str()).unwrap_or("proxy");
    cache.join("proxies").join(format!("{name}.proxy.mp4"))
}

pub fn make_proxy(src: &Path, dst: &Path, progress: impl FnMut(f64)) -> Result<()> {
    std::fs::create_dir_all(dst.parent().unwrap())?;
    let dur = ffmpeg::probe(src)?.duration;
    let tmp = dst.with_extension("part.mp4");
    ffmpeg::run_with_progress(
        &[
            "-i".into(), src.display().to_string(),
            "-vf".into(), "scale=-2:720".into(),
            "-c:v".into(), "libx264".into(), "-preset".into(), "ultrafast".into(), "-crf".into(), "26".into(),
            "-g".into(), "25".into(),
            "-c:a".into(), "aac".into(), "-b:a".into(), "128k".into(),
            tmp.display().to_string(),
        ],
        dur,
        None,
        progress,
    )?;
    std::fs::rename(tmp, dst)?;
    Ok(())
}

/// Planches contact : une vignette toutes les 2,5 s, 8 colonnes, horodatées en temps
/// de la timeline maîtresse (pour repérer qui est en scène).
pub fn contact_sheets(video: &Path, out_dir: &Path, master_offset: f64, rows: u32) -> Result<Vec<PathBuf>> {
    std::fs::create_dir_all(out_dir)?;
    let name = video.file_stem().and_then(|s| s.to_str()).unwrap_or("sheet");
    let pattern = out_dir.join(format!("{name}_%03d.jpg"));
    let font = crate::render_a::fonts_dir().join("Montserrat-SemiBold.ttf");
    let vf = format!(
        "fps=1/2.5,scale=320:-2,drawtext=fontfile={}:text='%{{pts\\:hms\\:{:.3}}}':x=6:y=6:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=4,tile=8x{rows}:padding=4:color=0x0b0907",
        ffmpeg::filter_path(&font),
        master_offset
    );
    ffmpeg::run(&[
        "-v".into(), "error".into(),
        "-i".into(), video.display().to_string(),
        "-vf".into(), vf,
        "-q:v".into(), "4".into(),
        pattern.display().to_string(),
    ])?;
    let mut sheets: Vec<PathBuf> = std::fs::read_dir(out_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with(name) && n.ends_with(".jpg")))
        .collect();
    sheets.sort();
    Ok(sheets)
}

/// Construit un projet initial : sources caméra + micros, `rec` estimé depuis les
/// horodatages des noms de fichiers (à affiner ensuite par `sync`).
pub fn initial_project(index: &MediaIndex, preset: Preset) -> Project {
    let mut p = Project::new(preset);
    let t0 = index
        .files
        .iter()
        .filter(|f| matches!(f.kind, MediaKind::Camera | MediaKind::Mic))
        .filter_map(|f| f.clock)
        .reduce(f64::min)
        .unwrap_or(0.0);
    let mut cams: Vec<&MediaFile> = index.files.iter().filter(|f| f.kind == MediaKind::Camera).collect();
    cams.sort_by(|a, b| a.path.cmp(&b.path));
    for (i, f) in cams.iter().enumerate() {
        p.sources.push(Source {
            id: format!("cam{}", i + 1),
            path: f.path.clone(),
            proxy: f.proxy.clone(),
            rec: f.clock.map(|c| ((c - t0) * MASTER_FPS).round()).unwrap_or(0.0),
            duration: Some(f.duration),
        });
    }
    if cams.is_empty() {
        // Pas de rushes caméra : on travaille sur l'export DaVinci.
        for (i, f) in index.files.iter().filter(|f| f.kind == MediaKind::Edit).enumerate() {
            p.sources.push(Source {
                id: format!("edit{}", i + 1),
                path: f.path.clone(),
                proxy: None,
                rec: 0.0,
                duration: Some(f.duration),
            });
        }
    }
    let mut mics: Vec<&MediaFile> = index.files.iter().filter(|f| f.kind == MediaKind::Mic).collect();
    mics.sort_by(|a, b| a.path.cmp(&b.path));
    for (i, f) in mics.iter().enumerate() {
        p.mics.push(Mic {
            id: format!("m{}", i + 1),
            path: f.path.clone(),
            rec: f.clock.map(|c| ((c - t0) * MASTER_FPS).round()).unwrap_or(0.0),
            actor: None,
            duration: Some(f.duration),
        });
    }
    p
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_real_names() {
        assert_eq!(classify(Path::new("/x/DJI_20261008201106_0004_D_P004.MP4")), MediaKind::Camera);
        assert_eq!(classify(Path::new("/x/DJI_20261008201106_0004_D_P004.LRF")), MediaKind::Proxy);
        assert_eq!(classify(Path::new("/x/TX00_MIC017_20261008_194419_orig.wav")), MediaKind::Mic);
        assert_eq!(classify(Path::new("/x/Spectacle 8 octbre 2026.mov")), MediaKind::Edit);
        assert_eq!(classify(Path::new("/x/Music/Ritual Pulse.m4a")), MediaKind::Music);
        assert_eq!(classify(Path::new("/x/avis1.PNG")), MediaKind::Image);
    }

    #[test]
    fn initial_rec_from_clocks() {
        let mf = |path: &str, kind, clock| MediaFile {
            path: path.into(), kind, duration: 1600.0, width: None, height: None, fps: None, clock: Some(clock), proxy: None,
        };
        let idx = MediaIndex {
            root: "/x".into(),
            files: vec![
                mf("/x/DJI_20261008201106_0004_D_P004.MP4", MediaKind::Camera, 72666.0),
                mf("/x/TX00_MIC017_20261008_194419_orig.wav", MediaKind::Mic, 71059.0),
            ],
        };
        let p = initial_project(&idx, Preset::ShortScene);
        assert_eq!(p.mics[0].rec, 0.0);
        assert_eq!(p.sources[0].rec, (72666.0 - 71059.0) * 25.0);
    }
}
