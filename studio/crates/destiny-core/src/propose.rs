//! Propositions automatiques : construction d'un short « scène » à partir d'un
//! intervalle maître, et repérage des pics de rétention YouTube.

use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use ts_rs::TS;

use crate::asr::Transcript;
use crate::project::*;
use crate::style::short;
use crate::sync::{rec_seconds, split_master_range};

/// Silence au-delà duquel on coupe (secondes).
pub const MAX_SILENCE: f64 = 3.0;
/// Marge gardée autour des répliques.
pub const PAD: f64 = 0.3;

#[derive(Debug, Clone, Default, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct ShortOpts {
    pub kicker: Option<String>,
    pub hook: Vec<String>,
    /// Lignes du CTA final (défaut : « VIENS VOIR DESTINY / LIEN EN BIO »).
    pub cta: Option<Vec<String>>,
    /// Instant fort (temps maître) : punch-in zoom 1,2.
    pub punch_at: Option<f64>,
    pub emphasis: Vec<String>,
    /// Recadrage par défaut des clips.
    pub crop: Option<Crop>,
}

/// Intervalles de parole dans `[a, b]`, fusionnés si le silence ≤ 3 s.
pub fn speech_spans(t: Option<&Transcript>, a: f64, b: f64) -> Vec<[f64; 2]> {
    let Some(t) = t else { return vec![[a, b]] };
    let segs = t.range(a, b);
    if segs.is_empty() {
        return vec![[a, b]];
    }
    let mut out: Vec<[f64; 2]> = Vec::new();
    for s in segs {
        let iv = [(s.start - PAD).max(a), (s.end + PAD).min(b)];
        match out.last_mut() {
            Some(last) if iv[0] - last[1] <= MAX_SILENCE => last[1] = last[1].max(iv[1]),
            _ => out.push(iv),
        }
    }
    // On garde le début et la fin demandés quand ils sont proches de la parole.
    if let Some(first) = out.first_mut() {
        if first[0] - a <= MAX_SILENCE {
            first[0] = a;
        }
    }
    if let Some(last) = out.last_mut() {
        if b - last[1] <= MAX_SILENCE {
            last[1] = b;
        }
    }
    out
}

/// Construit un projet `short_scene` à partir de l'intervalle maître `[a, b]`.
/// `base` fournit sources, micros, gates et dictionnaire.
pub fn short_scene(base: &Project, transcript: Option<&Transcript>, a: f64, b: f64, opts: &ShortOpts) -> Result<Project> {
    if b <= a {
        bail!("intervalle vide");
    }
    let mut p = Project::new(Preset::ShortScene);
    p.sources = base.sources.clone();
    p.mics = base.mics.clone();
    p.mic_gates = base.mic_gates.clone();
    p.dictionary = base.dictionary.clone();
    p.export = base.export.clone();

    let mut spans = speech_spans(transcript, a, b);
    // Queue de 4 s sous le CTA : la scène continue (réaction du public).
    let tail_start = spans.last().map(|s| s[1]).unwrap_or(b);
    spans.push([tail_start, tail_start + short::CTA_DUR]);

    let mut video = Vec::new();
    let mut voice = Vec::new();
    // Correspondance temps maître → temps vidéo : (début maître, fin maître, début vidéo).
    let mut map: Vec<(f64, f64, f64)> = Vec::new();
    let mut at = 0.0;
    for span in &spans {
        for piece in split_master_range(&p.sources, span[0], span[1]) {
            let k = video.len() + 1;
            let dur = piece.t_out - piece.t_in;
            let mut fx = Fx { punch: k == 1, ..Default::default() };
            if let Some(t) = opts.punch_at {
                if t >= piece.master && t < piece.master + dur {
                    let rel = t - piece.master;
                    fx.punch_in = Some([(rel - 0.2).max(0.0), (rel + 1.8).min(dur)]);
                }
            }
            video.push(VideoItem {
                id: format!("c{k}"),
                src: piece.src.clone(),
                t_in: piece.t_in,
                t_out: piece.t_out,
                at,
                crop: opts.crop.unwrap_or_default(),
                fx,
            });
            voice.push(VoiceItem {
                id: format!("v{k}"),
                src: piece.src.clone(),
                t_in: piece.t_in,
                t_out: piece.t_out,
                at,
                gain: 1.0,
                camera_audio: false,
            });
            map.push((piece.master, piece.master + dur, at));
            at += dur;
        }
    }
    if video.is_empty() {
        bail!("aucune source ne couvre {a:.1} → {b:.1}");
    }
    let total = at;
    let to_out = |t: f64| map.iter().find(|(m0, m1, _)| t >= *m0 && t <= *m1).map(|(m0, _, o)| o + (t - m0));

    let mut caps = Vec::new();
    if let Some(t) = transcript {
        for s in t.range(a, tail_start) {
            if s.text.trim().is_empty() {
                continue;
            }
            let (Some(st), Some(en)) = (to_out(s.start.max(a)), to_out(s.end.min(tail_start))) else { continue };
            if en > st {
                caps.push(Caption {
                    start: st,
                    end: en,
                    text: crate::captions::apply_dictionary(&s.text, &p.dictionary),
                    words: vec![],
                    emphasis: opts.emphasis.clone(),
                });
            }
        }
    }

    let cta_at = (total - short::CTA_DUR).max(0.0);
    let mut g = Vec::new();
    if let Some(k) = &opts.kicker {
        g.push(GraphicItem::Kicker { at: 0.0, dur: total, text: k.clone() });
    }
    if !opts.hook.is_empty() {
        g.push(GraphicItem::Hook { at: 0.0, dur: total, lines: crate::ass::wrap_hook(&opts.hook) });
    }
    let switch = short::TAG_SWITCH.min(cta_at);
    if switch > 0.0 {
        g.push(GraphicItem::Tag { at: 0.0, dur: switch, text: short::TAG_1.into() });
    }
    if cta_at > switch {
        g.push(GraphicItem::Tag { at: switch, dur: cta_at - switch, text: short::TAG_2.into() });
    }
    g.push(GraphicItem::Cta {
        at: cta_at,
        dur: total - cta_at,
        lines: opts.cta.clone().unwrap_or_else(|| short::CTA.iter().map(|s| s.to_string()).collect()),
    });
    g.push(GraphicItem::Progress { at: 0.0, dur: total });

    p.tracks = vec![
        Track::Video { id: "v0".into(), items: video },
        Track::Voice { id: "a_voice".into(), items: voice },
        Track::Graphics { id: "g_text".into(), items: g },
        Track::Captions { id: "subs".into(), items: caps },
    ];
    p.markers.cuts = map.iter().skip(1).map(|(_, _, o)| *o).collect();
    p.validate()?;
    Ok(p)
}

/// Fenêtre de pic de rétention (temps maître).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[ts(export)]
pub struct Peak {
    pub start: f64,
    pub end: f64,
    pub top: f64,
    pub value: f64,
}

/// Lit un CSV de rétention `temps,valeur` (secondes ou mm:ss ; en-tête toléré).
pub fn parse_retention_csv(text: &str) -> Vec<(f64, f64)> {
    let parse_t = |s: &str| -> Option<f64> {
        let s = s.trim().trim_matches('"');
        if let Some((m, sec)) = s.rsplit_once(':') {
            let mut total = sec.parse::<f64>().ok()?;
            let mut mul = 60.0;
            for part in m.rsplit(':') {
                total += part.parse::<f64>().ok()? * mul;
                mul *= 60.0;
            }
            Some(total)
        } else {
            s.parse().ok()
        }
    };
    text.lines()
        .filter_map(|l| {
            let mut it = l.split([',', ';', '\t']);
            let t = parse_t(it.next()?)?;
            let v = it.next()?.trim().trim_matches('"').trim_end_matches('%').replace(',', ".").parse().ok()?;
            Some((t, v))
        })
        .collect()
}

/// Courbe de rétention lue sur une capture d'écran YouTube Studio : pour chaque
/// colonne, le pixel de courbe (bleu saturé) le plus haut. L'axe horizontal va de la
/// première à la dernière colonne où la courbe apparaît (0 → `duration` s) ; la valeur
/// est la hauteur relative (0–100), suffisante pour repérer les pics.
pub fn retention_from_rgb(rgb: &[u8], w: usize, h: usize, duration: f64) -> Vec<(f64, f64)> {
    let is_curve = |x: usize, y: usize| {
        let i = (y * w + x) * 3;
        let (r, g, b) = (rgb[i] as i32, rgb[i + 1] as i32, rgb[i + 2] as i32);
        b >= 150 && b - r >= 70 && g >= 80
    };
    let cols: Vec<(usize, usize)> =
        (0..w).filter_map(|x| (0..h).find(|&y| is_curve(x, y)).map(|y| (x, y))).collect();
    let (Some(first), Some(last)) = (cols.first(), cols.last()) else { return vec![] };
    let span = (last.0 - first.0).max(1) as f64;
    cols.iter()
        .map(|&(x, y)| ((x - first.0) as f64 / span * duration, (h - y) as f64 / h as f64 * 100.0))
        .collect()
}

/// Décode une capture (PNG/JPG) avec ffmpeg et en extrait la courbe de rétention.
pub fn retention_from_screenshot(path: &std::path::Path, duration: f64) -> Result<Vec<(f64, f64)>> {
    let pr = crate::ffmpeg::probe(path)?;
    let (Some(w), Some(h)) = (pr.width, pr.height) else { bail!("image illisible : {}", path.display()) };
    let out = std::process::Command::new(crate::ffmpeg::ffmpeg_bin())
        .args(["-v", "error", "-i"])
        .arg(path)
        .args(["-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
        .output()?;
    if !out.status.success() || out.stdout.len() < (w * h * 3) as usize {
        bail!("décodage de {} impossible", path.display());
    }
    Ok(retention_from_rgb(&out.stdout, w as usize, h as usize, duration))
}

/// Repère les `n` pics de rétention : fenêtre = début de la montée → redescente.
/// `offset` = position de la vidéo publiée dans la timeline maîtresse.
pub fn retention_peaks(curve: &[(f64, f64)], offset: f64, n: usize) -> Vec<Peak> {
    if curve.len() < 5 {
        return vec![];
    }
    // Lissage (moyenne glissante sur 5 points) pour ignorer le bruit.
    let v: Vec<f64> = (0..curve.len())
        .map(|i| {
            let lo = i.saturating_sub(2);
            let hi = (i + 3).min(curve.len());
            curve[lo..hi].iter().map(|x| x.1).sum::<f64>() / (hi - lo) as f64
        })
        .collect();
    let mut peaks: Vec<(usize, f64)> = Vec::new();
    for i in 1..v.len() - 1 {
        if v[i] > v[i - 1] && v[i] >= v[i + 1] {
            // Proéminence : hauteur au-dessus du plus haut des deux creux voisins.
            let mut l = i;
            while l > 0 && v[l - 1] <= v[l] {
                l -= 1;
            }
            let mut r = i;
            while r + 1 < v.len() && v[r + 1] <= v[r] {
                r += 1;
            }
            let prom = v[i] - v[l].max(v[r]);
            peaks.push((i, prom));
        }
    }
    peaks.sort_by(|a, b| b.1.total_cmp(&a.1));
    let mut out: Vec<Peak> = Vec::new();
    for (i, prom) in peaks {
        if prom <= 0.0 || out.len() >= n {
            break;
        }
        let half = v[i] - prom * 0.6;
        let mut l = i;
        while l > 0 && v[l - 1] <= v[l] && v[l - 1] > half - prom {
            l -= 1;
        }
        let mut r = i;
        while r + 1 < v.len() && v[r] > half {
            r += 1;
        }
        let pk = Peak { start: curve[l].0 + offset, end: curve[r].0 + offset, top: curve[i].0 + offset, value: v[i] };
        if out.iter().all(|o| pk.end <= o.start || pk.start >= o.end) {
            out.push(pk);
        }
    }
    out.sort_by(|a, b| a.start.total_cmp(&b.start));
    out
}

/// Recale une fenêtre sur des frontières de répliques (début et fin de segment).
pub fn snap_to_lines(t: &Transcript, a: f64, b: f64) -> (f64, f64) {
    let segs = t.range(a, b);
    let start = segs.first().map(|s| s.start.min(a)).unwrap_or(a);
    let end = segs.last().map(|s| s.end.max(b)).unwrap_or(b);
    (start, end)
}

/// Durée totale de la timeline maître couverte par les sources.
pub fn master_extent(p: &Project) -> (f64, f64) {
    let a = p.sources.iter().map(|s| rec_seconds(s.rec)).fold(f64::INFINITY, f64::min);
    let b = p.sources.iter().map(|s| rec_seconds(s.rec) + s.duration.unwrap_or(0.0)).fold(0.0, f64::max);
    (if a.is_finite() { a } else { 0.0 }, b)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::asr::Segment;

    fn base() -> Project {
        let mut p = Project::new(Preset::ShortScene);
        p.sources.push(Source { id: "edit".into(), path: "soiree.mov".into(), proxy: None, rec: 0.0, duration: Some(8000.0) });
        p
    }

    fn seg(a: f64, b: f64, t: &str) -> Segment {
        Segment { start: a, end: b, text: t.into(), mic: "m1".into(), db: -20.0 }
    }

    #[test]
    fn serpent_reference_short() {
        // Test de référence : « Un immense serpent aux yeux verts » (5264,6 → 5327,1 s).
        let t = Transcript {
            segments: vec![
                seg(5265.0, 5268.0, "Un immense serpent aux yeux verts !"),
                seg(5268.5, 5272.0, "C'est pour toi ? Y a quelqu'un ?"),
                // 10 s de silence (changement de décor muet) → coupé
                seg(5282.0, 5290.0, "Il a une morture"),
                seg(5300.0, 5327.0, "On court !"),
            ],
        };
        let mut b = base();
        b.dictionary.insert("morture".into(), "morsure".into());
        let opts = ShortOpts {
            kicker: Some("SCÈNE 4/25".into()),
            hook: vec!["UN IMMENSE SERPENT AUX YEUX VERTS".into()],
            punch_at: Some(5266.0),
            ..Default::default()
        };
        let p = short_scene(&b, Some(&t), 5264.6, 5327.1, &opts).unwrap();
        let clips: Vec<_> = p.video_items().collect();
        // 3 blocs de parole (silences > 3 s coupés) + queue CTA de 4 s
        assert_eq!(clips.len(), 4, "{clips:#?}");
        assert!(clips[0].fx.punch_in.is_some());
        let caps: Vec<_> = p.captions().collect();
        assert_eq!(caps.len(), 4);
        assert_eq!(caps[2].text, "Il a une morsure");
        let total = p.duration();
        assert!(matches!(p.graphics().find(|g| matches!(g, GraphicItem::Cta { .. })), Some(GraphicItem::Cta { at, .. }) if (*at - (total - 4.0)).abs() < 1e-9));
        // les sous-titres ne débordent pas sous le CTA
        assert!(caps.iter().all(|c| c.end <= total - 4.0 + 1e-9));
    }

    #[test]
    fn retention_from_pixels() {
        // Image 100×50 noire, courbe bleue y = 40 − bosse au milieu.
        let (w, h) = (100usize, 50usize);
        let mut rgb = vec![0u8; w * h * 3];
        for x in 10..90 {
            let y = if (45..55).contains(&x) { 10 } else { 40 };
            let i = (y * w + x) * 3;
            rgb[i..i + 3].copy_from_slice(&[62, 166, 255]);
        }
        let c = retention_from_rgb(&rgb, w, h, 800.0);
        assert_eq!(c.len(), 80);
        assert_eq!(c[0].0, 0.0);
        assert_eq!(c[79].0, 800.0);
        let top = c.iter().cloned().fold((0.0, 0.0), |a, b| if b.1 > a.1 { b } else { a });
        assert!(top.0 > 350.0 && top.0 < 450.0, "{top:?}");
    }

    #[test]
    fn retention_csv_and_peaks() {
        let mut csv = String::from("temps,rétention\n");
        for i in 0..200 {
            let t = i as f64 * 5.0;
            let bump = |c: f64, h: f64| h * (-((t - c) / 20.0).powi(2)).exp();
            let v = 40.0 - t * 0.01 + bump(300.0, 15.0) + bump(700.0, 8.0) + bump(500.0, 4.0);
            csv.push_str(&format!("{t},{v:.2}%\n"));
        }
        let curve = parse_retention_csv(&csv);
        assert_eq!(curve.len(), 200);
        let peaks = retention_peaks(&curve, 4570.0, 3);
        assert_eq!(peaks.len(), 3);
        assert!((peaks[0].top - 4870.0).abs() <= 10.0, "{peaks:?}");
        assert!(peaks[0].start < peaks[0].top && peaks[0].end > peaks[0].top);
        assert_eq!(parse_retention_csv("1:05,30\n")[0].0, 65.0);
    }
}
