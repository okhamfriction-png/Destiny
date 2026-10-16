//! Jobs longs (ingest, analyse, rendu, export) sur des threads dédiés, avec
//! progression envoyée au front par l'événement `job` et annulation par PID.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use destiny_core::ffmpeg::Cancel;
use serde::Serialize;
use serde_json::Value;
use tauri::{AppHandle, Emitter};

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct JobEvent {
    pub id: String,
    pub kind: String,
    pub stage: String,
    pub progress: f64,
    pub done: bool,
    pub error: Option<String>,
    pub result: Option<Value>,
}

pub struct Ctx {
    pub id: String,
    pub kind: String,
    pub cancel: Cancel,
    app: AppHandle,
    last: Mutex<(String, i64)>,
}

impl Ctx {
    /// Émet la progression (au plus un événement par point de pourcentage).
    pub fn progress(&self, stage: &str, x: f64) {
        let pct = (x * 100.0).floor() as i64;
        {
            let mut last = self.last.lock().unwrap();
            if last.0 == stage && last.1 == pct {
                return;
            }
            *last = (stage.to_string(), pct);
        }
        let _ = self.app.emit("job", JobEvent {
            id: self.id.clone(),
            kind: self.kind.clone(),
            stage: stage.into(),
            progress: x.clamp(0.0, 1.0),
            done: false,
            error: None,
            result: None,
        });
    }

    pub fn check(&self) -> anyhow::Result<()> {
        if self.cancel.is_cancelled() {
            anyhow::bail!("annulé");
        }
        Ok(())
    }
}

#[derive(Default)]
pub struct Jobs {
    next: AtomicU64,
    running: Arc<Mutex<HashMap<String, Cancel>>>,
}

impl Jobs {
    pub fn spawn(
        &self,
        app: &AppHandle,
        kind: &str,
        work: impl FnOnce(&Ctx) -> anyhow::Result<Value> + Send + 'static,
    ) -> String {
        let id = format!("{kind}-{}", self.next.fetch_add(1, Ordering::SeqCst) + 1);
        let ctx = Ctx {
            id: id.clone(),
            kind: kind.into(),
            cancel: Cancel::default(),
            app: app.clone(),
            last: Mutex::new((String::new(), -1)),
        };
        self.running.lock().unwrap().insert(id.clone(), ctx.cancel.clone());
        let running = self.running.clone();
        std::thread::spawn(move || {
            let res = work(&ctx);
            running.lock().unwrap().remove(&ctx.id);
            let (error, result) = match res {
                Ok(v) => (None, Some(v)),
                Err(e) => (Some(format!("{e:#}")), None),
            };
            let _ = ctx.app.emit("job", JobEvent {
                id: ctx.id.clone(),
                kind: ctx.kind.clone(),
                stage: if error.is_some() { "erreur".into() } else { "terminé".into() },
                progress: 1.0,
                done: true,
                error,
                result,
            });
        });
        id
    }

    pub fn cancel(&self, id: &str) {
        if let Some(c) = self.running.lock().unwrap().get(id) {
            c.cancel();
        }
    }
}
