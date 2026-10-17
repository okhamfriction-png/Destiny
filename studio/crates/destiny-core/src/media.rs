//! Médias pour la timeline de l'éditeur : vignettes des plans (bande d'images) et formes
//! d'onde. Tout est calculé ici, en Rust, et mis en cache sur disque : le front ne décode
//! jamais d'audio et ne lit qu'une petite image JPEG par vignette.

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

use anyhow::{Context, Result};
use rayon::prelude::*;
use serde::Serialize;

use crate::audio;
use crate::ffmpeg;

/// Clé de cache d'un fichier : chemin + taille + date de modification (un fichier
/// remplacé sous le même nom est recalculé).
pub fn file_key(path: &Path) -> String {
    let mut h = DefaultHasher::new();
    path.hash(&mut h);
    if let Ok(m) = std::fs::metadata(path) {
        m.len().hash(&mut h);
        if let Ok(t) = m.modified() {
            t.hash(&mut h);
        }
    }
    format!("{:016x}", h.finish())
}

/// Fichier temporaire propre à cet appel (écritures concurrentes du même cache : la
/// timeline demande souvent plusieurs clips du même rush au même instant).
fn unique_tmp(path: &Path, ext: &str) -> PathBuf {
    static N: AtomicUsize = AtomicUsize::new(0);
    path.with_extension(format!("{}-{}.{ext}", std::process::id(), N.fetch_add(1, Ordering::Relaxed)))
}

/// Vérifie qu'on peut lire `path`, en 10 s au plus. Sur Mac, une app qui ouvre un fichier
/// d'un volume réseau (le NAS) attend l'autorisation de macOS : sans réponse, ffmpeg restait
/// bloqué indéfiniment (même `kill -9` n'y peut rien) et la timeline restait vide sans
/// explication. Une fois un fichier lu avec succès, on ne revérifie plus.
pub fn ensure_readable(path: &Path) -> Result<()> {
    use std::collections::HashSet;
    use std::io::Read;
    static OK: Mutex<Option<HashSet<PathBuf>>> = Mutex::new(None);
    if OK.lock().unwrap_or_else(|e| e.into_inner()).get_or_insert_with(HashSet::new).contains(path) {
        return Ok(());
    }
    let (tx, rx) = std::sync::mpsc::channel();
    let p = path.to_path_buf();
    std::thread::spawn(move || {
        let r = std::fs::File::open(&p).and_then(|mut f| f.read(&mut [0u8; 1]).map(|_| ()));
        let _ = tx.send(r.map_err(|e| e.to_string()));
    });
    match rx.recv_timeout(std::time::Duration::from_secs(10)) {
        Ok(Ok(())) => {
            OK.lock().unwrap_or_else(|e| e.into_inner()).get_or_insert_with(HashSet::new).insert(path.to_path_buf());
            Ok(())
        }
        Ok(Err(e)) => anyhow::bail!("lecture impossible de {} : {e}", path.display()),
        Err(_) => anyhow::bail!(
            "accès bloqué à {} : macOS attend une autorisation. Répondez « Autoriser » au message de macOS, \
             ou Réglages Système › Confidentialité et sécurité › Fichiers et dossiers › Destiny Studio › Volumes réseau.",
            path.display()
        ),
    }
}

// ---------------------------------------------------------------- vignettes

#[derive(Debug, Clone, Serialize)]
pub struct Thumb {
    /// Instant dans le fichier source (s).
    pub t: f64,
    pub path: String,
}

/// Nombre maximal de vignettes par appel (une bande à l'écran n'en montre pas plus).
pub const MAX_THUMBS: usize = 240;

/// Vignettes de `video` aux multiples de `step` compris dans `[from, to]`, hautes de
/// `height` px. Les manquantes sont extraites en parallèle, une recherche par image clé
/// (`-ss` avant `-i`) : quelques dizaines de ms par vignette sur un proxy LRF, quel que
/// soit l'endroit du fichier.
pub fn thumbs(video: &Path, from: f64, to: f64, step: f64, height: u32, cache: &Path) -> Result<Vec<Thumb>> {
    let step = step.max(0.1);
    let dir = cache.join(format!("{}_{height}", file_key(video)));
    std::fs::create_dir_all(&dir)?;
    let k0 = (from.max(0.0) / step).floor() as i64;
    let k1 = (to / step).ceil() as i64;
    let times: Vec<f64> = (k0..=k1).map(|k| (k as f64 * step * 1000.0).round() / 1000.0).take(MAX_THUMBS).collect();
    let name = |t: f64| dir.join(format!("{:09}.jpg", (t * 1000.0).round() as i64));
    if times.iter().any(|t| !name(*t).exists()) {
        ensure_readable(video)?;
    }
    let errors: Vec<String> = times
        .par_iter()
        .filter(|t| !name(**t).exists())
        .filter_map(|&t| extract_frame(video, t, height, &name(t)).err().map(|e| format!("{e:#}")))
        .collect();
    // Une vignette ratée (fin de fichier) est simplement absente ; aucune réussie, c'est que
    // le fichier est illisible (accès refusé, format) : on le dit au lieu d'une bande vide.
    if let Some(e) = errors.first().filter(|_| times.iter().all(|t| !name(*t).exists())) {
        anyhow::bail!("vignettes de {} : {e}", video.display());
    }
    Ok(times
        .into_iter()
        .filter(|t| name(*t).exists())
        .map(|t| Thumb { t, path: name(t).display().to_string() })
        .collect())
}

fn extract_frame(video: &Path, t: f64, height: u32, out: &Path) -> Result<()> {
    // Écriture dans un fichier temporaire puis renommage : jamais de JPEG à moitié écrit.
    let tmp = unique_tmp(out, "tmp.jpg");
    let out_ = Command::new(ffmpeg::ffmpeg_bin())
        .args(["-hide_banner", "-nostdin", "-v", "error", "-y", "-ss", &format!("{t:.3}"), "-i"])
        .arg(video)
        .args(["-frames:v", "1", "-vf", &format!("scale=-2:{height}"), "-q:v", "6"])
        .arg(&tmp)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .with_context(|| format!("ffmpeg introuvable ({})", ffmpeg::ffmpeg_bin()))?;
    if out_.status.success() && tmp.exists() {
        std::fs::rename(&tmp, out)?;
        return Ok(());
    }
    let _ = std::fs::remove_file(&tmp);
    let msg = String::from_utf8_lossy(&out_.stderr);
    anyhow::bail!("{}", msg.lines().last().unwrap_or("ffmpeg a échoué").trim())
}

// ---------------------------------------------------------------- formes d'onde

/// Résolution de l'enveloppe en cache : 100 valeurs par seconde.
pub const WAVE_RATE: f64 = 100.0;
/// Fréquence de décodage pour l'enveloppe (suffit pour un niveau crête par 10 ms).
const WAVE_SR: u32 = 8_000;

/// Enveloppe crête du fichier entier (0..1, échelle dB de −60 à 0), calculée une fois
/// puis lue depuis `cache/<clé>.f32` (f32 little-endian).
pub fn envelope(path: &Path, cache: &Path) -> Result<Vec<f32>> {
    let file = cache.join(format!("{}.f32", file_key(path)));
    let read = |f: &Path| {
        std::fs::read(f).ok().map(|bytes| bytes.chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect())
    };
    if let Some(env) = read(&file) {
        return Ok(env);
    }
    // Un seul décodage à la fois : les appels simultanés pour le même rush attendent puis
    // lisent le cache que le premier vient d'écrire (bug réel : A1 vide sur 2 clips sur 3).
    static DECODE: Mutex<()> = Mutex::new(());
    let _guard = DECODE.lock().unwrap_or_else(|e| e.into_inner());
    if let Some(env) = read(&file) {
        return Ok(env);
    }
    ensure_readable(path)?;
    let pcm = ffmpeg::load_audio(path, None, WAVE_SR)?;
    let env = peak_envelope(&pcm.samples, pcm.sr);
    std::fs::create_dir_all(cache)?;
    let tmp = unique_tmp(&file, "tmp");
    let mut f = std::fs::File::create(&tmp)?;
    for v in &env {
        f.write_all(&v.to_le_bytes())?;
    }
    drop(f);
    std::fs::rename(tmp, file)?;
    Ok(env)
}

/// Crête par fenêtre de 10 ms, ramenée sur 0..1 (−60 dB → 0, 0 dB → 1) : une forme
/// d'onde en dB montre aussi les voix faibles, comme dans les logiciels de montage.
pub fn peak_envelope(samples: &[f32], sr: u32) -> Vec<f32> {
    let n = ((sr as f64 / WAVE_RATE).round() as usize).max(1);
    samples
        .chunks(n)
        .map(|c| {
            let peak = c.iter().fold(0f32, |m, s| m.max(s.abs()));
            ((audio::to_db(peak) + 60.0) / 60.0).clamp(0.0, 1.0)
        })
        .collect()
}

/// `buckets` valeurs (max par case) de l'enveloppe sur `[from, to]` secondes du fichier.
pub fn slice(env: &[f32], from: f64, to: f64, buckets: usize) -> Vec<f32> {
    let buckets = buckets.clamp(1, 4096);
    let a = (from.max(0.0) * WAVE_RATE) as usize;
    let b = ((to.max(from) * WAVE_RATE).ceil() as usize).max(a + 1);
    (0..buckets)
        .map(|i| {
            let s = a + (b - a) * i / buckets;
            let e = (a + (b - a) * (i + 1) / buckets).max(s + 1);
            env.get(s.min(env.len())..e.min(env.len())).map_or(0.0, |w| w.iter().fold(0f32, |m, v| m.max(*v)))
        })
        .collect()
}

/// Dossier de cache des médias de l'éditeur pour un projet.
pub fn cache_dir(project_dir: &Path) -> PathBuf {
    project_dir.join(".cache").join("media")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn envelope_in_db() {
        // 1 s de silence puis 1 s de sinus plein : 0 puis ~1.
        let sr = 8_000;
        let mut s = vec![0f32; sr as usize];
        s.extend((0..sr).map(|i| (i as f32 * 0.3).sin()));
        let env = peak_envelope(&s, sr);
        assert_eq!(env.len(), 200);
        assert!(env[50] < 0.01 && env[150] > 0.95, "{} {}", env[50], env[150]);
    }

    #[test]
    fn slice_takes_max_per_bucket() {
        let env: Vec<f32> = (0..1000).map(|i| if i == 512 { 1.0 } else { 0.1 }).collect();
        let v = slice(&env, 5.0, 6.0, 4);
        assert_eq!(v.len(), 4);
        assert_eq!(v[0], 1.0, "{v:?}");
        assert!(v[1..].iter().all(|x| (*x - 0.1).abs() < 1e-6));
        // Au-delà de la fin du fichier : silence, pas de panique.
        assert_eq!(slice(&env, 20.0, 21.0, 3), vec![0.0; 3]);
    }

    #[test]
    fn key_changes_with_path() {
        assert_ne!(file_key(Path::new("/a.wav")), file_key(Path::new("/b.wav")));
    }
}

/// Mesure sur les médias synthétiques (`examples/synthetic/make_media.sh`) :
/// `cargo test -p destiny-core --release -- --ignored media_speed --nocapture`.
#[cfg(test)]
#[test]
#[ignore]
fn media_speed() {
    let media = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../examples/synthetic/media");
    let cache = std::env::temp_dir().join(format!("destiny-media-{}", std::process::id()));
    let t = std::time::Instant::now();
    let th = thumbs(&media.join("DJI_20261008201106_0001_D_P004.LRF"), 0.0, 60.0, 1.0, 54, &cache).unwrap();
    println!("{} vignettes en {:?}", th.len(), t.elapsed());
    let t = std::time::Instant::now();
    let again = thumbs(&media.join("DJI_20261008201106_0001_D_P004.LRF"), 0.0, 60.0, 1.0, 54, &cache).unwrap();
    println!("depuis le cache : {} en {:?}", again.len(), t.elapsed());
    let t = std::time::Instant::now();
    let env = envelope(&media.join("TX00_MIC001_20261008_201103_orig.wav"), &cache).unwrap();
    println!("enveloppe {} valeurs en {:?}", env.len(), t.elapsed());
    let t = std::time::Instant::now();
    let _ = envelope(&media.join("TX00_MIC001_20261008_201103_orig.wav"), &cache).unwrap();
    println!("enveloppe depuis le cache en {:?}", t.elapsed());
    let _ = std::fs::remove_dir_all(cache);
}

#[cfg(test)]
mod concurrency {
    use super::*;

    /// Plusieurs clips du même rush demandent la forme d'onde en même temps : tous
    /// doivent la recevoir (avant, un seul réussissait).
    #[test]
    fn envelope_concurrent_calls_all_succeed() {
        let dir = std::env::temp_dir().join(format!("destiny-env-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let wav = dir.join("a.wav");
        let spec = hound::WavSpec { channels: 1, sample_rate: 8000, bits_per_sample: 16, sample_format: hound::SampleFormat::Int };
        let mut w = hound::WavWriter::create(&wav, spec).unwrap();
        for i in 0..16_000 {
            w.write_sample(((i as f32 * 0.2).sin() * 12_000.0) as i16).unwrap();
        }
        w.finalize().unwrap();
        let cache = dir.join("wave");
        let res: Vec<_> = (0..6).map(|_| { let (w, c) = (wav.clone(), cache.clone()); std::thread::spawn(move || envelope(&w, &c)) }).collect();
        for r in res {
            assert_eq!(r.join().unwrap().unwrap().len(), 200);
        }
        std::fs::remove_dir_all(dir).unwrap();
    }
}
