use super::*;
use crate::project::{Format, Project};

const TRAILER: &str = r#"{
  "version": 1,
  "format": { "w": 1080, "h": 1920, "fps": 30 },
  "preset": "trailer_v",
  "sources": [ { "id": "cam", "path": "cam.mp4", "proxy": "cam.lrf", "rec": 0 } ],
  "tracks": [
    { "id": "v0", "kind": "video", "items": [
      { "id": "c1", "src": "cam", "in": 3.0, "out": 4.8, "at": 0.0, "fx": { "punch": true } },
      { "id": "c2", "src": "cam", "in": 10.0, "out": 13.0, "at": 2.0, "fx": { "flash": true, "push": 0.08 } }
    ] },
    { "id": "g", "kind": "graphics", "items": [
      { "type": "hook", "at": 0.0, "dur": 1.8, "lines": ["ILS N’ONT RIEN RÉPÉTÉ.", "LE PUBLIC MET 10/10."] },
      { "type": "reviews_txt", "at": 1.8, "dur": 3.2, "items": [["Excellent !", "Paul"], ["Génial", "Inès"]] },
      { "type": "card", "at": 5.0, "dur": 1.2, "lines": ["ET TOUT", "BASCULE."], "style": "stamp" },
      { "type": "black", "at": 6.2, "dur": 0.5 },
      { "type": "end_card", "at": 6.7, "dur": 3.0 }
    ] }
  ],
  "markers": { "music_hits": [2.95, 6.7] }
}"#;

fn trailer() -> Project {
    Project::from_json(TRAILER).unwrap()
}

fn horizontal(mut p: Project) -> Project {
    p.preset = Preset::TrailerH;
    p.format = Format { w: 1920, h: 1080, fps: 25 };
    p
}

fn html_of(p: &Project) -> (String, Value, Vec<Clip>) {
    let segs = plates::segments(p);
    let (data, clips) = comp_data(p, &segs, &[], &|_| vec![], &|_| None);
    (index_html(&data, &clips, &Frame::new(&p.format)), data, clips)
}

#[test]
fn html_has_clips_with_timing_attributes() {
    let p = trailer();
    let (html, data, clips) = html_of(&p);
    // Une scène par élément graphique, une plaque par plan, un flash de montage pour c2.
    assert_eq!(clips.iter().filter(|c| c.scene == "clip").count(), 2);
    assert_eq!(clips.iter().filter(|c| c.scene == "flash").count(), 1);
    for (scene, start, dur) in [("hook", "0.000", "1.800"), ("reviews_txt", "1.800", "3.200"), ("card", "5.000", "1.200"), ("black", "6.200", "0.500"), ("end_card", "6.700", "3.000")] {
        let needle = format!("data-scene=\"{scene}\" data-start=\"{start}\" data-duration=\"{dur}\"");
        assert!(html.contains(&needle), "{needle} absent de\n{html}");
    }
    // Plaques sur la piste 0, graphismes sur la piste 1, flash de coupe au-dessus.
    assert!(html.contains("data-scene=\"clip\" data-start=\"0.000\" data-duration=\"1.800\" data-track-index=\"0\""));
    assert!(html.contains("data-scene=\"clip\" data-start=\"2.000\" data-duration=\"3.000\" data-track-index=\"0\""));
    assert!(html.contains("data-scene=\"hook\" data-start=\"0.000\" data-duration=\"1.800\" data-track-index=\"1\""));
    assert!(html.contains("data-scene=\"flash\" data-start=\"2.000\" data-duration=\"0.220\" data-track-index=\"90\""));
    assert_eq!(html.matches("class=\"clip ").count(), clips.len());
    // Scripts locaux uniquement (pas de CDN) ; durée exposée.
    assert!(html.contains("<script src=\"gsap.min.js\"></script>"));
    assert!(!html.contains("http://") && !html.contains("https://"));
    assert!((data["duration"].as_f64().unwrap() - 9.7).abs() < 1e-9);
    assert_eq!(data["frames"], 291);
    // Carte finale : lignes sans date par défaut + bouton.
    let end = data["items"].as_array().unwrap().iter().find(|v| v["type"] == "end_card").unwrap();
    assert_eq!(end["info"][0], "PROCHAINES DATES SUR BILLET RÉDUC");
    assert_eq!(end["button"], "VIENS AVEC QUELQU’UN.");
    // Pas de bandes en vertical.
    assert!(!html.contains("bars top"));
    let (hh, _, _) = html_of(&horizontal(trailer()));
    assert!(hh.contains("bars top"));
}

#[test]
fn reviews_slam_on_music_hits_inside_window() {
    let p = trailer();
    let (_, data, _) = html_of(&p);
    let rt = data["items"].as_array().unwrap().iter().find(|v| v["type"] == "reviews_txt").unwrap();
    let slams: Vec<f64> = rt["slams"].as_array().unwrap().iter().map(|v| v.as_f64().unwrap()).collect();
    assert_eq!(slams.len(), 2);
    assert!(slams.contains(&2.95), "{slams:?}");
    assert!(slams.windows(2).all(|w| w[1] - w[0] >= 0.45 - 1e-9));
    assert!(slams.iter().all(|t| *t >= 1.8 + 0.9 && *t <= 5.0));
    // Les onsets les plus forts sont préférés, et la grille complète au besoin.
    let s = slam_times(10.0, 4.0, 3, &[], &[(11.0, 5.0), (11.2, 20.0), (12.5, 18.0), (16.0, 99.0)]);
    assert_eq!(s.len(), 3);
    assert!(s.contains(&11.2) && s.contains(&12.5) && !s.contains(&11.0), "{s:?}");
    let g = slam_times(0.0, 3.0, 4, &[], &[]);
    assert_eq!(g.len(), 4);
    assert!(g.windows(2).all(|w| w[1] > w[0]));
}

#[test]
fn composition_is_deterministic() {
    let p = trailer();
    let (a, _, _) = html_of(&p);
    let (b, _, _) = html_of(&p);
    assert_eq!(a, b);
    // Le runtime et les scènes n'utilisent ni aléa ni horloge, ni animation CSS.
    for (name, src) in [("runtime.js", RUNTIME_JS), ("scenes.js", SCENES_JS)] {
        for banned in ["Math.random", "Date.now", "new Date", "performance.now", "setTimeout", "setInterval"] {
            assert!(!src.contains(banned), "{name} contient {banned}");
        }
    }
    assert!(!STYLE_CSS.contains("@keyframes"));
    // Écrit deux fois sur disque : fichiers identiques octet pour octet.
    let d1 = tempfile::tempdir().unwrap();
    let d2 = tempfile::tempdir().unwrap();
    let c1 = compose(&p, Path::new("."), d1.path(), Quality::Preview, false, None, |_| {}).unwrap();
    let c2 = compose(&p, Path::new("."), d2.path(), Quality::Preview, false, None, |_| {}).unwrap();
    assert_eq!(c1.frames, c2.frames);
    for f in ["index.html", "style.css", "runtime.js", "scenes.js", "gsap.min.js"] {
        assert_eq!(std::fs::read(d1.path().join(f)).unwrap(), std::fs::read(d2.path().join(f)).unwrap(), "{f}");
    }
    let css = std::fs::read_to_string(d1.path().join("style.css")).unwrap();
    assert!(css.contains(style::GOLD_GRADIENT));
    assert!(d1.path().join("fonts/Cinzel-Black.ttf").exists());
}

#[test]
fn segments_are_frame_aligned_and_fill_gaps() {
    let p = trailer();
    let segs = plates::segments(&p);
    // c1 [0, 54), noir [54, 60), c2 [60, 150), noir jusqu'à 291.
    let spans: Vec<(u64, u64, bool)> = segs
        .iter()
        .map(|s| match s {
            Seg::Clip { f0, f1, .. } => (*f0, *f1, true),
            Seg::Black { f0, f1 } => (*f0, *f1, false),
        })
        .collect();
    assert_eq!(spans, vec![(0, 54, true), (54, 60, false), (60, 150, true), (150, 291, false)]);
    let total: u64 = segs.iter().map(|s| s.frames()).sum();
    assert_eq!(total, plates::total_frames(&p));
}

#[test]
fn cover_crop_keeps_center_and_bounds() {
    // 16:9 720p → vertical 1080×1920 centré à gauche.
    let ((w, h), (x0, y0), (cx, _)) = plates::cover_crop((1280, 720), (1080, 1920), 0.2, 0.5);
    assert_eq!(h, 1920);
    assert!(w >= 1080 && x0 + 1080 <= w && y0 == 0);
    assert!(cx >= 0.0 && cx <= 1.0);
    let ((w, h), (x0, _), (cx, _)) = plates::cover_crop((1920, 1080), (1920, 1080), 0.5, 0.5);
    assert_eq!((w, h, x0), (1920, 1080, 0));
    assert!((cx - 0.5).abs() < 1e-9);
    // Expression de zoom : push, punch et punch-in présents.
    let p = trailer();
    let c = p.video_items().nth(1).unwrap();
    let z = plates::zoom_expr(c, 0.0, 30);
    assert!(z.contains("0.0800"), "{z}");
}

#[test]
fn safe_zone_catches_text_outside_bars_in_16_9() {
    // Le trailer d'exemple tient dans la zone 131–949 px.
    let h = horizontal(trailer());
    let issues = check_safe_zone(&h);
    assert!(issues.iter().all(|i| !i.fatal), "{issues:?}");
    assert!(validate_safe_zone(&h).is_ok());
    // Une carte de sept lignes déborde sur les bandes : erreur bloquante en 16:9.
    let mut bad = h.clone();
    if let Track::Graphics { items, .. } = &mut bad.tracks[1] {
        items.push(GraphicItem::Card {
            at: 9.0,
            dur: 1.0,
            lines: ["UN", "DEUX", "TROIS", "QUATRE", "CINQ", "SIX", "SEPT"].map(String::from).to_vec(),
            style: Default::default(),
        });
    }
    let issues = check_safe_zone(&bad);
    let fatal: Vec<_> = issues.iter().filter(|i| i.fatal).collect();
    assert_eq!(fatal.len(), 1, "{issues:?}");
    assert_eq!(fatal[0].scene, "card");
    assert!(fatal[0].message.contains("131–949"), "{}", fatal[0].message);
    let err = validate_safe_zone(&bad).unwrap_err().to_string();
    assert!(err.contains("card"), "{err}");
    // Tags ancrés en bas : trop de lignes poussent le texte sous la bande du bas… ou au-dessus.
    let mut tags = h.clone();
    if let Track::Graphics { items, .. } = &mut tags.tracks[1] {
        items.push(GraphicItem::Tags { at: 9.0, dur: 1.0, items: ["LE DANGER", "EFFONDREMENT", "INCENDIE", "INONDATION", "TEMPÊTE", "SÉISME", "PANIQUE", "CHAOS"].map(String::from).to_vec() });
    }
    assert!(validate_safe_zone(&tags).is_err());
    // Le même contenu en vertical (1920 de haut) passe.
    let mut v = trailer();
    if let Track::Graphics { items, .. } = &mut v.tracks[1] {
        items.push(GraphicItem::Tags { at: 9.0, dur: 1.0, items: ["LE DANGER", "EFFONDREMENT"].map(String::from).to_vec() });
    }
    assert!(validate_safe_zone(&v).is_ok());
}

#[test]
fn frame_geometry() {
    let v = Frame::new(&Format { w: 1080, h: 1920, fps: 30 });
    assert_eq!((v.dw, v.dh, v.k, v.bars), (1080.0, 1920.0, 1.0, 0.0));
    let h = Frame::new(&Format { w: 1920, h: 1080, fps: 25 });
    assert_eq!((h.bars, h.zone), (131.0, [131.0, 949.0]));
    // 4K 16:9 : même repère de dessin, mise à l'échelle ×2.
    let k = Frame::new(&Format { w: 3840, h: 2160, fps: 25 });
    assert_eq!((k.dw, k.dh, k.k, k.bars), (1920.0, 1080.0, 2.0, 131.0));
}

#[test]
fn composite_graph_overlays_graphics_and_letterboxes_16_9() {
    let p = horizontal(trailer());
    let segs = plates::segments(&p);
    let frames = plates::total_frames(&p);
    let comp = Composition {
        dir: "/comp".into(),
        index: "/comp/index.html".into(),
        duration: frames as f64 / 25.0,
        frames,
        segs,
        clips: vec![],
        issues: vec![],
    };
    let args = composite_args(&p, &comp, Quality::Delivery, Path::new("/w/mix.wav"), Path::new("/o.mp4"));
    let graph = &args[args.iter().position(|a| a == "-filter_complex").unwrap() + 1];
    assert!(graph.contains("concat=n=4:v=1:a=0,setpts=N/25/TB[bg]"), "{graph}");
    assert!(graph.contains("[2:v]setpts=N/25/TB,format=rgba[gfx]"), "{graph}");
    assert!(graph.contains(style::GRAIN));
    assert!(graph.contains("drawbox=x=0:y=0:w=iw:h=131"));
    assert!(graph.contains("loudnorm=I=-14:TP=-1.2:LRA=9"));
    assert!(args.windows(2).any(|w| w[0] == "-c:v" && w[1] == "png"));
    assert!(args.windows(2).any(|w| w[0] == "-crf" && w[1] == "20"));
    assert!(args.contains(&"+faststart".to_string()));
    let pv = composite_args(&trailer(), &comp, Quality::Preview, Path::new("/w/mix.wav"), Path::new("/o.mp4"));
    let g2 = &pv[pv.iter().position(|a| a == "-filter_complex").unwrap() + 1];
    assert!(!g2.contains("noise=") && !g2.contains("drawbox"));
}

#[test]
fn engine_b_handles_trailers_only() {
    assert!(handles(Preset::TrailerV) && handles(Preset::TrailerH) && handles(Preset::ReelBm));
    assert!(!handles(Preset::ShortScene) && !handles(Preset::RetentionPeaks));
}
