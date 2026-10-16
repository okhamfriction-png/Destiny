//! Géométrie des compositions du moteur B et contrôle de la zone de texte sûre.
//!
//! Rust est la source de vérité des tailles : elles sont émises dans la composition
//! (`window.__COMP.sz`) et le runtime JS les applique telles quelles. Le contrôle Rust
//! estime la boîte de chaque bloc de texte (largeur moyenne des glyphes mesurée dans
//! Chromium, retour à la ligne mot à mot) ; le renderer JS revérifie les vraies boîtes
//! englobantes à chaque image et signale les écarts.

use std::collections::BTreeMap;

use serde::Serialize;

use crate::project::{EndCardVariant, Format, GraphicItem, Project};
use crate::style;

/// Repère de dessin : le plus petit côté vaut 1080 px (1080×1920 ou 1920×1080),
/// les autres résolutions sont obtenues par une mise à l'échelle uniforme `k`.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct Frame {
    /// Taille de sortie (pixels).
    pub w: u32,
    pub h: u32,
    /// Taille du repère de dessin.
    #[serde(rename = "W")]
    pub dw: f64,
    #[serde(rename = "H")]
    pub dh: f64,
    /// Facteur repère → pixels.
    pub k: f64,
    pub vertical: bool,
    /// Hauteur des bandes noires cinéma (repère de dessin), 0 en vertical.
    pub bars: f64,
    /// Zone où le texte est autorisé (`[y0, y1]`, repère de dessin).
    pub zone: [f64; 2],
    /// Boîte de contenu des scènes (`[x0, y0, x1, y1]`) : zone sûre moins une marge.
    pub safe: [f64; 4],
}

impl Frame {
    pub fn new(f: &Format) -> Self {
        let k = f.w.min(f.h) as f64 / 1080.0;
        let (dw, dh) = (f.w as f64 / k, f.h as f64 / k);
        let vertical = f.is_vertical();
        if vertical {
            // Pas de bandes ; on garde le texte hors des zones d'interface des réseaux
            // (pseudo en bas, boutons à droite) : marge basse plus large.
            Frame { w: f.w, h: f.h, dw, dh, k, vertical, bars: 0.0, zone: [0.0, dh], safe: [90.0, 170.0, dw - 90.0, dh - 270.0] }
        } else {
            // Bandes de 131 px à 1080 de haut, proportionnelles à la hauteur.
            let bars = style::LETTERBOX as f64 * dh / 1080.0;
            Frame {
                w: f.w,
                h: f.h,
                dw,
                dh,
                k,
                vertical,
                bars,
                zone: [bars, dh - bars],
                safe: [150.0, bars + 28.0, dw - 150.0, dh - bars - 28.0],
            }
        }
    }
    pub fn safe_w(&self) -> f64 {
        self.safe[2] - self.safe[0]
    }
    pub fn safe_h(&self) -> f64 {
        self.safe[3] - self.safe[1]
    }
}

/// Tailles de police (repère de dessin) par scène, vertical / horizontal.
pub fn sizes(vertical: bool) -> BTreeMap<&'static str, f64> {
    let v = |a: f64, b: f64| if vertical { a } else { b };
    BTreeMap::from([
        ("label", v(30.0, 26.0)),
        ("hook", v(108.0, 86.0)),
        ("big", v(230.0, 200.0)),
        ("stars", v(64.0, 54.0)),
        ("rquote", v(68.0, 48.0)),
        ("rauthor", v(28.0, 22.0)),
        ("rimg_w", v(900.0, 1060.0)),
        ("rimg_h", v(1150.0, 640.0)),
        ("quote", v(78.0, 64.0)),
        ("card_w", v(284.0, 320.0)),
        ("card_h", v(430.0, 470.0)),
        ("card_txt", v(44.0, 42.0)),
        ("cube", v(300.0, 220.0)),
        ("dice1", v(32.0, 28.0)),
        ("dice2", v(96.0, 78.0)),
        ("dice3", v(52.0, 44.0)),
        ("const", v(44.0, 38.0)),
        ("card", v(120.0, 112.0)),
        ("tag", v(34.0, 30.0)),
        ("tagbig", v(128.0, 104.0)),
        ("lname", v(64.0, 56.0)),
        ("lrole", v(28.0, 24.0)),
        ("fin", v(104.0, 92.0)),
        ("logo", v(180.0, 168.0)),
        ("tagline", v(74.0, 56.0)),
        ("info", v(32.0, 26.0)),
        ("info2", v(58.0, 44.0)),
        ("button", v(34.0, 26.0)),
        ("kicker", v(34.0, 30.0)),
        ("cta", v(60.0, 52.0)),
    ])
}

/// Familles de police, avec la largeur moyenne d'un caractère (en em) mesurée dans
/// Chromium sur des capitales accentuées (espaces compris), majorée de 6 %.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Font {
    Cinzel900,
    Cinzel700,
    /// Montserrat SemiBold, capitales, interlettrage .32em.
    Label,
}

impl Font {
    fn em_per_char(self) -> f64 {
        match self {
            Font::Cinzel900 => 0.64,
            Font::Cinzel700 => 0.62,
            Font::Label => 0.61 + 0.32,
        }
    }
}

/// Bloc de texte estimé.
#[derive(Debug, Clone, PartialEq)]
pub struct TextBlock {
    pub text: String,
    pub font: Font,
    pub size: f64,
    pub line_height: f64,
    /// Largeur maximale avant retour à la ligne ; `None` = une seule ligne (réduite au besoin).
    pub wrap: Option<f64>,
    /// Espace après le bloc.
    pub gap: f64,
}

impl TextBlock {
    fn new(text: &str, font: Font, size: f64, lh: f64, wrap: Option<f64>, gap: f64) -> Self {
        TextBlock { text: text.to_string(), font, size, line_height: lh, wrap, gap }
    }
    pub fn text_width(&self, s: &str) -> f64 {
        s.chars().count() as f64 * self.font.em_per_char() * self.size
    }
    /// Lignes après retour à la ligne mot à mot.
    pub fn lines(&self) -> Vec<String> {
        let Some(maxw) = self.wrap else { return vec![self.text.clone()] };
        let mut out: Vec<String> = Vec::new();
        let mut cur = String::new();
        for word in self.text.split_whitespace() {
            let cand = if cur.is_empty() { word.to_string() } else { format!("{cur} {word}") };
            if self.text_width(&cand) <= maxw || cur.is_empty() {
                cur = cand;
            } else {
                out.push(std::mem::take(&mut cur));
                cur = word.to_string();
            }
        }
        if !cur.is_empty() {
            out.push(cur);
        }
        out
    }
    pub fn height(&self) -> f64 {
        self.lines().len().max(1) as f64 * self.size * self.line_height
    }
    pub fn width(&self) -> f64 {
        self.lines().iter().map(|l| self.text_width(l)).fold(0.0, f64::max)
    }
}

/// Ancrage vertical d'une pile de blocs dans la boîte de contenu.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Anchor {
    Center,
    /// Bas de la pile à `marge` px au-dessus du bas de la boîte de contenu.
    Bottom(f64),
    Top,
}

/// Pile de textes d'une scène, telle que le runtime JS la dispose.
#[derive(Debug, Clone)]
pub struct Stack {
    pub blocks: Vec<TextBlock>,
    pub anchor: Anchor,
    /// Hauteur non textuelle insérée dans la pile (cartes, dé, captures…).
    pub extra_h: f64,
}

impl Stack {
    pub fn height(&self) -> f64 {
        let gaps: f64 = self.blocks.iter().rev().skip(1).map(|b| b.gap).sum();
        self.blocks.iter().map(|b| b.height()).sum::<f64>() + gaps + self.extra_h
    }
    /// `[y0, y1]` de la pile dans le repère de dessin.
    pub fn span(&self, f: &Frame) -> [f64; 2] {
        let h = self.height();
        let [_, sy0, _, sy1] = f.safe;
        match self.anchor {
            Anchor::Center => {
                let c = (sy0 + sy1) / 2.0;
                [c - h / 2.0, c + h / 2.0]
            }
            Anchor::Bottom(m) => [sy1 - m - h, sy1 - m],
            Anchor::Top => [sy0, sy0 + h],
        }
    }
}

fn up(s: &str) -> String {
    s.to_uppercase()
}

/// Piles de texte de chaque élément graphique (même disposition que `scenes.js`).
pub fn stacks(g: &GraphicItem, f: &Frame) -> Vec<Stack> {
    use Font::*;
    use GraphicItem as G;
    let sz = sizes(f.vertical);
    let s = |k: &str| sz[k];
    let sw = f.safe_w();
    let one = |blocks: Vec<TextBlock>, anchor: Anchor, extra_h: f64| vec![Stack { blocks, anchor, extra_h }];
    match g {
        G::Hook { lines, .. } => one(
            lines.iter().map(|l| TextBlock::new(&up(l), Cinzel900, s("hook"), 1.08, Some(sw), 34.0)).collect(),
            Anchor::Center,
            24.0,
        ),
        G::ReviewsTxt { items, .. } => {
            let head = vec![
                TextBlock::new("10/10", Cinzel900, s("big"), 1.0, None, 18.0),
                TextBlock::new("★★★★★", Cinzel900, s("stars"), 1.0, None, 22.0),
                TextBlock::new("AVIS DU PUBLIC", Label, s("label"), 1.2, None, 60.0),
            ];
            let qw = if f.vertical { sw } else { sw * 0.60 };
            let quotes: Vec<TextBlock> = items
                .iter()
                .flat_map(|(q, a)| {
                    [
                        TextBlock::new(&format!("« {} »", up(q)), Cinzel700, s("rquote"), 1.12, Some(qw), 10.0),
                        TextBlock::new(&format!("— {}", up(a)), Label, s("rauthor"), 1.3, None, 34.0),
                    ]
                })
                .collect();
            if f.vertical {
                let mut b = head;
                b.extend(quotes);
                one(b, Anchor::Center, 0.0)
            } else {
                vec![Stack { blocks: head, anchor: Anchor::Center, extra_h: 0.0 }, Stack { blocks: quotes, anchor: Anchor::Center, extra_h: 0.0 }]
            }
        }
        G::Reviews { .. } => one(
            vec![TextBlock::new("AVIS DU PUBLIC", Label, s("label"), 1.2, None, 40.0)],
            Anchor::Center,
            s("rimg_h").min(f.safe_h() - 120.0),
        ),
        G::Quotes { items, .. } => items
            .iter()
            .map(|q| Stack { blocks: vec![TextBlock::new(&up(q), Cinzel700, s("quote"), 1.15, Some(sw * 0.9), 0.0)], anchor: Anchor::Center, extra_h: 0.0 })
            .collect(),
        G::Mech { cards, .. } => {
            let mut v = one(vec![TextBlock::new("LE PUBLIC CHOISIT", Label, s("label"), 1.2, None, 56.0)], Anchor::Center, s("card_h"));
            // Textes des cartes : largeur de carte moins les marges intérieures.
            let cw = s("card_w") - 48.0;
            for c in cards {
                v.push(Stack { blocks: vec![TextBlock::new(&up(c), Cinzel900, s("card_txt"), 1.1, Some(cw), 0.0)], anchor: Anchor::Center, extra_h: 0.0 });
            }
            v
        }
        G::Dice { lines, .. } => {
            let mut b = Vec::new();
            for (i, l) in lines.iter().enumerate() {
                b.push(match i {
                    0 => TextBlock::new(&up(l), Label, s("dice1"), 1.2, Some(sw), 40.0),
                    1 => TextBlock::new(&up(l), Cinzel900, s("dice2"), 1.05, Some(sw), 26.0),
                    _ => TextBlock::new(l, Cinzel700, s("dice3"), 1.2, Some(sw), 0.0),
                });
            }
            // Le dé (et son ombre) s'insère entre la 1re et la 2e ligne.
            one(b, Anchor::Center, s("cube") * 1.25 + 60.0)
        }
        G::Constellation { names, .. } => {
            let mut v = one(vec![TextBlock::new("LES ARCHÉTYPES", Label, s("label"), 1.2, None, 0.0)], Anchor::Top, 0.0);
            for n in names {
                v.push(Stack { blocks: vec![TextBlock::new(&up(n), Cinzel700, s("const"), 1.1, None, 0.0)], anchor: Anchor::Center, extra_h: 0.0 });
            }
            v
        }
        G::Card { lines, .. } => one(
            lines.iter().map(|l| TextBlock::new(&up(l), Cinzel900, s("card"), 1.04, Some(sw), 6.0)).collect(),
            Anchor::Center,
            0.0,
        ),
        G::Tags { items, .. } => {
            let b = items
                .iter()
                .enumerate()
                .map(|(i, t)| {
                    if i == 0 {
                        TextBlock::new(&up(t), Label, s("tag"), 1.2 + 1.2, None, 22.0)
                    } else {
                        TextBlock::new(&up(t), Cinzel900, s("tagbig"), 1.02, Some(sw), 8.0)
                    }
                })
                .collect();
            one(b, Anchor::Bottom(if f.vertical { 180.0 } else { 10.0 }), 0.0)
        }
        G::Lower { name, role, .. } => one(
            vec![
                TextBlock::new(&up(name), Cinzel700, s("lname"), 1.1, Some(sw - 40.0), 8.0),
                TextBlock::new(&up(role), Label, s("lrole"), 1.3, Some(sw - 40.0), 0.0),
            ],
            Anchor::Bottom(if f.vertical { 120.0 } else { 0.0 }),
            0.0,
        ),
        G::Fin { text, .. } => one(vec![TextBlock::new(&up(text), Cinzel900, s("fin"), 1.08, Some(sw * 0.92), 0.0)], Anchor::Center, 0.0),
        G::EndCard { variant, lines, .. } => {
            let info = end_card_lines(*variant, lines);
            let mut b = vec![
                TextBlock::new("DESTINY", Cinzel900, s("logo"), 1.0, None, 26.0),
                TextBlock::new("RIEN N’EST ÉCRIT.", Cinzel700, s("tagline"), 1.15, Some(sw), 30.0),
            ];
            for (i, l) in info.iter().enumerate() {
                b.push(if i % 2 == 1 {
                    TextBlock::new(l, Cinzel700, s("info2"), 1.25, Some(sw), 14.0)
                } else {
                    TextBlock::new(&up(l), Label, s("info"), 1.3, Some(sw), 14.0)
                });
            }
            if let Some(last) = b.last_mut() {
                last.gap = 48.0;
            }
            // Bouton : texte + marges intérieures (0,9 em) et bordure.
            b.push(TextBlock::new(END_CARD_BUTTON, Label, s("button"), 1.2 + 1.8, Some(sw), 0.0));
            // Ornement (filet + losange) entre l'accroche et les infos.
            one(b, Anchor::Center, 40.0)
        }
        G::Kicker { text, .. } => one(vec![TextBlock::new(&up(text), Label, s("kicker"), 1.2 + 1.0, None, 0.0)], Anchor::Top, 0.0),
        G::Tag { text, .. } => one(vec![TextBlock::new(&up(text), Label, s("tag"), 1.2 + 1.2, None, 0.0)], Anchor::Bottom(240.0), 0.0),
        G::Cta { lines, .. } => one(
            lines.iter().map(|l| TextBlock::new(&up(l), Cinzel900, s("cta"), 1.1, Some(sw - 80.0), 6.0)).collect(),
            Anchor::Bottom(40.0),
            60.0,
        ),
        G::Progress { .. } | G::Ring { .. } | G::Black { .. } | G::Flash { .. } => vec![],
    }
}

pub const END_CARD_BUTTON: &str = "VIENS AVEC QUELQU’UN.";
pub const END_CARD_UNDATED: [&str; 3] = ["PROCHAINES DATES SUR BILLET RÉDUC", "La Divine Comédie · Paris 9e", "PLACES DÈS 9,95 €"];

/// Lignes d'information de la carte finale (variante sans date par défaut).
pub fn end_card_lines(variant: EndCardVariant, lines: &[String]) -> Vec<String> {
    match variant {
        EndCardVariant::Dated if !lines.is_empty() => lines.to_vec(),
        _ => END_CARD_UNDATED.iter().map(|s| s.to_string()).collect(),
    }
}

/// Problème de zone sûre détecté sur un élément graphique.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct SafeIssue {
    /// Index de l'élément dans l'ordre des pistes graphiques.
    pub index: usize,
    pub at: f64,
    pub scene: String,
    pub message: String,
    /// Bloquant : texte qui sortirait de la zone 131–949 px en 16:9 (ou de l'écran).
    pub fatal: bool,
}

pub(crate) fn scene_name(g: &GraphicItem) -> String {
    serde_json::to_value(g).ok().and_then(|v| v["type"].as_str().map(String::from)).unwrap_or_default()
}

/// Contrôle de la zone de texte : chaque pile de texte estimée doit tenir dans la
/// zone autorisée (16:9 : entre les bandes, 131–949 px à 1080 de haut) et dans la
/// largeur de l'écran. En vertical, un débordement de la boîte de contenu (zones
/// d'interface des réseaux) n'est qu'un avertissement.
pub fn check_safe_zone(p: &Project) -> Vec<SafeIssue> {
    let f = Frame::new(&p.format);
    let mut out = Vec::new();
    for (index, g) in p.graphics().enumerate() {
        let scene = scene_name(g);
        let at = g.span().0;
        for st in stacks(g, &f) {
            let [y0, y1] = st.span(&f);
            let push = |out: &mut Vec<SafeIssue>, message: String, fatal: bool| {
                out.push(SafeIssue { index, at, scene: scene.clone(), message, fatal })
            };
            if y0 < f.zone[0] - 0.5 || y1 > f.zone[1] + 0.5 {
                let what = if f.vertical { "hors de l'écran".to_string() } else { format!("hors de la zone {:.0}–{:.0} px (bandes cinéma)", f.zone[0], f.zone[1]) };
                push(&mut out, format!("texte {what} : y {:.0}–{:.0} px ({} bloc(s), {:.0} px de haut)", y0, y1, st.blocks.len(), st.height()), true);
            } else if y0 < f.safe[1] - 0.5 || y1 > f.safe[3] + 0.5 {
                push(&mut out, format!("texte hors de la boîte de contenu : y {:.0}–{:.0} px (marge {:.0}–{:.0})", y0, y1, f.safe[1], f.safe[3]), false);
            }
            for b in &st.blocks {
                // Le runtime réduit la police d'un mot (ou d'une ligne insécable) trop
                // large jusqu'à 60 % ; au-delà le texte déborde réellement.
                let maxw = b.wrap.unwrap_or(f.safe_w());
                let w = match b.wrap {
                    Some(_) => b.text.split_whitespace().map(|wd| b.text_width(wd)).fold(0.0, f64::max),
                    None => b.width(),
                };
                if w * 0.6 > maxw + 0.5 {
                    push(&mut out, format!("« {} » trop large ({:.0} px pour {:.0}, même réduit) : raccourcir le texte", b.text, w, maxw), w * 0.6 > f.dw);
                } else if w > maxw + 0.5 {
                    push(&mut out, format!("« {} » réduit à {:.0} % pour tenir ({:.0} px pour {:.0})", b.text, 100.0 * maxw / w, w, maxw), false);
                }
            }
        }
    }
    out
}

/// Version bloquante : erreur si un texte sort de la zone autorisée.
pub fn validate_safe_zone(p: &Project) -> anyhow::Result<Vec<SafeIssue>> {
    let issues = check_safe_zone(p);
    let fatal: Vec<String> = issues.iter().filter(|i| i.fatal).map(|i| format!("{} à {:.2} s : {}", i.scene, i.at, i.message)).collect();
    if !fatal.is_empty() {
        anyhow::bail!("zone de texte sûre :\n  {}", fatal.join("\n  "));
    }
    Ok(issues)
}
