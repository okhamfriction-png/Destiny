//! Plaques vidéo du moteur B : chaque plan est extrait sur son seul intervalle
//! (`-ss` avant `-i`, proxy en aperçu, pleine résolution en livraison), recadré,
//! animé (push, punch, punch-in) et étalonné par ffmpeg, au format de sortie.
//!
//! Les mouvements de caméra sont faits dans ffmpeg (zoompan) et non dans le navigateur :
//! le calque graphique Chromium est rendu transparent puis superposé aux plaques, ce
//! qui évite de chercher une image exacte dans un `<video>` (non déterministe).

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use md5::{Digest, Md5};

use crate::ffmpeg::{self, Cancel};
use crate::project::{Project, VideoItem};
use crate::render_a::{resolve, Quality};
use crate::style;

/// Segment du fond vidéo, aligné sur des frames entières de la sortie.
#[derive(Debug, Clone, PartialEq)]
pub enum Seg {
    Clip {
        item: VideoItem,
        /// Secondes rognées au début du plan (recouvrement avec le précédent).
        skip: f64,
        /// Frames de sortie `[f0, f1)`.
        f0: u64,
        f1: u64,
        /// Plaque, relative au dossier de composition (`plates/…mp4`).
        file: String,
    },
    Black { f0: u64, f1: u64 },
}

impl Seg {
    pub fn frames(&self) -> u64 {
        match self {
            Seg::Clip { f0, f1, .. } | Seg::Black { f0, f1 } => f1 - f0,
        }
    }
}

/// Nombre total de frames de la vidéo finale.
pub fn total_frames(p: &Project) -> u64 {
    (p.duration() * p.format.fps as f64).round() as u64
}

/// Clips triés et rendus contigus (comme le moteur A) : les trous deviennent du noir,
/// les recouvrements sont rognés (le clip suivant gagne). Les bornes sont arrondies à la
/// frame pour que fond et calque graphique restent alignés image par image.
pub fn segments(p: &Project) -> Vec<Seg> {
    let fps = p.format.fps as f64;
    let fr = |t: f64| (t * fps).round().max(0.0) as u64;
    let mut clips: Vec<&VideoItem> = p.video_items().collect();
    clips.sort_by(|a, b| a.at.total_cmp(&b.at));
    let total = total_frames(p);
    let mut segs = Vec::new();
    let mut cur = 0u64;
    for (i, c) in clips.iter().enumerate() {
        let start = fr(c.at);
        if start > cur {
            segs.push(Seg::Black { f0: cur, f1: start.min(total) });
            cur = start;
        }
        let next = clips.get(i + 1).map(|n| fr(n.at)).unwrap_or(u64::MAX);
        let end = fr(c.end()).min(next).min(total);
        if end > cur {
            let skip = (cur as f64 / fps - c.at).max(0.0);
            segs.push(Seg::Clip { item: (*c).clone(), skip, f0: cur, f1: end, file: String::new() });
            cur = end;
        }
    }
    if total > cur {
        segs.push(Seg::Black { f0: cur, f1: total });
    }
    segs
}

fn f(x: f64) -> String {
    format!("{x:.4}")
}

/// Expression de zoom zoompan (`t` = secondes depuis le début du plan).
pub fn zoom_expr(c: &VideoItem, skip: f64, fps: u32) -> String {
    let t = format!("(on/{fps}+{})", f(skip));
    let push = c.fx.push.unwrap_or(style::DEFAULT_PUSH);
    let mut e = format!("{}*(1+{}*{t}/{})", f(c.crop.zoom.max(1.0)), f(push), f(c.dur().max(0.01)));
    if c.fx.punch {
        let _ = write!(e, "*if(lt({t},{pd}),1+{pa}*pow(1-{t}/{pd},2),1)", pd = style::PUNCH_DUR, pa = style::PUNCH_AMOUNT);
    }
    if let Some([a, b]) = c.fx.punch_in {
        let _ = write!(e, "*(1+{}*clip(({t}-{})/0.25,0,1)*clip(({}-{t})/0.25,0,1))", f(style::PUNCH_IN_ZOOM - 1.0), f(a), f(b));
    }
    e
}

/// Recadrage « cover » centré sur (cx, cy) : renvoie la taille mise à l'échelle,
/// l'origine du recadrage et le centre (cx, cy) ramené dans l'image recadrée.
pub fn cover_crop(src: (u32, u32), out: (u32, u32), cx: f64, cy: f64) -> ((u32, u32), (u32, u32), (f64, f64)) {
    let (sw, sh) = (src.0 as f64, src.1 as f64);
    let (ow, oh) = (out.0 as f64, out.1 as f64);
    let s = (ow / sw).max(oh / sh);
    let even = |x: f64| ((x / 2.0).ceil() * 2.0) as u32;
    let (scw, sch) = (even(sw * s).max(out.0), even(sh * s).max(out.1));
    let x0 = (cx * scw as f64 - ow / 2.0).clamp(0.0, scw as f64 - ow).round();
    let y0 = (cy * sch as f64 - oh / 2.0).clamp(0.0, sch as f64 - oh).round();
    let ncx = ((cx * scw as f64 - x0) / ow).clamp(0.0, 1.0);
    let ncy = ((cy * sch as f64 - y0) / oh).clamp(0.0, 1.0);
    ((scw, sch), (x0 as u32, y0 as u32), (ncx, ncy))
}

/// Arguments ffmpeg d'une plaque.
pub fn plate_args(
    c: &VideoItem,
    skip: f64,
    frames: u64,
    input: &Path,
    src_wh: (u32, u32),
    p: &Project,
    quality: Quality,
    out: &Path,
) -> Vec<String> {
    let (w, h, fps) = (p.format.w, p.format.h, p.format.fps);
    // zoompan travaille au pixel entier : image 2× en livraison pour lisser le mouvement.
    let ss = if quality == Quality::Delivery { 2 } else { 1 };
    let (zw, zh) = (w * ss, h * ss);
    let ((scw, sch), (x0, y0), (ncx, ncy)) = cover_crop(src_wh, (zw, zh), c.crop.cx, c.crop.cy);
    let z = zoom_expr(c, skip, fps);
    let px = format!("max(0,min(iw-iw/zoom,{}*iw-iw/zoom/2))", f(ncx));
    let py = format!("max(0,min(ih-ih/zoom,{}*ih-ih/zoom/2))", f(ncy));
    let dur = frames as f64 / fps as f64;
    let graph = format!(
        "[0:v]setpts=PTS-STARTPTS,fps={fps},setsar=1,scale={scw}:{sch}:flags=bicubic,crop={zw}:{zh}:{x0}:{y0},\
zoompan=z='{z}':x='{px}':y='{py}':d=1:s={w}x{h}:fps={fps}[z];[z]{grade},format=yuv420p[out]",
        grade = style::GRADE
    );
    let (preset, crf) = match quality {
        Quality::Preview => ("veryfast", "17"),
        Quality::Delivery => ("medium", "12"),
    };
    vec![
        "-v".into(), "error".into(),
        "-ss".into(), f(c.t_in + skip),
        "-t".into(), f(dur + 0.5),
        "-i".into(), input.display().to_string(),
        "-filter_complex".into(), graph,
        "-map".into(), "[out]".into(),
        "-frames:v".into(), frames.to_string(),
        "-an".into(),
        "-c:v".into(), "libx264".into(),
        "-preset".into(), preset.into(),
        "-crf".into(), crf.into(),
        "-g".into(), fps.to_string(),
        "-movflags".into(), "+faststart".into(),
        out.display().to_string(),
    ]
}

/// Chemin du média utilisé pour un plan (proxy en aperçu s'il existe).
pub fn clip_input(p: &Project, base: &Path, c: &VideoItem, quality: Quality) -> Result<PathBuf> {
    let src = p.source(&c.src).with_context(|| format!("source {}", c.src))?;
    let path = match (quality, &src.proxy) {
        (Quality::Preview, Some(px)) => px.as_str(),
        _ => src.path.as_str(),
    };
    Ok(resolve(base, path))
}

/// Clé de cache d'une plaque : tout ce qui change ses pixels.
fn plate_key(args_sig: &str, input: &Path) -> String {
    let meta = std::fs::metadata(input).ok();
    let mut h = Md5::new();
    h.update(args_sig.as_bytes());
    h.update(input.display().to_string().as_bytes());
    if let Some(m) = meta {
        h.update(m.len().to_le_bytes());
        if let Ok(t) = m.modified() {
            if let Ok(d) = t.duration_since(std::time::UNIX_EPOCH) {
                h.update(d.as_secs().to_le_bytes());
            }
        }
    }
    let d = h.finalize();
    d.iter().take(8).map(|b| format!("{b:02x}")).collect()
}

/// Calcule (et extrait si `extract`) les plaques de tous les plans. Les plaques déjà
/// présentes avec la même clé sont réutilisées : ne changer qu'un texte ne réextrait rien.
pub fn build(
    p: &Project,
    base: &Path,
    comp_dir: &Path,
    quality: Quality,
    extract: bool,
    cancel: Option<&Cancel>,
    mut progress: impl FnMut(f64),
) -> Result<Vec<Seg>> {
    let dir = comp_dir.join("plates");
    std::fs::create_dir_all(&dir)?;
    let mut segs = segments(p);
    let mut dims: HashMap<PathBuf, (u32, u32)> = HashMap::new();
    let n = segs.iter().filter(|s| matches!(s, Seg::Clip { .. })).count().max(1);
    let mut done = 0usize;
    let q = match quality {
        Quality::Preview => "preview",
        Quality::Delivery => "delivery",
    };
    for s in segs.iter_mut() {
        let Seg::Clip { item, skip, f0, f1, file } = s else { continue };
        let input = clip_input(p, base, item, quality)?;
        let frames = *f1 - *f0;
        // Signature sans le chemin de sortie (et sans la taille source, lue après).
        let sig = format!("{q}|{}x{}@{}|{:?}|{:?}|{}|{}|{}|{}", p.format.w, p.format.h, p.format.fps, item.crop, item.fx, item.t_in, skip, frames, style::GRADE);
        let name = format!("{}_{}.mp4", sanitize(&item.id), plate_key(&sig, &input));
        *file = format!("plates/{name}");
        let out = dir.join(&name);
        if extract && !out.exists() {
            if cancel.is_some_and(|c| c.is_cancelled()) {
                anyhow::bail!("rendu annulé");
            }
            let wh = match dims.get(&input) {
                Some(d) => *d,
                None => {
                    let pr = ffmpeg::probe(&input)?;
                    let d = (pr.width.context("plan sans vidéo")?, pr.height.context("plan sans vidéo")?);
                    dims.insert(input.clone(), d);
                    d
                }
            };
            let tmp = dir.join(format!("{name}.part.mp4"));
            let args = plate_args(item, *skip, frames, &input, wh, p, quality, &tmp);
            let (k, nn) = (done as f64, n as f64);
            ffmpeg::run_with_progress(&args, frames as f64 / p.format.fps as f64, cancel, |x| progress((k + x) / nn))
                .with_context(|| format!("plaque du plan {}", item.id))?;
            std::fs::rename(&tmp, &out)?;
        }
        done += 1;
        progress(done as f64 / n as f64);
    }
    Ok(segs)
}

fn sanitize(s: &str) -> String {
    s.chars().map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' }).collect()
}
