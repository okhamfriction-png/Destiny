//! « Demander à Claude » : la consigne est confiée à Claude Code en mode non
//! interactif (`claude -p`), lancé dans le dossier du projet. Il répond par un patch
//! RFC 6902 que l'UI montre avant de l'appliquer (annulable). Aucune clé dans le code :
//! Claude Code utilise la connexion déjà configurée sur la machine.

use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};
use destiny_core::Project;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Proposal {
    pub patch: json_patch::Patch,
    pub explanation: String,
}

fn claude_bin() -> String {
    // Installation native de Claude Code (~/.local/bin), puis npm via Homebrew.
    destiny_core::ffmpeg::tool_bin(
        "DESTINY_CLAUDE_BIN",
        &["~/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"],
        "claude",
    )
}

fn prompt(project: &Project, instruction: &str) -> Result<String> {
    Ok(format!(
        "Tu es l'assistant de montage de Destiny Studio (voir CLAUDE.md du dépôt pour la direction artistique).\n\
Voici le project.json actuel du montage :\n```json\n{}\n```\n\
Consigne de Marouene : « {instruction} »\n\n\
Réponds UNIQUEMENT par un objet JSON, sans texte autour : \
{{\"explanation\": \"<une à trois phrases en français>\", \"patch\": [<opérations RFC 6902 sur ce project.json>]}}. \
Temps des items en secondes de la vidéo finale, in/out en secondes source. Ne modifie pas les chemins des sources. \
N'écris aucun fichier : le patch sera relu puis appliqué par l'application.",
        project.to_json()?
    ))
}

/// Extrait le premier objet JSON équilibré d'un texte (la réponse peut être entourée de ```).
fn extract_json(text: &str) -> Option<&str> {
    let start = text.find('{')?;
    let mut depth = 0i32;
    let mut in_str = false;
    let mut esc = false;
    for (i, c) in text[start..].char_indices() {
        match c {
            _ if esc => esc = false,
            '\\' if in_str => esc = true,
            '"' => in_str = !in_str,
            '{' if !in_str => depth += 1,
            '}' if !in_str => {
                depth -= 1;
                if depth == 0 {
                    return Some(&text[start..start + i + 1]);
                }
            }
            _ => {}
        }
    }
    None
}

pub fn parse_reply(stdout: &str) -> Result<Proposal> {
    // `--output-format json` enveloppe la réponse dans {"result": "..."}.
    let inner = match serde_json::from_str::<serde_json::Value>(stdout) {
        Ok(v) if v.get("result").and_then(|r| r.as_str()).is_some() => v["result"].as_str().unwrap().to_string(),
        _ => stdout.to_string(),
    };
    let json = extract_json(&inner).context("la réponse de Claude ne contient pas de JSON")?;
    serde_json::from_str(json).context("réponse de Claude mal formée (attendu {explanation, patch})")
}

pub fn ask(project_path: &Path, project: &Project, instruction: &str) -> Result<Proposal> {
    let dir = project_path.parent().unwrap_or(Path::new("."));
    let out = Command::new(claude_bin())
        .current_dir(dir)
        .args(["-p", &prompt(project, instruction)?, "--output-format", "json"])
        .output()
        .context("Claude Code introuvable : installer `claude` ou définir DESTINY_CLAUDE_BIN")?;
    if !out.status.success() {
        bail!("Claude Code a échoué : {}", String::from_utf8_lossy(&out.stderr));
    }
    let proposal = parse_reply(&String::from_utf8_lossy(&out.stdout))?;
    // Vérification à blanc : le patch doit s'appliquer et donner un projet valide.
    let mut check = project.clone();
    destiny_core::history::History::default().apply_patch(&mut check, &proposal.patch, "vérification")?;
    Ok(proposal)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_wrapped_reply() {
        let inner = "Voici :\n```json\n{\"explanation\": \"Hook raccourci {ok}\", \"patch\": [{\"op\": \"replace\", \"path\": \"/format/fps\", \"value\": 25}]}\n```";
        let wrapped = serde_json::json!({ "type": "result", "result": inner }).to_string();
        let p = parse_reply(&wrapped).unwrap();
        assert_eq!(p.explanation, "Hook raccourci {ok}");
        assert_eq!(p.patch.0.len(), 1);
    }
}
