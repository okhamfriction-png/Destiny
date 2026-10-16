//! Direction artistique Destiny : couleurs, polices, étalonnage, géométrie des presets.

/// Fond `#0b0907`.
pub const BG: &str = "#0b0907";
/// Texte `#f3ede4`.
pub const TEXT: &str = "#f3ede4";
/// Or `#e6b446`.
pub const GOLD: &str = "#e6b446";
/// Or clair `#f7dc8a`.
pub const GOLD_LIGHT: &str = "#f7dc8a";
/// Dégradé or des titres (moteur B).
pub const GOLD_GRADIENT: &str =
    "linear-gradient(180deg,#fbe7a6 0%,#e6b446 45%,#a8701e 75%,#e9c060 100%)";
/// Jaune des shorts (kicker, tag, mot actif, barre de progression).
/// La charte ne fixe que l'or ; on prend l'or clair pour rester dans la palette.
pub const SHORT_YELLOW: &str = "#f7dc8a";
/// Rouge des mots d'emphase et du bloc CTA.
pub const SHORT_RED: &str = "#e0352b";
/// Flash blanc chaud entre plans.
pub const FLASH: &str = "#fff3dc";
pub const FLASH_DUR: f64 = 0.22;

pub const FONT_ANTON: &str = "Anton";
pub const FONT_MONTSERRAT: &str = "Montserrat SemiBold";
pub const FONT_CINZEL: &str = "Cinzel";

/// Étalonnage commun appliqué à toutes les images caméra (filtre ffmpeg exact).
pub const GRADE: &str = "split[g0][g1];[g1]curves=all='0/0 0.72/0 1/1',gblur=sigma=26,colorchannelmixer=rr=1:gg=0.6:bb=0.25[h];[g0][h]blend=all_mode=screen:all_opacity=0.18,curves=all='0/0 0.10/0.03 0.30/0.20 0.55/0.50 0.80/0.82 1/0.97',colorbalance=rs=-0.08:gs=-0.01:bs=0.08:rm=0.03:bm=-0.03:rh=0.08:gh=0.02:bh=-0.08,eq=saturation=0.9,vignette=angle=PI/3.6";

/// Grain léger à l'export.
pub const GRAIN: &str = "noise=alls=3:allf=t";

/// Zoom continu par défaut sur la durée d'un plan (1 → 1,06).
pub const DEFAULT_PUSH: f64 = 0.06;
/// Punch d'entrée : 1,09 → 1 en 0,6 s.
pub const PUNCH_AMOUNT: f64 = 0.09;
pub const PUNCH_DUR: f64 = 0.6;
/// Punch-in sur le moment fort.
pub const PUNCH_IN_ZOOM: f64 = 1.2;

/// Bandes noires cinéma en 16:9 : zone de texte sûre 131–949 px.
pub const LETTERBOX: u32 = 131;

/// Géométrie du layout « group » des shorts verticaux 1080×1920.
pub mod short {
    pub const BAND_W: u32 = 1080;
    pub const BAND_H: u32 = 608;
    /// Zoom de base de la bande vidéo.
    pub const BAND_ZOOM: f64 = 1.2;
    /// Centre vertical de la bande = centre de l'écran − 60.
    pub const BAND_CY_OFFSET: i32 = -60;
    pub const BG_BRIGHTNESS: f64 = -0.18;
    pub const BG_SATURATION: f64 = 0.8;
    pub const SUB_SIZE: u32 = 118;
    pub const SUB_ACTIVE_SCALE: u32 = 112;
    pub const SUB_MAX_CHARS: usize = 16;
    pub const SUB_MAX_WORDS: usize = 3;
    pub const SUB_PAUSE: f64 = 0.45;
    pub const HOOK_MAX_CHARS: usize = 20;
    pub const CTA_DUR: f64 = 4.0;
    pub const TAG_SWITCH: f64 = 6.0;
    pub const TAG_1: &str = "AUCUNE DE CES RÉPLIQUES N'A ÉTÉ ÉCRITE";
    pub const TAG_2: &str = "IMPRO DESTINY · RIEN N'EST ÉCRIT";
    pub const CTA: [&str; 2] = ["VIENS VOIR DESTINY", "LIEN EN BIO"];
    pub const PROGRESS_H: u32 = 12;
}

/// Convertit `#rrggbb` en couleur ASS `&HAABBGGRR` (alpha 00 = opaque).
pub fn ass_color(hex: &str, alpha: u8) -> String {
    let h = hex.trim_start_matches('#');
    let r = &h[0..2];
    let g = &h[2..4];
    let b = &h[4..6];
    format!("&H{alpha:02X}{}{}{}", b.to_uppercase(), g.to_uppercase(), r.to_uppercase())
}

/// Couleur d'override ASS `&HBBGGRR&` (balises `\\1c`).
pub fn ass_rgb(hex: &str) -> String {
    let c = ass_color(hex, 0);
    format!("&H{}&", &c[4..])
}

/// Convertit `#rrggbb` en `0xRRGGBB` pour ffmpeg.
pub fn ff_color(hex: &str) -> String {
    format!("0x{}", hex.trim_start_matches('#'))
}

#[cfg(test)]
mod tests {
    #[test]
    fn colors() {
        assert_eq!(super::ass_color("#e6b446", 0), "&H0046B4E6");
        assert_eq!(super::ass_rgb("#e6b446"), "&H46B4E6&");
        assert_eq!(super::ff_color("#fff3dc"), "0xfff3dc");
    }
}
