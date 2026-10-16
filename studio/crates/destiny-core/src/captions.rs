//! Sous-titres dynamiques : corrections ASR, calage mot à mot, découpe en blocs.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::project::{Caption, Word};
use crate::style::short::{SUB_MAX_CHARS, SUB_MAX_WORDS, SUB_PAUSE};

/// Applique le dictionnaire de corrections (insensible à la casse, sur mots entiers).
pub fn apply_dictionary(text: &str, dict: &BTreeMap<String, String>) -> String {
    let mut out = text.to_string();
    // Les entrées les plus longues d'abord : « sonnette d'Allah » avant « Allah ».
    let mut entries: Vec<_> = dict.iter().collect();
    entries.sort_by_key(|(k, _)| std::cmp::Reverse(k.chars().count()));
    for (wrong, right) in entries {
        out = replace_ci_words(&out, wrong, right);
    }
    out
}

fn replace_ci_words(text: &str, needle: &str, repl: &str) -> String {
    if needle.is_empty() {
        return text.to_string();
    }
    let lower = text.to_lowercase();
    let nl = needle.to_lowercase();
    // to_lowercase peut changer les longueurs en octets : on ne remplace que si elles sont stables.
    if lower.len() != text.len() {
        return text.replace(needle, repl);
    }
    let is_word = |c: Option<char>| c.is_some_and(|c| c.is_alphanumeric());
    let mut out = String::with_capacity(text.len());
    let mut i = 0;
    while let Some(pos) = lower[i..].find(&nl) {
        let s = i + pos;
        let e = s + nl.len();
        let before = text[..s].chars().next_back();
        let after = text[e..].chars().next();
        out.push_str(&text[i..s]);
        if is_word(before) || is_word(after) {
            out.push_str(&text[s..e]);
        } else {
            out.push_str(repl);
        }
        i = e;
    }
    out.push_str(&text[i..]);
    out
}

fn letters(w: &str) -> usize {
    w.chars().filter(|c| c.is_alphanumeric()).count().max(1)
}

/// Calage mot à mot : le temps du segment est réparti au prorata des lettres,
/// pondéré par l'enveloppe d'énergie de la voix (`energy` : niveaux linéaires
/// régulièrement espacés sur `[start, end]`). Les frontières de mots tombent là où
/// l'énergie cumulée atteint la proportion de lettres cumulée.
pub fn time_words(start: f64, end: f64, text: &str, energy: Option<&[f32]>) -> Vec<Word> {
    // Ponctuation isolée (« toi ? ») rattachée au mot précédent par une espace insécable.
    let mut owned: Vec<String> = Vec::new();
    for tok in text.split_whitespace() {
        let punct_only = !tok.chars().any(|c| c.is_alphanumeric());
        match owned.last_mut() {
            Some(prev) if punct_only => {
                prev.push('\u{a0}');
                prev.push_str(tok);
            }
            _ => owned.push(tok.to_string()),
        }
    }
    let words: Vec<&str> = owned.iter().map(String::as_str).collect();
    if words.is_empty() || end <= start {
        return vec![];
    }
    let total: usize = words.iter().map(|w| letters(w)).sum();
    let dur = end - start;
    // Fonction inverse de l'énergie cumulée : fraction de « parole » → temps.
    let cum: Option<Vec<f64>> = energy.filter(|e| e.len() >= 2 && e.iter().any(|v| *v > 0.0)).map(|e| {
        let mut c = vec![0.0];
        // plancher : un silence compte un peu, pour ne pas écraser un mot à zéro
        let floor = e.iter().copied().fold(0.0f32, f32::max) as f64 * 0.05;
        for v in e {
            c.push(c.last().unwrap() + (*v as f64).max(floor));
        }
        let tot = *c.last().unwrap();
        c.into_iter().map(|x| x / tot).collect()
    });
    let frac_to_t = |f: f64| -> f64 {
        match &cum {
            None => start + f * dur,
            Some(c) => {
                let k = c.partition_point(|x| *x < f).clamp(1, c.len() - 1);
                let (c0, c1) = (c[k - 1], c[k]);
                let local = if c1 > c0 { (f - c0) / (c1 - c0) } else { 0.0 };
                start + ((k - 1) as f64 + local) / (c.len() - 1) as f64 * dur
            }
        }
    };
    let mut acc = 0usize;
    words
        .iter()
        .map(|w| {
            let a = frac_to_t(acc as f64 / total as f64);
            acc += letters(w);
            let b = frac_to_t(acc as f64 / total as f64);
            Word { start: a, end: b, text: (*w).to_string() }
        })
        .collect()
}

/// Bloc de sous-titre affiché d'un coup (1 à 3 mots, ≤ 16 caractères).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Block {
    pub start: f64,
    pub end: f64,
    pub words: Vec<Word>,
}

impl Block {
    pub fn text(&self) -> String {
        self.words.iter().map(|w| w.text.as_str()).collect::<Vec<_>>().join(" ")
    }
}

fn ends_with_punct(w: &str) -> bool {
    w.ends_with(['.', ',', '!', '?', ';', ':', '…'])
}

/// Découpe des mots horodatés en blocs : coupure sur ponctuation, pause > 0,45 s,
/// 3 mots ou 16 caractères.
pub fn blocks(words: &[Word]) -> Vec<Block> {
    let mut out: Vec<Block> = Vec::new();
    let mut cur: Vec<Word> = Vec::new();
    let flush = |cur: &mut Vec<Word>, out: &mut Vec<Block>| {
        if !cur.is_empty() {
            out.push(Block { start: cur[0].start, end: cur.last().unwrap().end, words: std::mem::take(cur) });
        }
    };
    for w in words {
        if let Some(prev) = cur.last() {
            let len = cur.iter().map(|x| x.text.chars().count() + 1).sum::<usize>() + w.text.chars().count() - 1;
            if w.start - prev.end > SUB_PAUSE || cur.len() >= SUB_MAX_WORDS || len > SUB_MAX_CHARS || ends_with_punct(&prev.text) {
                flush(&mut cur, &mut out);
            }
        }
        cur.push(w.clone());
    }
    flush(&mut cur, &mut out);
    // Chaque bloc reste affiché jusqu'au suivant si l'écart est court (pas de clignotement).
    for i in 0..out.len().saturating_sub(1) {
        let next = out[i + 1].start;
        if next - out[i].end < SUB_PAUSE {
            out[i].end = next;
        }
    }
    out
}

/// Mots d'une liste de sous-titres (calage automatique si absent).
pub fn caption_words(captions: &[&Caption]) -> Vec<Word> {
    captions
        .iter()
        .flat_map(|c| if c.words.is_empty() { time_words(c.start, c.end, &c.text, None) } else { c.words.clone() })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dictionary() {
        let mut d = BTreeMap::new();
        d.insert("sonnette d'Allah".to_string(), "sonnette d'alarme".to_string());
        d.insert("morture".to_string(), "morsure".to_string());
        assert_eq!(apply_dictionary("La Sonnette d'Allah sonne", &d), "La sonnette d'alarme sonne");
        assert_eq!(apply_dictionary("une morture, mortures", &d), "une morsure, mortures");
    }

    #[test]
    fn prorata_letters() {
        let w = time_words(0.0, 3.0, "a bb ccc", None);
        assert_eq!(w.len(), 3);
        assert_eq!(time_words(0.0, 1.0, "toi ? oui !", None)[0].text, "toi\u{a0}?");
        assert!((w[0].end - 0.5).abs() < 1e-9);
        assert!((w[1].end - 1.5).abs() < 1e-9);
        assert!((w[2].end - 3.0).abs() < 1e-9);
    }

    #[test]
    fn energy_weighting_moves_boundaries() {
        // Toute l'énergie dans la 2e moitié : le 1er mot se termine après la moitié de sa part.
        let e = [0.0, 0.0, 1.0, 1.0];
        let w = time_words(0.0, 4.0, "aa bb", Some(&e));
        assert!(w[0].end > 2.0, "{:?}", w);
    }

    #[test]
    fn block_rules() {
        let words: Vec<Word> = [
            (0.0, 0.3, "C'est"), (0.3, 0.6, "pour"), (0.6, 1.2, "toi\u{a0}?"),
            (1.3, 1.5, "Y"), (1.5, 1.7, "a"), (1.7, 2.3, "quelqu'un"), (3.0, 3.4, "Immense"),
        ]
        .iter()
        .map(|(a, b, t)| Word { start: *a, end: *b, text: t.to_string() })
        .collect();
        let b = blocks(&words);
        let texts: Vec<String> = b.iter().map(|x| x.text()).collect();
        assert_eq!(texts, vec!["C'est pour toi\u{a0}?", "Y a quelqu'un", "Immense"]);
        assert!(b.iter().all(|x| x.text().chars().count() <= 16));
    }
}
