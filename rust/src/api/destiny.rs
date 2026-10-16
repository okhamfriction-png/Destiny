use flutter_rust_bridge::frb;
use rand::rngs::SmallRng;
use rand::SeedableRng;

use crate::escalade::{self, Escalade, Mechant};
use crate::generator::{self, Catalog};
use crate::models::{Archetype, Danger, Dilemma, Generation, Location, MemoryState};

/// Tire une histoire. `seed` rend le tirage reproductible (tests, partage) ;
/// sans seed, le hasard du système est utilisé.
///
/// Dart applique ensuite `memory` à sa mémoire SQLite (`CombinationMemory`).
/// Une `GenerationError` arrive côté Dart en `AnyhowException`.
#[frb(sync)]
#[allow(clippy::too_many_arguments)]
pub fn generate_story(
    locations: Vec<Location>,
    dangers: Vec<Danger>,
    archetypes: Vec<Archetype>,
    dilemmas: Vec<Dilemma>,
    memory: MemoryState,
    player_count: u32,
    dilemma: bool,
    seed: Option<u64>,
) -> anyhow::Result<Generation> {
    let catalog = Catalog {
        locations: &locations,
        dangers: &dangers,
        archetypes: &archetypes,
        dilemmas: &dilemmas,
    };
    let mut rng = match seed {
        Some(s) => SmallRng::seed_from_u64(s),
        None => SmallRng::from_entropy(),
    };
    Ok(generator::generate_story(&catalog, &memory, player_count, dilemma, &mut rng)?)
}

/// Escalade d'un épisode : une marche par présage (voir `orchestrer` en Dart).
#[frb(sync)]
pub fn orchestrer(mechant: Mechant) -> Vec<Escalade> {
    escalade::orchestrer(&mechant)
}

/// Horaires (ms écoulées) des présages d'un épisode de `duree_ms`.
#[frb(sync)]
pub fn horaires_des_presages(duree_ms: i64, nombre: u32, intervalle_ms: Option<i64>) -> Vec<i64> {
    escalade::horaires_des_presages(duree_ms, nombre as usize, intervalle_ms)
}

/// Ramène des horaires dans l'épisode, ordonnés, distincts et espacés.
#[frb(sync)]
pub fn borner(horaires: Vec<i64>, duree_ms: i64) -> Vec<i64> {
    escalade::borner(&horaires, duree_ms)
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
