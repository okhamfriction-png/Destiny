//! Copie vers le NAS (`/Volumes/ShikaZero`) : lent en écriture, suppression parfois
//! interdite. On rend toujours en local, puis on copie avec reprise (ajout en fin de
//! fichier, équivalent de `tail -c +N >> fichier`) et contrôle md5.

use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use md5::{Digest, Md5};

pub const DEFAULT_NAS_ROOT: &str = "/Volumes/ShikaZero";

pub fn nas_root() -> PathBuf {
    std::env::var("DESTINY_NAS_ROOT").unwrap_or_else(|_| DEFAULT_NAS_ROOT.into()).into()
}

/// `nas:/Spectacle/…` → `/Volumes/ShikaZero/Spectacle/…` ; un chemin normal est inchangé.
pub fn resolve_target(target: &str) -> PathBuf {
    match target.strip_prefix("nas:") {
        Some(rest) => nas_root().join(rest.trim_start_matches('/')),
        None => target.into(),
    }
}

pub fn md5_file(path: &Path) -> Result<String> {
    let mut f = File::open(path).with_context(|| format!("ouverture {}", path.display()))?;
    let mut h = Md5::new();
    let mut buf = vec![0u8; 1 << 20];
    loop {
        let n = f.read(&mut buf)?;
        if n == 0 {
            break;
        }
        h.update(&buf[..n]);
    }
    Ok(format!("{:x}", h.finalize()))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CopyOutcome {
    AlreadyThere,
    Copied { bytes: u64 },
    Resumed { from: u64, bytes: u64 },
}

/// Copie `src` vers `dst` avec reprise. Si `dst` est plus court, on n'ajoute que la
/// fin ; s'il est complet, on vérifie le md5. Un fichier corrompu de même taille est
/// réécrit en place (sans suppression, parfois interdite sur le NAS).
pub fn copy_resumable(src: &Path, dst: &Path, mut progress: impl FnMut(u64, u64)) -> Result<CopyOutcome> {
    let total = std::fs::metadata(src)?.len();
    if let Some(dir) = dst.parent() {
        std::fs::create_dir_all(dir).with_context(|| format!("création {}", dir.display()))?;
    }
    let existing = std::fs::metadata(dst).map(|m| m.len()).unwrap_or(0);
    let src_md5 = md5_file(src)?;
    if existing == total && total > 0 && md5_file(dst)? == src_md5 {
        return Ok(CopyOutcome::AlreadyThere);
    }
    let from = if existing < total && existing > 0 && prefix_matches(src, dst, existing)? { existing } else { 0 };
    let mut input = File::open(src)?;
    input.seek(SeekFrom::Start(from))?;
    let mut output = OpenOptions::new().create(true).write(true).truncate(false).open(dst)?;
    if from == 0 {
        output.set_len(0)?;
    }
    output.seek(SeekFrom::Start(from))?;
    let mut buf = vec![0u8; 4 << 20];
    let mut done = from;
    loop {
        let n = input.read(&mut buf)?;
        if n == 0 {
            break;
        }
        output.write_all(&buf[..n])?;
        done += n as u64;
        progress(done, total);
    }
    output.sync_all()?;
    drop(output);
    if md5_file(dst)? != src_md5 {
        bail!("md5 différent après copie de {} : relancer la copie", dst.display());
    }
    Ok(if from > 0 { CopyOutcome::Resumed { from, bytes: total - from } } else { CopyOutcome::Copied { bytes: total } })
}

/// Vérifie que les `n` premiers octets de `dst` sont ceux de `src` (sur un échantillon
/// en fin de préfixe : relire tout le NAS coûterait aussi cher que recopier).
fn prefix_matches(src: &Path, dst: &Path, n: u64) -> Result<bool> {
    let k = n.min(1 << 20);
    let read_tail = |p: &Path| -> Result<Vec<u8>> {
        let mut f = File::open(p)?;
        f.seek(SeekFrom::Start(n - k))?;
        let mut v = vec![0u8; k as usize];
        f.read_exact(&mut v)?;
        Ok(v)
    };
    Ok(read_tail(src)? == read_tail(dst)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resumes_interrupted_copy() {
        let d = tempfile::tempdir().unwrap();
        let src = d.path().join("a.mp4");
        let data: Vec<u8> = (0..3_000_000u32).map(|i| (i % 251) as u8).collect();
        std::fs::write(&src, &data).unwrap();
        let dst = d.path().join("nas/out.mp4");
        std::fs::create_dir_all(dst.parent().unwrap()).unwrap();
        std::fs::write(&dst, &data[..1_234_567]).unwrap();
        let r = copy_resumable(&src, &dst, |_, _| {}).unwrap();
        assert_eq!(r, CopyOutcome::Resumed { from: 1_234_567, bytes: 3_000_000 - 1_234_567 });
        assert_eq!(std::fs::read(&dst).unwrap(), data);
        assert_eq!(copy_resumable(&src, &dst, |_, _| {}).unwrap(), CopyOutcome::AlreadyThere);
    }

    #[test]
    fn nas_targets() {
        std::env::remove_var("DESTINY_NAS_ROOT");
        assert_eq!(resolve_target("nas:/Spectacle/x/"), PathBuf::from("/Volumes/ShikaZero/Spectacle/x/"));
        assert_eq!(resolve_target("/tmp/a"), PathBuf::from("/tmp/a"));
    }
}
