//! Tirage d'une histoire. Port de `GenerateStoryUseCase` : même règles, mais
//! sans I/O — le catalogue et la mémoire entrent, l'histoire et la mise à jour
//! de mémoire sortent.

use std::collections::{HashMap, HashSet};
use std::fmt;

use rand::seq::SliceRandom;
use rand::Rng;

use crate::models::{
    Archetype, Danger, Dilemma, Generation, Location, MemoryState, MemoryUpdate, PlayerAssignment,
    Story,
};

#[derive(Debug, Clone, PartialEq)]
pub enum GenerationError {
    /// Le nombre de joueurs doit être entre 1 et 10.
    InvalidPlayerCount(u32),
    /// Il manque des lieux, dangers ou archétypes actifs.
    MissingData,
    /// Le lieu tiré n'a aucun rôle à distribuer.
    NoRoles(String),
}

impl fmt::Display for GenerationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidPlayerCount(n) => write!(f, "playerCount {n} : doit être entre 1 et 10"),
            Self::MissingData => write!(f, "Données locales insuffisantes pour tirer une histoire"),
            Self::NoRoles(id) => write!(f, "Le lieu « {id} » n'a aucun rôle"),
        }
    }
}

impl std::error::Error for GenerationError {}

pub struct Catalog<'a> {
    pub locations: &'a [Location],
    pub dangers: &'a [Danger],
    pub archetypes: &'a [Archetype],
    pub dilemmas: &'a [Dilemma],
}

/// Tire une histoire. On fait défiler TOUS les dangers actifs avant d'en
/// reprendre un ; le lieu, lui, est libre.
pub fn generate_story<R: Rng + ?Sized>(
    catalog: &Catalog,
    memory: &MemoryState,
    player_count: u32,
    dilemma: bool,
    rng: &mut R,
) -> Result<Generation, GenerationError> {
    if !(1..=10).contains(&player_count) {
        return Err(GenerationError::InvalidPlayerCount(player_count));
    }

    let locations: Vec<&Location> = catalog.locations.iter().filter(|l| l.actif).collect();
    let dangers: Vec<&Danger> = catalog.dangers.iter().filter(|d| d.actif).collect();
    if locations.is_empty() || dangers.is_empty() || catalog.archetypes.is_empty() {
        return Err(GenerationError::MissingData);
    }
    let cycle = memory.cycle.max(1);

    // Mode Dilemme : un dilemme réel + son danger lié + un lieu libre.
    if dilemma {
        if let Some(d) = catalog.dilemmas.choose(rng) {
            let danger = match catalog.dangers.iter().find(|x| x.id == d.danger_lie) {
                Some(linked) => linked,
                None => *dangers.choose(rng).unwrap(),
            };
            let location = *locations.choose(rng).unwrap();
            return Ok(Generation {
                story: Story {
                    location_id: location.id.clone(),
                    danger_id: danger.id.clone(),
                    players: vec![],
                    dilemma_id: Some(d.id.clone()),
                    cycle,
                    used_count: 0,
                    total_combos: dangers.len() as u32,
                },
                memory: MemoryUpdate { reset_cycle: false, mark_used: None },
            });
        }
    }

    let total = dangers.len();
    let used: HashSet<&str> = memory.used_danger_ids.iter().map(String::as_str).collect();
    let mut remaining: Vec<&Danger> =
        dangers.iter().copied().filter(|d| !used.contains(d.id.as_str())).collect();

    let mut new_cycle = cycle;
    let reset_cycle = remaining.is_empty();
    if reset_cycle {
        // Tous les dangers ont été vus : nouveau cycle.
        new_cycle += 1;
        remaining = dangers.clone();
    }

    let danger = *remaining.choose(rng).unwrap();
    let location = *locations.choose(rng).unwrap();
    if location.roles.is_empty() {
        return Err(GenerationError::NoRoles(location.id.clone()));
    }
    let used_count = (total - remaining.len() + 1) as u32;

    let archetypes = pick_archetypes_with_variety(catalog.archetypes, player_count as usize, rng);
    let roles = pick_many(&location.roles, player_count as usize, rng);

    let players = archetypes
        .iter()
        .zip(roles)
        .enumerate()
        .map(|(i, (a, role))| PlayerAssignment {
            player_index: i as u32 + 1,
            archetype_id: a.id.clone(),
            role: role.clone(),
        })
        .collect();

    Ok(Generation {
        story: Story {
            location_id: location.id.clone(),
            danger_id: danger.id.clone(),
            players,
            dilemma_id: None,
            cycle: new_cycle,
            used_count,
            total_combos: total as u32,
        },
        memory: MemoryUpdate { reset_cycle, mark_used: Some(danger.id.clone()) },
    })
}

/// Tire `count` éléments sans doublon tant que possible ; au-delà de la taille
/// de la source, complète par des tirages libres. `source` ne doit pas être vide.
pub fn pick_many<'a, T, R: Rng + ?Sized>(source: &'a [T], count: usize, rng: &mut R) -> Vec<&'a T> {
    let mut shuffled: Vec<&T> = source.iter().collect();
    shuffled.shuffle(rng);
    shuffled.truncate(count);
    while shuffled.len() < count {
        shuffled.push(source.choose(rng).unwrap());
    }
    shuffled
}

fn statut(a: &Archetype) -> &str {
    match a.statut.trim() {
        "" => "neutre",
        s => s,
    }
}

/// Tire `count` archétypes en garantissant, quand c'est possible, un mélange
/// de statuts (haut / bas / neutre) — « à chaque histoire, on a de tout ».
pub fn pick_archetypes_with_variety<'a, R: Rng + ?Sized>(
    archetypes: &'a [Archetype],
    count: usize,
    rng: &mut R,
) -> Vec<&'a Archetype> {
    let mut by_statut: HashMap<&str, Vec<&Archetype>> = HashMap::new();
    for a in archetypes {
        by_statut.entry(statut(a)).or_default().push(a);
    }
    // Variété impossible (1 seul joueur ou 1 seul statut) : tirage normal.
    if count <= 1 || by_statut.len() < 2 {
        return pick_many(archetypes, count, rng);
    }

    let mut chosen: Vec<&Archetype> = Vec::new();
    // 1) Un archétype de chaque statut présent, dans la limite de count.
    for s in ["haut", "bas", "neutre"] {
        if chosen.len() >= count {
            break;
        }
        if let Some(a) = by_statut.get(s).and_then(|pool| pool.choose(rng)) {
            chosen.push(a);
        }
    }
    // 2) Complète avec des archétypes aléatoires (tous statuts), sans doublon.
    let rest: Vec<&Archetype> =
        archetypes.iter().filter(|a| !chosen.iter().any(|c| c.id == a.id)).collect();
    if chosen.len() < count && !rest.is_empty() {
        let missing = count - chosen.len();
        chosen.extend(pick_many(&rest, missing, rng).into_iter().copied());
    }
    // Moins d'archétypes que de joueurs : on répète (le Dart levait RangeError).
    while chosen.len() < count {
        chosen.push(archetypes.choose(rng).unwrap());
    }
    // 3) Mélange l'ordre pour que le statut ne colle pas aux positions.
    chosen.shuffle(rng);
    chosen.truncate(count);
    chosen
}
