/* Destiny Studio — runtime des compositions du moteur B (généré, ne pas éditer à la main).
 *
 * Convention HyperFrames : chaque élément porte class="clip", data-start, data-duration,
 * data-track-index. Une seule timeline GSAP maîtresse, en pause ; rien ne bouge sans
 * window.__seek(t). Aucune source d'aléa ni d'horloge (pas de générateur aléatoire, pas d'heure,
 * pas de transition/animation CSS) : une même image t donne toujours les mêmes pixels.
 *
 * API :
 *   await window.__ready          composition construite (polices + images chargées)
 *   window.__duration             durée en secondes
 *   await window.__seek(t)        place la timeline à t (s), met à jour la visibilité et
 *                                 résout après deux images du compositeur
 *   window.__checkSafe()          textes visibles hors de la zone autorisée (16:9 : 131–949 px)
 *   window.__play(t) / __pause()  lecture temps réel (aperçu live uniquement)
 */
(function () {
  'use strict';
  var C = JSON.parse(document.getElementById('comp-data').textContent);
  var RENDER = !!window.__RENDER || /[?&]render=1/.test(location.search);
  // Calque de l'aperçu de l'éditeur : fond transparent posé sur le proxy vidéo de l'app.
  var OVERLAY = /[?&]overlay=1/.test(location.search);
  var EPS = 1e-6;
  window.__COMP = C;
  window.__duration = C.duration;

  var root = document.documentElement;
  root.style.setProperty('--W', C.frame.W + 'px');
  root.style.setProperty('--H', C.frame.H + 'px');
  root.style.setProperty('--k', String(C.frame.k));
  root.style.setProperty('--bars', C.frame.bars + 'px');
  root.style.setProperty('--sx0', C.frame.safe[0] + 'px');
  root.style.setProperty('--sy0', C.frame.safe[1] + 'px');
  root.style.setProperty('--sw', (C.frame.safe[2] - C.frame.safe[0]) + 'px');
  root.style.setProperty('--sh', (C.frame.safe[3] - C.frame.safe[1]) + 'px');
  document.body.classList.add(C.frame.vertical ? 'fmt-v' : 'fmt-h');
  document.body.classList.add(RENDER ? 'render' : OVERLAY ? 'overlay' : 'live');

  var stage = document.getElementById('stage');
  stage.style.transform = 'scale(' + C.frame.k + ')';
  // Aperçu live (iframe de l'éditeur) : la scène s'adapte à la fenêtre, centrée.
  // En rendu, taille exacte de sortie (la fenêtre fait w × h).
  function fitLive() {
    if (RENDER) return;
    var s = Math.min(window.innerWidth / C.frame.w, window.innerHeight / C.frame.h) || 1;
    var k = C.frame.k * s;
    var ox = (window.innerWidth - C.frame.w * s) / 2, oy = (window.innerHeight - C.frame.h * s) / 2;
    stage.style.transform = 'translate(' + ox + 'px,' + oy + 'px) scale(' + k + ')';
  }
  fitLive();
  window.addEventListener('resize', fitLive);

  gsap.ticker.lagSmoothing(0);
  // Pas de rendu différé (« lazy ») : chaque seek écrit toutes les valeurs immédiatement.
  gsap.defaults({ lazy: false });
  // Transformations 2D (pas de translate3d) : pas de promotion en calque compositeur,
  // dont l'échelle de rastérisation dépendrait de l'historique des images (non déterministe).
  gsap.config({ force3D: false });
  var master = gsap.timeline({ paused: true });
  window.__timeline = master;

  // ---------- utilitaires partagés par les scènes ----------
  var X = {
    C: C,
    sz: C.sz,
    render: RENDER,
    el: function (tag, cls, parent, text) {
      var e = document.createElement(tag);
      if (cls) e.className = cls;
      if (text != null) e.textContent = text;
      if (parent) parent.appendChild(e);
      return e;
    },
    /** Boîte de contenu (zone sûre moins la marge), en colonne centrée. */
    safe: function (parent, cls) {
      return X.el('div', 'safe' + (cls ? ' ' + cls : ''), parent);
    },
    veil: function (parent, alpha, kind) {
      var v = X.el('div', 'veil' + (kind ? ' veil-' + kind : ''), parent);
      v.style.setProperty('--a', String(alpha));
      return v;
    },
    up: function (s) { return String(s).toUpperCase(); },
    /** Filtre « flou + filtre de base de l'élément » (ombres portées de .gold…), pour
     *  qu'un fondu flou → net ne supprime pas les ombres de la charte. Ne jamais animer
     *  un flou avec une courbe qui dépasse (back, elastic) : un flou négatif est ignoré
     *  par le navigateur et l'image dépendrait alors de l'image précédente. */
    fb: function (e, b) {
      if (e.__baseFilter == null) {
        var f = getComputedStyle(e).filter;
        e.__baseFilter = f && f !== 'none' ? ' ' + f : '';
      }
      return 'blur(' + b + 'px)' + e.__baseFilter;
    },
    /** Réduit la police d'une ligne insécable jusqu'à ce qu'elle tienne (≥ 65 %). */
    fit: function (e, maxW) {
      var size = parseFloat(e.style.fontSize || getComputedStyle(e).fontSize);
      var min = size * 0.65;
      var guard = 40;
      while (e.scrollWidth > maxW + 0.5 && size > min && guard-- > 0) {
        size = Math.max(min, size * 0.96);
        e.style.fontSize = size + 'px';
      }
      return e;
    },
    /** Générateur pseudo-aléatoire à graine fixe (mulberry32) : déterministe. */
    rng: function (seed) {
      var a = seed >>> 0;
      return function () {
        a = (a + 0x6D2B79F5) >>> 0;
        var t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    },
    /** Secousse courte (impact), en keyframes GSAP. */
    shake: function (tl, target, at, amp) {
      amp = amp || 14;
      tl.to(target, {
        keyframes: [
          { x: amp, y: -amp * 0.4, duration: 0.03 },
          { x: -amp * 0.7, y: amp * 0.5, duration: 0.03 },
          { x: amp * 0.45, y: -amp * 0.2, duration: 0.03 },
          { x: -amp * 0.2, y: 0, duration: 0.03 },
          { x: 0, y: 0, duration: 0.04 }
        ]
      }, at);
    },
    star: function (parent, size) {
      var ns = 'http://www.w3.org/2000/svg';
      var s = document.createElementNS(ns, 'svg');
      s.setAttribute('viewBox', '0 0 100 100');
      s.setAttribute('class', 'star');
      s.style.width = size + 'px';
      s.style.height = size + 'px';
      var p = document.createElementNS(ns, 'polygon');
      p.setAttribute('points', '50,4 61.8,37.6 97.5,38.2 69,59.9 79.4,94.1 50,73.6 20.6,94.1 31,59.9 2.5,38.2 38.2,37.6');
      p.setAttribute('fill', 'url(#goldgrad)');
      s.appendChild(p);
      parent.appendChild(s);
      return s;
    }
  };
  window.__X = X;

  // ---------- construction ----------
  var clips = [];

  function buildScenes() {
    var S = window.__SCENES || {};
    var nodes = stage.querySelectorAll('.clip');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var c = {
        el: el,
        start: parseFloat(el.getAttribute('data-start')),
        dur: parseFloat(el.getAttribute('data-duration')),
        scene: el.getAttribute('data-scene')
      };
      clips.push(c);
      if (c.scene === 'clip') {
        if (!RENDER && el.getAttribute('data-src')) {
          var v = X.el('video', 'plate-video', el);
          v.muted = true;
          v.playsInline = true;
          v.preload = 'auto';
          v.src = el.getAttribute('data-src');
          c.video = v;
        }
        continue;
      }
      var item = C.items[el.getAttribute('data-item')];
      var fn = S[c.scene];
      if (!fn) { console.warn('scène inconnue', c.scene); continue; }
      var tl = gsap.timeline();
      fn(el, item, tl, X);
      // La timeline d'une scène commence à son data-start et ne dépasse pas sa durée.
      master.add(tl, c.start);
    }
    master.set({}, {}, C.duration);
    autoFit();
    // Pré-lecture : chaque tween s'initialise une fois, dans l'ordre de la timeline.
    // Sans elle, la 1re image rendue après un saut peut différer de la même image
    // atteinte en lecture continue (valeurs de départ lues à l'initialisation).
    for (var t = 0; t < C.duration; t += 0.1) master.time(t, true);
    master.time(C.duration, true);
    master.time(0, true);
  }

  /** Ajuste les textes qui débordent : un mot plus large que sa boîte (retour à la
   *  ligne impossible) ou une ligne insécable plus large que la zone sûre. Réduction
   *  par pas de 4 %, jusqu'à 60 %. Fait une fois après construction (déterministe). */
  function autoFit() {
    var sw = C.frame.safe[2] - C.frame.safe[0];
    var nodes = stage.querySelectorAll('.txt');
    for (var i = 0; i < nodes.length; i++) {
      var e = nodes[i];
      var lim = e.getAttribute('data-fit');
      var maxW = lim ? parseFloat(lim) : (e.classList.contains('nowrap') ? sw : Math.min(sw, e.clientWidth || sw));
      var size = parseFloat(getComputedStyle(e).fontSize);
      var min = size * 0.6, guard = 30;
      while (e.scrollWidth > maxW + 0.5 && size > min && guard-- > 0) {
        size = Math.max(min, size * 0.96);
        e.style.fontSize = size + 'px';
      }
    }
  }

  function setVisibility(t) {
    for (var i = 0; i < clips.length; i++) {
      var c = clips[i];
      var on = t >= c.start - EPS && t < c.start + c.dur - EPS;
      var vis = on ? 'visible' : 'hidden';
      if (c.el.style.visibility !== vis) c.el.style.visibility = vis;
      if (c.video && on) {
        var lt = Math.max(0, t - c.start);
        if (Math.abs(c.video.currentTime - lt) > 0.06) c.video.currentTime = lt;
      }
    }
  }

  window.__seek = function (t) {
    t = Math.max(0, Math.min(t, C.duration));
    master.time(t, false);
    setVisibility(t);
    // Force la mise en page, puis attend deux images du compositeur : la capture
    // suivante contient forcément l'état de t (filtres et 3D compris).
    void stage.offsetHeight;
    return new Promise(function (res) {
      requestAnimationFrame(function () { requestAnimationFrame(function () { res(t); }); });
    });
  };

  function opacityChain(e) {
    var o = 1;
    while (e && e !== stage) {
      var cs = getComputedStyle(e);
      if (cs.visibility === 'hidden' || cs.display === 'none') return 0;
      o *= parseFloat(cs.opacity);
      e = e.parentElement;
    }
    return o;
  }

  function scaleChain(e) {
    var k = 1;
    while (e && e !== stage) {
      var tf = getComputedStyle(e).transform;
      if (tf && tf !== 'none') { var m = new DOMMatrix(tf); k *= Math.hypot(m.a, m.b); }
      e = e.parentElement;
    }
    return k;
  }

  window.__checkSafe = function () {
    var out = [];
    var k = C.frame.k;
    var y0 = C.frame.zone[0] * k, y1 = C.frame.zone[1] * k, w = C.frame.w;
    var txt = stage.querySelectorAll('.txt');
    for (var i = 0; i < txt.length; i++) {
      var e = txt[i];
      var r = e.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) continue;
      if (r.top >= y0 - 1 && r.bottom <= y1 + 1 && r.left >= -1 && r.right <= w + 1) continue;
      if (opacityChain(e) < 0.05) continue;
      // Effets d'entrée (texte qui claque, grossi) : état transitoire, pas une mise en page.
      if (scaleChain(e) > 1.02) continue;
      var clip = e.closest('.clip');
      out.push({
        scene: clip ? clip.getAttribute('data-scene') : '?',
        text: (e.textContent || '').slice(0, 40),
        top: Math.round(r.top), bottom: Math.round(r.bottom),
        left: Math.round(r.left), right: Math.round(r.right)
      });
    }
    return out;
  };

  var playing = null;
  window.__play = function (from) {
    if (RENDER) return;
    window.__pause();
    var t0 = from == null ? master.time() : from;
    var origin = null;
    function step(ts) {
      if (origin == null) origin = ts - t0 * 1000;
      var t = (ts - origin) / 1000;
      window.__seek(t);
      clips.forEach(function (c) { if (c.video) { var on = c.el.style.visibility === 'visible'; if (on && c.video.paused) c.video.play().catch(function () {}); if (!on && !c.video.paused) c.video.pause(); } });
      if (t < C.duration) playing = requestAnimationFrame(step); else window.__pause();
    }
    playing = requestAnimationFrame(step);
  };
  window.__pause = function () {
    if (playing != null) cancelAnimationFrame(playing);
    playing = null;
    clips.forEach(function (c) { if (c.video) c.video.pause(); });
  };

  function loadFonts() {
    var specs = ['900 100px Cinzel', '700 100px Cinzel', '600 100px Montserrat', '400 100px Anton'];
    return Promise.all(specs.map(function (s) { return document.fonts.load(s, 'ÉÀÇ10/ ★'); }))
      .then(function () { return document.fonts.ready; });
  }

  function decodeImages() {
    var imgs = stage.querySelectorAll('img');
    return Promise.all(Array.prototype.map.call(imgs, function (im) {
      if (im.complete && im.naturalWidth) return im.decode ? im.decode().catch(function () {}) : null;
      return new Promise(function (res) { im.onload = im.onerror = function () { res(); }; })
        .then(function () { return im.decode ? im.decode().catch(function () {}) : null; });
    }));
  }

  window.__ready = loadFonts().then(function () {
    buildScenes();
    return decodeImages();
  }).then(function () {
    return window.__seek(0);
  }).then(function () { return true; });

  // Aperçu live dans l'éditeur : l'iframe (protocole comp://) n'a pas la même origine que
  // l'app, qui ne peut donc pas appeler __seek directement. Messages { seek: t } ; la
  // composition annonce { compReady: durée } quand elle est prête. Rien de tout ça au rendu.
  if (!RENDER && window.parent !== window) {
    window.addEventListener('message', function (e) {
      var d = e.data || {};
      if (typeof d.seek === 'number') window.__ready.then(function () { window.__seek(d.seek); });
    });
    window.__ready.then(function () { window.parent.postMessage({ compReady: C.duration }, '*'); });
  }
})();
