//! Undo/redo par patchs JSON (RFC 6902) et application des patchs de l'agent.
//! Chaque modification de l'UI ou de Claude devient une paire (aller, retour).

use anyhow::{Context, Result};
use json_patch::Patch;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::project::Project;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub label: String,
    pub forward: Patch,
    pub backward: Patch,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct History {
    pub undo: Vec<Entry>,
    pub redo: Vec<Entry>,
}

fn to_value(p: &Project) -> Value {
    serde_json::to_value(p).expect("projet sérialisable")
}

impl History {
    /// Remplace le projet par `next` (déjà validé) et enregistre le diff.
    pub fn commit(&mut self, current: &mut Project, next: Project, label: impl Into<String>) -> Result<()> {
        next.validate()?;
        let a = to_value(current);
        let b = to_value(&next);
        let forward = json_patch::diff(&a, &b);
        if forward.0.is_empty() {
            return Ok(());
        }
        let backward = json_patch::diff(&b, &a);
        self.undo.push(Entry { label: label.into(), forward, backward });
        self.redo.clear();
        *current = next;
        Ok(())
    }

    /// Applique un patch RFC 6902 (ex. renvoyé par « Demander à Claude ») de façon
    /// atomique : en cas d'échec ou de projet invalide, rien ne change.
    pub fn apply_patch(&mut self, current: &mut Project, patch: &Patch, label: impl Into<String>) -> Result<()> {
        let mut v = to_value(current);
        json_patch::patch(&mut v, patch).context("patch inapplicable")?;
        let next: Project = serde_json::from_value(v).context("le patch produit un projet mal formé")?;
        self.commit(current, next, label)
    }

    pub fn undo(&mut self, current: &mut Project) -> Result<Option<String>> {
        let Some(e) = self.undo.pop() else { return Ok(None) };
        let mut v = to_value(current);
        json_patch::patch(&mut v, &e.backward)?;
        *current = serde_json::from_value(v)?;
        let label = e.label.clone();
        self.redo.push(e);
        Ok(Some(label))
    }

    pub fn redo(&mut self, current: &mut Project) -> Result<Option<String>> {
        let Some(e) = self.redo.pop() else { return Ok(None) };
        let mut v = to_value(current);
        json_patch::patch(&mut v, &e.forward)?;
        *current = serde_json::from_value(v)?;
        let label = e.label.clone();
        self.undo.push(e);
        Ok(Some(label))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::project::*;

    #[test]
    fn undo_redo_and_agent_patch() {
        let mut p = Project::new(Preset::ShortScene);
        let mut h = History::default();
        let mut next = p.clone();
        next.tracks.push(Track::Graphics {
            id: "g".into(),
            items: vec![GraphicItem::Kicker { at: 0.0, dur: 3.0, text: "SCÈNE 4/25".into() }],
        });
        h.commit(&mut p, next, "kicker").unwrap();
        let patch: json_patch::Patch = serde_json::from_str(
            r#"[{"op":"replace","path":"/tracks/0/items/0/text","value":"LE PLUS REVU · 1/3"}]"#,
        )
        .unwrap();
        h.apply_patch(&mut p, &patch, "claude").unwrap();
        assert!(matches!(&p.graphics().next().unwrap(), GraphicItem::Kicker { text, .. } if text == "LE PLUS REVU · 1/3"));
        assert_eq!(h.undo(&mut p).unwrap().as_deref(), Some("claude"));
        assert!(matches!(&p.graphics().next().unwrap(), GraphicItem::Kicker { text, .. } if text == "SCÈNE 4/25"));
        h.undo(&mut p).unwrap();
        assert!(p.tracks.is_empty());
        h.redo(&mut p).unwrap();
        assert_eq!(p.tracks.len(), 1);
        // Un patch qui casse le projet est refusé sans rien modifier.
        let bad: json_patch::Patch =
            serde_json::from_str(r#"[{"op":"replace","path":"/tracks/0/items/0/dur","value":0}]"#).unwrap();
        let before = p.clone();
        assert!(h.apply_patch(&mut p, &bad, "bad").is_err());
        assert_eq!(p, before);
    }
}
