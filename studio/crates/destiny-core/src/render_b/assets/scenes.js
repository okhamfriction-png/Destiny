/* Destiny Studio — bibliothèque de scènes du moteur B (une fonction par scène).
 *
 * Signature : scene(el, item, tl, X)
 *   el   : conteneur .clip de la scène (plein cadre, repère de dessin 1080 de petit côté)
 *   item : élément graphique de project.json ({type, at, dur, …}) enrichi par Rust
 *          (slams, images copiées, lignes de la carte finale…)
 *   tl   : timeline GSAP locale (0 = début de la scène), ajoutée à la timeline maîtresse
 *   X    : utilitaires (X.sz = tailles décidées par Rust, X.el, X.safe, X.fit, X.rng…)
 * Toutes les animations sont des tweens GSAP posés à des instants fixes : déterministe.
 */
(function () {
  'use strict';
  var S = {};
  window.__SCENES = S;

  function txt(X, parent, cls, text, size) {
    var e = X.el('div', 'txt ' + cls, parent, text);
    if (size) e.style.fontSize = size + 'px';
    return e;
  }
  function px(n) { return n + 'px'; }

  // ------------------------------------------------------------------ hook
  S.hook = function (el, it, tl, X) {
    var d = it.dur, sz = X.sz.hook;
    var veil = X.veil(el, 0.72, 'hook');
    var box = X.safe(el);
    var l1 = txt(X, box, 'c9 cream wrap', X.up(it.lines[0] || ''), sz);
    l1.style.maxWidth = '100%';
    var rule = X.el('div', 'rule', box);
    rule.style.margin = '20px 0 4px';
    var l2 = it.lines[1] != null ? txt(X, box, 'c9 gold wrap', X.up(it.lines[1]), sz) : null;
    if (l2) { l2.style.maxWidth = '100%'; l2.style.marginTop = '14px'; }

    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.25, ease: 'power1.out' }, 0);
    tl.fromTo(box, { scale: 1 }, { scale: 1.045, duration: d, ease: 'none' }, 0);
    tl.fromTo(l1, { opacity: 0, y: 34, filter: X.fb(l1, 14) }, { opacity: 1, y: 0, filter: X.fb(l1, 0), duration: 0.5, ease: 'power3.out' }, 0.02);
    tl.fromTo(rule, { scaleX: 0, opacity: 0 }, { scaleX: 1, opacity: 1, duration: 0.45, ease: 'power2.inOut' }, 0.22);
    if (l2) {
      // 2e ligne en or à +0,5 s : arrive grossie et floue, se pose net.
      tl.fromTo(l2, { opacity: 0, scale: 1.28, filter: X.fb(l2, 10) }, { opacity: 1, scale: 1, filter: X.fb(l2, 0), duration: 0.32, ease: 'power4.out' }, 0.5);
      X.shake(tl, box, 0.52, 6);
    }
    tl.to(box, { opacity: 0, duration: 0.14, ease: 'power1.in' }, Math.max(0.6, d - 0.14));
    tl.to(veil, { opacity: 0.5, duration: 0.14 }, Math.max(0.6, d - 0.14));
  };

  // ------------------------------------------------------------------ reviews_txt
  S.reviews_txt = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur, vert = X.C.frame.vertical;
    var veil = X.veil(el, 0.84, 'radial');
    var box = X.safe(el);
    var layout = vert ? box : X.el('div', 'row', box);
    if (!vert) { layout.style.width = '100%'; layout.style.height = '100%'; }
    var head = X.el('div', 'rq', layout);
    if (!vert) { head.style.width = '36%'; }
    var big = txt(X, head, 'c9 gold nowrap', '10/10', sz.big);
    X.fit(big, vert ? X.C.frame.safe[2] - X.C.frame.safe[0] : (X.C.frame.safe[2] - X.C.frame.safe[0]) * 0.36);
    var stars = X.el('div', 'txt row', head);
    stars.style.margin = '14px 0 18px';
    var st = [];
    for (var i = 0; i < 5; i++) st.push(X.star(stars, sz.stars));
    var lab = txt(X, head, 'lab nowrap', 'AVIS DU PUBLIC', sz.label);
    var list = X.el('div', 'rq', layout);
    if (vert) list.style.marginTop = '60px';
    else { list.style.width = '60%'; list.style.marginLeft = '4%'; }
    var qs = (it.items || []).map(function (pair) {
      var q = X.el('div', 'q', list);
      q.style.marginBottom = vert ? '44px' : '30px';
      var streak = X.el('div', 'streak', q);
      var t = txt(X, q, 'c7 cream wrap', '« ' + X.up(pair[0]) + ' »', sz.rquote);
      t.style.position = 'relative';
      var a = txt(X, q, 'lab nowrap', '— ' + X.up(pair[1]), sz.rauthor);
      a.style.marginTop = '10px';
      a.style.position = 'relative';
      return { q: q, t: t, streak: streak };
    });

    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.2 }, 0);
    tl.fromTo(big, { scale: 0.55 }, { scale: 1, duration: 0.42, ease: 'back.out(1.6)' }, 0.02);
    tl.fromTo(big, { opacity: 0, filter: X.fb(big, 12) }, { opacity: 1, filter: X.fb(big, 0), duration: 0.3, ease: 'power2.out' }, 0.02);
    tl.fromTo(st, { opacity: 0, scale: 0.2, rotation: -40 }, { opacity: 1, scale: 1, rotation: 0, duration: 0.28, ease: 'back.out(2.2)', stagger: 0.07 }, 0.25);
    tl.fromTo(lab, { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.3 }, 0.55);
    var slams = it.slams || [];
    qs.forEach(function (o, i) {
      var t = (slams[i] != null ? slams[i] - it.at : 0.9 + i * 0.7);
      // Le texte claque sur l'onset : il tombe (grossi → net) et arrive pile sur le temps.
      tl.fromTo(o.q, { opacity: 0, scale: 1.9, filter: X.fb(o.q, 8) }, { opacity: 1, scale: 1, filter: X.fb(o.q, 0), duration: 0.13, ease: 'power3.in' }, t - 0.13);
      tl.fromTo(o.streak, { opacity: 0.9, scaleX: 0.3 }, { opacity: 0, scaleX: 1.3, duration: 0.6, ease: 'power2.out' }, t);
      X.shake(tl, box, t, 10);
      for (var j = 0; j < i; j++) tl.to(qs[j].q, { opacity: 0.5, duration: 0.2 }, t);
    });
    tl.to(box, { opacity: 0, duration: 0.15 }, d - 0.15);
  };

  // ------------------------------------------------------------------ reviews (captures)
  S.reviews = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur, F = X.C.frame;
    var veil = X.veil(el, 0.84, 'radial');
    var box = X.safe(el);
    var lab = txt(X, box, 'lab nowrap', 'AVIS DU PUBLIC', sz.label);
    lab.style.marginBottom = '40px';
    var imgs = it.images || [];
    var n = Math.max(1, imgs.length);
    var slot = d / n;
    var rots = [-2.2, 1.8, -1.3, 2.4, -1.8];
    var maxW = Math.min(sz.rimg_w, F.safe[2] - F.safe[0]);
    var maxH = Math.min(sz.rimg_h, F.safe[3] - F.safe[1] - 120);
    var dims = imgs.map(function (im) {
      var r = im.w / im.h, w = maxW, h = w / r;
      if (h > maxH) { h = maxH; w = h * r; }
      return [w, h];
    });
    var holder = X.el('div', 'slot', box);
    holder.style.width = px(maxW);
    holder.style.height = px(dims.reduce(function (m, d2) { return Math.max(m, d2[1]); }, 0));
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.2 }, 0);
    tl.fromTo(lab, { opacity: 0, y: -10 }, { opacity: 1, y: 0, duration: 0.3 }, 0.05);
    imgs.forEach(function (im, i) {
      var w = dims[i][0], h = dims[i][1];
      var shot = X.el('div', 'shot', holder);
      shot.style.width = px(w); shot.style.height = px(h);
      shot.style.marginLeft = px(-w / 2); shot.style.marginTop = px(-h / 2);
      var img = X.el('img', null, shot);
      img.src = im.src;
      var t0 = i * slot, rot = rots[i % rots.length];
      tl.fromTo(shot, { opacity: 0, y: 140, scale: 0.86, rotation: rot + 5 }, { opacity: 1, y: 0, scale: 1, rotation: rot, duration: 0.42, ease: 'power3.out' }, t0);
      tl.to(shot, { scale: 1.035, duration: Math.max(0.05, slot - 0.42), ease: 'none' }, t0 + 0.42);
      if (i < imgs.length - 1) tl.to(shot, { opacity: 0, y: -90, scale: 0.94, duration: 0.24, ease: 'power2.in' }, t0 + slot - 0.24);
    });
    tl.to(box, { opacity: 0, duration: 0.15 }, d - 0.15);
  };

  // ------------------------------------------------------------------ quotes
  S.quotes = function (el, it, tl, X) {
    var sz = X.sz.quote, d = it.dur;
    var veil = X.veil(el, 0.72, 'radial');
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.2 }, 0);
    var items = it.items || [];
    var slot = d / Math.max(1, items.length);
    items.forEach(function (q, i) {
      var box = X.safe(el);
      var mark = X.el('div', 'c9 qmark', box, '“');
      mark.style.fontSize = px(sz * 2.6); mark.style.lineHeight = '0.6'; mark.style.opacity = '0.5'; mark.style.height = px(sz * 1.0);
      var t = txt(X, box, 'c7 cream wrap', X.up(q), sz);
      t.style.maxWidth = '90%';
      var t0 = i * slot;
      tl.fromTo(box, { opacity: 0 }, { opacity: 1, duration: 0.01 }, t0);
      tl.fromTo(mark, { opacity: 0, y: -20 }, { opacity: 0.5, y: 0, duration: 0.4, ease: 'power2.out' }, t0);
      tl.fromTo(t, { opacity: 0, y: 26, filter: X.fb(t, 10) }, { opacity: 1, y: 0, filter: X.fb(t, 0), duration: 0.45, ease: 'power3.out' }, t0 + 0.05);
      tl.fromTo(t, { scale: 1 }, { scale: 1.04, duration: slot, ease: 'none' }, t0);
      tl.to(box, { opacity: 0, duration: 0.2 }, t0 + slot - 0.2);
    });
  };

  // ------------------------------------------------------------------ mech (3 cartes du public)
  S.mech = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur;
    if (it.background_src) {
      var bg = X.el('img', 'fill', el);
      bg.src = it.background_src;
      bg.style.width = '100%'; bg.style.height = '100%'; bg.style.objectFit = 'cover';
      tl.fromTo(bg, { scale: 1 }, { scale: 1.06, duration: d, ease: 'none' }, 0);
    }
    // Luminosité 0,5 : on assombrit l'image (plaque ou fond) de moitié.
    var veil = X.veil(el, 0.5);
    var vg = X.veil(el, 0.55, 'radial');
    var box = X.safe(el);
    var lab = txt(X, box, 'lab nowrap', 'LE PUBLIC CHOISIT', sz.label);
    lab.style.marginBottom = '56px';
    var row = X.el('div', 'cards', box);
    var cw = sz.card_w, ch = sz.card_h;
    var gap = X.C.frame.vertical ? 24 : 56;
    var romans = ['I', 'II', 'III', 'IV', 'V'];
    var texts = (it.cards || []).map(function (name, i) {
      var c = X.el('div', 'card3d', row);
      c.style.width = px(cw); c.style.height = px(ch);
      if (i) c.style.marginLeft = px(gap);
      var back = X.el('div', 'face back', c);
      var o1 = X.el('div', 'orn', back, '✦'); o1.style.fontSize = px(cw * 0.32);
      var o2 = X.el('div', 'lab', back, 'DESTINY'); o2.style.fontSize = px(16); o2.style.marginTop = '18px';
      var front = X.el('div', 'face front', c);
      var num = X.el('div', 'num', front, romans[i] || ''); num.style.fontSize = px(46);
      X.el('div', 'orn-line', front);
      var t = txt(X, front, 'c9 cream wrap', X.up(name), sz.card_txt);
      t.style.maxWidth = px(cw - 40);
      t.style.textShadow = 'none';
      t.setAttribute('data-fit', String(cw - 40));
      return { c: c, t: t };
    });
    // Même corps pour les trois cartes : le plus grand qui fait tenir chaque mot.
    var fs = sz.card_txt;
    texts.forEach(function (o) {
      var f = sz.card_txt, guard = 30;
      o.t.style.fontSize = px(f);
      while (o.t.scrollWidth > cw - 40 + 0.5 && guard-- > 0) { f *= 0.96; o.t.style.fontSize = px(f); }
      fs = Math.min(fs, f);
    });
    texts.forEach(function (o) { o.t.style.fontSize = px(fs); });
    var cards = texts.map(function (o) { return o.c; });
    tl.fromTo([veil, vg], { opacity: 0 }, { opacity: 1, duration: 0.25 }, 0);
    tl.fromTo(lab, { opacity: 0, y: -14 }, { opacity: 1, y: 0, duration: 0.35 }, 0.05);
    var n = cards.length;
    cards.forEach(function (c, i) {
      var side = i - (n - 1) / 2;
      tl.fromTo(c, { opacity: 0, y: 260, rotationZ: side * 9, rotationY: 0 }, { opacity: 1, y: 0, rotationZ: 0, duration: 0.5, ease: 'power3.out' }, 0.1 + i * 0.1);
    });
    // Retournements : un par un, levés en milieu de course.
    var flip0 = Math.min(0.75, d * 0.3), step = Math.min(0.45, (d - flip0 - 0.6) / Math.max(1, n));
    cards.forEach(function (c, i) {
      var t = flip0 + i * step;
      tl.to(c, { rotationY: 180, duration: 0.55, ease: 'power2.inOut' }, t);
      tl.to(c, { keyframes: [{ scale: 1.08, z: 60, duration: 0.27, ease: 'power2.out' }, { scale: 1, z: 0, duration: 0.28, ease: 'power2.in' }] }, t);
    });
    tl.fromTo(row, { scale: 1 }, { scale: 1.03, duration: d, ease: 'none' }, 0);
    tl.to(box, { opacity: 0, duration: 0.15 }, d - 0.15);
  };

  // ------------------------------------------------------------------ dice (cube 3D CSS)
  var PIPS = {
    1: [[50, 50]], 2: [[28, 28], [72, 72]], 3: [[26, 26], [50, 50], [74, 74]],
    4: [[28, 28], [72, 28], [28, 72], [72, 72]], 5: [[27, 27], [73, 27], [50, 50], [27, 73], [73, 73]],
    6: [[28, 24], [72, 24], [28, 50], [72, 50], [28, 76], [72, 76]]
  };
  S.dice = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur, L = it.lines || [];
    var veil = X.veil(el, 0.74, 'radial');
    var box = X.safe(el);
    var S0 = sz.cube;
    var wrap = X.el('div', 'dicewrap', box);
    wrap.style.width = px(S0 * 1.6); wrap.style.height = px(S0 * 1.25 + 20);
    wrap.style.margin = '0 0 34px';
    var shadow = X.el('div', 'dshadow', wrap);
    shadow.style.width = px(S0 * 1.2); shadow.style.height = px(S0 * 0.22);
    shadow.style.marginLeft = px(-S0 * 0.6); shadow.style.bottom = '0px';
    var cube = X.el('div', 'cube', wrap);
    cube.style.width = px(S0); cube.style.height = px(S0);
    var faces = [[1, 'rotateY(0deg)'], [6, 'rotateY(180deg)'], [3, 'rotateY(90deg)'], [4, 'rotateY(-90deg)'], [2, 'rotateX(90deg)'], [5, 'rotateX(-90deg)']];
    faces.forEach(function (f) {
      var fe = X.el('div', 'f', cube);
      fe.style.transform = f[1] + ' translateZ(' + (S0 / 2) + 'px)';
      PIPS[f[0]].forEach(function (p) {
        var pip = X.el('div', 'pip', fe);
        pip.style.left = p[0] + '%'; pip.style.top = p[1] + '%';
      });
    });
    var l1 = L[0] != null ? txt(X, box, 'lab wrap', X.up(L[0]), sz.dice1) : null;
    var l2 = L[1] != null ? txt(X, box, 'c9 gold wrap', X.up(L[1]), sz.dice2) : null;
    if (l2) l2.style.marginTop = '22px';
    var l3 = L[2] != null ? txt(X, box, 'c7 cream wrap', L[2], sz.dice3) : null;
    if (l3) l3.style.marginTop = '22px';

    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.2 }, 0);
    if (l1) tl.fromTo(l1, { opacity: 0, y: -12 }, { opacity: 1, y: 0, duration: 0.35 }, 0.05);
    // Le dé est lancé : il tombe en tournoyant, rebondit et se pose sur trois faces visibles.
    var land = Math.min(1.0, d * 0.42);
    tl.fromTo(cube, { rotationX: -560, rotationY: 470, rotationZ: 40, y: -S0 * 0.9, scale: 0.55 },
      { rotationX: -24, rotationY: 36, rotationZ: 0, y: 0, scale: 1, duration: land, ease: 'power3.out' }, 0.08);
    tl.to(cube, { keyframes: [{ y: -S0 * 0.12, duration: 0.12, ease: 'power2.out' }, { y: 0, duration: 0.12, ease: 'power2.in' }] }, land + 0.08);
    tl.fromTo(shadow, { opacity: 0, scaleX: 0.4 }, { opacity: 1, scaleX: 1, duration: land, ease: 'power3.out' }, 0.08);
    tl.to(cube, { rotationY: 52, duration: d - land - 0.1, ease: 'none' }, land + 0.1);
    if (l2) { tl.fromTo(l2, { opacity: 0, scale: 1.35, filter: X.fb(l2, 8) }, { opacity: 1, scale: 1, filter: X.fb(l2, 0), duration: 0.18, ease: 'power3.in' }, land - 0.05); X.shake(tl, box, land + 0.13, 9); }
    if (l3) tl.fromTo(l3, { opacity: 0, y: 18, filter: X.fb(l3, 8) }, { opacity: 1, y: 0, filter: X.fb(l3, 0), duration: 0.45, ease: 'power2.out' }, land + 0.4);
    tl.to(box, { opacity: 0, duration: 0.15 }, d - 0.15);
  };

  // ------------------------------------------------------------------ constellation
  S.constellation = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur, F = X.C.frame;
    var veil = X.veil(el, 0.78, 'radial');
    var cst = X.el('div', 'cst', el);
    var rnd = X.rng(20261008);
    var bgs = [];
    for (var i = 0; i < 90; i++) {
      var s = X.el('div', 'bg-star', cst);
      var r = 1 + rnd() * 2.6;
      s.style.width = px(r); s.style.height = px(r);
      s.style.left = (rnd() * 100) + '%'; s.style.top = (F.bars + rnd() * (F.H - 2 * F.bars)) + 'px';
      s.style.opacity = String(0.25 + rnd() * 0.5);
      bgs.push(s);
    }
    var box = X.safe(el, 'top');
    var lab = txt(X, box, 'lab nowrap', 'LES ARCHÉTYPES', sz.label);
    var names = it.names || [];
    var n = names.length;
    // Positions : spirale à angle d'or, légèrement perturbée (graine fixe), dans la boîte de contenu.
    var x0 = F.safe[0], x1 = F.safe[2], y0 = F.safe[1] + 110, y1 = F.safe[3] - 30;
    var cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    var rx = (x1 - x0) / 2 * 0.8, ry = (y1 - y0) / 2 * (F.vertical ? 0.9 : 0.78);
    var pts = [];
    for (var j = 0; j < n; j++) {
      var a = j * 2.39996 + 0.6 + (rnd() - 0.5) * 0.5;
      var rr = 0.32 + 0.68 * Math.sqrt(j / Math.max(1, n - 1));
      pts.push([cx + Math.cos(a) * rx * rr, cy + Math.sin(a) * ry * rr]);
    }
    // Relaxation (déterministe) : écarte les étoiles dont les noms se toucheraient.
    var mdx = sz.const * 7, mdy = sz.const * 2.6;
    for (var it2 = 0; it2 < 120; it2++) {
      for (var p1 = 0; p1 < n; p1++) {
        for (var p2 = p1 + 1; p2 < n; p2++) {
          var ddx = (pts[p2][0] - pts[p1][0]) / mdx, ddy = (pts[p2][1] - pts[p1][1]) / mdy;
          var dd = Math.hypot(ddx, ddy);
          if (dd >= 1) continue;
          if (dd < 1e-6) { ddx = 0; ddy = 1; dd = 1e-6; }
          var push = (1 - dd) / 2 / dd;
          pts[p1][0] -= ddx * push * mdx; pts[p1][1] -= ddy * push * mdy;
          pts[p2][0] += ddx * push * mdx; pts[p2][1] += ddy * push * mdy;
        }
      }
      for (var p3 = 0; p3 < n; p3++) {
        pts[p3][0] = Math.max(x0 + 40, Math.min(x1 - 40, pts[p3][0]));
        pts[p3][1] = Math.max(y0, Math.min(y1 - sz.const * 1.6, pts[p3][1]));
      }
    }
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    cst.appendChild(svg);
    var lines = [];
    function link(a, b) {
      var l = document.createElementNS(ns, 'line');
      l.setAttribute('x1', pts[a][0]); l.setAttribute('y1', pts[a][1]);
      l.setAttribute('x2', pts[b][0]); l.setAttribute('y2', pts[b][1]);
      l.setAttribute('stroke', 'rgba(230,180,70,0.55)'); l.setAttribute('stroke-width', '2');
      var len = Math.hypot(pts[b][0] - pts[a][0], pts[b][1] - pts[a][1]);
      l.setAttribute('stroke-dasharray', String(len)); l.setAttribute('stroke-dashoffset', String(len));
      svg.appendChild(l);
      lines.push({ l: l, a: a, b: b, len: len });
    }
    // Tracé : les étoiles reliées dans l'ordre angulaire autour du centre (contour sans
    // croisement), plus une corde par trois étoiles.
    var order = pts.map(function (p, i) { return [Math.atan2(p[1] - cy, p[0] - cx), i]; })
      .sort(function (u, v) { return u[0] - v[0] || u[1] - v[1]; }).map(function (u) { return u[1]; });
    for (var k = 1; k < n; k++) link(order[k - 1], order[k]);
    for (var m = 3; m < n; m += 3) link(order[m - 3], order[m]);
    var stars = pts.map(function (p, i) {
      var dot = X.el('div', 'dot', cst);
      dot.style.left = px(p[0]); dot.style.top = px(p[1]);
      var nm = txt(X, cst, 'c7 cream name', X.up(names[i]), sz.const);
      nm.style.top = px(p[1] + 18);
      nm.style.left = px(p[0]);
      // Garde le nom dans la boîte de contenu (mesure réelle, déterministe).
      var w = nm.offsetWidth;
      var lx = Math.max(x0 + w / 2, Math.min(x1 - w / 2, p[0]));
      nm.style.left = px(lx);
      return { dot: dot, nm: nm };
    });
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.25 }, 0);
    tl.fromTo(bgs, { opacity: 0 }, { opacity: function (i, t) { return t.style.opacity; }, duration: 0.6, stagger: 0.004 }, 0);
    tl.fromTo(lab, { opacity: 0, y: -12 }, { opacity: 1, y: 0, duration: 0.35 }, 0.05);
    var span = Math.max(0.3, d * 0.62);
    var step = span / Math.max(1, n);
    stars.forEach(function (s, i) {
      var t = 0.25 + i * step;
      tl.fromTo(s.dot, { scale: 0, opacity: 0 }, { scale: 1, opacity: 1, duration: 0.3, ease: 'back.out(3)' }, t);
      tl.fromTo(s.nm, { opacity: 0, y: 12, filter: X.fb(s.nm, 6) }, { opacity: 1, y: 0, filter: X.fb(s.nm, 0), duration: 0.35, ease: 'power2.out' }, t + 0.06);
    });
    lines.forEach(function (o) {
      var t = 0.25 + Math.max(o.a, o.b) * step;
      tl.fromTo(o.l, { attr: { 'stroke-dashoffset': o.len } }, { attr: { 'stroke-dashoffset': 0 }, duration: 0.4, ease: 'power1.inOut' }, t);
    });
    tl.fromTo(cst, { scale: 1 }, { scale: 1.05, duration: d, ease: 'none' }, 0);
    tl.to([cst, box], { opacity: 0, duration: 0.15 }, d - 0.15);
  };

  // ------------------------------------------------------------------ card (fade | stamp)
  S.card = function (el, it, tl, X) {
    var sz = X.sz.card, d = it.dur, L = it.lines || [];
    var stamp = it.style === 'stamp';
    var veil = X.veil(el, 0.9, 'radial');
    var box = X.safe(el);
    var ls = L.map(function (l, i) {
      var last = i === L.length - 1 && L.length > 1;
      var e = txt(X, box, 'c9 wrap ' + (last ? 'gold' : 'cream'), X.up(l), sz);
      e.style.maxWidth = '100%';
      if (i) e.style.marginTop = '6px';
      return e;
    });
    var glow = X.el('div', 'glow', el);
    var gs = X.C.frame.W * 1.1;
    glow.style.width = px(gs); glow.style.height = px(gs);
    glow.style.left = px(X.C.frame.W / 2 - gs / 2); glow.style.top = px(X.C.frame.H / 2 - gs / 2);
    glow.style.opacity = '0';
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: stamp ? 0.05 : 0.3 }, 0);
    if (stamp) {
      ls.forEach(function (e, i) {
        var t = 0.08 + i * 0.36;
        tl.fromTo(e, { opacity: 0, scale: 2.4, filter: X.fb(e, 6) }, { opacity: 1, scale: 1, filter: X.fb(e, 0), duration: 0.14, ease: 'power4.in' }, t);
        X.shake(tl, box, t + 0.14, i === ls.length - 1 ? 18 : 10);
        tl.fromTo(glow, { opacity: 0.9, scale: 0.6 }, { opacity: 0, scale: 1.2, duration: 0.55, ease: 'power2.out' }, t + 0.14);
      });
      tl.fromTo(box, { scale: 1 }, { scale: 1.06, duration: d, ease: 'none' }, 0);
    } else {
      ls.forEach(function (e, i) {
        tl.fromTo(e, { opacity: 0, y: 28, filter: X.fb(e, 14) }, { opacity: 1, y: 0, filter: X.fb(e, 0), duration: 0.6, ease: 'power2.out' }, 0.1 + i * 0.28);
      });
      tl.fromTo(box, { scale: 1.05 }, { scale: 1, duration: d, ease: 'power1.out' }, 0);
      tl.to(box, { opacity: 0, duration: 0.25 }, d - 0.25);
    }
  };

  // ------------------------------------------------------------------ tags
  S.tags = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur, items = it.items || [];
    var veil = X.veil(el, 0.82, 'bottom');
    var box = X.safe(el, 'bottom');
    box.style.paddingBottom = px(X.C.frame.vertical ? 180 : 10);
    var els = items.map(function (t, i) {
      if (i === 0) {
        var b = X.el('div', 'tagbox txt lab nowrap', box, X.up(t));
        b.style.fontSize = px(sz.tag);
        b.style.marginBottom = '22px';
        return b;
      }
      var e = txt(X, box, 'c9 gold wrap', X.up(t), sz.tagbig);
      e.style.maxWidth = '100%';
      e.style.marginTop = '8px';
      return e;
    });
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.15 }, 0);
    els.forEach(function (e, i) {
      var t = 0.05 + i * 0.32;
      if (i === 0) tl.fromTo(e, { opacity: 0, scaleX: 0.2 }, { opacity: 1, scaleX: 1, duration: 0.22, ease: 'power3.out' }, t);
      else {
        tl.fromTo(e, { opacity: 0, scale: 1.8, filter: X.fb(e, 6) }, { opacity: 1, scale: 1, filter: X.fb(e, 0), duration: 0.12, ease: 'power4.in' }, t);
        X.shake(tl, e, t + 0.12, 16);
        // Glitch court : décalages horizontaux secs.
        tl.to(e, { keyframes: [{ x: -14, skewX: -8, duration: 0.04 }, { x: 10, skewX: 6, duration: 0.04 }, { x: 0, skewX: 0, duration: 0.05 }] }, t + 0.5);
      }
    });
    tl.to(box, { opacity: 0, duration: 0.12 }, d - 0.12);
  };

  // ------------------------------------------------------------------ lower (nom + rôle)
  S.lower = function (el, it, tl, X) {
    var sz = X.sz, d = it.dur;
    var veil = X.veil(el, 0.6, 'bottom');
    var box = X.safe(el, 'bottom left');
    box.style.paddingBottom = px(X.C.frame.vertical ? 120 : 0);
    var lw = X.el('div', 'lower', box);
    var bar = X.el('div', 'bar', lw);
    var nm = txt(X, lw, 'c7 cream wrap', X.up(it.name || ''), sz.lname);
    var rl = txt(X, lw, 'lab wrap', X.up(it.role || ''), sz.lrole);
    rl.style.marginTop = '8px'; rl.style.paddingLeft = '0';
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.3 }, 0);
    tl.fromTo(bar, { scaleY: 0 }, { scaleY: 1, duration: 0.3, ease: 'power2.out' }, 0.05);
    tl.fromTo(nm, { opacity: 0, x: -40, clipPath: 'inset(0 100% 0 0)' }, { opacity: 1, x: 0, clipPath: 'inset(0 0% 0 0)', duration: 0.45, ease: 'power3.out' }, 0.15);
    tl.fromTo(rl, { opacity: 0, x: -20 }, { opacity: 1, x: 0, duration: 0.35, ease: 'power2.out' }, 0.35);
    tl.to([lw, veil], { opacity: 0, duration: 0.25 }, d - 0.25);
  };

  // ------------------------------------------------------------------ ring
  S.ring = function (el, it, tl, X) {
    var d = it.dur, F = X.C.frame;
    var base = Math.min(F.W, F.H - 2 * F.bars) * 0.9;
    var glow = X.el('div', 'glow', el);
    glow.style.width = px(base); glow.style.height = px(base);
    glow.style.left = px(F.W / 2 - base / 2); glow.style.top = px(F.H / 2 - base / 2);
    tl.fromTo(glow, { opacity: 0.9, scale: 0.3 }, { opacity: 0, scale: 1.2, duration: Math.min(d, 0.9), ease: 'power2.out' }, 0);
    for (var i = 0; i < 3; i++) {
      var r = X.el('div', 'ringc', el);
      r.style.width = px(base); r.style.height = px(base);
      r.style.marginLeft = px(-base / 2); r.style.marginTop = px(-base / 2);
      tl.fromTo(r, { scale: 0.05, opacity: 1, borderWidth: 10 }, { scale: 1.25, opacity: 0, borderWidth: 1, duration: Math.min(d, 1.1), ease: 'power2.out' }, i * 0.16);
    }
  };

  // ------------------------------------------------------------------ fin (balayage lumineux)
  S.fin = function (el, it, tl, X) {
    var d = it.dur, F = X.C.frame;
    var veil = X.veil(el, 0.9);
    var box = X.safe(el);
    var t = txt(X, box, 'c9 sweep wrap', X.up(it.text || ''), X.sz.fin);
    t.style.maxWidth = '92%';
    var streak = X.el('div', 'streakline', el);
    streak.style.top = px(F.H / 2);
    tl.fromTo(veil, { opacity: 0 }, { opacity: 1, duration: 0.35 }, 0);
    tl.fromTo(t, { opacity: 0, scale: 1.08, filter: X.fb(t, 12) }, { opacity: 1, scale: 1, filter: X.fb(t, 0), duration: 0.7, ease: 'power2.out' }, 0.05);
    // Le reflet traverse le texte de gauche à droite.
    tl.fromTo(t, { backgroundPosition: '100% 0%' }, { backgroundPosition: '0% 0%', duration: Math.max(0.6, d * 0.8), ease: 'power1.inOut' }, 0.15);
    tl.fromTo(streak, { left: px(-F.W * 0.5), opacity: 0 }, { left: px(F.W * 1.05), opacity: 1, duration: Math.max(0.6, d * 0.8), ease: 'power1.inOut' }, 0.15);
    tl.to(box, { opacity: 0, duration: 0.3 }, d - 0.3);
  };

  // ------------------------------------------------------------------ black
  S.black = function (el) {
    var X = window.__X;
    X.el('div', 'blackc', el);
  };

  // ------------------------------------------------------------------ flash
  S.flash = function (el, it, tl, X) {
    var f = X.el('div', 'flashc', el);
    tl.fromTo(f, { opacity: 1 }, { opacity: 0, duration: it.dur, ease: 'power1.out' }, 0);
  };

  // ------------------------------------------------------------------ end_card
  S.end_card = function (el, it, tl, X) {
    var sz = X.sz, F = X.C.frame;
    X.el('div', 'endbg', el);
    var burst = X.el('div', 'glow', el);
    var gs = F.W * 1.3;
    burst.style.width = px(gs); burst.style.height = px(gs);
    burst.style.left = px(F.W / 2 - gs / 2); burst.style.top = px(F.H / 2 - gs / 2 - 80);
    var box = X.safe(el);
    var logo = X.el('div', 'logo', box);
    var lt = txt(X, logo, 'c9 gold nowrap', 'DESTINY', sz.logo);
    lt.style.letterSpacing = '0.06em'; lt.style.paddingLeft = '0.06em';
    X.fit(lt, X.C.frame.safe[2] - X.C.frame.safe[0]);
    var sheen = X.el('div', 'sheen c9 nowrap', logo, 'DESTINY');
    sheen.style.fontSize = lt.style.fontSize;
    var tag = txt(X, box, 'c7 cream wrap', 'RIEN N’EST ÉCRIT.', sz.tagline);
    tag.style.marginTop = X.C.frame.vertical ? '34px' : '22px';
    var orn = X.el('div', 'orn-row', box);
    orn.style.margin = X.C.frame.vertical ? '40px 0 30px' : '26px 0 20px';
    var la = X.el('div', 'l a', orn); X.el('div', 'd', orn); var lb = X.el('div', 'l b', orn);
    var info = (it.info || []).map(function (l, i) {
      var e = i % 2 === 1 ? txt(X, box, 'c7 cream wrap', l, sz.info2) : txt(X, box, 'lab wrap', X.up(l), sz.info);
      e.style.margin = X.C.frame.vertical ? '9px 0' : '6px 0';
      return e;
    });
    var btn = X.el('div', 'button txt lab nowrap', box, it.button || 'VIENS AVEC QUELQU’UN.');
    btn.style.fontSize = px(sz.button);
    btn.style.marginTop = X.C.frame.vertical ? '60px' : '40px';
    btn.style.color = '#f3ede4';
    // Tout est posé sur le coup le plus fort de la musique (t = 0) : pas de fondu d'entrée du fond.
    tl.fromTo(burst, { opacity: 1, scale: 0.4 }, { opacity: 0.25, scale: 1, duration: 1.2, ease: 'power3.out' }, 0);
    tl.fromTo(logo, { opacity: 0, scale: 1.16, filter: X.fb(logo, 10) }, { opacity: 1, scale: 1, filter: X.fb(logo, 0), duration: 0.5, ease: 'expo.out' }, 0);
    tl.fromTo(sheen, { backgroundPosition: '120% 0%' }, { backgroundPosition: '-20% 0%', duration: 1.1, ease: 'power2.inOut' }, 0.45);
    tl.fromTo(tag, { opacity: 0, y: 16, filter: X.fb(tag, 8) }, { opacity: 1, y: 0, filter: X.fb(tag, 0), duration: 0.5, ease: 'power2.out' }, 0.5);
    tl.fromTo([la, lb], { scaleX: 0 }, { scaleX: 1, duration: 0.45, ease: 'power2.out' }, 0.85);
    tl.fromTo(orn, { opacity: 0 }, { opacity: 1, duration: 0.3 }, 0.85);
    info.forEach(function (e, i) {
      tl.fromTo(e, { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.4, ease: 'power2.out' }, 1.05 + i * 0.16);
    });
    var tb = 1.1 + info.length * 0.16 + 0.15;
    tl.fromTo(btn, { opacity: 0, scale: 0.88 }, { opacity: 1, scale: 1, duration: 0.35, ease: 'back.out(2)' }, tb);
    tl.to(btn, { keyframes: [{ scale: 1.045, boxShadow: '0 0 60px rgba(230,180,70,0.45)', duration: 0.35, ease: 'sine.out' }, { scale: 1, boxShadow: '0 0 40px rgba(230,180,70,0.18)', duration: 0.45, ease: 'sine.in' }] }, tb + 0.45);
    tl.fromTo(box, { scale: 1 }, { scale: 1.025, duration: it.dur, ease: 'none' }, 0);
    // Coupe franche à la fin : aucune sortie.
  };

  // ------------------------------------------------------------------ shorts (compatibilité)
  S.kicker = function (el, it, tl, X) {
    var box = X.safe(el, 'top');
    var k = X.el('div', 'kicker txt lab nowrap', box, X.up(it.text || ''));
    k.style.fontSize = px(X.sz.kicker); k.style.color = '#0b0907';
    tl.fromTo(k, { opacity: 0, y: -16 }, { opacity: 1, y: 0, duration: 0.3 }, 0);
  };
  S.tag = function (el, it, tl, X) {
    var box = X.safe(el, 'bottom');
    box.style.paddingBottom = '240px';
    var k = X.el('div', 'tagbox txt lab nowrap', box, X.up(it.text || ''));
    k.style.fontSize = px(X.sz.tag);
    tl.fromTo(k, { opacity: 0, scaleX: 0.3 }, { opacity: 1, scaleX: 1, duration: 0.25 }, 0);
  };
  S.cta = function (el, it, tl, X) {
    var box = X.safe(el, 'bottom');
    box.style.paddingBottom = '40px';
    var b = X.el('div', 'ctabox', box);
    (it.lines || []).forEach(function (l) { var e = txt(X, b, 'c9 gold wrap', X.up(l), X.sz.cta); e.style.margin = '3px 0'; });
    tl.fromTo(b, { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1, duration: 0.3, ease: 'back.out(2)' }, 0);
  };
  S.progress = function (el, it, tl, X) {
    var b = X.el('div', 'progress', el);
    if (X.C.frame.bars) b.style.bottom = px(X.C.frame.bars);
    tl.fromTo(b, { scaleX: 0 }, { scaleX: 1, duration: it.dur, ease: 'none' }, 0);
  };
})();
