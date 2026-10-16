//! Escalade d'un épisode de Campagne. Port fidèle de `orchestrer`,
//! `horairesDesPresages` et `borner` (`lib/domain/usecases/constructeur_episode.dart`).
//! Ces fonctions sont déterministes : mêmes entrées, mêmes sorties qu'en Dart.

#[derive(Debug, Clone, PartialEq)]
pub struct Sbire {
    pub nom: String,
    pub manoeuvres: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Mechant {
    pub nom: String,
    pub manoeuvres: Vec<String>,
    pub presages: Vec<String>,
    pub sbires: Vec<Sbire>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Escalade {
    pub rang: u32,
    pub qui_agit: String,
    pub ce_quil_fait: String,
    pub ce_que_ca_produit: String,
    pub est_mechant: bool,
}

/// Une marche par présage. Les DEUX dernières sont pour le méchant ; les
/// précédentes pour les sbires, à tour de rôle. Sans sbire, tout est du méchant.
pub fn orchestrer(mechant: &Mechant) -> Vec<Escalade> {
    let n = mechant.presages.len();
    let mut sbire_idx = 0;
    let pick = |m: &[String], i: usize| if m.is_empty() { String::new() } else { m[i % m.len()].clone() };
    (0..n)
        .map(|i| {
            let est_mechant = i + 2 >= n || mechant.sbires.is_empty();
            let (qui, man) = if est_mechant {
                (mechant.nom.clone(), pick(&mechant.manoeuvres, i))
            } else {
                let s = &mechant.sbires[sbire_idx % mechant.sbires.len()];
                sbire_idx += 1;
                (s.nom.clone(), pick(&s.manoeuvres, i))
            };
            Escalade {
                rang: i as u32 + 1,
                qui_agit: qui,
                ce_quil_fait: man,
                ce_que_ca_produit: mechant.presages[i].clone(),
                est_mechant,
            }
        })
        .collect()
}

/// Horaires (ms écoulées) des présages dans un épisode de `duree_ms`.
///
/// Avec `intervalle_ms` : intervalle × rang. Sinon des écarts égaux en minutes
/// entières : pas = floor((durée_min − 1) / nombre). Épisode trop court :
/// répartition fine en millisecondes. Puis [`borner`].
pub fn horaires_des_presages(duree_ms: i64, nombre: usize, intervalle_ms: Option<i64>) -> Vec<i64> {
    if nombre == 0 {
        return vec![];
    }
    let n = nombre as i64;
    let horaires: Vec<i64> = match intervalle_ms {
        Some(iv) if iv > 0 => (1..=n).map(|r| iv * r).collect(),
        _ => {
            // `~/` en Dart tronque vers zéro, comme `/` sur les entiers Rust.
            let duree_min = duree_ms / 60000;
            let pas = if duree_min >= 2 { ((duree_min - 1) as f64 / n as f64).floor() as i64 } else { 0 };
            if pas >= 1 {
                (1..=n).map(|r| pas * r * 60000).collect()
            } else {
                // Trop court pour des minutes entières : réparti finement en ms.
                (1..=n).map(|r| dart_round(duree_ms as f64 * r as f64 / (n + 1) as f64)).collect()
            }
        }
    };
    borner(&horaires, duree_ms)
}

/// Ramène des horaires dans l'épisode, ordonnés et distincts, avec un pas
/// minimal d'une minute (ou moins si l'épisode est trop court), en réservant
/// une place pour chacun des présages restants plus la fin.
pub fn borner(horaires: &[i64], duree_ms: i64) -> Vec<i64> {
    let n = horaires.len() as i64;
    if n == 0 {
        return vec![];
    }
    let mut pas_min: i64 = 60000;
    // Il faut loger n horaires + la fin : (n + 1) créneaux.
    if duree_ms < pas_min * (n + 1) {
        pas_min = ((duree_ms as f64) / (n + 1) as f64).floor() as i64;
        if pas_min < 1 {
            pas_min = 1;
        }
    }
    let mut sorted = horaires.to_vec();
    sorted.sort_unstable();
    let mut result: Vec<i64> = Vec::with_capacity(sorted.len());
    for (i, &h0) in sorted.iter().enumerate() {
        let min_h = result.last().map_or(pas_min, |last| last + pas_min);
        let restants = n - 1 - i as i64;
        let max_h = duree_ms - pas_min * (restants + 1);
        // Même ordre que le Dart : d'abord le plancher, puis le plafond.
        let h = h0.max(min_h).min(max_h);
        result.push(h);
    }
    result
}

/// `num.round()` de Dart : arrondi à l'entier le plus proche, moitiés loin de zéro.
fn dart_round(x: f64) -> i64 {
    x.round() as i64
}
