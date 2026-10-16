//! Génération du fichier ASS des shorts (moteur A) : kicker, bandeau hook, tag,
//! sous-titres dynamiques mot à mot et CTA.

use std::fmt::Write;

use crate::captions::{self, Block};
use crate::project::{GraphicItem, Project};
use crate::style::{self, short, ass_color};

/// Géométrie verticale du layout « group » (1080×1920).
pub struct Layout {
    pub w: u32,
    pub h: u32,
    pub kicker_y: i32,
    pub banner: (i32, i32),
    pub tag_y: i32,
    pub band_top: i32,
    pub band_bottom: i32,
    pub subs_y: i32,
    pub cta_y: i32,
}

impl Layout {
    pub fn for_format(w: u32, h: u32) -> Self {
        let band_cy = h as i32 / 2 + short::BAND_CY_OFFSET;
        let band_h = (short::BAND_H as f64 * w as f64 / short::BAND_W as f64) as i32;
        let band_top = band_cy - band_h / 2;
        let band_bottom = band_top + band_h;
        Layout {
            w,
            h,
            kicker_y: band_top - 345,
            banner: (band_top - 306, band_top - 96),
            tag_y: band_top - 50,
            band_top,
            band_bottom,
            subs_y: band_bottom + 230,
            cta_y: band_bottom + 250,
        }
    }
}

pub fn ts(t: f64) -> String {
    let cs = (t.max(0.0) * 100.0).round() as u64;
    format!("{}:{:02}:{:02}.{:02}", cs / 360_000, (cs / 6000) % 60, (cs / 100) % 60, cs % 100)
}

pub fn escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('{', "\\{").replace('}', "\\}").replace('\n', "\\N")
}

fn header(w: u32, h: u32) -> String {
    let white = ass_color(style::TEXT, 0);
    let black = ass_color("#000000", 0);
    let yellow = ass_color(short_yellow(), 0);
    let red = ass_color(style::SHORT_RED, 0);
    let shadow = ass_color("#000000", 0x60);
    format!(
        "[Script Info]\nScriptType: v4.00+\nPlayResX: {w}\nPlayResY: {h}\nWrapStyle: 2\nScaledBorderAndShadow: yes\nYCbCr Matrix: TV.709\n\n\
[V4+ Styles]\n\
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n\
Style: Kicker,{m},44,{yellow},{yellow},{black},{shadow},0,0,0,0,100,100,8,0,1,0,2,5,40,40,0,1\n\
Style: Hook,{a},92,{white},{white},{black},{black},0,0,0,0,100,100,1,0,1,0,0,5,40,40,0,1\n\
Style: Tag,{m},34,{black},{black},{yellow},{yellow},0,0,0,0,100,100,3,0,3,14,0,5,40,40,0,1\n\
Style: Sub,{a},{sub},{white},{white},{black},{shadow},0,0,0,0,100,100,1,0,1,7,3,5,30,30,0,1\n\
Style: Cta,{a},84,{white},{white},{red},{red},0,0,0,0,100,100,2,0,3,26,0,5,40,40,0,1\n\
Style: Box,{m},10,{black},{black},{black},{black},0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1\n\n\
[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n",
        m = style::FONT_MONTSERRAT,
        a = style::FONT_ANTON,
        sub = short::SUB_SIZE,
    )
}

fn short_yellow() -> &'static str {
    style::SHORT_YELLOW
}

fn dialogue(out: &mut String, layer: u32, a: f64, b: f64, style: &str, text: &str) {
    let _ = writeln!(out, "Dialogue: {layer},{},{},{style},,0,0,0,,{text}", ts(a), ts(b));
}

/// Coupe un hook en 2 lignes de 20 caractères max (si l'auteur n'a donné qu'une ligne).
pub fn wrap_hook(lines: &[String]) -> Vec<String> {
    if lines.len() != 1 || lines[0].chars().count() <= short::HOOK_MAX_CHARS {
        return lines.to_vec();
    }
    let words: Vec<&str> = lines[0].split_whitespace().collect();
    let total: usize = lines[0].chars().count();
    let mut best = (usize::MAX, 1);
    for k in 1..words.len() {
        let l1 = words[..k].join(" ").chars().count();
        let diff = l1.abs_diff(total - l1);
        if diff < best.0 {
            best = (diff, k);
        }
    }
    vec![words[..best.1].join(" "), words[best.1..].join(" ")]
}

/// Construit le fichier ASS complet d'un short.
pub fn build_short_ass(p: &Project) -> String {
    let (w, h) = (p.format.w, p.format.h);
    let lay = Layout::for_format(w, h);
    let mut out = header(w, h);
    let cx = w as i32 / 2;
    let mut cta_start = f64::INFINITY;

    for g in p.graphics() {
        match g {
            GraphicItem::Kicker { at, dur, text } => {
                dialogue(&mut out, 2, *at, at + dur, "Kicker",
                    &format!("{{\\pos({cx},{})\\fad(200,0)}}{}", lay.kicker_y, escape(&text.to_uppercase())));
            }
            GraphicItem::Hook { at, dur, lines } => {
                let (y0, y1) = lay.banner;
                // Bandeau noir pleine largeur.
                dialogue(&mut out, 0, *at, at + dur, "Box",
                    &format!("{{\\pos(0,0)\\p1\\1c&H000000&\\1a&H10&}}m 0 {y0} l {w} {y0} l {w} {y1} l 0 {y1}{{\\p0}}"));
                let text = wrap_hook(lines).iter().map(|l| escape(&l.to_uppercase())).collect::<Vec<_>>().join("\\N");
                dialogue(&mut out, 1, *at, at + dur, "Hook",
                    &format!("{{\\pos({cx},{})\\fscx92\\fscy92\\t(0,180,\\fscx100\\fscy100)\\fad(120,0)}}{text}", (y0 + y1) / 2));
            }
            GraphicItem::Tag { at, dur, text } => {
                dialogue(&mut out, 2, *at, at + dur, "Tag",
                    &format!("{{\\pos({cx},{})\\fad(150,0)}}{}", lay.tag_y, escape(&text.to_uppercase())));
            }
            GraphicItem::Cta { at, dur, lines } => {
                cta_start = cta_start.min(*at);
                let text = lines.iter().map(|l| escape(&l.to_uppercase())).collect::<Vec<_>>().join("\\N");
                dialogue(&mut out, 3, *at, at + dur, "Cta",
                    &format!("{{\\pos({cx},{})\\fscx70\\fscy70\\t(0,220,\\fscx106\\fscy106)\\t(220,340,\\fscx100\\fscy100)}}{text}", lay.cta_y));
            }
            _ => {}
        }
    }

    // Sous-titres dynamiques : un événement par mot actif.
    let caps: Vec<_> = p.captions().collect();
    let mut words = captions::caption_words(&caps);
    for wd in &mut words {
        wd.text = captions::apply_dictionary(&wd.text, &p.dictionary);
    }
    let emphasis: Vec<String> = caps.iter().flat_map(|c| c.emphasis.iter().map(|e| normalize(e))).collect();
    for block in captions::blocks(&words) {
        if block.start >= cta_start {
            continue;
        }
        write_block(&mut out, &block, &emphasis, cx, lay.subs_y, cta_start);
    }
    out
}

fn normalize(w: &str) -> String {
    w.chars().filter(|c| c.is_alphanumeric()).collect::<String>().to_lowercase()
}

fn write_block(out: &mut String, block: &Block, emphasis: &[String], cx: i32, y: i32, cta_start: f64) {
    let yellow = style::ass_rgb(short_yellow());
    let red = style::ass_rgb(style::SHORT_RED);
    let end_block = block.end.min(cta_start);
    for (i, active) in block.words.iter().enumerate() {
        let a = if i == 0 { block.start } else { active.start };
        let b = if i + 1 == block.words.len() { end_block } else { block.words[i + 1].start };
        if b <= a {
            continue;
        }
        let mut text = String::new();
        if i == 0 {
            // Petit « pop » à l'apparition du bloc.
            text.push_str("{\\fscx90\\fscy90\\t(0,90,\\fscx100\\fscy100)}");
        }
        for (j, wd) in block.words.iter().enumerate() {
            if j > 0 {
                text.push(' ');
            }
            let up = escape(&wd.text.to_uppercase());
            let emph = emphasis.contains(&normalize(&wd.text));
            if j == i {
                let c = if emph { &red } else { &yellow };
                let s = style::short::SUB_ACTIVE_SCALE;
                let _ = write!(text, "{{\\1c{c}\\fscx{s}\\fscy{s}}}{up}{{\\1c&HFFFFFF&\\fscx100\\fscy100}}");
            } else if emph {
                let _ = write!(text, "{{\\1c{red}}}{up}{{\\1c&HFFFFFF&}}");
            } else {
                text.push_str(&up);
            }
        }
        let _ = writeln!(out, "Dialogue: 1,{},{},Sub,,0,0,0,,{{\\pos({cx},{y})}}{}", ts(a), ts(b), text);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::project::*;

    #[test]
    fn timestamps() {
        assert_eq!(ts(0.0), "0:00:00.00");
        assert_eq!(ts(83.6), "0:01:23.60");
        assert_eq!(ts(3725.456), "1:02:05.46");
    }

    #[test]
    fn hook_wrapping() {
        let l = wrap_hook(&["UN IMMENSE SERPENT AUX YEUX VERTS".to_string()]);
        assert_eq!(l.len(), 2);
        assert!(l.iter().all(|x| x.chars().count() <= 20), "{l:?}");
    }

    #[test]
    fn layout_keeps_texts_off_the_band() {
        let l = Layout::for_format(1080, 1920);
        assert_eq!((l.band_top, l.band_bottom), (596, 1204));
        assert!(l.banner.1 < l.tag_y && l.tag_y < l.band_top);
        assert!(l.subs_y > l.band_bottom && l.subs_y < 1920 - 200);
    }

    #[test]
    fn active_word_highlight() {
        let mut p = Project::new(Preset::ShortScene);
        p.tracks.push(Track::Captions {
            id: "subs".into(),
            items: vec![Caption { start: 1.0, end: 2.0, text: "Un serpent".into(), words: vec![], emphasis: vec!["serpent".into()] }],
        });
        let ass = build_short_ass(&p);
        let subs: Vec<&str> = ass.lines().filter(|l| l.contains(",Sub,")).collect();
        assert_eq!(subs.len(), 2);
        assert!(subs[1].contains("\\fscx112") && subs[1].contains("SERPENT"));
        // mot d'emphase actif en rouge
        assert!(subs[1].contains(&style::ass_rgb(style::SHORT_RED)));
    }
}
