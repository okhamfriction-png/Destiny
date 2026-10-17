//! Détection des comédiens (corps entiers et visages) et recadrage automatique des plans.
//!
//! Sur Mac, le framework Vision d'Apple (petit programme Swift compilé par `build.rs` et
//! embarqué ici) analyse quelques images de chaque plan ; on en déduit le cadrage
//! (`Crop` : centre et zoom), que l'inspecteur permet ensuite de retoucher.

use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{bail, Context, Result};
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::project::{Crop, Project};

/// Boîtes détectées sur une image (normalisées 0..1, origine en haut à gauche) :
/// `[x, y, w, h, confiance]`.
#[derive(Debug, Clone, Default, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Detections {
    #[serde(default)]
    pub faces: Vec<[f64; 5]>,
    #[serde(default)]
    pub people: Vec<[f64; 5]>,
}

/// Resserrement maximal ajouté au rendu par le punch d'entrée (×1,09) et le zoom continu.
const FX_ZOOM: f64 = 1.09;

/// Confiance minimale d'une personne (vraie soirée : comédiens à 0,68–0,78).
const MIN_PERSON: f64 = 0.5;

#[cfg(vision)]
const HELPER: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/destiny-vision"));

/// Le détecteur est-il disponible (Mac avec Vision) ?
pub fn available() -> bool {
    cfg!(vision)
}

/// Programme Vision écrit une fois dans le dossier temporaire (nom unique par contenu).
fn helper() -> Result<PathBuf> {
    #[cfg(vision)]
    {
        use std::hash::{Hash, Hasher};
        use std::os::unix::fs::PermissionsExt;
        let mut h = std::collections::hash_map::DefaultHasher::new();
        HELPER.hash(&mut h);
        let path = std::env::temp_dir().join(format!("destiny-vision-{:016x}", h.finish()));
        if !path.exists() {
            let tmp = path.with_extension(format!("{}.tmp", std::process::id()));
            std::fs::write(&tmp, HELPER)?;
            std::fs::set_permissions(&tmp, std::fs::Permissions::from_mode(0o755))?;
            std::fs::rename(&tmp, &path)?;
        }
        Ok(path)
    }
    #[cfg(not(vision))]
    bail!("détection Vision indisponible (macOS et swiftc requis à la compilation)")
}

/// Détecte visages et personnes sur des images (une ligne JSON par image).
pub fn detect(images: &[PathBuf]) -> Result<Vec<Detections>> {
    if images.is_empty() {
        return Ok(vec![]);
    }
    let out = Command::new(helper()?).args(images).stderr(Stdio::piped()).output().context("détecteur Vision")?;
    if !out.status.success() {
        bail!("détecteur Vision : {}", String::from_utf8_lossy(&out.stderr));
    }
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(|l| serde_json::from_str::<Detections>(l).context("sortie du détecteur"))
        .collect()
}

/// Détections d'une image d'un fichier vidéo à l'instant `t`, en cache disque.
pub fn detect_at(video: &Path, t: f64, cache: &Path) -> Result<Detections> {
    let dir = cache.join(crate::media::file_key(video));
    std::fs::create_dir_all(&dir)?;
    let ms = (t * 1000.0).round() as i64;
    let json = dir.join(format!("{ms:09}.json"));
    if let Ok(txt) = std::fs::read_to_string(&json) {
        if let Ok(d) = serde_json::from_str(&txt) {
            return Ok(d);
        }
    }
    crate::media::ensure_readable(video)?;
    let img = dir.join(format!("{ms:09}.jpg"));
    // 960 px de large : les visages d'un plan large de scène restent détectables.
    let st = Command::new(crate::ffmpeg::ffmpeg_bin())
        .args(["-hide_banner", "-nostdin", "-v", "error", "-y", "-ss", &format!("{t:.3}"), "-i"])
        .arg(video)
        .args(["-frames:v", "1", "-vf", "scale=960:-2", "-q:v", "3"])
        .arg(&img)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    if !st.success() || !img.exists() {
        bail!("image illisible à {t:.2} s dans {}", video.display());
    }
    let d = detect(std::slice::from_ref(&img))?.pop().unwrap_or_default();
    std::fs::write(&json, serde_json::to_string(&d)?)?;
    let _ = std::fs::remove_file(&img);
    Ok(d)
}

fn percentile(mut v: Vec<f64>, q: f64) -> f64 {
    v.sort_by(f64::total_cmp);
    let i = ((v.len() - 1) as f64 * q).round() as usize;
    v[i]
}

/// Cadrage d'un plan d'après les détections de plusieurs de ses images.
///
/// - largeur : tous les comédiens présents (10e et 90e centiles des bords, pour ignorer une
///   détection isolée), avec de l'air autour ; centre horizontal au milieu du groupe ;
/// - hauteur : le haut des têtes (visages s'il y en a, sinon haut des corps) à 20 % du haut
///   de l'image visible : on cadre les visages, quitte à couper les jambes ;
/// - zoom entre 1 et 2,5 (au-delà, même la 4K s'abîme), réduit de `FX_ZOOM` : le punch
///   d'entrée et le zoom continu resserrent encore l'image au rendu (têtes coupées sinon,
///   vu sur la vraie soirée).
///
/// `base_zoom` est le zoom de base du preset (1,2 pour la bande des shorts) : la part
/// visible de l'image vaut `1 / (base_zoom × zoom)` en largeur comme en hauteur.
pub fn framing(dets: &[Detections], base_zoom: f64) -> Option<Crop> {
    let people: Vec<[f64; 5]> = dets.iter().flat_map(|d| d.people.iter().copied()).filter(|b| b[4] >= MIN_PERSON).collect();
    if people.is_empty() {
        return None;
    }
    let left = percentile(people.iter().map(|b| b[0]).collect(), 0.1);
    let right = percentile(people.iter().map(|b| b[0] + b[2]).collect(), 0.9);
    let faces: Vec<[f64; 5]> = dets.iter().flat_map(|d| d.faces.iter().copied()).collect();
    let head_top = if faces.is_empty() {
        percentile(people.iter().map(|b| b[1]).collect(), 0.1)
    } else {
        percentile(faces.iter().map(|f| f[1] - 0.3 * f[3]).collect(), 0.1)
    };
    // Largeur à montrer : le groupe + 40 % d'air, au moins un tiers de l'image.
    let want = ((right - left) * 1.4 + 0.05).clamp(1.0 / (base_zoom * 2.5), 1.0 / base_zoom);
    let zoom = (1.0 / (base_zoom * want * FX_ZOOM)).clamp(1.0, 2.5);
    let visible = 1.0 / (base_zoom * zoom);
    let half = visible / 2.0;
    let r3 = |v: f64| (v * 1000.0).round() / 1000.0;
    Some(Crop {
        cx: r3(((left + right) / 2.0).clamp(half, 1.0 - half)),
        cy: r3((head_top - 0.2 * visible + half).clamp(half, 1.0 - half)),
        zoom: r3(zoom),
    })
}

/// Résultat du recadrage d'un plan.
#[derive(Debug, Clone, Serialize)]
pub struct Reframed {
    pub id: String,
    pub crop: Option<Crop>,
    pub people: usize,
    pub faces: usize,
}

/// Recadre les plans vidéo de `p` (tous, ou ceux de `only`) sur les comédiens. Les plans où
/// personne n'est détecté gardent leur cadrage. Quelques images par plan (une toutes les
/// 2 s, entre 3 et 12), analysées en parallèle et mises en cache.
pub fn reframe(p: &mut Project, base: &Path, cache: &Path, base_zoom: f64, only: Option<&[String]>) -> Result<Vec<Reframed>> {
    let jobs: Vec<(usize, usize, PathBuf, Vec<f64>)> = p
        .tracks
        .iter()
        .enumerate()
        .flat_map(|(ti, t)| match t {
            crate::project::Track::Video { items, .. } => items
                .iter()
                .enumerate()
                .filter(|(_, c)| only.is_none_or(|ids| ids.contains(&c.id)))
                .filter_map(|(ii, c)| {
                    let s = p.sources.iter().find(|s| s.id == c.src)?;
                    let file = crate::render_a::resolve(base, s.proxy.as_deref().unwrap_or(&s.path));
                    let dur = (c.t_out - c.t_in).max(0.1);
                    let n = ((dur / 2.0).round() as usize).clamp(3, 12);
                    let times = (0..n).map(|k| c.t_in + dur * (k as f64 + 0.5) / n as f64).collect();
                    Some((ti, ii, file, times))
                })
                .collect::<Vec<_>>(),
            _ => vec![],
        })
        .collect();
    let results: Vec<Result<(usize, usize, Vec<Detections>)>> = jobs
        .par_iter()
        .map(|(ti, ii, file, times)| {
            let dets = times.iter().map(|t| detect_at(file, *t, cache)).collect::<Result<Vec<_>>>()?;
            Ok((*ti, *ii, dets))
        })
        .collect();
    let mut report = Vec::new();
    for r in results {
        let (ti, ii, dets) = r?;
        let crate::project::Track::Video { items, .. } = &mut p.tracks[ti] else { continue };
        let c = &mut items[ii];
        let crop = framing(&dets, base_zoom);
        if let Some(cr) = crop {
            c.crop = cr;
        }
        report.push(Reframed {
            id: c.id.clone(),
            crop,
            people: dets.iter().map(|d| d.people.len()).max().unwrap_or(0),
            faces: dets.iter().map(|d| d.faces.len()).max().unwrap_or(0),
        });
    }
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Détections réelles (soirée du 8 octobre, scène du serpent, caméra 3 à 115 et 160 s).
    fn serpent() -> Vec<Detections> {
        vec![
            Detections {
                faces: vec![[0.7317, 0.3248, 0.0244, 0.0433, 0.58]],
                people: vec![[0.6965, 0.3004, 0.0863, 0.4934, 0.78], [0.5078, 0.2345, 0.0715, 0.4119, 0.76]],
            },
            Detections {
                faces: vec![[0.5357, 0.246, 0.0244, 0.0433, 0.6]],
                people: vec![
                    [0.7827, 0.3487, 0.0818, 0.4466, 0.74],
                    [0.6661, 0.2871, 0.0822, 0.4412, 0.73],
                    [0.516, 0.2228, 0.0699, 0.4024, 0.73],
                ],
            },
        ]
    }

    #[test]
    fn frames_the_performers() {
        let c = framing(&serpent(), 1.2).unwrap();
        // Groupe entre x ≈ 0,51 et 0,86 : centre vers 0,68, zoom > 1 pour les rapprocher.
        assert!((0.62..0.74).contains(&c.cx), "{c:?}");
        assert!(c.zoom > 1.3 && c.zoom <= 2.5, "{c:?}");
        let visible = 1.0 / (1.2 * c.zoom);
        // Tous les comédiens dans le cadre, en largeur.
        assert!(c.cx - visible / 2.0 <= 0.51 && c.cx + visible / 2.0 >= 0.86, "{c:?}");
        // Les têtes (y ≈ 0,22–0,30) dans le tiers haut de l'image visible.
        let top = c.cy - visible / 2.0;
        assert!(top <= 0.22 && 0.30 <= top + visible / 3.0, "{c:?}");
    }

    #[test]
    fn nobody_keeps_crop() {
        assert!(framing(&[Detections::default()], 1.2).is_none());
        // Détection trop faible : ignorée.
        let d = Detections { faces: vec![], people: vec![[0.1, 0.1, 0.1, 0.4, 0.2]] };
        assert!(framing(&[d], 1.2).is_none());
    }

    /// Le vrai détecteur sur une image de test : `cargo test -p destiny-core -- --ignored vision_runs`.
    #[test]
    #[ignore]
    fn vision_runs() {
        assert!(available());
        let img = std::env::temp_dir().join("destiny-vision-test.jpg");
        let st = Command::new(crate::ffmpeg::ffmpeg_bin())
            .args(["-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=640x360:d=1", "-frames:v", "1"])
            .arg(&img)
            .status()
            .unwrap();
        assert!(st.success());
        let d = detect(&[img]).unwrap();
        assert_eq!(d.len(), 1);
    }
}
