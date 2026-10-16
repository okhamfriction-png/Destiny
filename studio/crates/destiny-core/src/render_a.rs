//! Moteur A : shorts verticaux en un seul passage ffmpeg (filtergraph + ASS).

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::ffmpeg::{self, filter_path, Cancel};
use crate::project::{GraphicItem, Preset, Project, VideoItem};
use crate::style::{self, short};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Quality {
    /// Proxies, encodage rapide : aperçu et snapshots.
    Preview,
    /// Fichiers 4K sur les seuls intervalles utilisés, x264 CRF 20.
    Delivery,
}

pub struct RenderJob {
    pub args: Vec<String>,
    pub duration: f64,
    pub ass_path: PathBuf,
    pub mix_path: PathBuf,
    pub out: PathBuf,
}

/// Résout un chemin du projet (relatif au dossier du projet).
pub fn resolve(base: &Path, p: &str) -> PathBuf {
    let pb = PathBuf::from(p);
    if pb.is_absolute() { pb } else { base.join(pb) }
}

/// Dossier des polices embarquées (`assets/fonts`), surchargeable par `DESTINY_FONTS`.
pub fn fonts_dir() -> PathBuf {
    if let Ok(d) = std::env::var("DESTINY_FONTS") {
        return d.into();
    }
    let dev = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../assets/fonts");
    if dev.exists() {
        return dev;
    }
    std::env::current_exe()
        .ok()
        .and_then(|e| e.parent().map(|d| d.join("assets/fonts")))
        .unwrap_or_else(|| "assets/fonts".into())
}

/// Clips triés et rendus contigus : les trous deviennent du noir, les recouvrements
/// sont rognés (le clip suivant gagne).
fn timeline_segments(p: &Project) -> Vec<Seg> {
    let mut clips: Vec<&VideoItem> = p.video_items().collect();
    clips.sort_by(|a, b| a.at.total_cmp(&b.at));
    let mut segs = Vec::new();
    let mut t = 0.0;
    for (i, c) in clips.iter().enumerate() {
        if c.at > t + 1e-3 {
            segs.push(Seg::Black(c.at - t));
            t = c.at;
        }
        let next_at = clips.get(i + 1).map(|n| n.at).unwrap_or(f64::INFINITY);
        let skip = (t - c.at).max(0.0);
        let end = c.end().min(next_at);
        if end - t > 1e-3 {
            segs.push(Seg::Clip { item: (*c).clone(), skip, dur: end - t });
            t = end;
        }
    }
    let total = p.duration();
    if total > t + 1e-3 {
        segs.push(Seg::Black(total - t));
    }
    segs
}

enum Seg {
    Clip { item: VideoItem, skip: f64, dur: f64 },
    Black(f64),
}

fn f(x: f64) -> String {
    format!("{x:.4}")
}

/// Expression de zoom par plan (zoompan, `t = on / fps`).
fn zoom_expr(c: &VideoItem, base: f64, dur: f64, fps: u32) -> String {
    let t = format!("(on/{fps})");
    let push = c.fx.push.unwrap_or(style::DEFAULT_PUSH);
    let mut e = format!("{}*(1+{}*{t}/{})", f(base * c.crop.zoom), f(push), f(dur.max(0.01)));
    if c.fx.punch {
        let _ = write!(e, "*if(lt({t},{pd}),1+{pa}*pow(1-{t}/{pd},2),1)", pd = style::PUNCH_DUR, pa = style::PUNCH_AMOUNT);
    }
    if let Some([a, b]) = c.fx.punch_in {
        let _ = write!(e, "*(1+{}*clip(({t}-{})/0.25,0,1)*clip(({}-{t})/0.25,0,1))", f(style::PUNCH_IN_ZOOM - 1.0), f(a), f(b));
    }
    e
}

/// Construit la commande ffmpeg complète d'un short.
pub fn build(p: &Project, base: &Path, work: &Path, out: &Path, quality: Quality) -> Result<RenderJob> {
    if !matches!(p.preset, Preset::ShortScene | Preset::RetentionPeaks) {
        bail!("le moteur A ne rend que les shorts (preset {:?} → moteur B)", p.preset);
    }
    std::fs::create_dir_all(work)?;
    let (w, h, fps) = (p.format.w, p.format.h, p.format.fps);
    let vertical = p.format.is_vertical();
    let total = p.duration();
    if total <= 0.0 {
        bail!("projet vide : aucune durée");
    }
    let lay = crate::ass::Layout::for_format(w, h);
    let band_w = w;
    let band_h = if vertical { (lay.band_bottom - lay.band_top) as u32 } else { h };
    // zoompan travaille au pixel entier : on lui donne une image 2× pour lisser.
    let (zw, zh) = (band_w * 2, band_h * 2);

    let mut args: Vec<String> = Vec::new();
    let mut graph = String::new();
    let mut labels = Vec::new();
    let mut input = 0usize;
    let base_zoom = if vertical { short::BAND_ZOOM } else { 1.0 };

    for (k, seg) in timeline_segments(p).into_iter().enumerate() {
        match seg {
            Seg::Black(d) => {
                let _ = writeln!(graph, "color=c=black:s={w}x{h}:r={fps}:d={}[s{k}];", f(d));
            }
            Seg::Clip { item, skip, dur } => {
                let src = p.source(&item.src).context("source")?;
                let path = match (quality, &src.proxy) {
                    (Quality::Preview, Some(px)) => px.as_str(),
                    _ => src.path.as_str(),
                };
                // -ss avant -i : recherche rapide, ne décode que l'intervalle utilisé.
                args.extend([
                    "-ss".into(), f(item.t_in + skip),
                    "-t".into(), f(dur + 0.5),
                    "-i".into(), resolve(base, path).display().to_string(),
                ]);
                let i = input;
                input += 1;
                let z = zoom_expr(&item, base_zoom, item.dur(), fps);
                let px = format!("max(0,min(iw-iw/zoom,{}*iw-iw/zoom/2))", f(item.crop.cx));
                let py = format!("max(0,min(ih-ih/zoom,{}*ih-ih/zoom/2))", f(item.crop.cy));
                let _ = write!(
                    graph,
                    "[{i}:v]setpts=PTS-STARTPTS,fps={fps},trim=duration={d},setpts=PTS-STARTPTS,setsar=1",
                    d = f(dur)
                );
                if vertical {
                    let _ = writeln!(
                        graph,
                        ",split=2[bg{k}][fg{k}];\
[bg{k}]scale=270:480:force_original_aspect_ratio=increase,crop=270:480,{gbg},boxblur=10:2,scale={w}:{h},eq=brightness={}:saturation={}[bgb{k}];\
[fg{k}]scale={zw}:{zh}:force_original_aspect_ratio=increase,crop={zw}:{zh},zoompan=z='{z}':x='{px}':y='{py}':d=1:s={band_w}x{band_h}:fps={fps},{gfg}[band{k}];\
[bgb{k}][band{k}]overlay=x=0:y={top}:shortest=1[s{k}];",
                        short::BG_BRIGHTNESS, short::BG_SATURATION, top = lay.band_top,
                        gbg = style::grade(&format!("b{k}"), 26.0 * 270.0 / 1080.0),
                        gfg = style::grade(&format!("f{k}"), 26.0 * band_w as f64 / 1080.0),
                    );
                } else {
                    let _ = writeln!(
                        graph,
                        ",scale={zw}:{zh}:force_original_aspect_ratio=increase,crop={zw}:{zh},zoompan=z='{z}':x='{px}':y='{py}':d=1:s={w}x{h}:fps={fps},{g}[s{k}];",
                        g = style::grade(&format!("f{k}"), 26.0 * w as f64 / 1920.0),
                    );
                }
            }
        }
        labels.push(format!("[s{k}]"));
    }
    // L'étalonnage est appliqué plan par plan, à la résolution utile (bande et fond flou
    // séparément) : 3× moins de pixels que l'image 1080×1920 entière, et le noir des trous
    // n'est pas « étalonné ».
    let _ = writeln!(graph, "{}concat=n={}:v=1:a=0[cat];", labels.join(""), labels.len());
    let mut cur = "cat".to_string();
    let mut n = 0;
    let mut chain = |graph: &mut String, filter: String| {
        let next = format!("p{n}");
        let _ = writeln!(graph, "{filter}[{next}];");
        n += 1;
        next
    };
    if quality == Quality::Delivery {
        cur = chain(&mut graph, format!("[{cur}]{}", style::GRAIN));
    }
    if !vertical {
        // Bandes noires cinéma (131 px à 1080 de haut).
        let lb = (style::LETTERBOX as f64 * h as f64 / 1080.0).round() as u32;
        cur = chain(&mut graph, format!("[{cur}]drawbox=x=0:y=0:w=iw:h={lb}:c=black:t=fill,drawbox=x=0:y=ih-{lb}:w=iw:h={lb}:c=black:t=fill"));
    }
    // Flashes blancs chauds à l'entrée des plans marqués, et éléments `flash` explicites.
    let mut flashes: Vec<f64> = p.video_items().filter(|c| c.fx.flash && c.at > 0.0).map(|c| c.at).collect();
    flashes.extend(p.graphics().filter_map(|g| matches!(g, GraphicItem::Flash { .. }).then(|| g.span().0)));
    for (j, at) in flashes.iter().enumerate() {
        let d = style::FLASH_DUR;
        let _ = writeln!(
            graph,
            "color=c={}:s={w}x{h}:r={fps}:d={d},format=rgba,fade=t=out:st=0:d={d}:alpha=1,setpts=PTS+{}/TB[fl{j}];",
            style::ff_color(style::FLASH), f(*at)
        );
        cur = chain(&mut graph, format!("[{cur}][fl{j}]overlay=eof_action=pass:format=auto"));
    }
    // Barre de progression jaune en bas.
    for (j, g) in p.graphics().filter(|g| matches!(g, GraphicItem::Progress { .. })).enumerate() {
        let (a, d) = g.span();
        let ph = short::PROGRESS_H;
        let _ = writeln!(graph, "color=c={}:s={w}x{ph}:r={fps}:d={}[pb{j}];", style::ff_color(style::SHORT_YELLOW), f(total));
        cur = chain(
            &mut graph,
            format!("[{cur}][pb{j}]overlay=x='-w+w*(t-{})/{}':y=H-h:eval=frame:enable='between(t,{},{})'", f(a), f(d), f(a), f(a + d)),
        );
    }
    let ass_path = work.join("graphics.ass");
    std::fs::write(&ass_path, crate::ass::build_short_ass(p))?;
    let _ = writeln!(
        graph,
        "[{cur}]ass=filename={}:fontsdir={},format=yuv420p[vout];",
        filter_path(&ass_path),
        filter_path(&fonts_dir())
    );
    // Audio : mix Rust (voix gatées) puis mastering ffmpeg.
    let mix_path = work.join("mix.wav");
    let loud = match p.preset {
        Preset::ShortScene | Preset::RetentionPeaks => "I=-16:TP=-1.5:LRA=11",
        _ => "I=-14:TP=-1.2:LRA=9",
    };
    let _ = write!(
        graph,
        "[{input}:a]acompressor=threshold=-18dB:ratio=3:attack=5:release=120,loudnorm={loud},aresample=48000,aformat=channel_layouts=stereo[aout]"
    );
    args.extend(["-i".into(), mix_path.display().to_string()]);
    let (preset, crf) = match quality {
        Quality::Preview => ("veryfast", "26"),
        Quality::Delivery => ("medium", "20"),
    };
    args.extend([
        "-filter_complex".into(), graph,
        "-map".into(), "[vout]".into(),
        "-map".into(), "[aout]".into(),
        "-r".into(), fps.to_string(),
        "-c:v".into(), "libx264".into(),
        "-preset".into(), preset.into(),
        "-crf".into(), crf.into(),
        "-pix_fmt".into(), "yuv420p".into(),
        "-c:a".into(), "aac".into(),
        "-b:a".into(), "192k".into(),
        "-movflags".into(), "+faststart".into(),
        "-t".into(), f(total),
        out.display().to_string(),
    ]);
    Ok(RenderJob { args, duration: total, ass_path, mix_path, out: out.to_path_buf() })
}

/// Rendu complet : mix audio en Rust, puis passage ffmpeg unique.
pub fn render(
    p: &Project,
    base: &Path,
    work: &Path,
    out: &Path,
    quality: Quality,
    cancel: Option<&Cancel>,
    mut progress: impl FnMut(&str, f64),
) -> Result<RenderJob> {
    let job = build(p, base, work, out, quality)?;
    progress("mix", 0.0);
    let mut resolved = p.clone();
    for s in &mut resolved.sources {
        s.path = resolve(base, &s.path).display().to_string();
        s.proxy = s.proxy.as_ref().map(|x| resolve(base, x).display().to_string());
    }
    for m in &mut resolved.mics {
        m.path = resolve(base, &m.path).display().to_string();
    }
    let mix = crate::mixer::mix(&resolved, job.duration, base, quality == Quality::Preview)?;
    crate::mixer::write_mix(&job.mix_path, &mix)?;
    progress("video", 0.0);
    ffmpeg::run_with_progress(&job.args, job.duration, cancel, |x| progress("video", x))?;
    Ok(job)
}
