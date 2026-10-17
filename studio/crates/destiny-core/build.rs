// Compile le détecteur Vision (Swift) sur Mac et l'embarque dans la bibliothèque : l'app et
// la CLI l'ont toujours avec elles, sans installation ni chemin à configurer. Sans `swiftc`
// (Linux, Mac sans outils de développement), le recadrage automatique est simplement
// indisponible (cfg `vision` absent) et tout le reste compile.

use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo::rustc-check-cfg=cfg(vision)");
    println!("cargo:rerun-if-changed=vision/detect.swift");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("macos") {
        return;
    }
    let out = PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("destiny-vision");
    let ok = Command::new("swiftc")
        .args(["-O", "vision/detect.swift", "-o"])
        .arg(&out)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if ok {
        println!("cargo:rustc-cfg=vision");
    } else {
        println!("cargo:warning=swiftc indisponible : recadrage automatique (Vision) désactivé");
    }
}
