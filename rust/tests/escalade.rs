//! Valeurs attendues calculées à la main à partir du code Dart
//! (`horairesDesPresages`, `borner`, `orchestrer`).

use rust_lib_destiny::escalade::{borner, horaires_des_presages, orchestrer, Mechant, Sbire};

const MIN: i64 = 60000;

#[test]
fn douze_minutes_quatre_presages() {
    // pas = floor((12 − 1) / 4) = 2 → 2, 4, 6, 8 minutes.
    assert_eq!(horaires_des_presages(12 * MIN, 4, None), vec![2 * MIN, 4 * MIN, 6 * MIN, 8 * MIN]);
}

#[test]
fn intervalle_impose() {
    assert_eq!(horaires_des_presages(20 * MIN, 3, Some(5 * MIN)), vec![5 * MIN, 10 * MIN, 15 * MIN]);
    // Intervalle trop grand : borné, une minute par présage restant + la fin.
    assert_eq!(horaires_des_presages(10 * MIN, 3, Some(5 * MIN)), vec![5 * MIN, 8 * MIN, 9 * MIN]);
}

#[test]
fn episode_trop_court() {
    // 90 s, 2 présages : pas_min = floor(90000 / 3) = 30000 ; 30 s et 60 s.
    assert_eq!(horaires_des_presages(90_000, 2, None), vec![30_000, 60_000]);
    assert_eq!(horaires_des_presages(MIN, 0, None), Vec::<i64>::new());
}

#[test]
fn borner_ordonne_et_espace() {
    assert_eq!(borner(&[0, 0, 0], 10 * MIN), vec![MIN, 2 * MIN, 3 * MIN]);
    assert_eq!(borner(&[9 * MIN, MIN], 10 * MIN), vec![MIN, 9 * MIN]);
    // Rien ne tombe sur le coup de sifflet.
    assert_eq!(borner(&[10 * MIN, 10 * MIN], 10 * MIN), vec![8 * MIN, 9 * MIN]);
}

#[test]
fn deux_dernieres_marches_au_mechant() {
    let s = |n: &str| n.to_string();
    let mechant = Mechant {
        nom: s("Ombre"),
        manoeuvres: vec![s("m0"), s("m1")],
        presages: vec![s("p1"), s("p2"), s("p3"), s("p4"), s("p5")],
        sbires: vec![
            Sbire { nom: s("A"), manoeuvres: vec![s("a")] },
            Sbire { nom: s("B"), manoeuvres: vec![] },
        ],
    };
    let e = orchestrer(&mechant);
    let qui: Vec<_> = e.iter().map(|x| x.qui_agit.as_str()).collect();
    assert_eq!(qui, ["A", "B", "A", "Ombre", "Ombre"]);
    assert_eq!(e[1].ce_quil_fait, "");
    assert_eq!(e[3].ce_quil_fait, "m1"); // 3 % 2
    assert_eq!(e[4].rang, 5);
    assert!(e[3].est_mechant && !e[2].est_mechant);

    let seul = Mechant { sbires: vec![], ..mechant };
    assert!(orchestrer(&seul).iter().all(|x| x.est_mechant));
}
