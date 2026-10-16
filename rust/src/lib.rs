//! Cœur logique de DestinyStory, en Rust.
//!
//! L'interface reste en Flutter ; ce crate porte la logique pure (sans I/O) :
//! - `generator` : tirage d'une histoire (lieu, danger, archétypes, rôles) avec
//!   la mémoire anti-répétition des dangers ;
//! - `escalade` : orchestration et horaires des présages d'un épisode.
//!
//! `api` est la surface exposée à Dart via flutter_rust_bridge.

pub mod api;
pub mod escalade;
mod frb_generated;
pub mod generator;
pub mod models;
