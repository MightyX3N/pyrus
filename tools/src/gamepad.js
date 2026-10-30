// Gamepads (any standard controller, in desktop and phone browsers).
// In the keyboard games: the left stick or d-pad moves, A B X Y are the game's buttons (the same
// ones as the touch buttons), Start is Enter. Two controllers in the Duel: one for each player.
// Everywhere else (menus and the mouse games): the left stick moves a pointer and A clicks;
// the right stick scrolls.
import { K, GAMES, MAP } from './touch.js';

const DEAD = 0.35;
// standard mapping: 0 A, 1 B, 2 X, 3 Y, 9 Start, 12 up, 13 down, 14 left, 15 right
const FACE = [0, 1, 2, 3];

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
