//! Entités du domaine, miroir de `lib/domain/entities`. Les noms de champs
//! JSON sont ceux des fichiers de `assets/data/`.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Location {
    pub id: String,
    pub name: String,
    pub roles: Vec<String>,
    /// Vrai si le lieu convient au mode Rue.
    #[serde(default)]
    pub rue: bool,
    /// Vrai si le lieu est actif (sinon jamais tiré).
    #[serde(default = "vrai")]
    pub actif: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Danger {
    pub id: String,
    pub name: String,
    /// Tonalité narrative (Catastrophe, Fantastique, Mystère, ...).
    #[serde(default = "libre")]
    pub style: String,
    /// Éligible au mode Rue. Rétro-compat : ancien champ `fun`.
    #[serde(default, alias = "fun")]
    pub rue: bool,
    #[serde(default = "vrai")]
    pub theatre: bool,
    #[serde(default = "vrai")]
    pub actif: bool,
    /// Les 4 paliers d'escalade, du plus léger au climax.
    #[serde(default)]
    pub paliers: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Archetype {
    pub id: String,
    pub name: String,
    /// Statut de jeu : 'haut', 'bas' ou 'neutre'.
    #[serde(default = "neutre")]
    pub statut: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Dilemma {
    pub id: String,
    pub nom: String,
    /// Id du danger lié (banque de dangers).
    #[serde(default, rename = "danger_lie")]
    pub danger_lie: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlayerAssignment {
    pub player_index: u32,
    pub archetype_id: String,
    pub role: String,
}

/// Histoire tirée. Les entités sont référencées par id : Dart garde les objets
/// complets et les retrouve dans son catalogue.
#[derive(Debug, Clone, PartialEq)]
pub struct Story {
    pub location_id: String,
    pub danger_id: String,
    pub players: Vec<PlayerAssignment>,
    /// Dilemme tiré (mode Dilemme uniquement).
    pub dilemma_id: Option<String>,
    /// Numéro du cycle courant.
    pub cycle: u32,
    /// Dangers déjà tirés dans le cycle (celui-ci inclus).
    pub used_count: u32,
    /// Nombre de dangers actifs (taille du cycle).
    pub total_combos: u32,
}

/// État de la mémoire anti-répétition, persisté côté Dart (SQLite).
#[derive(Debug, Clone, PartialEq, Default)]
pub struct MemoryState {
    pub used_danger_ids: Vec<String>,
    pub cycle: u32,
}

/// Ce que Dart doit écrire dans sa mémoire après un tirage.
#[derive(Debug, Clone, PartialEq)]
pub struct MemoryUpdate {
    /// Vrai si un nouveau cycle commence : vider la mémoire avant `mark_used`.
    pub reset_cycle: bool,
    /// Danger à marquer comme utilisé (absent en mode Dilemme).
    pub mark_used: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Generation {
    pub story: Story,
    pub memory: MemoryUpdate,
}

fn vrai() -> bool {
    true
}
fn libre() -> String {
    "Libre".into()
}
fn neutre() -> String {
    "neutre".into()
}
