//! Schéma de `project.json` : le contrat entre l'agent, l'UI et les moteurs de rendu.
//!
//! Conventions de temps :
//! - `at`, `dur`, `start`, `end` des items : secondes de la **vidéo finale** ;
//! - `in` / `out` des clips : secondes **dans le fichier source** ;
//! - `rec` des sources et micros : frame de début sur la **timeline maîtresse** à 25 i/s ;
//! - `mic_gates` et `markers.cuts` côté source : secondes de la **timeline maîtresse**.

use std::collections::BTreeMap;
use std::path::Path;

use anyhow::{bail, Context, Result};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use ts_rs::TS;

pub const PROJECT_VERSION: u32 = 1;
/// Cadence de la timeline maîtresse (frames `rec`).
pub const MASTER_FPS: f64 = 25.0;

fn is_default<T: Default + PartialEq>(v: &T) -> bool {
    *v == T::default()
}
fn one() -> f64 {
    1.0
}
fn is_one(v: &f64) -> bool {
    *v == 1.0
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Project {
    pub version: u32,
    pub format: Format,
    pub preset: Preset,
    #[serde(default)]
    pub sources: Vec<Source>,
    #[serde(default)]
    pub mics: Vec<Mic>,
    #[serde(default)]
    pub tracks: Vec<Track>,
    /// Intervalles où chaque micro est ouvert (secondes de la timeline maîtresse).
    /// Un micro absent de la table est ouvert partout ; une liste vide le ferme.
    #[serde(default)]
    pub mic_gates: BTreeMap<String, Vec<[f64; 2]>>,
    #[serde(default)]
    pub markers: Markers,
    #[serde(default)]
    pub export: ExportCfg,
    /// Corrections ASR propres au projet (« sonnette d'Allah » → « sonnette d'alarme »).
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub dictionary: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Format {
    pub w: u32,
    pub h: u32,
    pub fps: u32,
}

impl Format {
    pub const VERTICAL: Format = Format { w: 1080, h: 1920, fps: 30 };
    pub const HORIZONTAL: Format = Format { w: 1920, h: 1080, fps: 25 };
    pub fn is_vertical(&self) -> bool {
        self.h > self.w
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, TS, JsonSchema)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum Preset {
    ShortScene,
    ReelBm,
    TrailerV,
    TrailerH,
    RetentionPeaks,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Source {
    pub id: String,
    /// Fichier pleine résolution (4K), utilisé uniquement à l'export final.
    pub path: String,
    /// Proxy synchrone (`.LRF` DJI ou proxy 720p généré) pour analyse et aperçu.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub proxy: Option<String>,
    /// Frame de début sur la timeline maîtresse (25 i/s, fractionnaire après auto-sync).
    #[serde(default)]
    pub rec: f64,
    /// Durée du fichier en secondes (renseignée par l'ingest).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub duration: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Mic {
    pub id: String,
    pub path: String,
    #[serde(default)]
    pub rec: f64,
    /// Comédien porteur du micro (identifiant libre : « pink_jacket », « Jean »…).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub actor: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub duration: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[ts(export)]
pub enum Track {
    Video { id: String, items: Vec<VideoItem> },
    Voice { id: String, items: Vec<VoiceItem> },
    Music { id: String, items: Vec<MusicItem> },
    Sfx { id: String, items: Vec<SfxItem> },
    Graphics { id: String, items: Vec<GraphicItem> },
    Captions { id: String, items: Vec<Caption> },
}

impl Track {
    pub fn id(&self) -> &str {
        match self {
            Track::Video { id, .. }
            | Track::Voice { id, .. }
            | Track::Music { id, .. }
            | Track::Sfx { id, .. }
            | Track::Graphics { id, .. }
            | Track::Captions { id, .. } => id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Crop {
    /// Centre horizontal normalisé (0 = gauche, 1 = droite).
    pub cx: f64,
    pub cy: f64,
    /// Zoom appliqué en plus du zoom de base du preset.
    pub zoom: f64,
}

impl Default for Crop {
    fn default() -> Self {
        Crop { cx: 0.5, cy: 0.5, zoom: 1.0 }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Fx {
    /// « Punch » d'entrée : échelle 1,09 → 1 en 0,6 s.
    #[serde(default, skip_serializing_if = "is_default")]
    pub punch: bool,
    /// Flash blanc chaud de 0,22 s à l'entrée du plan.
    #[serde(default, skip_serializing_if = "is_default")]
    pub flash: bool,
    /// Zoom continu sur la durée du plan (0,06 → 1 à 1,06). `None` = défaut du preset.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub push: Option<f64>,
    /// Punch-in (zoom 1,2) entre ces deux instants, relatifs au début du plan.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub punch_in: Option<[f64; 2]>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct VideoItem {
    pub id: String,
    pub src: String,
    #[serde(rename = "in")]
    #[ts(rename = "in")]
    pub t_in: f64,
    #[serde(rename = "out")]
    #[ts(rename = "out")]
    pub t_out: f64,
    pub at: f64,
    #[serde(default)]
    pub crop: Crop,
    #[serde(default)]
    pub fx: Fx,
}

impl VideoItem {
    pub fn dur(&self) -> f64 {
        self.t_out - self.t_in
    }
    pub fn end(&self) -> f64 {
        self.at + self.dur()
    }
}

/// Découpe voix : même découpe que la vidéo, la voix vient des micros gatés.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct VoiceItem {
    pub id: String,
    /// Source de référence pour `in`/`out` (convertie en timeline maîtresse via `rec`).
    pub src: String,
    #[serde(rename = "in")]
    #[ts(rename = "in")]
    pub t_in: f64,
    #[serde(rename = "out")]
    #[ts(rename = "out")]
    pub t_out: f64,
    pub at: f64,
    #[serde(default = "one", skip_serializing_if = "is_one")]
    pub gain: f64,
    /// Utiliser l'audio caméra plutôt que les micros (ex. cri du public).
    #[serde(default, skip_serializing_if = "is_default")]
    pub camera_audio: bool,
}

impl VoiceItem {
    pub fn dur(&self) -> f64 {
        self.t_out - self.t_in
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct MusicItem {
    pub file: String,
    pub at: f64,
    /// Position dans le fichier musique correspondant à `at`.
    #[serde(default)]
    pub offset: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dur: Option<f64>,
    /// Enveloppe de gain `[temps vidéo, gain]`, interpolée linéairement.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub gain_env: Vec<[f64; 2]>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, TS, JsonSchema)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum SfxKind {
    Snap,
    Whoosh,
    Tom,
    Gong,
    Braam,
    SubDrop,
    Impact,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct SfxItem {
    #[serde(rename = "type")]
    #[ts(rename = "type")]
    pub kind: SfxKind,
    pub at: f64,
    #[serde(default = "one")]
    pub gain: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize, TS, JsonSchema)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum EndCardVariant {
    Dated,
    #[default]
    Undated,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize, TS, JsonSchema)]
#[serde(rename_all = "snake_case")]
#[ts(export)]
pub enum CardStyle {
    #[default]
    Fade,
    Stamp,
}

/// Éléments graphiques. Les shorts (moteur A) utilisent kicker/hook/tag/cta/progress ;
/// les trailers (moteur B) la bibliothèque de scènes complète.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[serde(tag = "type", rename_all = "snake_case")]
#[ts(export)]
pub enum GraphicItem {
    Kicker { at: f64, dur: f64, text: String },
    Hook { at: f64, dur: f64, lines: Vec<String> },
    Tag { at: f64, dur: f64, text: String },
    Cta {
        at: f64,
        dur: f64,
        lines: Vec<String>,
    },
    Progress { at: f64, dur: f64 },
    /// Citations d'avis stylisées `[texte, auteur]`.
    ReviewsTxt { at: f64, dur: f64, items: Vec<(String, String)> },
    /// Vraies captures d'avis (chemins d'images), une à une.
    Reviews { at: f64, dur: f64, images: Vec<String> },
    Quotes { at: f64, dur: f64, items: Vec<String> },
    /// Les trois cartes du public (lieu / danger / archétypes).
    Mech {
        at: f64,
        dur: f64,
        cards: Vec<String>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        background: Option<String>,
    },
    Dice { at: f64, dur: f64, lines: Vec<String> },
    Constellation { at: f64, dur: f64, names: Vec<String> },
    Card {
        at: f64,
        dur: f64,
        lines: Vec<String>,
        #[serde(default)]
        style: CardStyle,
    },
    Tags { at: f64, dur: f64, items: Vec<String> },
    Lower { at: f64, dur: f64, name: String, role: String },
    Ring { at: f64, dur: f64 },
    Fin { at: f64, dur: f64, text: String },
    Black { at: f64, dur: f64 },
    EndCard {
        at: f64,
        dur: f64,
        #[serde(default)]
        variant: EndCardVariant,
        /// Lignes de date/lieu pour la variante datée.
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        lines: Vec<String>,
    },
    Flash { at: f64, dur: f64 },
}

impl GraphicItem {
    pub fn span(&self) -> (f64, f64) {
        use GraphicItem::*;
        match self {
            Kicker { at, dur, .. }
            | Hook { at, dur, .. }
            | Tag { at, dur, .. }
            | Cta { at, dur, .. }
            | Progress { at, dur }
            | ReviewsTxt { at, dur, .. }
            | Reviews { at, dur, .. }
            | Quotes { at, dur, .. }
            | Mech { at, dur, .. }
            | Dice { at, dur, .. }
            | Constellation { at, dur, .. }
            | Card { at, dur, .. }
            | Tags { at, dur, .. }
            | Lower { at, dur, .. }
            | Ring { at, dur }
            | Fin { at, dur, .. }
            | Black { at, dur }
            | EndCard { at, dur, .. }
            | Flash { at, dur } => (*at, *dur),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Word {
    pub start: f64,
    pub end: f64,
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Caption {
    pub start: f64,
    pub end: f64,
    pub text: String,
    /// Calage mot à mot ; calculé au rendu s'il est absent.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub words: Vec<Word>,
    /// Mots-clés d'emphase (affichés en rouge).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub emphasis: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct Markers {
    #[serde(default)]
    pub music_hits: Vec<f64>,
    #[serde(default)]
    pub cuts: Vec<f64>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize, TS, JsonSchema)]
#[ts(export)]
pub struct ExportCfg {
    /// Destinations : chemin local ou `nas:/chemin/relatif/au/NAS/`.
    #[serde(default)]
    pub targets: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

impl Project {
    pub fn new(preset: Preset) -> Self {
        let format = match preset {
            Preset::TrailerH => Format::HORIZONTAL,
            _ => Format::VERTICAL,
        };
        Project {
            version: PROJECT_VERSION,
            format,
            preset,
            sources: vec![],
            mics: vec![],
            tracks: vec![],
            mic_gates: BTreeMap::new(),
            markers: Markers::default(),
            export: ExportCfg::default(),
            dictionary: BTreeMap::new(),
        }
    }

    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        let txt = std::fs::read_to_string(path)
            .with_context(|| format!("lecture de {}", path.display()))?;
        Self::from_json(&txt).with_context(|| format!("projet invalide : {}", path.display()))
    }

    pub fn from_json(txt: &str) -> Result<Self> {
        let p: Project = serde_json::from_str(txt)?;
        p.validate()?;
        Ok(p)
    }

    /// Écriture atomique (fichier temporaire puis renommage) : l'UI et l'agent
    /// peuvent écrire le même fichier sans jamais lire un JSON tronqué.
    pub fn save(&self, path: impl AsRef<Path>) -> Result<()> {
        let path = path.as_ref();
        // Premier montage d'un spectacle : `montages/` n'existe pas encore.
        if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
            std::fs::create_dir_all(dir)?;
        }
        let tmp = path.with_extension("json.tmp");
        std::fs::write(&tmp, self.to_json()?)?;
        std::fs::rename(&tmp, path)?;
        Ok(())
    }

    pub fn to_json(&self) -> Result<String> {
        Ok(serde_json::to_string_pretty(self)? + "\n")
    }

    pub fn source(&self, id: &str) -> Option<&Source> {
        self.sources.iter().find(|s| s.id == id)
    }

    pub fn mic(&self, id: &str) -> Option<&Mic> {
        self.mics.iter().find(|m| m.id == id)
    }

    pub fn video_items(&self) -> impl Iterator<Item = &VideoItem> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Video { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    pub fn voice_items(&self) -> impl Iterator<Item = &VoiceItem> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Voice { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    pub fn graphics(&self) -> impl Iterator<Item = &GraphicItem> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Graphics { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    pub fn captions(&self) -> impl Iterator<Item = &Caption> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Captions { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    pub fn music_items(&self) -> impl Iterator<Item = &MusicItem> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Music { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    pub fn sfx_items(&self) -> impl Iterator<Item = &SfxItem> {
        self.tracks.iter().flat_map(|t| match t {
            Track::Sfx { items, .. } => items.as_slice(),
            _ => &[],
        })
    }

    /// Durée de la vidéo finale : fin du dernier élément visuel.
    pub fn duration(&self) -> f64 {
        let v = self.video_items().map(|c| c.end());
        let g = self.graphics().map(|g| {
            let (a, d) = g.span();
            a + d
        });
        v.chain(g).fold(0.0, f64::max)
    }

    /// Vérifications sémantiques (le JSON Schema ne couvre que la forme).
    pub fn validate(&self) -> Result<()> {
        if self.version != PROJECT_VERSION {
            bail!("version {} non prise en charge (attendu {PROJECT_VERSION})", self.version);
        }
        if self.format.w == 0 || self.format.h == 0 || self.format.fps == 0 {
            bail!("format invalide");
        }
        let mut ids = std::collections::HashSet::new();
        for s in &self.sources {
            if !ids.insert(&s.id) {
                bail!("identifiant de source dupliqué : {}", s.id);
            }
        }
        for m in &self.mics {
            if !ids.insert(&m.id) {
                bail!("identifiant de micro dupliqué : {}", m.id);
            }
        }
        let mut track_ids = std::collections::HashSet::new();
        for t in &self.tracks {
            if !track_ids.insert(t.id()) {
                bail!("identifiant de piste dupliqué : {}", t.id());
            }
        }
        let mut item_ids = std::collections::HashSet::new();
        for c in self.video_items() {
            if !item_ids.insert(&c.id) {
                bail!("identifiant de clip dupliqué : {}", c.id);
            }
            if self.source(&c.src).is_none() {
                bail!("clip {} : source inconnue {}", c.id, c.src);
            }
            if !(c.t_out > c.t_in) || c.t_in < 0.0 || c.at < 0.0 {
                bail!("clip {} : intervalle invalide ({} → {} à {})", c.id, c.t_in, c.t_out, c.at);
            }
            if c.crop.zoom <= 0.0 {
                bail!("clip {} : zoom doit être > 0", c.id);
            }
        }
        for v in self.voice_items() {
            if self.source(&v.src).is_none() {
                bail!("voix {} : source inconnue {}", v.id, v.src);
            }
            if !(v.t_out > v.t_in) {
                bail!("voix {} : intervalle invalide", v.id);
            }
        }
        for (mic, gates) in &self.mic_gates {
            if self.mic(mic).is_none() {
                bail!("mic_gates : micro inconnu {mic}");
            }
            for g in gates {
                if !(g[1] > g[0]) {
                    bail!("mic_gates {mic} : intervalle invalide {:?}", g);
                }
            }
        }
        for c in self.captions() {
            if !(c.end > c.start) {
                bail!("sous-titre « {} » : fin avant début", c.text);
            }
        }
        for g in self.graphics() {
            if let GraphicItem::Hook { lines, .. } = g {
                if lines.len() > 2 {
                    bail!("hook : 2 lignes maximum ({} reçues)", lines.len());
                }
            }
            let (_, d) = g.span();
            if d <= 0.0 {
                bail!("élément graphique de durée nulle : {:?}", g);
            }
        }
        Ok(())
    }
}

/// JSON Schema du projet (forme), publié dans `schema/project.schema.json`.
pub fn json_schema() -> serde_json::Value {
    serde_json::to_value(schemars::schema_for!(Project)).expect("schéma sérialisable")
}

#[cfg(test)]
mod tests {
    use super::*;

    const SPEC_EXAMPLE: &str = r#"{
      "version": 1,
      "format": { "w": 1080, "h": 1920, "fps": 30 },
      "preset": "short_scene",
      "sources": [ { "id": "cam4", "path": "a.MP4", "proxy": "a.LRF", "rec": 170453 } ],
      "mics": [ { "id": "m2", "path": "m2.wav", "rec": 130284, "actor": "pink_jacket" } ],
      "tracks": [
        { "id": "v0", "kind": "video", "items": [
          { "id": "c1", "src": "cam4", "in": 6779.3, "out": 6801.6, "at": 0.0,
            "crop": { "cx": 0.55, "cy": 0.50, "zoom": 1.6 },
            "fx": { "punch": true, "flash": true, "push": 0.06 } } ] },
        { "id": "a_music", "kind": "music", "items": [ { "file": "Ritual Pulse.m4a", "at": 0, "offset": 0, "gain_env": [[0,0.45],[54.5,0.62],[83.1,1.0]] } ] },
        { "id": "a_sfx", "kind": "sfx", "items": [ { "type": "snap", "at": 2.1, "gain": 0.45 } ] },
        { "id": "g_text", "kind": "graphics", "items": [
          { "type": "hook", "at": 0, "dur": 1.6, "lines": ["ILS N’ONT RIEN RÉPÉTÉ.", "LE PUBLIC MET 10/10."] },
          { "type": "reviews_txt", "at": 1.6, "dur": 5.0, "items": [["EXCELLENT ET INNOVANT !","Paul"]] },
          { "type": "end_card", "at": 83.6, "dur": 5.55, "variant": "undated" } ] },
        { "id": "subs", "kind": "captions", "items": [ { "start": 1.08, "end": 2.39, "text": "C'est pour toi ? Y a quelqu'un ?" } ] }
      ],
      "mic_gates": { "m2": [[5266.8, 5327.3]] },
      "markers": { "music_hits": [55.9, 83.6], "cuts": [14.0] },
      "export": { "targets": ["nas:/Spectacle/8 Octobre 2026/Shorts pics YouTube/"] }
    }"#;

    #[test]
    fn parses_spec_example_and_roundtrips() {
        let p = Project::from_json(SPEC_EXAMPLE).unwrap();
        assert_eq!(p.preset, Preset::ShortScene);
        assert_eq!(p.sources[0].rec, 170453.0);
        let c = p.video_items().next().unwrap();
        assert_eq!(c.t_in, 6779.3);
        assert!((p.duration() - 89.15).abs() < 1e-9);
        let again = Project::from_json(&p.to_json().unwrap()).unwrap();
        assert_eq!(p, again);
    }

    #[test]
    fn rejects_unknown_source_and_long_hook() {
        let bad = SPEC_EXAMPLE.replace("\"src\": \"cam4\"", "\"src\": \"cam9\"");
        assert!(Project::from_json(&bad).is_err());
        let bad = SPEC_EXAMPLE.replace(
            "\"LE PUBLIC MET 10/10.\"]",
            "\"LE PUBLIC MET 10/10.\", \"TROIS\"]",
        );
        assert!(Project::from_json(&bad).is_err());
    }

    #[test]
    fn schema_is_generated() {
        let s = json_schema();
        assert!(s["$defs"]["Track"].is_object());
    }
}
