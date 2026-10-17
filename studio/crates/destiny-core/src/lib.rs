//! Cœur de Destiny Studio : schéma du projet, analyse audio, moteurs de rendu.
//! Partagé par la CLI `destiny-cli` et l'application Tauri.

pub mod asr;
pub mod audio;
pub mod captions;
pub mod ffmpeg;
pub mod history;
pub mod ingest;
pub mod media;
pub mod mics;
pub mod mixer;
pub mod moments;
pub mod music;
pub mod nas;
pub mod project;
pub mod propose;
pub mod render_a;
pub mod render_b;
pub mod ass;
pub mod style;
pub mod sync;
pub mod verify;
pub mod vision;

pub use project::*;
