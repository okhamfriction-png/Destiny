//! `destiny-cli` : pilotage de Destiny Studio en ligne de commande (par Claude Code
//! ou à la main). Résultats en JSON sur stdout, progression sur stderr.

use std::collections::BTreeMap;
use std::io::Write;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand, ValueEnum};
use destiny_core::render_a::{self, Quality};
use destiny_core::{asr, ingest, mics, music, nas, propose, sync, verify, Preset, Project};

#[derive(Parser)]
#[command(name = "destiny-cli", version, about = "Destiny Studio — montage semi-automatique des spectacles Destiny")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Clone, Copy, ValueEnum)]
enum Q {
    Preview,
    Delivery,
}

#[derive(Subcommand)]
enum Cmd {
    /// Écrit le JSON Schema de project.json.
    Schema {
        #[arg(long)]
        out: Option<PathBuf>,
    },
    /// Vérifie un project.json (forme + règles).
    Validate { project: PathBuf },
    /// Indexe un dossier de spectacle, crée les proxies et planches contact manquants,
    /// et écrit un project.json pré-synchronisé (horodatages des noms de fichiers).
    Ingest {
        dir: PathBuf,
        /// Dossier projet (project.json + .cache) — local, jamais sur le NAS.
        #[arg(long)]
        project_dir: PathBuf,
        #[arg(long, default_value = "short_scene")]
        preset: String,
        /// Génère les proxies 720p des vidéos sans LRF.
        #[arg(long)]
        proxies: bool,
        /// Génère les planches contact (vignette toutes les 2,5 s, 8 colonnes).
        #[arg(long)]
        sheets: bool,
    },
    /// Cale les micros sur la caméra par corrélation d'enveloppes (10 ms).
    Sync {
        project: PathBuf,
        #[arg(long)]
        mic: Option<String>,
        #[arg(long, default_value_t = 180.0)]
        window: f64,
        #[arg(long, default_value_t = 20.0)]
        max_lag: f64,
        /// Écrit les nouveaux `rec` dans le projet.
        #[arg(long)]
        write: bool,
    },
    /// Analyse un intervalle maître : transcription, carte des micros, chuchotements.
    Analyze {
        project: PathBuf,
        #[arg(long)]
        from: f64,
        #[arg(long)]
        to: f64,
        /// Modèle whisper (ggml), nécessite la feature `asr`.
        #[arg(long)]
        model: Option<PathBuf>,
        /// Mesure la réduction du bruit de coulisses par les gates.
        #[arg(long)]
        measure_gates: bool,
    },
    /// Analyse une musique : énergie 100 ms, onsets, coups, creux.
    Music { file: PathBuf },
    /// Propose un short « scène » sur l'intervalle maître [from, to].
    Propose {
        project: PathBuf,
        #[arg(long)]
        from: f64,
        #[arg(long)]
        to: f64,
        #[arg(long)]
        out: PathBuf,
        #[arg(long)]
        transcript: Option<PathBuf>,
        #[arg(long)]
        kicker: Option<String>,
        /// Hook (répéter pour 2 lignes).
        #[arg(long)]
        hook: Vec<String>,
        #[arg(long)]
        punch_at: Option<f64>,
        #[arg(long)]
        emphasis: Vec<String>,
    },
    /// Shorts sur les pics de rétention YouTube (CSV temps,valeur).
    Peaks {
        project: PathBuf,
        #[arg(long)]
        csv: PathBuf,
        /// Position de la vidéo publiée dans la timeline maîtresse (s).
        #[arg(long)]
        offset: f64,
        #[arg(long)]
        transcript: Option<PathBuf>,
        #[arg(long, default_value_t = 3)]
        count: usize,
        #[arg(long)]
        out_dir: PathBuf,
    },
    /// Fixe les gates micros depuis un JSON de présence {"m1": [[a,b],…]}.
    Gates { project: PathBuf, presence: PathBuf },
    /// Rend la vidéo (moteur A) puis vérifie durée et son.
    Render {
        project: PathBuf,
        #[arg(long)]
        out: PathBuf,
        #[arg(long, value_enum, default_value = "preview")]
        quality: Q,
    },
    /// Images PNG aux instants donnés (« 1,15,40 ») pour relecture.
    Snapshot {
        project: PathBuf,
        #[arg(long, value_delimiter = ',')]
        at: Vec<f64>,
        #[arg(long)]
        out_dir: Option<PathBuf>,
    },
    /// Rendu livraison + vérifications + copie (reprise, md5) vers les cibles d'export.
    Export {
        project: PathBuf,
        /// Remplace les cibles du projet.
        #[arg(long)]
        target: Vec<String>,
    },
    /// Applique un patch JSON (RFC 6902), valide, et journalise l'historique.
    Patch { project: PathBuf, patch: PathBuf },
}

fn print_json(v: &impl serde::Serialize) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(v)?);
    Ok(())
}

fn progress(stage: &str, x: f64) {
    // Une ligne par étape, réécrite au plus une fois par point de pourcentage.
    static LAST: std::sync::Mutex<(String, i64)> = std::sync::Mutex::new((String::new(), -1));
    let pct = (x * 100.0).floor() as i64;
    let mut last = LAST.lock().unwrap();
    if last.0 == stage && last.1 == pct {
        return;
    }
    if last.0 != stage && last.1 >= 0 {
        eprintln!();
    }
    *last = (stage.to_string(), pct);
    eprint!("\r{stage:>8} {pct:3} %");
    let _ = std::io::stderr().flush();
}

fn project_dir(project: &Path) -> PathBuf {
    project.parent().map(Path::to_path_buf).filter(|p| !p.as_os_str().is_empty()).unwrap_or_else(|| ".".into())
}

fn cache_dir(project: &Path) -> PathBuf {
    project_dir(project).join(".cache")
}

fn parse_preset(s: &str) -> Result<Preset> {
    Ok(serde_json::from_value(serde_json::Value::String(s.into())).with_context(|| format!("preset inconnu : {s}"))?)
}

fn project_name(project: &Path, p: &Project) -> String {
    p.export.name.clone().unwrap_or_else(|| project.file_stem().and_then(|s| s.to_str()).unwrap_or("montage").to_string())
}

/// Résout les chemins relatifs du projet par rapport à son dossier.
fn resolved(project: &Path, p: &Project) -> Project {
    let base = project_dir(project);
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

fn render_checked(project: &Path, p: &Project, out: &Path, q: Quality) -> Result<verify::Report> {
    let base = project_dir(project);
    let work = cache_dir(project).join("render").join(project_name(project, p));
    let job = render_a::render(p, &base, &work, out, q, None, progress)?;
    let report = verify::check(out, job.duration, Some((p.format.w, p.format.h)))?;
    Ok(report)
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Schema { out } => {
            let s = serde_json::to_string_pretty(&destiny_core::project::json_schema())? + "\n";
            match out {
                Some(o) => std::fs::write(o, s)?,
                None => print!("{s}"),
            }
        }
        Cmd::Validate { project } => {
            let p = Project::load(&project)?;
            print_json(&serde_json::json!({ "ok": true, "duration": p.duration(), "preset": p.preset }))?;
        }
        Cmd::Ingest { dir, project_dir, preset, proxies, sheets } => {
            std::fs::create_dir_all(project_dir.join(".cache"))?;
            let mut index = ingest::scan(&dir)?;
            let cache = project_dir.join(".cache");
            for f in index.files.iter_mut() {
                let is_video = matches!(f.kind, ingest::MediaKind::Camera | ingest::MediaKind::Edit);
                if is_video && f.proxy.is_none() {
                    let px = ingest::proxy_path(&cache, &f.path);
                    if proxies && !px.exists() {
                        eprintln!("proxy {}", f.path);
                        ingest::make_proxy(Path::new(&f.path), &px, |x| progress("proxy", x))?;
                    }
                    if px.exists() {
                        f.proxy = Some(px.display().to_string());
                    }
                }
            }
            std::fs::write(cache.join("ingest.json"), serde_json::to_string_pretty(&index)?)?;
            let p = ingest::initial_project(&index, parse_preset(&preset)?);
            if sheets {
                for s in &p.sources {
                    let v = s.proxy.as_deref().unwrap_or(&s.path);
                    let out = ingest::contact_sheets(Path::new(v), &cache.join("sheets"), sync::rec_seconds(s.rec), 6)?;
                    eprintln!("{} planches pour {}", out.len(), s.id);
                }
            }
            let path = project_dir.join("project.json");
            p.save(&path)?;
            print_json(&serde_json::json!({ "project": path, "files": index.files.len(), "sources": p.sources.len(), "mics": p.mics.len() }))?;
        }
        Cmd::Sync { project, mic, window, max_lag, write } => {
            let mut p = Project::load(&project)?;
            let r = resolved(&project, &p);
            let ids: Vec<String> = match mic {
                Some(m) => vec![m],
                None => p.mics.iter().map(|m| m.id.clone()).collect(),
            };
            let mut results = Vec::new();
            for id in ids {
                match sync::autosync_mic(&r, &id, window, max_lag) {
                    Ok(res) => {
                        if write && res.score >= 0.3 {
                            if let Some(m) = p.mics.iter_mut().find(|m| m.id == id) {
                                m.rec = res.rec;
                            }
                        }
                        results.push(serde_json::to_value(&res)?);
                    }
                    Err(e) => results.push(serde_json::json!({ "mic": id, "error": e.to_string() })),
                }
            }
            if write {
                p.save(&project)?;
            }
            print_json(&results)?;
        }
        Cmd::Analyze { project, from, to, model, measure_gates } => {
            let p = Project::load(&project)?;
            let r = resolved(&project, &p);
            let cache = cache_dir(&project);
            std::fs::create_dir_all(&cache)?;
            #[cfg(not(feature = "asr"))]
            if model.is_some() {
                bail!("transcription whisper indisponible : recompiler avec `--features asr`");
            }
            let t = asr::transcribe_project(&r, from, to, model.as_deref())?;
            let tag = format!("{from:.0}-{to:.0}");
            t.save(&cache.join(format!("transcript_{tag}.json")))?;
            let map = mics::mic_map(&r, from, to)?;
            let suspects = mics::detect_whispers(&map);
            std::fs::write(cache.join(format!("micmap_{tag}.json")), serde_json::to_string(&map)?)?;
            let reduction: BTreeMap<String, f32> =
                if measure_gates { mics::gate_reduction_db(&r, &suspects)? } else { BTreeMap::new() };
            print_json(&serde_json::json!({
                "transcript": cache.join(format!("transcript_{tag}.json")),
                "segments": t.segments.len(),
                "suspects": suspects,
                "gate_reduction_db": reduction,
            }))?;
        }
        Cmd::Music { file } => {
            let mut a = music::analyze_file(&file)?;
            a.env.clear(); // l'enveloppe complète n'est utile qu'à l'UI
            print_json(&a)?;
        }
        Cmd::Propose { project, from, to, out, transcript, kicker, hook, punch_at, emphasis } => {
            let p = Project::load(&project)?;
            let t = transcript.map(|t| asr::Transcript::load(&t)).transpose()?;
            let opts = propose::ShortOpts { kicker, hook, punch_at, emphasis, ..Default::default() };
            let s = propose::short_scene(&p, t.as_ref(), from, to, &opts)?;
            s.save(&out)?;
            print_json(&serde_json::json!({ "project": out, "duration": s.duration() }))?;
        }
        Cmd::Peaks { project, csv, offset, transcript, count, out_dir } => {
            let p = Project::load(&project)?;
            let t = transcript.map(|t| asr::Transcript::load(&t)).transpose()?;
            let curve = propose::parse_retention_csv(&std::fs::read_to_string(&csv)?);
            let peaks = propose::retention_peaks(&curve, offset, count);
            std::fs::create_dir_all(&out_dir)?;
            let mut outs = Vec::new();
            for (i, pk) in peaks.iter().enumerate() {
                let (a, b) = match &t {
                    Some(t) => propose::snap_to_lines(t, pk.start, pk.end),
                    None => (pk.start, pk.end),
                };
                let opts = propose::ShortOpts {
                    kicker: Some(format!("LE PLUS REVU · {}/{}", i + 1, peaks.len())),
                    ..Default::default()
                };
                let mut s = propose::short_scene(&p, t.as_ref(), a, b, &opts)?;
                s.preset = Preset::RetentionPeaks;
                let path = out_dir.join(format!("pic_{}.json", i + 1));
                s.save(&path)?;
                outs.push(serde_json::json!({ "project": path, "peak": pk, "from": a, "to": b }));
            }
            print_json(&outs)?;
        }
        Cmd::Gates { project, presence } => {
            let mut p = Project::load(&project)?;
            let pres: BTreeMap<String, Vec<[f64; 2]>> = serde_json::from_str(&std::fs::read_to_string(&presence)?)?;
            for (k, v) in mics::gates_from_presence(&pres) {
                p.mic_gates.insert(k, v);
            }
            p.validate()?;
            p.save(&project)?;
            print_json(&p.mic_gates)?;
        }
        Cmd::Render { project, out, quality } => {
            let p = Project::load(&project)?;
            let q = match quality {
                Q::Preview => Quality::Preview,
                Q::Delivery => Quality::Delivery,
            };
            let report = render_checked(&project, &p, &out, q)?;
            print_json(&report)?;
            if !report.ok() {
                bail!("vérifications échouées : {:?}", report.problems);
            }
        }
        Cmd::Snapshot { project, at, out_dir } => {
            let p = Project::load(&project)?;
            let cache = cache_dir(&project);
            let out_dir = out_dir.unwrap_or_else(|| cache.join("snapshots"));
            std::fs::create_dir_all(&out_dir)?;
            // Aperçu mis en cache selon le contenu du projet.
            let hash = {
                use std::hash::{Hash, Hasher};
                let mut h = std::collections::hash_map::DefaultHasher::new();
                p.to_json()?.hash(&mut h);
                h.finish()
            };
            let preview = cache.join(format!("preview_{hash:016x}.mp4"));
            if !preview.exists() {
                let base = project_dir(&project);
                let work = cache.join("render").join(project_name(&project, &p));
                render_a::render(&p, &base, &work, &preview, Quality::Preview, None, progress)?;
            }
            let mut files = Vec::new();
            for t in at {
                let f = out_dir.join(format!("{}_{:06.2}.png", project_name(&project, &p), t));
                destiny_core::ffmpeg::extract_frame(&preview, t, &f)?;
                files.push(f);
            }
            print_json(&files)?;
        }
        Cmd::Export { project, target } => {
            let p = Project::load(&project)?;
            let name = project_name(&project, &p);
            let local = cache_dir(&project).join("exports");
            std::fs::create_dir_all(&local)?;
            let file = local.join(format!("{name}_{}x{}.mp4", p.format.w, p.format.h));
            // Toujours rendre en local : le NAS est lent en écriture.
            let report = render_checked(&project, &p, &file, Quality::Delivery)?;
            if !report.ok() {
                print_json(&report)?;
                bail!("export refusé : {:?}", report.problems);
            }
            let targets = if target.is_empty() { p.export.targets.clone() } else { target };
            let mut copies = Vec::new();
            for t in targets {
                let dst = nas::resolve_target(&t).join(file.file_name().unwrap());
                let r = nas::copy_resumable(&file, &dst, |d, tot| progress("copie", d as f64 / tot.max(1) as f64))?;
                copies.push(serde_json::json!({ "dest": dst, "result": format!("{r:?}") }));
            }
            print_json(&serde_json::json!({ "file": file, "report": report, "copies": copies }))?;
        }
        Cmd::Patch { project, patch } => {
            let mut p = Project::load(&project)?;
            let ptxt = std::fs::read_to_string(&patch)?;
            let pt: json_patch::Patch = serde_json::from_str(&ptxt).context("patch RFC 6902 attendu")?;
            let mut h = destiny_core::history::History::default();
            h.apply_patch(&mut p, &pt, patch.display().to_string())?;
            p.save(&project)?;
            // Journal append-only : l'UI peut reconstruire l'historique.
            let log = project_dir(&project).join(".history.jsonl");
            let mut f = std::fs::OpenOptions::new().create(true).append(true).open(log)?;
            for e in &h.undo {
                writeln!(f, "{}", serde_json::to_string(e)?)?;
            }
            print_json(&serde_json::json!({ "ok": true, "duration": p.duration() }))?;
        }
    }
    Ok(())
}
