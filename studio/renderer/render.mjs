#!/usr/bin/env node
// Destiny Studio — moteur B : rendu image par image d'une composition HTML/GSAP
// (index.html généré par destiny-core::render_b) en Chromium headless.
//
//   node renderer/render.mjs --comp <dir> --fps 30 --w 1080 --h 1920 --out <dir | ->
//        [--frames N] [--from F] [--workers 3] [--at t1,t2,…]
//
// Chaque image : window.__seek(frame / fps) puis capture PNG transparente
// (fond transparent, Page.captureScreenshot). Avec --out -, les PNG partent dans l'ordre sur stdout (à lire par
// ffmpeg -f image2pipe -c:v png -i -) et la progression « frame N/M » sur stderr ;
// avec un dossier, les fichiers frame_000000.png y sont écrits et la progression va
// sur stdout. Les avertissements de zone sûre sont émis sous la forme « warn … ».
//
// Navigateur : DESTINY_CHROMIUM (chemin d'un Chrome/Chromium), sinon le Chromium de
// Playwright (PLAYWRIGHT_BROWSERS_PATH), sinon Google Chrome / Chromium installé.

import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function parseArgs(argv) {
  const a = { fps: 30, w: 1080, h: 1920, workers: 3, out: '-', from: 0 };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    const v = argv[i + 1];
    switch (k) {
      case '--comp': a.comp = v; i++; break;
      case '--fps': a.fps = Number(v); i++; break;
      case '--w': a.w = Number(v); i++; break;
      case '--h': a.h = Number(v); i++; break;
      case '--frames': a.frames = Number(v); i++; break;
      case '--from': a.from = Number(v); i++; break;
      case '--workers': a.workers = Math.max(1, Number(v)); i++; break;
      case '--out': a.out = v; i++; break;
      case '--at': a.at = v.split(',').map(Number); i++; break;
      case '-h': case '--help':
        console.error('usage: render.mjs --comp <dir> --fps 30 --w 1080 --h 1920 --out <dir|-> [--frames N] [--workers 3] [--at t1,t2]');
        process.exit(0);
        break;
      default:
        console.error(`argument inconnu : ${k}`);
        process.exit(2);
    }
  }
  if (!a.comp) { console.error('--comp requis'); process.exit(2); }
  return a;
}

const args = parseArgs(process.argv);
const toStdout = args.out === '-';
const log = (s) => (toStdout ? process.stderr : process.stdout).write(s + '\n');
const warn = (s) => process.stderr.write('warn ' + s + '\n');

function candidates() {
  const c = [];
  if (process.env.DESTINY_CHROMIUM) c.push(process.env.DESTINY_CHROMIUM);
  c.push(null); // Chromium de Playwright (emplacement par défaut)
  const pw = process.env.PLAYWRIGHT_BROWSERS_PATH;
  if (pw && fs.existsSync(pw)) {
    for (const d of fs.readdirSync(pw).sort().reverse()) {
      for (const rel of ['chrome-linux/chrome', 'chrome-linux/headless_shell', 'chrome-mac/Chromium.app/Contents/MacOS/Chromium',
        'chrome-mac-arm64/Chromium.app/Contents/MacOS/Chromium', 'chrome-headless-shell-linux64/chrome-headless-shell']) {
        const p = path.join(pw, d, rel);
        if (fs.existsSync(p)) c.push(p);
      }
    }
  }
  c.push('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome');
  return c.filter((p) => p === null || fs.existsSync(p));
}

async function launch() {
  const errors = [];
  const flags = ['--font-render-hinting=none', '--disable-lcd-text', '--force-color-profile=srgb',
    '--allow-file-access-from-files', '--hide-scrollbars', '--mute-audio'];
  for (const exe of candidates()) {
    try {
      return await chromium.launch({ headless: true, executablePath: exe || undefined, args: flags });
    } catch (e) {
      errors.push(`${exe || 'playwright'} : ${String(e.message || e).split('\n')[0]}`);
    }
  }
  throw new Error('aucun Chromium utilisable (définir DESTINY_CHROMIUM) :\n  ' + errors.join('\n  '));
}

async function openPage(browser, url) {
  const page = await browser.newPage({ viewport: { width: args.w, height: args.h }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => log(`erreur page : ${e.message}`));
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') log(`console ${m.type()} : ${m.text()}`); });
  await page.addInitScript(() => { window.__RENDER = true; });
  await page.goto(url, { waitUntil: 'load' });
  await page.evaluate(() => window.__ready);
  // Capture directe par CDP : fond transparent, encodage PNG rapide (≈ 3× plus rapide
  // que page.screenshot, qui ré-encode avec une compression maximale).
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
  page.__shot = async () => {
    const r = await cdp.send('Page.captureScreenshot', { format: 'png', optimizeForSpeed: true, fromSurface: true, captureBeyondViewport: false });
    return Buffer.from(r.data, 'base64');
  };
  return page;
}

const browser = await launch();
let stopping = false;
async function shutdown(code) {
  if (stopping) return;
  stopping = true;
  try { await browser.close(); } catch { /* déjà fermé */ }
  process.exit(code);
}
process.on('SIGTERM', () => shutdown(143));
process.on('SIGINT', () => shutdown(130));
process.stdout.on('error', (e) => { log(`sortie fermée : ${e.code || e.message}`); shutdown(1); });

try {
  const url = pathToFileURL(path.resolve(args.comp, 'index.html')).href;
  const first = await openPage(browser, url);
  const duration = await first.evaluate(() => window.__duration);
  let frames;
  if (args.at) frames = args.at.map((t) => Math.round(t * args.fps));
  else {
    const total = args.frames ?? Math.round(duration * args.fps);
    frames = [];
    for (let f = args.from; f < total; f++) frames.push(f);
  }
  const M = frames.length;
  const pages = [first];
  const nw = Math.min(args.workers, Math.max(1, M));
  for (let i = 1; i < nw; i++) pages.push(await openPage(browser, url));
  if (!toStdout) fs.mkdirSync(args.out, { recursive: true });

  // Écriture dans l'ordre ; les pages ne prennent pas plus de `ahead` images d'avance.
  const done = new Map();
  let next = 0;
  let written = 0;
  const ahead = nw * 3;
  const waiters = [];
  const seen = new Set();
  const write = (buf) => new Promise((res) => {
    if (process.stdout.write(buf)) res();
    else process.stdout.once('drain', res);
  });

  async function flush() {
    while (done.has(next)) {
      const buf = done.get(next);
      done.delete(next);
      const f = frames[next];
      if (toStdout) await write(buf);
      else fs.writeFileSync(path.join(args.out, `frame_${String(f).padStart(6, '0')}.png`), buf);
      next++;
      written++;
      if (written % 10 === 0 || written === M) log(`frame ${written}/${M}`);
      waiters.splice(0).forEach((w) => w());
    }
  }

  let cursor = 0;
  let flushing = Promise.resolve();
  async function worker(page) {
    for (;;) {
      const i = cursor++;
      if (i >= M) return;
      while (i - next >= ahead) await new Promise((r) => waiters.push(r));
      const t = frames[i] / args.fps;
      const bad = await page.evaluate(async (tt) => { await window.__seek(tt); return window.__checkSafe(); }, t);
      for (const b of bad) {
        const key = `${b.scene}|${b.text}`;
        if (!seen.has(key)) {
          seen.add(key);
          warn(`zone sûre t=${t.toFixed(2)} scène=${b.scene} « ${b.text} » y=${b.top}–${b.bottom} x=${b.left}–${b.right}`);
        }
      }
      const buf = await page.__shot();
      done.set(i, buf);
      flushing = flushing.then(flush);
      await flushing;
    }
  }
  await Promise.all(pages.map(worker));
  await flushing;
  if (toStdout) await new Promise((r) => process.stdout.end(r));
  await shutdown(0);
} catch (e) {
  log(`erreur : ${e.stack || e}`);
  await shutdown(1);
}
