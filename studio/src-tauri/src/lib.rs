//! Shell Tauri de Destiny Studio : expose le cœur (`destiny-core`) au front Svelte.
//! Tout passe par `project.json` : chaque édition de l'UI est validée, diffée
//! (undo/redo) puis réécrite atomiquement, pour que Claude Code voie le même fichier.

mod agent;
mod jobs;

use std::path::{Path, PathBuf};
use std::sync::Mutex;

use destiny_core::history::History;
use destiny_core::render_a::{self, Quality, RenderJob};
use destiny_core::render_b;
use destiny_core::{asr, ingest, mics, music, nas, propose, verify, Project};
use serde::Serialize;
use serde_json::Value;
use tauri::{AppHandle, Manager, State};

use crate::jobs::Jobs;

type CmdResult<T> = Result<T, String>;

fn err(e: impl std::fmt::Display) -> String {
    // anyhow : on garde la chaîne de causes, utile à Marouene.
    format!("{e:#}")
}

#[derive(Default)]
struct Open {
    path: Option<PathBuf>,
    project: Option<Project>,
    history: History,
}

#[derive(Default)]
struct AppState {
    open: Mutex<Open>,
    /// Dossier de la composition live du moteur B, servi par le protocole `comp://`.
    comp: Mutex<Option<PathBuf>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ProjectState {
    path: String,
    project: Project,
    can_undo: bool,
    can_redo: bool,
    undo_label: Option<String>,
    redo_label: Option<String>,
}

fn state_of(o: &Open) -> CmdResult<ProjectState> {
    let (Some(path), Some(project)) = (&o.path, &o.project) else {
        return Err("aucun projet ouvert".into());
    };
    Ok(ProjectState {
        path: path.display().to_string(),
        project: project.clone(),
        can_undo: !o.history.undo.is_empty(),
        can_redo: !o.history.redo.is_empty(),
        undo_label: o.history.undo.last().map(|e| e.label.clone()),
        redo_label: o.history.redo.last().map(|e| e.label.clone()),
    })
}

fn save(o: &Open) -> CmdResult<()> {
    if let (Some(p), Some(prj)) = (&o.path, &o.project) {
        prj.save(p).map_err(err)?;
    }
    Ok(())
}

/// Projet ouvert (copie) + son dossier, pour les jobs longs.
fn current(state: &State<AppState>) -> CmdResult<(PathBuf, Project)> {
    let o = state.open.lock().unwrap();
    match (&o.path, &o.project) {
        (Some(p), Some(prj)) => Ok((p.clone(), prj.clone())),
        _ => Err("aucun projet ouvert".into()),
    }
}

fn project_dir(path: &Path) -> PathBuf {
    path.parent().map(Path::to_path_buf).unwrap_or_else(|| ".".into())
}

fn cache_dir(path: &Path) -> PathBuf {
    project_dir(path).join(".cache")
}

fn name_of(path: &Path, p: &Project) -> String {
    p.export.name.clone().unwrap_or_else(|| path.file_stem().and_then(|s| s.to_str()).unwrap_or("montage").to_string())
}

/// Chemins relatifs résolus par rapport au dossier du projet.
fn resolved(path: &Path, p: &Project) -> Project {
    let base = project_dir(path);
    let mut r = p.clone();
    for s in &mut r.sources {
        s.path = render_a::resolve(&base, &s.path).display().to_string();
        s.proxy = s.proxy.as_ref().map(|x| render_a::resolve(&base, x).display().to_string());
    }
    for m in &mut r.mics {
        m.path = render_a::resolve(&base, &m.path).display().to_string();
    }
    r
}

// ---------------------------------------------------------------- bibliothèque

#[tauri::command]
fn default_root() -> String {
    std::env::var("DESTINY_ROOT").ok().map(PathBuf::from).unwrap_or_else(|| {
        dirs::home_dir().unwrap_or_else(|| ".".into()).join("DestinyStudio")
    })
    .display()
    .to_string()
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct LibraryEntry {
    dir: String,
    name: String,
    projects: Vec<String>,
    /// Résumé de chaque montage (le plus récent d'abord), pour la vue « Tous les projets ».
    montages: Vec<MontageInfo>,
    has_ingest: bool,
    transcripts: Vec<String>,
    sheets: Vec<String>,
    modified: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MontageInfo {
    path: String,
    name: String,
    preset: destiny_core::project::Preset,
    duration: f64,
    modified: u64,
    /// `project.json` de l'ingest : les rushes du spectacle, pas un montage.
    master: bool,
}

fn mtime(path: &Path) -> u64 {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Montages d'un spectacle : `*.json` du dossier et de `montages/` (là où les propositions
/// sont écrites). Les JSON qui ne sont pas des projets sont ignorés.
fn montages_of(dir: &Path) -> Vec<MontageInfo> {
    let mut paths = list_files(dir, |n| n.ends_with(".json"));
    paths.extend(list_files(&dir.join("montages"), |n| n.ends_with(".json")));
    let mut v: Vec<MontageInfo> = paths
        .into_iter()
        .filter_map(|p| {
            let path = PathBuf::from(&p);
            let prj = Project::load(&path).ok()?;
            Some(MontageInfo {
                name: path.file_stem()?.to_string_lossy().into_owned(),
                preset: prj.preset,
                duration: prj.duration(),
                modified: mtime(&path),
                master: path.parent() == Some(dir) && path.file_name().is_some_and(|n| n == "project.json"),
                path: p,
            })
        })
        .collect();
    v.sort_by(|a, b| b.modified.cmp(&a.modified).then_with(|| a.name.cmp(&b.name)));
    v
}

/// Premier chemin libre : `nom.json`, sinon `nom_2.json`, `nom_3.json`… Un nouveau montage
/// n'écrase jamais un montage existant.
fn free_path(path: &Path) -> PathBuf {
    if !path.exists() {
        return path.to_path_buf();
    }
    let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("montage");
    // Repart de la racine du nom : dupliquer « x_2 » donne « x_3 », pas « x_2_2 ».
    let root = match stem.rsplit_once('_') {
        Some((r, n)) if !r.is_empty() && n.parse::<u32>().is_ok() => r,
        _ => stem,
    };
    let dir = path.parent().unwrap_or(Path::new("."));
    (2..).map(|k| dir.join(format!("{root}_{k}.json"))).find(|p| !p.exists()).unwrap()
}

fn list_files(dir: &Path, pred: impl Fn(&str) -> bool) -> Vec<String> {
    let mut v: Vec<String> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_file() && p.file_name().and_then(|n| n.to_str()).is_some_and(&pred))
        .map(|p| p.display().to_string())
        .collect();
    v.sort();
    v
}

/// Un spectacle = un dossier projet sous la racine (project.json + montages + .cache).
#[tauri::command]
fn library(root: String) -> CmdResult<Vec<LibraryEntry>> {
    let root = PathBuf::from(root);
    std::fs::create_dir_all(&root).map_err(err)?;
    let mut out = Vec::new();
    for e in std::fs::read_dir(&root).map_err(err)?.flatten() {
        let dir = e.path();
        if !dir.is_dir() || dir.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with('.')) {
            continue;
        }
        let cache = dir.join(".cache");
        let montages = montages_of(&dir);
        // Un spectacle « bouge » quand un de ses montages bouge.
        let modified = montages.iter().map(|m| m.modified).fold(mtime(&dir), u64::max);
        out.push(LibraryEntry {
            name: dir.file_name().unwrap().to_string_lossy().into_owned(),
            projects: montages.iter().map(|m| m.path.clone()).collect(),
            montages,
            has_ingest: cache.join("ingest.json").exists(),
            transcripts: list_files(&cache, |n| n.starts_with("transcript_") && n.ends_with(".json")),
            sheets: list_files(&cache.join("sheets"), |n| n.ends_with(".jpg")),
            dir: dir.display().to_string(),
            modified,
        });
    }
    out.sort_by(|a, b| b.modified.cmp(&a.modified));
    Ok(out)
}

#[tauri::command]
fn read_json(path: String) -> CmdResult<Value> {
    let txt = std::fs::read_to_string(&path).map_err(err)?;
    serde_json::from_str(&txt).map_err(err)
}

// ---------------------------------------------------------------- projet

#[tauri::command]
fn open_project(path: String, state: State<AppState>) -> CmdResult<ProjectState> {
    let project = Project::load(&path).map_err(err)?;
    let mut o = state.open.lock().unwrap();
    *o = Open { path: Some(PathBuf::from(path)), project: Some(project), history: History::default() };
    state_of(&o)
}

#[tauri::command]
fn commit_project(project: Project, label: String, state: State<AppState>) -> CmdResult<ProjectState> {
    let mut o = state.open.lock().unwrap();
    let Open { project: cur, history, .. } = &mut *o;
    let cur = cur.as_mut().ok_or("aucun projet ouvert")?;
    history.commit(cur, project, label).map_err(err)?;
    save(&o)?;
    state_of(&o)
}

#[tauri::command]
fn apply_patch(patch: json_patch::Patch, label: String, state: State<AppState>) -> CmdResult<ProjectState> {
    let mut o = state.open.lock().unwrap();
    let Open { project: cur, history, .. } = &mut *o;
    let cur = cur.as_mut().ok_or("aucun projet ouvert")?;
    history.apply_patch(cur, &patch, label).map_err(err)?;
    save(&o)?;
    state_of(&o)
}

#[tauri::command]
fn undo(state: State<AppState>) -> CmdResult<ProjectState> {
    let mut o = state.open.lock().unwrap();
    let Open { project: cur, history, .. } = &mut *o;
    history.undo(cur.as_mut().ok_or("aucun projet ouvert")?).map_err(err)?;
    save(&o)?;
    state_of(&o)
}

#[tauri::command]
fn redo(state: State<AppState>) -> CmdResult<ProjectState> {
    let mut o = state.open.lock().unwrap();
    let Open { project: cur, history, .. } = &mut *o;
    history.redo(cur.as_mut().ok_or("aucun projet ouvert")?).map_err(err)?;
    save(&o)?;
    state_of(&o)
}

// ---------------------------------------------------------------- analyse

#[tauri::command]
async fn music_analysis(file: String) -> CmdResult<music::MusicAnalysis> {
    tauri::async_runtime::spawn_blocking(move || music::analyze_file(&file).map_err(err)).await.map_err(err)?
}

#[tauri::command]
fn propose_short(
    from: f64,
    to: f64,
    opts: propose::ShortOpts,
    transcript: Option<String>,
    out: String,
    state: State<AppState>,
) -> CmdResult<String> {
    let (_, p) = current(&state)?;
    let t = transcript.map(|t| asr::Transcript::load(Path::new(&t))).transpose().map_err(err)?;
    let s = propose::short_scene(&p, t.as_ref(), from, to, &opts).map_err(err)?;
    let out = free_path(Path::new(&out));
    s.save(&out).map_err(err)?;
    Ok(out.display().to_string())
}

/// Copie d'un montage sous un nom libre (variante sans toucher à l'original).
#[tauri::command]
fn duplicate_project(path: String) -> CmdResult<String> {
    let src = PathBuf::from(&path);
    let p = Project::load(&src).map_err(err)?;
    let out = free_path(&src);
    p.save(&out).map_err(err)?;
    Ok(out.display().to_string())
}

#[tauri::command]
fn ingest(dir: String, project_dir: String, proxies: bool, sheets: bool, app: AppHandle, jobs: State<Jobs>) -> String {
    jobs.spawn(&app, "ingest", move |ctx| {
        let pdir = PathBuf::from(&project_dir);
        let cache = pdir.join(".cache");
        std::fs::create_dir_all(&cache)?;
        ctx.progress("scan", 0.0);
        let mut index = ingest::scan(Path::new(&dir))?;
        let n = index.files.len().max(1) as f64;
        for (i, f) in index.files.iter_mut().enumerate() {
            let is_video = matches!(f.kind, ingest::MediaKind::Camera | ingest::MediaKind::Edit);
            if is_video && f.proxy.is_none() {
                let px = ingest::proxy_path(&cache, &f.path);
                if proxies && !px.exists() {
                    ingest::make_proxy(Path::new(&f.path), &px, |x| ctx.progress("proxy", (i as f64 + x) / n))?;
                }
                if px.exists() {
                    f.proxy = Some(px.display().to_string());
                }
            }
            ctx.check()?;
        }
        std::fs::write(cache.join("ingest.json"), serde_json::to_string_pretty(&index)?)?;
        let p = ingest::initial_project(&index, destiny_core::Preset::ShortScene);
        if sheets {
            for (i, s) in p.sources.iter().enumerate() {
                ctx.progress("planches", i as f64 / p.sources.len().max(1) as f64);
                let v = s.proxy.as_deref().unwrap_or(&s.path);
                ingest::contact_sheets(Path::new(v), &cache.join("sheets"), destiny_core::sync::rec_seconds(s.rec), 6)?;
            }
        }
        let path = pdir.join("project.json");
        if !path.exists() {
            p.save(&path)?;
        }
        Ok(serde_json::json!({ "project": path, "files": index.files.len() }))
    })
}

#[tauri::command]
fn analyze(from: f64, to: f64, model: Option<String>, app: AppHandle, jobs: State<Jobs>, state: State<AppState>) -> CmdResult<String> {
    let (path, p) = current(&state)?;
    Ok(jobs.spawn(&app, "analyze", move |ctx| {
        let r = resolved(&path, &p);
        let cache = cache_dir(&path);
        std::fs::create_dir_all(&cache)?;
        ctx.progress("transcription", 0.0);
        let t = asr::transcribe_project(&r, from, to, model.as_deref().map(Path::new))?;
        let tag = format!("{from:.0}-{to:.0}");
        let tpath = cache.join(format!("transcript_{tag}.json"));
        t.save(&tpath)?;
        ctx.progress("micros", 0.6);
        let map = mics::mic_map(&r, from, to)?;
        std::fs::write(cache.join(format!("micmap_{tag}.json")), serde_json::to_string(&map)?)?;
        let suspects = mics::detect_whispers(&map);
        Ok(serde_json::json!({ "transcript": tpath, "micmap": cache.join(format!("micmap_{tag}.json")), "suspects": suspects }))
    }))
}

// ---------------------------------------------------------------- rendu

/// Moteur A (shorts, ffmpeg + ASS) ou moteur B (trailers et reels, HTML/GSAP) selon le preset.
fn engine_render(
    p: &Project,
    base: &Path,
    work: &Path,
    out: &Path,
    q: Quality,
    cancel: Option<&destiny_core::ffmpeg::Cancel>,
    progress: impl FnMut(&str, f64),
) -> anyhow::Result<RenderJob> {
    if render_b::handles(p.preset) {
        render_b::render(p, base, work, out, q, cancel, progress)
    } else {
        render_a::render(p, base, work, out, q, cancel, progress)
    }
}

fn render_project(
    path: &Path,
    p: &Project,
    out: &Path,
    q: Quality,
    ctx: &jobs::Ctx,
) -> anyhow::Result<verify::Report> {
    let base = project_dir(path);
    let work = cache_dir(path).join("render").join(name_of(path, p));
    let job = engine_render(p, &base, &work, out, q, Some(&ctx.cancel), |stage, x| ctx.progress(stage, x))?;
    verify::check(out, job.duration, Some((p.format.w, p.format.h)))
}

#[tauri::command]
fn render(quality: String, out: Option<String>, app: AppHandle, jobs: State<Jobs>, state: State<AppState>) -> CmdResult<String> {
    let (path, p) = current(&state)?;
    let q = if quality == "delivery" { Quality::Delivery } else { Quality::Preview };
    let out = out.map(PathBuf::from).unwrap_or_else(|| {
        cache_dir(&path).join("exports").join(format!("{}_{quality}.mp4", name_of(&path, &p)))
    });
    Ok(jobs.spawn(&app, "render", move |ctx| {
        std::fs::create_dir_all(out.parent().unwrap())?;
        let report = render_project(&path, &p, &out, q, ctx)?;
        Ok(serde_json::json!({ "out": out, "report": report }))
    }))
}

/// Image exacte à l'instant t (aperçu rendu, mis en cache selon le contenu du projet).
#[tauri::command]
async fn snapshot(t: f64, state: State<'_, AppState>) -> CmdResult<String> {
    let (path, p) = current(&state)?;
    tauri::async_runtime::spawn_blocking(move || -> anyhow::Result<String> {
        use std::hash::{Hash, Hasher};
        let mut h = std::collections::hash_map::DefaultHasher::new();
        p.to_json()?.hash(&mut h);
        let cache = cache_dir(&path);
        let preview = cache.join(format!("preview_{:016x}.mp4", h.finish()));
        if !preview.exists() {
            let work = cache.join("render").join(name_of(&path, &p));
            engine_render(&p, &project_dir(&path), &work, &preview, Quality::Preview, None, |_, _| {})?;
        }
        let png = cache.join("snapshots").join(format!("{}_{t:07.3}.png", name_of(&path, &p)));
        std::fs::create_dir_all(png.parent().unwrap())?;
        destiny_core::ffmpeg::extract_frame(&preview, t, &png)?;
        Ok(png.display().to_string())
    })
    .await
    .map_err(err)?
    .map_err(err)
}

#[tauri::command]
fn export_project(targets: Option<Vec<String>>, app: AppHandle, jobs: State<Jobs>, state: State<AppState>) -> CmdResult<String> {
    let (path, p) = current(&state)?;
    Ok(jobs.spawn(&app, "export", move |ctx| {
        let local = cache_dir(&path).join("exports");
        std::fs::create_dir_all(&local)?;
        let file = local.join(format!("{}_{}x{}.mp4", name_of(&path, &p), p.format.w, p.format.h));
        // Rendu local d'abord : le NAS est lent en écriture.
        let report = render_project(&path, &p, &file, Quality::Delivery, ctx)?;
        if !report.ok() {
            anyhow::bail!("export refusé : {}", report.problems.join(" ; "));
        }
        let mut copies = Vec::new();
        for t in targets.unwrap_or_else(|| p.export.targets.clone()) {
            let dst = nas::resolve_target(&t).join(file.file_name().unwrap());
            let r = nas::copy_resumable(&file, &dst, |d, tot| ctx.progress("copie NAS", d as f64 / tot.max(1) as f64))?;
            copies.push(serde_json::json!({ "dest": dst, "result": format!("{r:?}") }));
        }
        Ok(serde_json::json!({ "out": file, "report": report, "copies": copies }))
    }))
}

#[tauri::command]
fn cancel_job(id: String, jobs: State<Jobs>) {
    jobs.cancel(&id);
}

// ---------------------------------------------------------------- médias de la timeline

/// Dossier de cache médias du projet ouvert (sinon dossier temporaire) et chemin résolu.
fn media_paths(state: &State<AppState>, path: &str) -> (PathBuf, PathBuf) {
    let o = state.open.lock().unwrap();
    let base = o.path.as_deref().map(project_dir);
    let file = match &base {
        Some(b) => render_a::resolve(b, path),
        None => PathBuf::from(path),
    };
    let cache = base.map(|b| destiny_core::media::cache_dir(&b)).unwrap_or_else(|| std::env::temp_dir().join("destiny-media"));
    (file, cache)
}

/// Vignettes d'un plan (temps source) pour la bande d'images de la timeline.
#[tauri::command]
async fn thumbs(path: String, from: f64, to: f64, step: f64, height: u32, state: State<'_, AppState>) -> CmdResult<Vec<destiny_core::media::Thumb>> {
    let (file, cache) = media_paths(&state, &path);
    tauri::async_runtime::spawn_blocking(move || destiny_core::media::thumbs(&file, from, to, step, height, &cache.join("thumbs")))
        .await
        .map_err(err)?
        .map_err(err)
}

/// Forme d'onde (0..1) de `[from, to]` secondes du fichier, en `buckets` cases.
#[tauri::command]
async fn waveform(path: String, from: f64, to: f64, buckets: usize, state: State<'_, AppState>) -> CmdResult<Vec<f32>> {
    let (file, cache) = media_paths(&state, &path);
    tauri::async_runtime::spawn_blocking(move || {
        let env = destiny_core::media::envelope(&file, &cache.join("wave"))?;
        Ok::<_, anyhow::Error>(destiny_core::media::slice(&env, from, to, buckets))
    })
    .await
    .map_err(err)?
    .map_err(err)
}

// ---------------------------------------------------------------- aperçu live (moteur B)

/// Écrit la composition HTML/GSAP du projet ouvert dans `.cache/live/` pour l'aperçu de
/// l'éditeur. Sans plaques vidéo (pas d'ffmpeg lourd) : l'iframe transparente se pose sur
/// le proxy que l'aperçu lit déjà. Renvoie un jeton qui change à chaque écriture (`None`
/// pour les shorts, simulés directement en Svelte).
#[tauri::command]
async fn compose_preview(state: State<'_, AppState>) -> CmdResult<Option<String>> {
    let (path, p) = current(&state)?;
    if !render_b::handles(p.preset) {
        return Ok(None);
    }
    let dir = cache_dir(&path).join("live").join(name_of(&path, &p));
    let base = project_dir(&path);
    let d = dir.clone();
    tauri::async_runtime::spawn_blocking(move || {
        render_b::compose(&resolved(&path, &p), &base, &d, Quality::Preview, false, None, |_| {})
    })
    .await
    .map_err(err)?
    .map_err(err)?;
    *state.comp.lock().unwrap() = Some(dir);
    let ms = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0);
    Ok(Some(ms.to_string()))
}

/// `comp://localhost/<fichier>` → fichier du dossier de composition. Un protocole dédié
/// plutôt que `asset://` : celui-ci encode le chemin entier dans un seul segment d'URL, ce qui
/// casse les liens relatifs de `index.html` (style.css, polices, images).
fn serve_comp(dir: Option<PathBuf>, uri_path: &str) -> tauri::http::Response<Vec<u8>> {
    let not_found = || tauri::http::Response::builder().status(404).body(Vec::new()).unwrap();
    let Some(dir) = dir else { return not_found() };
    let rel = percent_decode(uri_path.trim_start_matches('/'));
    let rel = if rel.is_empty() { "index.html".to_string() } else { rel };
    // Pas de sortie du dossier de composition.
    if Path::new(&rel).components().any(|c| !matches!(c, std::path::Component::Normal(_))) {
        return not_found();
    }
    let Ok(bytes) = std::fs::read(dir.join(&rel)) else { return not_found() };
    let mime = match Path::new(&rel).extension().and_then(|e| e.to_str()).unwrap_or("") {
        "html" => "text/html; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "js" => "text/javascript; charset=utf-8",
        "json" => "application/json",
        "ttf" => "font/ttf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "webp" => "image/webp",
        "mp4" => "video/mp4",
        _ => "application/octet-stream",
    };
    tauri::http::Response::builder()
        .header("Content-Type", mime)
        // Chaque édition réécrit la composition : jamais de cache.
        .header("Cache-Control", "no-store")
        .body(bytes)
        .unwrap()
}

fn percent_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            if let Ok(v) = u8::from_str_radix(&s[i + 1..i + 3], 16) {
                out.push(v);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

// ---------------------------------------------------------------- agent

#[tauri::command]
async fn ask_claude(instruction: String, state: State<'_, AppState>) -> CmdResult<agent::Proposal> {
    let (path, p) = current(&state)?;
    tauri::async_runtime::spawn_blocking(move || agent::ask(&path, &p, &instruction))
        .await
        .map_err(err)?
        .map_err(err)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState::default())
        .manage(Jobs::default())
        .register_uri_scheme_protocol("comp", |ctx, req| {
            let dir = ctx.app_handle().state::<AppState>().comp.lock().unwrap().clone();
            serve_comp(dir, req.uri().path())
        })
        .setup(|app| {
            // Polices embarquées (moteur A) : ressources du bundle.
            if std::env::var_os("DESTINY_FONTS").is_none() {
                if let Ok(res) = app.path().resource_dir() {
                    let fonts = res.join("assets/fonts");
                    if fonts.exists() {
                        std::env::set_var("DESTINY_FONTS", fonts);
                    }
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            default_root,
            library,
            read_json,
            open_project,
            commit_project,
            apply_patch,
            undo,
            redo,
            music_analysis,
            propose_short,
            duplicate_project,
            ingest,
            analyze,
            render,
            snapshot,
            export_project,
            cancel_job,
            compose_preview,
            thumbs,
            waveform,
            ask_claude,
        ])
        .run(tauri::generate_context!())
        .expect("erreur au lancement de Destiny Studio");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn free_path_never_overwrites() {
        let dir = std::env::temp_dir().join(format!("destiny-free-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let a = dir.join("serpent.json");
        assert_eq!(free_path(&a), a);
        std::fs::write(&a, "{}").unwrap();
        assert_eq!(free_path(&a), dir.join("serpent_2.json"));
        std::fs::write(dir.join("serpent_2.json"), "{}").unwrap();
        // Dupliquer la copie repart de la racine du nom.
        assert_eq!(free_path(&dir.join("serpent_2.json")), dir.join("serpent_3.json"));
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
