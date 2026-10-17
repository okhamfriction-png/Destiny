//! Moteur B : trailers et reels rendus depuis des compositions HTML/GSAP.
//!
//! Chaîne :
//! 1. [`compose`] : `project.json` → dossier de composition (`index.html`, `style.css`,
//!    `runtime.js`, `scenes.js`, `gsap.min.js`, polices, images d'avis, plaques vidéo).
//!    Chaque élément porte `class="clip"`, `data-start`, `data-duration`,
//!    `data-track-index` (convention HyperFrames) ; une timeline GSAP en pause,
//!    pilotée par `window.__seek(t)`. Le même `index.html` sert d'aperçu live (iframe).
//! 2. [`plates`] : chaque plan est extrait, recadré, animé et étalonné par ffmpeg.
//! 3. `renderer/render.mjs` (Node + Chromium headless) capture le calque graphique en
//!    PNG transparents, image par image, et les envoie par un tube à ffmpeg.
//! 4. ffmpeg superpose le calque aux plaques, ajoute grain et bandes 16:9, multiplexe le
//!    mix audio Rust ([`crate::mixer`]) masterisé (compresseur + loudnorm −14 LUFS).

pub mod layout;
pub mod plates;

use std::fmt::Write as _;
use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::mpsc;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use serde::Serialize;
use serde_json::{json, Value};

use crate::ffmpeg::{self, Cancel};
use crate::project::{GraphicItem, Preset, Project, Track};
use crate::render_a::{fonts_dir, resolve, Quality, RenderJob};
use crate::style;

pub use layout::{check_safe_zone, validate_safe_zone, Frame, SafeIssue};
pub use plates::Seg;

const GSAP_JS: &str = include_str!("../../../../assets/vendor/gsap.min.js");
const RUNTIME_JS: &str = include_str!("assets/runtime.js");
const SCENES_JS: &str = include_str!("assets/scenes.js");
const STYLE_CSS: &str = include_str!("assets/style.css");
const FONTS: [&str; 4] = ["Cinzel-Black.ttf", "Cinzel-Bold.ttf", "Montserrat-SemiBold.ttf", "Anton-Regular.ttf"];

/// Piste (data-track-index) des plaques vidéo et des flashes de montage.
pub const TRACK_PLATES: u32 = 0;
pub const TRACK_CUT_FLASH: u32 = 90;

/// Presets rendus par le moteur B.
pub fn handles(preset: Preset) -> bool {
    matches!(preset, Preset::TrailerV | Preset::TrailerH | Preset::ReelBm)
}

/// Une scène de la composition (élément `.clip`).
#[derive(Debug, Clone, Serialize)]
pub struct Clip {
    pub id: String,
    pub scene: String,
    pub start: f64,
    pub duration: f64,
    pub track: u32,
    /// Index dans `items` du JSON de composition (scènes graphiques).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub item: Option<usize>,
    /// Plaque vidéo (scène `clip`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub src: Option<String>,
}

/// Résultat de [`compose`].
#[derive(Debug, Clone)]
pub struct Composition {
    pub dir: PathBuf,
    pub index: PathBuf,
    pub duration: f64,
    pub frames: u64,
    pub segs: Vec<Seg>,
    pub clips: Vec<Clip>,
    pub issues: Vec<SafeIssue>,
}

fn t3(x: f64) -> String {
    format!("{x:.3}")
}

/// Onsets de la musique, ramenés en temps vidéo `(t, force dB)`.
pub fn music_onsets(p: &Project, base: &Path) -> Vec<(f64, f32)> {
    let mut out = Vec::new();
    for m in p.music_items() {
        let path = resolve(base, &m.file);
        let Ok(a) = crate::music::analyze_file(&path) else { continue };
        let end = m.dur.map(|d| m.offset + d).unwrap_or(f64::INFINITY);
        for o in a.onsets {
            if o.t >= m.offset && o.t <= end {
                out.push((m.at + o.t - m.offset, o.strength));
            }
        }
    }
    out.sort_by(|a, b| a.0.total_cmp(&b.0));
    out
}

/// Instants où les citations de `reviews_txt` claquent : d'abord les coups de
/// `markers.music_hits` dans la fenêtre, puis les onsets les plus forts, espacés d'au
/// moins `0,45 s` ; à défaut, une grille régulière. Le premier claquement laisse le
/// temps au « 10/10 » et aux étoiles d'apparaître (0,9 s).
pub fn slam_times(at: f64, dur: f64, n: usize, hits: &[f64], onsets: &[(f64, f32)]) -> Vec<f64> {
    if n == 0 {
        return vec![];
    }
    let (w0, w1) = (at + 0.9, at + dur - 0.45);
    if w1 <= w0 {
        return (0..n).map(|i| w0.min(at + dur) + i as f64 * 0.01).collect();
    }
    let min_gap = 0.45f64.min((w1 - w0) / n as f64);
    let mut cands: Vec<(f64, f32)> = hits.iter().filter(|h| (w0..=w1).contains(*h)).map(|h| (*h, f32::INFINITY)).collect();
    cands.extend(onsets.iter().filter(|o| (w0..=w1).contains(&o.0)).copied());
    cands.sort_by(|a, b| b.1.total_cmp(&a.1).then(a.0.total_cmp(&b.0)));
    let mut picked: Vec<f64> = Vec::new();
    for (t, _) in cands {
        if picked.len() == n {
            break;
        }
        if picked.iter().all(|p| (p - t).abs() >= min_gap - 1e-9) {
            picked.push(t);
        }
    }
    // Complète avec une grille régulière (pas et demi-pas) si les onsets manquent.
    let step = (w1 - w0) / n as f64;
    for i in 0..2 * n {
        if picked.len() == n {
            break;
        }
        let t = w0 + step * i as f64 / 2.0;
        if picked.iter().all(|p| (p - t).abs() >= min_gap - 1e-9) {
            picked.push(t);
        }
    }
    if picked.len() < n {
        picked = (0..n).map(|i| w0 + step * i as f64).collect();
    }
    picked.sort_by(f64::total_cmp);
    picked
}

fn copy_if_changed(src: &Path, dst: &Path) -> Result<()> {
    let same = match (std::fs::metadata(src), std::fs::metadata(dst)) {
        (Ok(a), Ok(b)) => a.len() == b.len(),
        _ => false,
    };
    if !same {
        std::fs::copy(src, dst).with_context(|| format!("copie de {}", src.display()))?;
    }
    Ok(())
}

fn write_if_changed(path: &Path, content: &str) -> Result<()> {
    if std::fs::read_to_string(path).ok().as_deref() != Some(content) {
        std::fs::write(path, content)?;
    }
    Ok(())
}

/// En-tête CSS : couleurs de la charte (style.rs reste la source de vérité).
fn css_root() -> String {
    format!(
        ":root {{ --bg: {}; --text: {}; --gold: {}; --gold-light: {}; --flash: {}; --gold-grad: {}; }}\n",
        style::BG,
        style::TEXT,
        style::GOLD,
        style::GOLD_LIGHT,
        style::FLASH,
        style::GOLD_GRADIENT
    )
}

/// Données de la composition (`<script id="comp-data">`) et liste des clips.
/// Fonction pure (aucune E/S) : `images` donne, pour chaque élément graphique, les
/// captures déjà copiées `(src relatif, largeur, hauteur)`.
pub fn comp_data(
    p: &Project,
    segs: &[Seg],
    onsets: &[(f64, f32)],
    images: &dyn Fn(usize) -> Vec<(String, u32, u32)>,
    backgrounds: &dyn Fn(usize) -> Option<String>,
) -> (Value, Vec<Clip>) {
    let frame = Frame::new(&p.format);
    let fps = p.format.fps as f64;
    let mut clips = Vec::new();
    let mut items: Vec<Value> = Vec::new();
    for s in segs {
        if let Seg::Clip { item, f0, f1, file, .. } = s {
            clips.push(Clip {
                id: format!("v_{}", item.id),
                scene: "clip".into(),
                start: *f0 as f64 / fps,
                duration: (*f1 - *f0) as f64 / fps,
                track: TRACK_PLATES,
                item: None,
                src: Some(file.clone()),
            });
        }
    }
    // Flash blanc chaud à l'entrée des plans marqués (entre deux plans de montage).
    for c in p.video_items().filter(|c| c.fx.flash && c.at > 0.0) {
        let idx = items.len();
        items.push(json!({ "type": "flash", "at": c.at, "dur": style::FLASH_DUR }));
        clips.push(Clip { id: format!("fx_{}", c.id), scene: "flash".into(), start: c.at, duration: style::FLASH_DUR, track: TRACK_CUT_FLASH, item: Some(idx), src: None });
    }
    let mut gi = 0usize;
    let mut ordinal = 0u32;
    for t in &p.tracks {
        let Track::Graphics { items: gitems, .. } = t else { continue };
        ordinal += 1;
        for g in gitems {
            let (at, dur) = g.span();
            let mut v = serde_json::to_value(g).unwrap_or(Value::Null);
            let scene = layout::scene_name(g);
            match g {
                GraphicItem::ReviewsTxt { items: q, .. } => {
                    v["slams"] = json!(slam_times(at, dur, q.len(), &p.markers.music_hits, onsets));
                }
                GraphicItem::Reviews { .. } => {
                    v["images"] = json!(images(gi).into_iter().map(|(src, w, h)| json!({ "src": src, "w": w, "h": h })).collect::<Vec<_>>());
                }
                GraphicItem::Mech { .. } => {
                    if let Some(b) = backgrounds(gi) {
                        v["background_src"] = json!(b);
                    }
                }
                GraphicItem::EndCard { variant, lines, .. } => {
                    v["info"] = json!(layout::end_card_lines(*variant, lines));
                    v["button"] = json!(layout::END_CARD_BUTTON);
                }
                _ => {}
            }
            let idx = items.len();
            items.push(v);
            clips.push(Clip { id: format!("g{gi}_{scene}"), scene, start: at, duration: dur, track: ordinal, item: Some(idx), src: None });
            gi += 1;
        }
    }
    // Ordre d'empilement : piste puis début (le dernier arrivé est au-dessus).
    clips.sort_by(|a, b| a.track.cmp(&b.track).then(a.start.total_cmp(&b.start)));
    let data = json!({
        "version": 1,
        "preset": p.preset,
        "fps": p.format.fps,
        "duration": plates::total_frames(p) as f64 / fps,
        "frames": plates::total_frames(p),
        "frame": frame,
        "sz": layout::sizes(frame.vertical),
        "hits": p.markers.music_hits,
        "items": items,
    });
    (data, clips)
}

fn esc(s: &str) -> String {
    s.replace('&', "&amp;").replace('"', "&quot;").replace('<', "&lt;").replace('>', "&gt;")
}

/// `index.html` de la composition.
pub fn index_html(data: &Value, clips: &[Clip], frame: &Frame) -> String {
    let mut h = String::new();
    let _ = writeln!(h, "<!doctype html>\n<html lang=\"fr\">\n<head>\n<meta charset=\"utf-8\">");
    let _ = writeln!(h, "<meta name=\"viewport\" content=\"width={}, height={}\">", frame.w, frame.h);
    let _ = writeln!(h, "<title>Destiny — composition</title>");
    let _ = writeln!(h, "<link rel=\"stylesheet\" href=\"style.css\">\n<script src=\"gsap.min.js\"></script>\n</head>\n<body>");
    let _ = writeln!(h, "<div id=\"stage\" data-width=\"{}\" data-height=\"{}\" data-fps=\"{}\" data-duration=\"{}\">", frame.w, frame.h, data["fps"], t3(data["duration"].as_f64().unwrap_or(0.0)));
    let _ = writeln!(h, "<svg class=\"svgdefs\" aria-hidden=\"true\"><defs><linearGradient id=\"goldgrad\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#fbe7a6\"/><stop offset=\"0.45\" stop-color=\"#e6b446\"/><stop offset=\"0.75\" stop-color=\"#a8701e\"/><stop offset=\"1\" stop-color=\"#e9c060\"/></linearGradient></defs></svg>");
    for c in clips {
        let _ = write!(
            h,
            "<div id=\"{}\" class=\"clip scene-{}\" data-scene=\"{}\" data-start=\"{}\" data-duration=\"{}\" data-track-index=\"{}\"",
            esc(&c.id), esc(&c.scene), esc(&c.scene), t3(c.start), t3(c.duration), c.track
        );
        if let Some(i) = c.item {
            let _ = write!(h, " data-item=\"{i}\"");
        }
        if let Some(s) = &c.src {
            let _ = write!(h, " data-src=\"{}\"", esc(s));
        }
        let _ = writeln!(h, "></div>");
    }
    if frame.bars > 0.0 {
        let _ = writeln!(h, "<div class=\"bars top\"></div><div class=\"bars bottom\"></div>");
    }
    let _ = writeln!(h, "</div>");
    let json = serde_json::to_string(data).unwrap_or_default().replace("</", "<\\/");
    let _ = writeln!(h, "<script id=\"comp-data\" type=\"application/json\">{json}</script>");
    let _ = writeln!(h, "<script src=\"scenes.js\"></script>");
    let _ = writeln!(h, "<script src=\"runtime.js\"></script>");
    let _ = writeln!(h, "</body>\n</html>");
    h
}

/// Écrit la composition dans `dir`. `extract_plates = false` calcule les noms des
/// plaques sans lancer ffmpeg (aperçu live sans vidéo, tests).
pub fn compose(
    p: &Project,
    base: &Path,
    dir: &Path,
    quality: Quality,
    extract_plates: bool,
    cancel: Option<&Cancel>,
    mut progress: impl FnMut(f64),
) -> Result<Composition> {
    if p.duration() <= 0.0 {
        bail!("projet vide : aucune durée");
    }
    let issues = check_safe_zone(p);
    std::fs::create_dir_all(dir.join("fonts"))?;
    std::fs::create_dir_all(dir.join("img"))?;
    write_if_changed(&dir.join("gsap.min.js"), GSAP_JS)?;
    write_if_changed(&dir.join("runtime.js"), RUNTIME_JS)?;
    write_if_changed(&dir.join("scenes.js"), SCENES_JS)?;
    write_if_changed(&dir.join("style.css"), &(css_root() + STYLE_CSS))?;
    let fdir = fonts_dir();
    for f in FONTS {
        let src = fdir.join(f);
        if src.exists() {
            copy_if_changed(&src, &dir.join("fonts").join(f))?;
        }
    }
    // Images : captures d'avis et fond des cartes, copiées dans img/.
    let mut imgs: Vec<Vec<(String, u32, u32)>> = Vec::new();
    let mut bgs: Vec<Option<String>> = Vec::new();
    for (gi, g) in p.graphics().enumerate() {
        let mut v = Vec::new();
        let mut bg = None;
        let copy = |k: usize, path: &str| -> Result<String> {
            let src = resolve(base, path);
            let ext = src.extension().and_then(|e| e.to_str()).unwrap_or("png").to_lowercase();
            let name = format!("img/g{gi}_{k}.{ext}");
            copy_if_changed(&src, &dir.join(&name)).with_context(|| format!("image {}", src.display()))?;
            Ok(name)
        };
        match g {
            GraphicItem::Reviews { images, .. } => {
                for (k, path) in images.iter().enumerate() {
                    let name = copy(k, path)?;
                    let pr = ffmpeg::probe(dir.join(&name))?;
                    v.push((name, pr.width.unwrap_or(1000), pr.height.unwrap_or(600)));
                }
            }
            GraphicItem::Mech { background: Some(b), .. } => {
                // Image de fond (sinon la plaque vidéo sous la scène est assombrie).
                let src = resolve(base, b);
                let is_img = src.extension().and_then(|e| e.to_str()).is_some_and(|e| matches!(e.to_lowercase().as_str(), "png" | "jpg" | "jpeg" | "webp"));
                if is_img && src.exists() {
                    bg = Some(copy(0, b)?);
                }
            }
            _ => {}
        }
        imgs.push(v);
        bgs.push(bg);
    }
    let segs = plates::build(p, base, dir, quality, extract_plates, cancel, &mut progress)?;
    let onsets = music_onsets(p, base);
    let (data, clips) = comp_data(p, &segs, &onsets, &|i| imgs.get(i).cloned().unwrap_or_default(), &|i| bgs.get(i).cloned().flatten());
    let index = dir.join("index.html");
    write_if_changed(&index, &index_html(&data, &clips, &Frame::new(&p.format)))?;
    let frames = plates::total_frames(p);
    Ok(Composition { dir: dir.to_path_buf(), index, duration: frames as f64 / p.format.fps as f64, frames, segs, clips, issues })
}

/// Arguments ffmpeg du passage final : plaques concaténées (noir dans les trous),
/// calque graphique PNG lu sur l'entrée standard, mix audio, grain, bandes 16:9.
pub fn composite_args(p: &Project, comp: &Composition, quality: Quality, mix: &Path, out: &Path) -> Vec<String> {
    let (w, h, fps) = (p.format.w, p.format.h, p.format.fps);
    let mut args: Vec<String> = vec!["-v".into(), "error".into()];
    let mut graph = String::new();
    let mut labels = String::new();
    let mut input = 0usize;
    for (k, s) in comp.segs.iter().enumerate() {
        match s {
            Seg::Clip { file, .. } => {
                args.extend(["-i".into(), comp.dir.join(file).display().to_string()]);
                let _ = writeln!(graph, "[{input}:v]trim=end_frame={},setpts=N/{fps}/TB,setsar=1,format=yuv444p[s{k}];", s.frames());
                input += 1;
            }
            Seg::Black { .. } => {
                let _ = writeln!(graph, "color=c=black:s={w}x{h}:r={fps},trim=end_frame={},setpts=N/{fps}/TB,setsar=1,format=yuv444p[s{k}];", s.frames());
            }
        }
        let _ = write!(labels, "[s{k}]");
    }
    let gfx = input;
    // Chromium encode en RGB (sans alpha) les images entièrement opaques : sans
    // `-reinit_filter 0`, ce changement de format reconstruirait tout le graphe
    // (compteurs remis à zéro, images perdues). On convertit en RGBA à la volée.
    args.extend([
        "-reinit_filter".into(), "0".into(),
        "-f".into(), "image2pipe".into(),
        "-framerate".into(), fps.to_string(),
        "-c:v".into(), "png".into(),
        "-i".into(), "-".into(),
    ]);
    let audio = gfx + 1;
    args.extend(["-i".into(), mix.display().to_string()]);
    // Horodatages reconstruits image par image (N / fps) : fond et calque restent
    // alignés à la frame près, sans doublon ni perte au passage CFR.
    let _ = writeln!(graph, "{labels}concat=n={}:v=1:a=0,setpts=N/{fps}/TB[bg];", comp.segs.len());
    let _ = writeln!(graph, "[{gfx}:v]setpts=N/{fps}/TB,format=rgba[gfx];");
    let _ = write!(graph, "[bg][gfx]overlay=0:0:format=yuv444:eof_action=pass:shortest=0");
    if quality == Quality::Delivery {
        let _ = write!(graph, ",{}", style::GRAIN);
    }
    if !p.format.is_vertical() {
        let lb = (style::LETTERBOX as f64 * h as f64 / 1080.0).round() as u32;
        let _ = write!(graph, ",drawbox=x=0:y=0:w=iw:h={lb}:c=black:t=fill,drawbox=x=0:y=ih-{lb}:w=iw:h={lb}:c=black:t=fill");
    }
    let _ = writeln!(graph, ",format=yuv420p[vout];");
    let _ = write!(
        graph,
        "[{audio}:a]acompressor=threshold=-18dB:ratio=3:attack=5:release=120,loudnorm=I=-14:TP=-1.2:LRA=9,aresample=48000,aformat=channel_layouts=stereo[aout]"
    );
    let (preset, crf) = match quality {
        Quality::Preview => ("veryfast", "23"),
        Quality::Delivery => ("medium", "20"),
    };
    args.extend([
        "-filter_complex".into(), graph,
        "-map".into(), "[vout]".into(),
        "-map".into(), "[aout]".into(),
        "-frames:v".into(), comp.frames.to_string(),
        "-r".into(), fps.to_string(),
        "-c:v".into(), "libx264".into(),
        "-preset".into(), preset.into(),
        "-crf".into(), crf.into(),
        "-pix_fmt".into(), "yuv420p".into(),
        "-c:a".into(), "aac".into(),
        "-b:a".into(), "192k".into(),
        "-movflags".into(), "+faststart".into(),
        "-t".into(), format!("{:.4}", comp.duration),
        out.display().to_string(),
    ]);
    args
}

/// Script Node du renderer : `DESTINY_RENDERER`, sinon `renderer/render.mjs` du dépôt
/// (développement), sinon à côté de l'exécutable.
pub fn renderer_path() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("DESTINY_RENDERER") {
        return Ok(p.into());
    }
    let dev = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../renderer/render.mjs");
    if dev.exists() {
        return Ok(dev);
    }
    if let Some(p) = std::env::current_exe().ok().and_then(|e| e.parent().map(|d| d.join("renderer/render.mjs"))) {
        if p.exists() {
            return Ok(p);
        }
    }
    bail!("renderer/render.mjs introuvable (définir DESTINY_RENDERER)")
}

fn node_bin() -> String {
    ffmpeg::tool_bin("DESTINY_NODE", &["/opt/homebrew/bin/node", "/usr/local/bin/node"], "node")
}

fn workers() -> usize {
    std::env::var("DESTINY_RENDER_WORKERS").ok().and_then(|s| s.parse().ok()).unwrap_or_else(|| {
        std::thread::available_parallelism().map(|n| n.get().saturating_sub(1).clamp(1, 4)).unwrap_or(2)
    })
}

/// Arrête un processus par son PID (SIGTERM puis SIGKILL), jamais par motif.
fn stop(child: &mut Child) {
    if let Ok(Some(_)) = child.try_wait() {
        return;
    }
    #[cfg(unix)]
    {
        let _ = Command::new("kill").arg("-TERM").arg(child.id().to_string()).status();
        for _ in 0..30 {
            if let Ok(Some(_)) = child.try_wait() {
                return;
            }
            std::thread::sleep(Duration::from_millis(50));
        }
    }
    let _ = child.kill();
    let _ = child.wait();
}

enum Ev {
    Frame(u64, u64),
    Warn(String),
    Line(String),
}

/// Rendu Chromium du calque graphique branché sur le passage ffmpeg final.
/// Renvoie les avertissements (zone sûre mesurée dans le navigateur).
pub fn run_pipeline(
    comp: &Composition,
    p: &Project,
    ff_args: &[String],
    cancel: Option<&Cancel>,
    mut progress: impl FnMut(f64),
) -> Result<Vec<String>> {
    let script = renderer_path()?;
    let mut node = Command::new(node_bin())
        .arg(&script)
        .args(["--comp", &comp.dir.display().to_string()])
        .args(["--fps", &p.format.fps.to_string()])
        .args(["--w", &p.format.w.to_string(), "--h", &p.format.h.to_string()])
        .args(["--frames", &comp.frames.to_string()])
        .args(["--workers", &workers().to_string()])
        .args(["--out", "-"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("node introuvable ({})", node_bin()))?;
    let node_out = node.stdout.take().context("stdout node")?;
    let node_err = node.stderr.take().context("stderr node")?;
    let mut ff = match Command::new(ffmpeg::ffmpeg_bin())
        .args(["-hide_banner", "-nostats", "-y"])
        .args(ff_args)
        .stdin(Stdio::from(node_out))
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            stop(&mut node);
            return Err(e).context("ffmpeg introuvable");
        }
    };
    let mut ff_err = ff.stderr.take().context("stderr ffmpeg")?;
    let ff_thread = std::thread::spawn(move || {
        let mut s = String::new();
        let _ = ff_err.read_to_string(&mut s);
        s
    });
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        for line in BufReader::new(node_err).lines().map_while(Result::ok) {
            let ev = if let Some(r) = line.strip_prefix("frame ") {
                let mut it = r.split('/');
                match (it.next().and_then(|a| a.trim().parse().ok()), it.next().and_then(|b| b.trim().parse().ok())) {
                    (Some(a), Some(b)) => Ev::Frame(a, b),
                    _ => Ev::Line(line),
                }
            } else if let Some(w) = line.strip_prefix("warn ") {
                Ev::Warn(w.to_string())
            } else {
                Ev::Line(line)
            };
            if tx.send(ev).is_err() {
                break;
            }
        }
    });
    let mut warns = Vec::new();
    let mut tail: Vec<String> = Vec::new();
    loop {
        match rx.recv_timeout(Duration::from_millis(100)) {
            Ok(Ev::Frame(a, b)) => progress(a as f64 / b.max(1) as f64),
            Ok(Ev::Warn(w)) => warns.push(w),
            Ok(Ev::Line(l)) => {
                tail.push(l);
                if tail.len() > 30 {
                    tail.remove(0);
                }
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
        }
        if cancel.is_some_and(|c| c.is_cancelled()) {
            stop(&mut node);
            stop(&mut ff);
            bail!("rendu annulé");
        }
    }
    let node_status = node.wait()?;
    let ff_status = ff.wait()?;
    let ff_log = ff_thread.join().unwrap_or_default();
    if !ff_status.success() {
        let t: Vec<&str> = ff_log.lines().rev().take(15).collect();
        bail!("ffmpeg (composition finale) a échoué ({ff_status}) :\n{}", t.into_iter().rev().collect::<Vec<_>>().join("\n"));
    }
    if !node_status.success() {
        bail!("renderer Chromium a échoué ({node_status}) :\n{}", tail.join("\n"));
    }
    progress(1.0);
    Ok(warns)
}

/// Rendu complet d'un trailer / reel (même forme que [`crate::render_a::render`]).
pub fn render(
    p: &Project,
    base: &Path,
    work: &Path,
    out: &Path,
    quality: Quality,
    cancel: Option<&Cancel>,
    mut progress: impl FnMut(&str, f64),
) -> Result<RenderJob> {
    validate_safe_zone(p)?;
    std::fs::create_dir_all(work)?;
    progress("plates", 0.0);
    let comp = compose(p, base, &work.join("comp"), quality, true, cancel, |x| progress("plates", x))?;
    progress("mix", 0.0);
    let mut resolved = p.clone();
    for s in &mut resolved.sources {
        s.path = resolve(base, &s.path).display().to_string();
        s.proxy = s.proxy.as_ref().map(|x| resolve(base, x).display().to_string());
    }
    for m in &mut resolved.mics {
        m.path = resolve(base, &m.path).display().to_string();
    }
    let mix = crate::mixer::mix(&resolved, comp.duration, base, quality == Quality::Preview)?;
    let mix_path = work.join("mix.wav");
    crate::mixer::write_mix(&mix_path, &mix)?;
    progress("mix", 1.0);
    if let Some(d) = out.parent() {
        if !d.as_os_str().is_empty() {
            std::fs::create_dir_all(d)?;
        }
    }
    let args = composite_args(p, &comp, quality, &mix_path, out);
    // Trace de la commande finale (rejouable : `ffmpeg … < flux PNG`).
    std::fs::write(work.join("composite_args.json"), serde_json::to_string_pretty(&args)?)?;
    progress("video", 0.0);
    let warns = run_pipeline(&comp, p, &args, cancel, |x| progress("video", x))?;
    let warn_file = work.join("warnings.txt");
    if warns.is_empty() {
        let _ = std::fs::remove_file(&warn_file);
    } else {
        std::fs::write(&warn_file, warns.join("\n") + "\n")?;
        eprintln!("moteur B : {} avertissement(s) de zone sûre, voir {}", warns.len(), warn_file.display());
    }
    Ok(RenderJob { args, duration: comp.duration, ass_path: comp.index, mix_path, out: out.to_path_buf() })
}

#[cfg(test)]
mod tests;
