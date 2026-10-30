// The website's translation layer: runs the Garry's Mod gamemode (its Lua files, unchanged) in
// the browser. Lua 5.1 runs in WebAssembly; gmod.lua provides the GMod functions on the Lua side,
// and this file does the browser side: the canvas, pictures, text, sound, keys, mouse and saving.
import { Lua } from 'wasmoon-lua5.1';
import GMOD_LUA from './gmod.lua';
import { setupTouch } from './touch.js';
import { setupGamepad } from './gamepad.js';

const GAME = 'game/';                       // the gamemode folder, copied as it is
const SEP = '\u0001';
const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const overlay = document.getElementById('overlay');
const statusEl = document.getElementById('status');
let manifest, luaFiles, lua;

// the language: what was chosen before, else the browser's (Danish for Danish browsers, English otherwise)
const TEXT = {
  da: { intro: "Pyrus' julekalender – med sommerferie og halloween. Spil med mus og tastatur – eller på telefon og tablet.",
    name: 'Dit navn (til highscorelisterne)', go: 'Klik for at starte', player: 'Spiller',
    small: 'Første gang hentes spillets billeder og lyde undervejs, så det kan tage et øjeblik.',
    loading: 'Henter spillet…', fonts: 'Henter skrifttyper…', lua: 'Starter Lua…', starting: 'Starter spillet…', failed: 'Noget gik galt: ' },
  en: { intro: "Pyrus' Christmas calendar – with summer holiday and Halloween. Play with mouse and keyboard – or on a phone or tablet.",
    name: 'Your name (for the highscore lists)', go: 'Click to start', player: 'Player',
    small: "The first time, the game's pictures and sounds are fetched as you go, so it can take a moment.",
    loading: 'Fetching the game…', fonts: 'Fetching fonts…', lua: 'Starting Lua…', starting: 'Starting the game…', failed: 'Something went wrong: ' },
};
function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
let LANG = store('an_lang') || ((navigator.languages || [navigator.language || '']).some(l => /^(da|nb|nn|no)\b/i.test(l)) ? 'da' : 'en');
if (!TEXT[LANG]) LANG = 'en';
function T(k) { return TEXT[LANG][k]; }
function applyLang() {
  document.documentElement.lang = LANG;
  for (const el of document.querySelectorAll('[data-t]')) el.textContent = T(el.dataset.t);
  const nm = document.getElementById('name');
  if (nm) nm.placeholder = T('player');
  for (const b of document.querySelectorAll('#langs button')) b.classList.toggle('on', b.dataset.lang === LANG);
}
for (const b of document.querySelectorAll('#langs button')) {
  b.addEventListener('click', e => { e.stopPropagation(); LANG = b.dataset.lang; store('an_lang', LANG); applyLang(); });
}
applyLang();

function status(t) { if (statusEl) statusEl.textContent = t; }

// ---------------------------------------------------------------------------
// pictures
// ---------------------------------------------------------------------------
const imgs = new Map();
function img(path) {
  let e = imgs.get(path);
  if (!e) {
    e = { ok: false, el: new Image(), tints: new Map() };
    e.el.decoding = 'async';
    e.el.onload = () => { e.ok = true; };
    e.el.onerror = () => { e.bad = true; };
    if (manifest.images[path]) e.el.src = GAME + 'content/materials/' + path;
    else e.bad = true;
    imgs.set(path, e);
  }
  return e;
}
// a picture in another colour (GMod multiplies the picture by the draw colour)
function tinted(e, r, g, b) {
  const key = (r << 16) | (g << 8) | b;
  let c = e.tints.get(key);
  if (!c) {
    const im = e.el;
    c = document.createElement('canvas');
    c.width = im.naturalWidth; c.height = im.naturalHeight;
    const x = c.getContext('2d');
    x.drawImage(im, 0, 0);
    x.globalCompositeOperation = 'multiply';
    x.fillStyle = `rgb(${r},${g},${b})`;
    x.fillRect(0, 0, c.width, c.height);
    x.globalCompositeOperation = 'destination-in';
    x.drawImage(im, 0, 0);
    if (e.tints.size > 24) e.tints.clear();
    e.tints.set(key, c);
  }
  return c;
}

// ---------------------------------------------------------------------------
// fonts
// ---------------------------------------------------------------------------
const FONT_FILES = {
  'Spumoni LP': 'spumoni.ttf',
  'Nunito ExtraBold': 'Nunito-ExtraBold.ttf',
  'Nunito Black': 'Nunito-Black.ttf',
};
const fonts = new Map();
async function loadFonts() {
  const all = [];
  for (const [fam, file] of Object.entries(FONT_FILES)) {
    const f = new FontFace(fam, `url(${GAME}content/resource/fonts/${file})`);
    all.push(f.load().then(ff => document.fonts.add(ff)).catch(() => console.warn('font', fam)));
  }
  await Promise.all(all);
}
function defFont(name, face, size, weight) {
  const css = `${size}px "${face}"`;
  ctx.font = css;
  const m = ctx.measureText('ÅÆØgjpqy');
  const asc = Math.round(m.fontBoundingBoxAscent ?? size * 0.9);
  const desc = Math.round(m.fontBoundingBoxDescent ?? size * 0.25);
  fonts.set(name, { css, asc, h: asc + desc });
}

// ---------------------------------------------------------------------------
// sound (Web Audio)
// ---------------------------------------------------------------------------
let actx = null;
const buffers = new Map();     // url -> Promise<AudioBuffer>
const chans = new Map();
let nextSnd = 1;
const soundEvents = [];        // delivered to Lua at the start of a frame
function audio() {
  if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
  return actx;
}
function loadBuffer(url) {
  let p = buffers.get(url);
  if (!p) {
    p = fetch(url).then(r => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); })
      .then(b => audio().decodeAudioData(b));
    buffers.set(url, p);
  }
  return p;
}
function sndOpen(path, flags) {
  const id = nextSnd++;
  const ch = { id, buffer: null, gain: null, src: null, vol: 1, loop: false, rate: 1, offset: 0, startedAt: 0, playing: false, paused: false };
  chans.set(id, ch);
  loadBuffer(GAME + 'content/' + path).then(buf => {
    ch.buffer = buf;
    ch.autoplay = !/noplay/.test(flags);   // GMod plays at once unless asked not to
    soundEvents.push([id, true]);
  }).catch(() => { chans.delete(id); soundEvents.push([id, false]); });
  return id;
}
function chTime(ch) {
  if (!ch.playing) return ch.offset;
  const t = ch.offset + (audio().currentTime - ch.startedAt) * ch.rate;
  return ch.loop && ch.buffer ? t % ch.buffer.duration : Math.min(t, ch.buffer ? ch.buffer.duration : t);
}
function chStop(ch, keepOffset) {
  if (ch.src) { ch.src.onended = null; try { ch.src.stop(); } catch (e) {} ch.src.disconnect(); ch.src = null; }
  if (keepOffset) ch.offset = chTime(ch);
  ch.playing = false;
}
function chPlay(ch) {
  if (!ch.buffer) return;
  const a = audio();
  if (ch.playing) chStop(ch, true);
  if (!ch.gain) { ch.gain = a.createGain(); ch.gain.connect(a.destination); }
  ch.gain.gain.value = ch.vol;
  const s = a.createBufferSource();
  s.buffer = ch.buffer; s.loop = ch.loop; s.playbackRate.value = ch.rate;
  s.connect(ch.gain);
  if (ch.offset >= ch.buffer.duration) ch.offset = 0;
  s.start(0, ch.offset);
  s.onended = () => { if (ch.src === s) { ch.playing = false; ch.offset = 0; ch.src = null; } };
  ch.src = s; ch.startedAt = a.currentTime; ch.playing = true;
}
function snd(id, op, v) {
  const ch = chans.get(id);
  if (!ch) return op === 'state' ? 0 : null;
  switch (op) {
    case 'play': chPlay(ch); break;
    case 'pause': chStop(ch, true); break;
    case 'stop': chStop(ch, false); if (ch.gain) ch.gain.disconnect(); chans.delete(id); break;
    case 'volume': ch.vol = v; if (ch.gain) ch.gain.gain.value = v; break;
    case 'getvolume': return ch.vol;
    case 'loop': ch.loop = !!v; if (ch.src) ch.src.loop = ch.loop; break;
    case 'rate': ch.rate = v; if (ch.src) ch.src.playbackRate.value = v; break;
    case 'time': { const was = ch.playing; chStop(ch, false); ch.offset = v; if (was) chPlay(ch); break; }
    case 'gettime': return chTime(ch);
    case 'length': return ch.buffer ? ch.buffer.duration : 0;
    case 'state': return ch.playing ? 1 : 0;
  }
  return null;
}

// ---------------------------------------------------------------------------
// saving: GMod's data folder lives in the browser
// ---------------------------------------------------------------------------
const STORE = 'gmdata:';
function globRe(pat) {
  return new RegExp('^' + pat.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '[^/]*').replace(/\?/g, '.') + '$', 'i');
}
function fileFind(pat) {
  const re = globRe(pat.toLowerCase());
  const out = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k.startsWith(STORE)) { const p = k.slice(STORE.length); if (re.test(p)) out.push(p.split('/').pop()); }
  }
  return out.sort().join(SEP);
}
function luaFind(pat) {
  const re = globRe(pat);
  return Object.keys(luaFiles).filter(p => re.test(p)).map(p => p.split('/').pop()).sort().join(SEP);
}

// ---------------------------------------------------------------------------
// keys and mouse
// ---------------------------------------------------------------------------
const KEYNAMES = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  'PAD_0', 'PAD_1', 'PAD_2', 'PAD_3', 'PAD_4', 'PAD_5', 'PAD_6', 'PAD_7', 'PAD_8', 'PAD_9',
  'PAD_DIVIDE', 'PAD_MULTIPLY', 'PAD_MINUS', 'PAD_PLUS', 'PAD_ENTER', 'PAD_DECIMAL',
  'LBRACKET', 'RBRACKET', 'SEMICOLON', 'APOSTROPHE', 'BACKQUOTE', 'COMMA', 'PERIOD', 'SLASH', 'BACKSLASH', 'MINUS', 'EQUAL',
  'ENTER', 'SPACE', 'BACKSPACE', 'TAB', 'CAPSLOCK', 'NUMLOCK', 'ESCAPE', 'SCROLLLOCK', 'INSERT', 'DELETE', 'HOME', 'END',
  'PAGEUP', 'PAGEDOWN', 'BREAK', 'LSHIFT', 'RSHIFT', 'LALT', 'RALT', 'LCONTROL', 'RCONTROL', 'LWIN', 'RWIN', 'APP',
  'UP', 'LEFT', 'DOWN', 'RIGHT', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'];
const KEY = {};
KEYNAMES.forEach((n, i) => { KEY[n] = i + 1; });
const CODES = {
  Enter: 'ENTER', Space: 'SPACE', Backspace: 'BACKSPACE', Tab: 'TAB', Escape: 'ESCAPE', Delete: 'DELETE',
  ShiftLeft: 'LSHIFT', ShiftRight: 'RSHIFT', ControlLeft: 'LCONTROL', ControlRight: 'RCONTROL', AltLeft: 'LALT', AltRight: 'RALT',
  ArrowUp: 'UP', ArrowDown: 'DOWN', ArrowLeft: 'LEFT', ArrowRight: 'RIGHT', Home: 'HOME', End: 'END', PageUp: 'PAGEUP', PageDown: 'PAGEDOWN',
  NumpadEnter: 'PAD_ENTER', NumpadAdd: 'PAD_PLUS', NumpadSubtract: 'PAD_MINUS', NumpadMultiply: 'PAD_MULTIPLY', NumpadDivide: 'PAD_DIVIDE', NumpadDecimal: 'PAD_DECIMAL',
  Comma: 'COMMA', Period: 'PERIOD', Minus: 'MINUS', Equal: 'EQUAL', Slash: 'SLASH', Backslash: 'BACKSLASH', Semicolon: 'SEMICOLON', Quote: 'APOSTROPHE', Backquote: 'BACKQUOTE', BracketLeft: 'LBRACKET', BracketRight: 'RBRACKET',
};
function keyOf(e) {
  const c = e.code;
  let n = CODES[c];
  if (!n && /^Key[A-Z]$/.test(c)) n = c.slice(3);
  else if (!n && /^Digit\d$/.test(c)) n = c.slice(5);
  else if (!n && /^Numpad\d$/.test(c)) n = 'PAD_' + c.slice(6);
  else if (!n && /^F\d+$/.test(c)) n = c;
  return n ? KEY[n] : 0;
}
let mx = 0, my = 0;
const mouseQ = [];
let mouseFlush = () => {};
const held = new Set();
function hookInput() {
  const keyFn = lua.global.get('WEB_KEY');
  const mouseFn = lua.global.get('WEB_MOUSE');
  const wheelFn = lua.global.get('WEB_WHEEL');
  window.addEventListener('keydown', e => {
    const k = keyOf(e);
    if (!k) return;
    if (k !== KEY.F11 && k !== KEY.F12 && k !== KEY.F5) e.preventDefault();
    held.add(k); keyFn(k, true);
  });
  window.addEventListener('keyup', e => { const k = keyOf(e); if (!k) return; held.delete(k); keyFn(k, false); });
  window.addEventListener('blur', () => { for (const k of held) keyFn(k, false); held.clear(); });
  const pos = e => { const r = canvas.getBoundingClientRect(); mx = (e.clientX - r.left) * canvas.width / r.width; my = (e.clientY - r.top) * canvas.height / r.height; };
  canvas.addEventListener('pointermove', pos);
  // presses wait until a frame has been drawn with the pointer where it is (a tap moves and
  // presses at once, and the game finds what is under the pointer while drawing)
  canvas.addEventListener('pointerdown', e => { pos(e); canvas.setPointerCapture(e.pointerId); mouseQ.push({ code: e.button === 2 ? 108 : 107, down: true, x: mx, y: my, seen: false }); });
  canvas.addEventListener('pointerup', e => { pos(e); mouseQ.push({ code: e.button === 2 ? 108 : 107, down: false, x: mx, y: my, seen: false }); });
  mouseFlush = () => {
    while (mouseQ.length && mouseQ[0].seen) { const m = mouseQ.shift(); mouseFn(m.code, m.down); if (mouseQ.length && !mouseQ[0].seen) break; }
  };
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  canvas.addEventListener('wheel', e => { e.preventDefault(); wheelFn(e.deltaY < 0 ? 1 : -1); }, { passive: false });
}

// ---------------------------------------------------------------------------
// drawing one frame from the commands gmod.lua collected
// ---------------------------------------------------------------------------
let M = [1, 0, 0, 1, 0, 0];
let clipped = false;
function rgba(r, g, b, a) { return `rgba(${r},${g},${b},${a / 255})`; }
function setM() { ctx.setTransform(M[0], M[1], M[2], M[3], M[4], M[5]); }
function texDraw(path, x, y, w, h, r, g, b, a, u0, v0, u1, v1) {
  if (a <= 0 || w === 0 || h === 0) return;
  if (path === '') { ctx.globalAlpha = 1; ctx.fillStyle = rgba(r, g, b, a); setM(); ctx.fillRect(x, y, w, h); return; }
  const e = img(path);
  if (!e.ok) return;
  const im = (r !== 255 || g !== 255 || b !== 255) ? tinted(e, r, g, b) : e.el;
  const iw = e.el.naturalWidth, ih = e.el.naturalHeight;
  let sx = Math.min(u0, u1) * iw, sy = Math.min(v0, v1) * ih;
  let sw = Math.abs(u1 - u0) * iw, sh = Math.abs(v1 - v0) * ih;
  if (sw < 0.01 || sh < 0.01) return;
  sx = Math.max(0, sx); sy = Math.max(0, sy);
  sw = Math.min(sw, iw - sx); sh = Math.min(sh, ih - sy);
  ctx.globalAlpha = a / 255;
  setM();
  const fx = u1 < u0, fy = v1 < v0;
  if (fx || fy) {
    ctx.translate(x + (fx ? w : 0), y + (fy ? h : 0));
    ctx.scale(fx ? -1 : 1, fy ? -1 : 1);
    ctx.drawImage(im, sx, sy, sw, sh, 0, 0, w, h);
  } else ctx.drawImage(im, sx, sy, sw, sh, x, y, w, h);
}
function draw(cmds) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  M = [1, 0, 0, 1, 0, 0];
  if (!cmds) return;
  const t = cmds.split(SEP);
  const n = t.length;
  let i = 0;
  const N = () => +t[i++];
  while (i < n) {
    const op = t[i++];
    switch (op) {
      case 'R': {
        const x = N(), y = N(), w = N(), h = N(), r = N(), g = N(), b = N(), a = N();
        if (a > 0) { ctx.globalAlpha = 1; ctx.fillStyle = rgba(r, g, b, a); setM(); ctx.fillRect(x, y, w, h); }
        break;
      }
      case 'T': {
        const p = t[i++];
        texDraw(p, N(), N(), N(), N(), N(), N(), N(), N(), N(), N(), N(), N());
        break;
      }
      case 'O': {
        const p = t[i++];
        const x = N(), y = N(), w = N(), h = N(), r = N(), g = N(), b = N(), a = N(), rot = N();
        if (a <= 0) break;
        setM();
        ctx.translate(x, y);
        ctx.rotate(-rot * Math.PI / 180);
        ctx.globalAlpha = a / 255;
        if (p === '') { ctx.fillStyle = rgba(r, g, b, a); ctx.globalAlpha = 1; ctx.fillRect(-w / 2, -h / 2, w, h); }
        else {
          const e = img(p);
          if (e.ok) ctx.drawImage((r !== 255 || g !== 255 || b !== 255) ? tinted(e, r, g, b) : e.el, -w / 2, -h / 2, w, h);
        }
        break;
      }
      case 'L': {
        const x1 = N(), y1 = N(), x2 = N(), y2 = N(), r = N(), g = N(), b = N(), a = N();
        ctx.globalAlpha = 1; ctx.strokeStyle = rgba(r, g, b, a); ctx.lineWidth = 1; setM();
        ctx.beginPath(); ctx.moveTo(x1 + 0.5, y1 + 0.5); ctx.lineTo(x2 + 0.5, y2 + 0.5); ctx.stroke();
        break;
      }
      case 'P': {
        const p = t[i++];
        const r = N(), g = N(), b = N(), a = N(), cnt = N();
        const v = [];
        for (let k = 0; k < cnt; k++) v.push([N(), N(), N(), N()]);
        if (a <= 0 || cnt < 3) break;
        setM();
        ctx.beginPath();
        ctx.moveTo(v[0][0], v[0][1]);
        for (let k = 1; k < cnt; k++) ctx.lineTo(v[k][0], v[k][1]);
        ctx.closePath();
        if (p === '') { ctx.globalAlpha = 1; ctx.fillStyle = rgba(r, g, b, a); ctx.fill(); break; }
        const e = img(p);
        if (!e.ok) break;
        // the picture mapped by the first three corners' u, v
        const iw = e.el.naturalWidth, ih = e.el.naturalHeight;
        const [x0, y0, s0, t0] = v[0], [x1, y1, s1, t1] = v[1], [x2, y2, s2, t2] = v[2];
        const U0 = s0 * iw, V0 = t0 * ih, U1 = s1 * iw, V1 = t1 * ih, U2 = s2 * iw, V2 = t2 * ih;
        const d = (U1 - U0) * (V2 - V0) - (U2 - U0) * (V1 - V0);
        if (Math.abs(d) < 1e-9) { ctx.globalAlpha = 1; ctx.fillStyle = rgba(r, g, b, a); ctx.fill(); break; }
        const A = ((x1 - x0) * (V2 - V0) - (x2 - x0) * (V1 - V0)) / d;
        const C = ((x2 - x0) * (U1 - U0) - (x1 - x0) * (U2 - U0)) / d;
        const B = ((y1 - y0) * (V2 - V0) - (y2 - y0) * (V1 - V0)) / d;
        const D = ((y2 - y0) * (U1 - U0) - (y1 - y0) * (U2 - U0)) / d;
        const E = x0 - A * U0 - C * V0, F = y0 - B * U0 - D * V0;
        ctx.save();
        ctx.clip();
        ctx.transform(A, B, C, D, E, F);
        ctx.globalAlpha = a / 255;
        ctx.drawImage((r !== 255 || g !== 255 || b !== 255) ? tinted(e, r, g, b) : e.el, 0, 0);
        ctx.restore();
        break;
      }
      case 'X': {
        const f = fonts.get(t[i++]);
        const x = N(), y = N(), r = N(), g = N(), b = N(), a = N();
        const s = t[i++];
        if (!f || a <= 0) break;
        ctx.globalAlpha = 1; ctx.font = f.css; ctx.fillStyle = rgba(r, g, b, a); ctx.textBaseline = 'alphabetic'; setM();
        ctx.fillText(s, x, y + f.asc);
        break;
      }
      case 'B': {
        const rad = N(), x = N(), y = N(), w = N(), h = N(), r = N(), g = N(), b = N(), a = N();
        const tl = N(), tr = N(), bl = N(), br = N();
        if (a <= 0) break;
        const rr = Math.max(0, Math.min(rad, w / 2, h / 2));
        ctx.globalAlpha = 1; ctx.fillStyle = rgba(r, g, b, a); setM();
        ctx.beginPath();
        ctx.roundRect(x, y, w, h, [tl ? rr : 0, tr ? rr : 0, br ? rr : 0, bl ? rr : 0]);
        ctx.fill();
        break;
      }
      case 'S': {
        const x1 = N(), y1 = N(), x2 = N(), y2 = N(), on = N();
        if (clipped) { ctx.restore(); clipped = false; }
        if (on) {
          ctx.save(); clipped = true;
          ctx.setTransform(1, 0, 0, 1, 0, 0);
          ctx.beginPath(); ctx.rect(x1, y1, x2 - x1, y2 - y1); ctx.clip();
        }
        break;
      }
      case 'M': M = [N(), N(), N(), N(), N(), N()]; break;
      case 'm': M = [1, 0, 0, 1, 0, 0]; break;
      default:
        console.warn('unknown draw command', op, i); i = n;
    }
  }
  if (clipped) { ctx.restore(); clipped = false; }
}

// ---------------------------------------------------------------------------
// starting
// ---------------------------------------------------------------------------
function size() {
  const dpr = Math.min(window.devicePixelRatio || 1, matchMedia('(pointer: coarse)').matches ? 1.5 : 2);
  const w = Math.max(320, Math.round(window.innerWidth * dpr));
  const h = Math.max(240, Math.round(window.innerHeight * dpr));
  if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
  return [w, h];
}

async function boot() {
  status(T('loading'));
  const [man, files] = await Promise.all([
    fetch(GAME + 'manifest.json', { cache: 'no-cache' }).then(r => r.json()),
    fetch(GAME + 'lua.json', { cache: 'no-cache' }).then(r => r.json()),
  ]);
  manifest = man; luaFiles = files;
  status(T('fonts'));
  await loadFonts();
  status(T('lua'));
  lua = await Lua.create({ customWasmUri: 'runtime/liblua5.1.wasm' });
  const G = lua.global;
  G.set('JS_log', (kind, s) => (kind === 'error' ? console.error : console.log)('[lua]', s));
  G.set('JS_luasrc', p => luaFiles[p] ?? null);
  G.set('JS_luaexists', p => p in luaFiles);
  G.set('JS_luafind', p => luaFind(p));
  G.set('JS_fileread', p => localStorage.getItem(STORE + p.toLowerCase()));
  G.set('JS_filewrite', (p, s) => { try { localStorage.setItem(STORE + p.toLowerCase(), s); } catch (e) { console.error('save failed', e); } });
  G.set('JS_filedelete', p => localStorage.removeItem(STORE + p.toLowerCase()));
  G.set('JS_filefind', p => fileFind(p));
  G.set('JS_imgsize', p => { const s = manifest.images[p]; return s ? s[0] * 65536 + s[1] : 0; });
  G.set('JS_font', (name, face, sz, weight) => defFont(name, face, sz, weight));
  G.set('JS_textsize', (name, s) => {
    const f = fonts.get(name);
    if (!f) return 0;
    ctx.font = f.css;
    return Math.ceil(ctx.measureText(s).width) * 65536 + f.h;
  });
  G.set('JS_sndopen', (p, flags) => sndOpen(p, flags));
  G.set('JS_snd', (id, op, v) => snd(id, op, v));
  G.set('JS_name', () => localStorage.getItem('an_name') || T('player'));
  G.set('JS_openurl', u => window.open(u, '_blank', 'noopener'));
  G.set('JS_quit', () => location.reload());
  lua.doStringSync(GMOD_LUA);
  window.GMLUA = lua;
  const [w, h] = size();
  status(T('starting'));
  lua.global.get('WEB_START')(w, h);
  lua.global.get('WEB_SETLANG')(LANG);
  hookInput();
  run();
}

function run() {
  const frameFn = lua.global.get('WEB_FRAME');
  const resizeFn = lua.global.get('WEB_RESIZE');
  const soundFn = lua.global.get('WEB_SOUND');
  const stateFn = lua.global.get('WEB_STATE');
  let gameState = '', lang = 'da';
  const touch = setupTouch({ keyFn: lua.global.get('WEB_KEY'), state: () => gameState, lang: () => lang });
  const pad = setupGamepad({
    press: touch.press, state: () => gameState, setHidden: touch.setHidden,
    pointer: {
      get: () => ({ x: mx, y: my, w: canvas.width, h: canvas.height, scale: canvas.width / canvas.getBoundingClientRect().width }),
      move: (x, y) => { mx = x; my = y; },
      click: down => mouseQ.push({ code: 107, down, x: mx, y: my, seen: false }),
      wheel: d => lua.global.get('WEB_WHEEL')(d),
    },
  });
  let frameNo = 0;
  let last = performance.now();
  function tick() {
    const now = performance.now();
    const ft = Math.min(0.25, Math.max(0.001, (now - last) / 1000));
    last = now;
    const [w, h] = size();
    resizeFn(w, h);
    while (soundEvents.length) {
      const [id, ok] = soundEvents.shift();
      const ch = chans.get(id);
      soundFn(id, ok);
      if (ok && ch && ch.autoplay && !ch.playing) chPlay(ch);
    }
    try { pad.poll(ft); } catch (e) { console.error(e); }
    mouseFlush();
    // (while a press waits, the frame is drawn with the pointer where it was pressed)
    const q = mouseQ.find(m => !m.seen);
    let cmds = '';
    try { cmds = frameFn(now / 1000, ft, q ? q.x : mx, q ? q.y : my); } catch (e) { console.error(e); }
    for (const m of mouseQ) { if (!m.seen) { m.seen = true; break; } }
    draw(cmds);
    // every few frames: is a keyboard game on? (for the touch controls)
    if (++frameNo % 10 === 0) {
      try { const st = String(stateFn() || '|da').split('|'); gameState = st[0]; lang = st[1] || 'da'; if (TEXT[lang] && lang !== LANG) { LANG = lang; store('an_lang', LANG); } } catch (e) { }
      touch.update();
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

// the browser only lets a page play sound after a click, so the game starts with one
let started = false;
// starting: the button, or Enter in the name field (the rest of the page is just the page)
function start() {
  if (started) return;
  started = true;
  const name = document.getElementById('name');
  if (name && name.value.trim()) localStorage.setItem('an_name', name.value.trim().slice(0, 24));
  audio().resume();
  overlay.classList.add('busy');
  boot().then(() => overlay.remove()).catch(e => { console.error(e); started = false; overlay.classList.remove('busy'); status(T('failed') + e.message); });
}
document.getElementById('go').addEventListener('click', start);
document.getElementById('name')?.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); start(); } });
const nm = document.getElementById('name');
if (nm) nm.value = localStorage.getItem('an_name') || '';
