// Gamepads (any standard controller, in desktop and phone browsers).
// In the keyboard games: the left stick or d-pad moves, A B X Y are the game's buttons (the same
// ones as the touch buttons), Start is Enter. Two controllers in the Duel: one for each player.
// Everywhere else (menus and the mouse games): the left stick moves a pointer and A clicks;
// the right stick scrolls.
import { K, GAMES, MAP } from './touch.js';

const DEAD = 0.35;
// standard mapping: 0 A, 1 B, 2 X, 3 Y, 9 Start, 12 up, 13 down, 14 left, 15 right
const FACE = [0, 1, 2, 3];


// Started with the page: tells when a controller is found or unplugged, and on the start page
// A or Start presses the start button.
export function watchPads({ lang, onStartPage }) {
  // a short message when a controller is found or unplugged
  let toastEl = null, toastT = 0;
  function toast(text) {
    if (!toastEl) {
      toastEl = document.createElement('div');
      toastEl.style.cssText = 'position:fixed;z-index:30;left:50%;top:18px;transform:translate(-50%,-20px);opacity:0;transition:opacity .25s,transform .25s;' +
        'pointer-events:none;display:flex;align-items:center;gap:12px;padding:12px 20px 12px 14px;border-radius:16px;max-width:90vw;' +
        'background:rgba(40,8,10,.92);border:2px solid #ffd76a;color:#fff1cf;font:800 17px system-ui,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.5);';
      document.body.appendChild(toastEl);
    }
    toastEl.innerHTML = '<svg width="34" height="24" viewBox="0 0 34 24"><path d="M8 3h18c4 0 7 4 7 9l-1 6c-1 4-5 5-7 2l-3-4H12l-3 4c-2 3-6 2-7-2l-1-6c0-5 3-9 7-9z" fill="#ffd76a"/><g fill="#3a0608"><rect x="7" y="9" width="8" height="3" rx="1"/><rect x="9.5" y="6.5" width="3" height="8" rx="1"/><circle cx="24" cy="8" r="1.8"/><circle cx="27.5" cy="11.5" r="1.8"/></g></svg>';
    const t = document.createElement('span'); t.textContent = text; toastEl.appendChild(t);
    requestAnimationFrame(() => { toastEl.style.opacity = '1'; toastEl.style.transform = 'translate(-50%,0)'; });
    clearTimeout(toastT);
    toastT = setTimeout(() => { toastEl.style.opacity = '0'; toastEl.style.transform = 'translate(-50%,-20px)'; }, 3500);
  }
  const en = () => (lang ? lang() : 'da') === 'en';
  const nameOf = g => (g.id || '').replace(/\s*\(.*?\)\s*/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 40);
  window.addEventListener('gamepadconnected', e => {
    const n = [...navigator.getGamepads()].filter(Boolean).length;
    const who = n > 1 ? (en() ? ` – player ${n}` : ` – spiller ${n}`) : '';
    toast((en() ? 'Controller connected' : 'Controller tilsluttet') + who + (nameOf(e.gamepad) ? ': ' + nameOf(e.gamepad) : ''));
  });
  window.addEventListener('gamepaddisconnected', () => toast(en() ? 'Controller disconnected' : 'Controller frakoblet'));
  let was = false;
  (function loop() {
    const start = onStartPage();
    if (!start) return;
    const pads = navigator.getGamepads ? [...navigator.getGamepads()].filter(Boolean) : [];
    const down = pads.some(p => (p.buttons[0] && p.buttons[0].pressed) || (p.buttons[9] && p.buttons[9].pressed));
    if (down && !was) start();
    was = down;
    requestAnimationFrame(loop);
  })();
}

export function setupGamepad({ press, state, setHidden, pointer }) {
  let used = false;                 // has a gamepad been used (hides the touch controls)
  const held = new Map();           // per pad: the keys it holds
  let cur = null;                   // the pointer picture
  let lastMove = 0, aWas = false, wheelAt = 0;

  function hold(pi, code, on) {
    let h = held.get(pi);
    if (!h) { h = new Set(); held.set(pi, h); }
    if (on && !h.has(code)) { h.add(code); press(code, true); }
    if (!on && h.has(code)) { h.delete(code); press(code, false); }
  }
  function releasePad(pi) { const h = held.get(pi); if (h) for (const c of [...h]) hold(pi, c, false); }

  function cursor(show, x, y) {
    if (!cur) {
      cur = document.createElement('div');
      cur.style.cssText = 'position:fixed;z-index:9;left:0;top:0;width:28px;height:28px;pointer-events:none;display:none;' +
        'background:no-repeat url("data:image/svg+xml;utf8,<svg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 28 28%27><path d=%27M3 2 L3 23 L9 17 L13 26 L17 24 L13 15 L21 15 Z%27 fill=%27%23fff1cf%27 stroke=%27%233a0608%27 stroke-width=%272%27/></svg>");';
      document.body.appendChild(cur);
    }
    cur.style.display = show ? 'block' : 'none';
    if (show) cur.style.transform = `translate(${x - 3}px, ${y - 2}px)`;
  }
  window.addEventListener('mousemove', () => { if (performance.now() - lastMove > 300) cursor(false); });
  window.addEventListener('gamepaddisconnected', e => { releasePad(e.gamepad.index); if (![...navigator.getGamepads()].some(Boolean)) { setHidden(false); cursor(false); } });

  function axis(p, i) { const v = p.axes[i] || 0; return Math.abs(v) < DEAD ? 0 : v; }
  function btn(p, i) { const b = p.buttons[i]; return !!(b && (b.pressed || b.value > 0.5)); }

  // one frame
  function poll(dt) {
    const pads = (navigator.getGamepads ? [...navigator.getGamepads()] : []).filter(p => p && p.connected);
    if (!pads.length) return;
    const any = pads.some(p => p.buttons.some(b => b.pressed) || p.axes.some(a => Math.abs(a) > DEAD));
    if (any && !used) { used = true; setHidden(true); }
    if (any) setHidden(true);
    const s = state() || '';
    const m = s.match(/^(game|split):(\d+)$/);
    const game = m && GAMES[+m[2]];
    const keyGame = game && game.stick !== false;

    pads.forEach((p, n) => {
      // which player: in the Duel the first controller is player 1, the second player 2
      const who = m && m[1] === 'split' ? (n === 0 ? 'p1' : n === 1 ? 'p2' : null) : (n === 0 ? 'solo' : null);
      if (!who || !game) { releasePad(p.index); return; }
      const map = MAP[who];
      const ax = axis(p, 0), ay = axis(p, 1);
      const horiz = game.stick === 'h';
      if (keyGame) {
        hold(p.index, K[map.LEFT], btn(p, 14) || ax < 0);
        hold(p.index, K[map.RIGHT], btn(p, 15) || ax > 0);
        hold(p.index, K[map.UP], btn(p, 12) || (!horiz && ay < 0));
        hold(p.index, K[map.DOWN], btn(p, 13) || (!horiz && ay > 0));
      }
      // the game's buttons on A B X Y (in a mouse game A clicks, so they start at B)
      const btns = game.buttons || [];
      const faces = keyGame ? FACE : FACE.slice(1);
      btns.forEach(([, key], i) => { if (faces[i] !== undefined) hold(p.index, K[map[key]], btn(p, faces[i])); });
      if (map.ENTER) hold(p.index + 100, K[map.ENTER], btn(p, 9));
    });

    // the pointer: in the menus and the mouse games, with the first controller
    const p = pads[0];
    if (!keyGame) {
      const ax = axis(p, 0) || (btn(p, 15) ? 0.6 : btn(p, 14) ? -0.6 : 0);
      const ay = axis(p, 1) || (btn(p, 13) ? 0.6 : btn(p, 12) ? -0.6 : 0);
      const { x, y, w, h, scale } = pointer.get();
      if (ax || ay) {
        const speed = 1.1 * Math.max(w, h) * dt;   // the whole screen in about a second at full tilt
        const curve = v => Math.sign(v) * Math.pow(Math.abs(v), 1.6);
        const nx = Math.max(0, Math.min(w - 1, x + curve(ax) * speed));
        const ny = Math.max(0, Math.min(h - 1, y + curve(ay) * speed));
        pointer.move(nx, ny);
        lastMove = performance.now();
      }
      const a = btn(p, 0);
      if (a !== aWas) { pointer.click(a); lastMove = performance.now(); }
      aWas = a;
      const ry = axis(p, 3);
      if (ry && performance.now() > wheelAt) { pointer.wheel(ry < 0 ? 1 : -1); wheelAt = performance.now() + 140; }
      const q = pointer.get();
      if (performance.now() - lastMove < 4000) cursor(true, q.x / q.scale, q.y / q.scale); else cursor(false);
    } else {
      if (aWas) { pointer.click(false); aWas = false; }
      cursor(false);
    }
  }
  return { poll };
}
