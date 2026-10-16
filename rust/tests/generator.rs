//! Mêmes garanties que `test/generate_story_usecase_test.dart`, plus le
//! chargement des vrais catalogues de `assets/data/`.

use std::collections::HashSet;

use rust_lib_destiny::generator::{generate_story, pick_archetypes_with_variety, Catalog, GenerationError};
use rust_lib_destiny::models::{Archetype, Danger, Dilemma, Location, MemoryState};
use rand::rngs::SmallRng;
use rand::SeedableRng;
use serde::Deserialize;

fn loc(id: &str) -> Location {
    Location { id: id.into(), name: id.into(), roles: vec!["r1".into(), "r2".into(), "r3".into()], rue: false, actif: true }
}
fn danger(id: &str, actif: bool) -> Danger {
    Danger { id: id.into(), name: id.into(), style: "Libre".into(), rue: false, theatre: true, actif, paliers: vec![] }
}
fn arch(id: &str, statut: &str) -> Archetype {
    Archetype { id: id.into(), name: id.into(), statut: statut.into() }
}

/// Applique la mise à jour de mémoire comme le ferait Dart.
fn apply(mem: &mut MemoryState, g: &rust_lib_destiny::models::Generation) {
    if g.memory.reset_cycle {
        mem.used_danger_ids.clear();
        mem.cycle = g.story.cycle;
    }
    if let Some(id) = &g.memory.mark_used {
        mem.used_danger_ids.push(id.clone());
    }
}

#[test]
fn ne_tire_que_les_entrees_actives() {
    let locations = [loc("a"), loc("b")];
    let dangers = [danger("d1", true), danger("d2", true), danger("d3", true), danger("off", false)];
    let archetypes = [arch("x", "neutre"), arch("y", "neutre"), arch("z", "neutre")];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &[] };
    let mut rng = SmallRng::seed_from_u64(1);
    let mut mem = MemoryState { used_danger_ids: vec![], cycle: 1 };
    for _ in 0..30 {
        let g = generate_story(&catalog, &mem, 1, false, &mut rng).unwrap();
        assert_eq!(g.story.total_combos, 3);
        assert_eq!(g.story.players.len(), 1);
        assert_ne!(g.story.danger_id, "off");
        apply(&mut mem, &g);
    }
}

#[test]
fn aucun_danger_repete_avant_epuisement_puis_nouveau_cycle() {
    let locations = [loc("a"), loc("b")];
    let dangers = [danger("d1", true), danger("d2", true), danger("d3", true)];
    let archetypes = [arch("x", "neutre"), arch("y", "neutre"), arch("z", "neutre")];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &[] };
    let mut rng = SmallRng::seed_from_u64(42);
    let mut mem = MemoryState { used_danger_ids: vec![], cycle: 1 };

    let mut seen = HashSet::new();
    for i in 0..3 {
        let g = generate_story(&catalog, &mem, 2, false, &mut rng).unwrap();
        assert!(seen.insert(g.story.danger_id.clone()), "danger répété dans le cycle");
        assert_eq!(g.story.cycle, 1);
        assert_eq!(g.story.used_count, i + 1);
        apply(&mut mem, &g);
    }
    let next = generate_story(&catalog, &mem, 2, false, &mut rng).unwrap();
    assert!(next.memory.reset_cycle);
    assert_eq!(next.story.cycle, 2);
    assert_eq!(next.story.used_count, 1);
}

#[test]
fn nombre_de_joueurs_hors_bornes() {
    let locations = [loc("a")];
    let dangers = [danger("d1", true)];
    let archetypes = [arch("x", "neutre")];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &[] };
    let mut rng = SmallRng::seed_from_u64(0);
    let mem = MemoryState::default();
    for n in [0, 11] {
        assert_eq!(
            generate_story(&catalog, &mem, n, false, &mut rng),
            Err(GenerationError::InvalidPlayerCount(n))
        );
    }
}

#[test]
fn variete_des_statuts_et_pas_de_doublon() {
    let archetypes = [
        arch("h1", "haut"), arch("h2", "haut"), arch("b1", "bas"),
        arch("b2", "bas"), arch("n1", "neutre"), arch("n2", ""),
    ];
    let mut rng = SmallRng::seed_from_u64(7);
    for _ in 0..200 {
        let picked = pick_archetypes_with_variety(&archetypes, 3, &mut rng);
        let statuts: HashSet<_> = picked.iter().map(|a| if a.statut.is_empty() { "neutre" } else { a.statut.as_str() }).collect();
        assert_eq!(statuts.len(), 3, "un haut, un bas, un neutre");
        let ids: HashSet<_> = picked.iter().map(|a| &a.id).collect();
        assert_eq!(ids.len(), 3);
    }
}

#[test]
fn plus_de_joueurs_que_de_roles() {
    let locations = [loc("a")]; // 3 rôles
    let dangers = [danger("d1", true)];
    let archetypes = [arch("x", "haut"), arch("y", "bas")];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &[] };
    let mut rng = SmallRng::seed_from_u64(3);
    let g = generate_story(&catalog, &MemoryState::default(), 10, false, &mut rng).unwrap();
    assert_eq!(g.story.players.len(), 10);
    let first: HashSet<_> = g.story.players[..3].iter().map(|p| &p.role).collect();
    assert_eq!(first.len(), 3, "les rôles distincts d'abord");
}

#[test]
fn mode_dilemme_prend_le_danger_lie() {
    let locations = [loc("a")];
    let dangers = [danger("d1", true), danger("d2", true)];
    let archetypes = [arch("x", "neutre")];
    let dilemmas = [Dilemma { id: "dl".into(), nom: "D".into(), danger_lie: "d2".into() }];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &dilemmas };
    let mut rng = SmallRng::seed_from_u64(9);
    let g = generate_story(&catalog, &MemoryState::default(), 3, true, &mut rng).unwrap();
    assert_eq!(g.story.danger_id, "d2");
    assert_eq!(g.story.dilemma_id.as_deref(), Some("dl"));
    assert!(g.story.players.is_empty());
    assert_eq!(g.memory.mark_used, None);
}

#[test]
fn meme_graine_meme_histoire() {
    let locations = [loc("a"), loc("b"), loc("c")];
    let dangers = [danger("d1", true), danger("d2", true), danger("d3", true)];
    let archetypes = [arch("x", "haut"), arch("y", "bas"), arch("z", "neutre")];
    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &[] };
    let run = || generate_story(&catalog, &MemoryState::default(), 3, false, &mut SmallRng::seed_from_u64(123)).unwrap();
    assert_eq!(run(), run());
}

#[derive(Deserialize)]
struct Locations { locations: Vec<Location> }
#[derive(Deserialize)]
struct Dangers { dangers: Vec<Danger> }
#[derive(Deserialize)]
struct Archetypes { archetypes: Vec<Archetype> }
#[derive(Deserialize)]
struct Dilemmas { dilemmes: Vec<Dilemma> }

fn asset(name: &str) -> String {
    std::fs::read_to_string(format!("{}/../assets/data/{name}", env!("CARGO_MANIFEST_DIR"))).unwrap()
}

#[test]
fn vrais_catalogues_de_l_app() {
    let locations = serde_json::from_str::<Locations>(&asset("locations.json")).unwrap().locations;
    let dangers = serde_json::from_str::<Dangers>(&asset("dangers.json")).unwrap().dangers;
    let archetypes = serde_json::from_str::<Archetypes>(&asset("archetypes.json")).unwrap().archetypes;
    let dilemmas = serde_json::from_str::<Dilemmas>(&asset("dilemmas.json")).unwrap().dilemmes;
    assert!(!locations.is_empty() && !dangers.is_empty() && !archetypes.is_empty() && !dilemmas.is_empty());

    let catalog = Catalog { locations: &locations, dangers: &dangers, archetypes: &archetypes, dilemmas: &dilemmas };
    let actifs = dangers.iter().filter(|d| d.actif).count();
    let mut rng = SmallRng::seed_from_u64(2026);
    let mut mem = MemoryState { used_danger_ids: vec![], cycle: 1 };
    let mut seen = HashSet::new();
    for _ in 0..actifs {
        let g = generate_story(&catalog, &mem, 5, false, &mut rng).unwrap();
        assert!(seen.insert(g.story.danger_id.clone()));
        assert_eq!(g.story.players.len(), 5);
        apply(&mut mem, &g);
    }
    assert_eq!(seen.len(), actifs, "tous les dangers actifs vus en un cycle");
    for _ in 0..50 {
        generate_story(&catalog, &mem, 4, true, &mut rng).unwrap();
    }
}
