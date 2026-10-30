// Touch controls for phones and tablets. Tapping already works as the mouse; this adds, in the
// games played with the keyboard, a stick and the buttons that game uses (with their names), and
// in the Duel split screen one set for each player. They press the same keys the keyboard would.
// Also: a fullscreen button and a "turn your phone" message.

// The keys (Garry's Mod's numbers, as in gmod.lua)
export const K = {};
['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'].forEach((n, i) => { K[n] = i + 1; });
Object.assign(K, { PAD_0: 37, PAD_ENTER: 51, ENTER: 64, SPACE: 65, RSHIFT: 80, LCONTROL: 83, RCONTROL: 84, UP: 88, LEFT: 89, DOWN: 90, RIGHT: 91 });

// What each keyboard game uses: the stick (stick: 'h' = only left and right, for games where up and
// down are buttons like jump and duck; false = none), and buttons (label, key, label in English)
// keys are the game's own: UP/DOWN/LEFT/RIGHT, SPACE, CTRL, ENTER, E
export const GAMES = {
  1: { stick: 'h', buttons: [['Hop', 'UP', 'Jump'], ['Duk', 'DOWN', 'Duck']] },
  2: {},
  9: { buttons: [['Olie', 'SPACE', 'Oil']] },
  11: { stick: false, buttons: [['Drej', 'SPACE', 'Turn']] },
  12: { stick: 'h', buttons: [['Skyd', 'CTRL', 'Shoot'], ['Videre', 'SPACE', 'Next']] },
  14: {},
  16: {},
  19: { buttons: [['Skyd', 'CTRL', 'Shoot'], ['Teleport', 'SPACE', 'Teleport'], ['Videre', 'ENTER', 'Next']] },
  21: { stick: false, buttons: [['Drej', 'SPACE', 'Turn']] },
  101: { buttons: [['Surf!', 'SPACE', 'Surf!']] },
  102: { buttons: [['Læg på', 'SPACE', 'Add'], ['Server', 'CTRL', 'Serve']] },
  103: { buttons: [['Kast', 'SPACE', 'Cast']] },
  105: { buttons: [['Byg', 'SPACE', 'Build'], ['Skift', 'CTRL', 'Change'], ['Færdig', 'E', 'Done']] },
  201: { buttons: [['Skær', 'SPACE', 'Cut']] },
  202: {},
  203: { stick: 'h', buttons: [['Hop', 'UP', 'Jump'], ['Ring på', 'SPACE', 'Ring']] },
  204: { buttons: [['Lygte', 'SPACE', 'Lantern']] },
};
// which real keys a game key is for each player (single player, and the Duel's two players – like cl_split.lua)
export const MAP = {
  solo: { UP: 'UP', DOWN: 'DOWN', LEFT: 'LEFT', RIGHT: 'RIGHT', SPACE: 'SPACE', CTRL: 'LCONTROL', ENTER: 'ENTER', E: 'E' },
  p1: { UP: 'W', DOWN: 'S', LEFT: 'A', RIGHT: 'D', SPACE: 'SPACE', CTRL: 'LCONTROL', ENTER: 'SPACE', E: 'E' },
  p2: { UP: 'UP', DOWN: 'DOWN', LEFT: 'LEFT', RIGHT: 'RIGHT', SPACE: 'ENTER', CTRL: 'RCONTROL', ENTER: 'ENTER', E: 'RSHIFT' },
};

const CSS = `
.tc { position: fixed; z-index: 5; pointer-events: none; user-select: none; -webkit-user-select: none; -webkit-touch-callout: none; touch-action: none; }
.tc * { pointer-events: auto; touch-action: none; }
.tc-stick { position: absolute; width: clamp(110px, 36vh, 160px); height: clamp(110px, 36vh, 160px); border-radius: 50%; background: rgba(255,241,207,.16); border: 3px solid rgba(255,241,207,.45); box-sizing: border-box; }
.tc-stick.h { height: clamp(64px, 19vh, 84px); border-radius: 50px; width: clamp(150px, 46vh, 210px); }
.tc-stick.h .tc-knob { width: auto; height: 76%; aspect-ratio: 1; margin: 0; left: 50%; top: 12%; translate: -50% 0; }
.tc-knob { position: absolute; left: 50%; top: 50%; width: 42%; height: 42%; transform-origin: center; margin: -21% 0 0 -21%; border-radius: 50%; background: rgba(255,241,207,.6); box-shadow: 0 2px 8px rgba(0,0,0,.4); pointer-events: none; }
.tc-btns { position: absolute; display: flex; flex-wrap: wrap-reverse; gap: 12px; width: 220px; justify-content: flex-end; }
.tc-btn { opacity: .92; min-width: clamp(60px, 19vh, 84px); height: clamp(60px, 19vh, 84px); padding: 0 10px; border-radius: 42px; border: 3px solid rgba(255,215,106,.85); background: rgba(200,16,46,.55); color: #fff; font: 800 18px system-ui, sans-serif; display: flex; align-items: center; justify-content: center; box-sizing: border-box; text-shadow: 0 1px 2px rgba(0,0,0,.6); }
.tc-btn.on { background: rgba(255,215,106,.85); color: #3a0608; }
.tc-p { position: absolute; font: 800 13px system-ui, sans-serif; color: rgba(255,241,207,.8); }
#tc-fs { position: fixed; z-index: 6; left: 10px; top: 10px; width: 44px; height: 44px; border-radius: 12px; border: 2px solid rgba(255,241,207,.5); background: rgba(0,0,0,.35); color: #fff1cf; font: 700 22px system-ui; display: none; align-items: center; justify-content: center; touch-action: manipulation; }
#tc-rotate { position: fixed; inset: 0; z-index: 20; display: none; flex-direction: column; gap: 18px; align-items: center; justify-content: center; text-align: center; padding: 24px; box-sizing: border-box;
  background: radial-gradient(ellipse at 50% 35%, #8a1a20 0%, #4a0c10 60%, #1a0406 100%); color: #fff1cf; font: 700 20px/1.4 system-ui, sans-serif; }
#tc-rotate .ph { width: 60px; height: 100px; border: 5px solid #ffd76a; border-radius: 12px; animation: tcturn 2s ease-in-out infinite; }
@keyframes tcturn { 0%, 30% { transform: rotate(0deg); } 60%, 100% { transform: rotate(-90deg); } }
`;

export function setupTouch({ keyFn, state, lang }) {
  // phones: a long press must not open "look up / search / find in page", select text or zoom
  const isField = t => t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA');
  document.addEventListener('contextmenu', e => { if (!isField(e.target)) e.preventDefault(); });
  document.addEventListener('selectstart', e => { if (!isField(e.target)) e.preventDefault(); });
  document.addEventListener('touchstart', e => {
    if (!isField(e.target) && (e.target.closest?.('.tc') || e.target.id === 'screen')) e.preventDefault();
  }, { passive: false });
  document.addEventListener('gesturestart', e => e.preventDefault());
  document.addEventListener('dblclick', e => e.preventDefault());
  const isTouch = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
  const style = document.createElement('style');
  style.textContent = CSS;
  document.head.appendChild(style);

  // keys pressed by the controls (counted, so two controls on one key don't fight)
  const held = new Map();
  function press(code, down) {
    const n = (held.get(code) || 0) + (down ? 1 : -1);
    held.set(code, Math.max(0, n));
    if (down && n === 1) keyFn(code, true);
    if (!down && n <= 0) keyFn(code, false);
  }
  function releaseAll() { for (const [c, n] of held) if (n > 0) keyFn(c, false); held.clear(); }

  // fullscreen
  const fs = document.createElement('button');
  fs.id = 'tc-fs';
  fs.textContent = '⛶';
  fs.title = 'Fuld skærm';
  fs.addEventListener('click', async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else {
        await (document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen).call(document.documentElement);
        try { await screen.orientation.lock('landscape'); } catch (e) { }
      }
    } catch (e) { }
  });
  document.body.appendChild(fs);
  const canFs = !!(document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen);
  if (isTouch && canFs) fs.style.display = 'flex';

  // "turn your phone"
  const rot = document.createElement('div');
  rot.id = 'tc-rotate';
  rot.innerHTML = '<div class="ph"></div><div></div>';
  document.body.appendChild(rot);
  function checkRotate() {
    const upright = isTouch && window.innerHeight > window.innerWidth * 1.1;
    rot.querySelector('div:last-child').textContent = lang() === 'en' ? 'Turn your phone sideways to play' : 'Vend telefonen om på siden for at spille';
    rot.style.display = upright ? 'flex' : 'none';
    if (upright) releaseAll();
  }
  window.addEventListener('resize', checkRotate);
  checkRotate();

  let hidden = false;
  if (!isTouch) return { update() {}, press, setHidden() {} };

  // one set of controls: a stick (left) and the game's buttons (right), for one player
  function makeSet(who, game, side) {
    const map = MAP[who];
    const root = document.createElement('div');
    root.className = 'tc';
    root.style.inset = '0';
    const parts = [];
    // the stick
    if (game.stick !== false) {
      const st = document.createElement('div');
      st.className = 'tc-stick' + (game.stick === 'h' ? ' h' : '');
      const horiz = game.stick === 'h';
      const knob = document.createElement('div');
      knob.className = 'tc-knob';
      st.appendChild(knob);
      const dirs = { UP: false, DOWN: false, LEFT: false, RIGHT: false };
      let pid = null;
      const setDir = (d, on) => { if (dirs[d] !== on) { dirs[d] = on; press(K[map[d]], on); } };
      const move = e => {
        const r = st.getBoundingClientRect();
        let dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
        if (horiz) dy = 0;
        const max = (horiz ? r.width / 2 - r.height / 2 : r.width / 2), len = Math.hypot(dx, dy);
        if (len > max) { dx *= max / len; dy *= max / len; }
        knob.style.transform = `translate(${dx}px, ${dy}px)`;
        const dead = horiz ? max * 0.2 : max * 0.3;
        // eight ways: a direction counts when the stick leans that way enough
        const a = Math.atan2(dy, dx);
        const on = len > dead;
        setDir('RIGHT', on && Math.cos(a) > 0.38);
        setDir('LEFT', on && Math.cos(a) < -0.38);
        setDir('DOWN', on && Math.sin(a) > 0.38);
        setDir('UP', on && Math.sin(a) < -0.38);
      };
      const end = () => { pid = null; knob.style.transform = ''; for (const d in dirs) setDir(d, false); };
      st.addEventListener('pointerdown', e => { if (pid !== null) return; pid = e.pointerId; st.setPointerCapture(pid); move(e); e.preventDefault(); });
      st.addEventListener('pointermove', e => { if (e.pointerId === pid) move(e); });
      st.addEventListener('pointerup', e => { if (e.pointerId === pid) end(); });
      st.addEventListener('pointercancel', e => { if (e.pointerId === pid) end(); });
      st.addEventListener('lostpointercapture', e => { if (e.pointerId === pid) end(); });
      parts.push({ el: st, kind: 'stick', end });
      root.appendChild(st);
    }
    // the buttons
    const box = document.createElement('div');
    box.className = 'tc-btns';
    for (const [da, key, en] of game.buttons || []) {
      const b = document.createElement('div');
      b.className = 'tc-btn';
      b.textContent = lang() === 'en' ? en : da;
      const code = K[map[key]];
      const pids = new Set();
      const down = e => { e.preventDefault(); if (!pids.size) press(code, true); pids.add(e.pointerId); b.setPointerCapture(e.pointerId); b.classList.add('on'); };
      const up = e => { if (!pids.delete(e.pointerId)) return; if (!pids.size) { press(code, false); b.classList.remove('on'); } };
      b.addEventListener('pointerdown', down);
      b.addEventListener('pointerup', up);
      b.addEventListener('pointercancel', up);
      b.addEventListener('lostpointercapture', up);
      box.appendChild(b);
    }
    root.appendChild(box);
    // where: single player – stick bottom left, buttons bottom right; Duel – each player's corner
    const stick = root.querySelector('.tc-stick');
    if (side === 'solo') {
      if (stick) { stick.style.left = '28px'; stick.style.bottom = '28px'; }
      box.style.right = '24px'; box.style.bottom = '24px';
    } else if (side === 'left') {
      if (stick) { stick.style.left = '20px'; stick.style.bottom = '20px'; }
      box.style.left = stick ? 'calc(clamp(110px, 36vh, 160px) + 34px)' : '20px'; box.style.bottom = '20px'; box.style.justifyContent = 'flex-start'; box.style.width = '170px';
      const p = document.createElement('div'); p.className = 'tc-p'; p.textContent = lang() === 'en' ? 'Player 1' : 'Spiller 1';
      p.style.left = '24px'; p.style.bottom = 'calc(clamp(110px, 36vh, 160px) + 28px)'; root.appendChild(p);
    } else {
      if (stick) { stick.style.right = '20px'; stick.style.bottom = '20px'; }
      box.style.right = stick ? 'calc(clamp(110px, 36vh, 160px) + 34px)' : '20px'; box.style.bottom = '20px'; box.style.width = '170px';
      const p = document.createElement('div'); p.className = 'tc-p'; p.textContent = lang() === 'en' ? 'Player 2' : 'Spiller 2';
      p.style.right = '24px'; p.style.bottom = 'calc(clamp(110px, 36vh, 160px) + 28px)'; root.appendChild(p);
    }
    document.body.appendChild(root);
    return { remove() { for (const p of parts) if (p.end) p.end(); root.remove(); } };
  }

  // follow the game: build the controls when a keyboard game starts, remove them when it ends
  let current = '', sets = [];
  function setHidden(h) {
    if (h === hidden) return;
    hidden = h;
    for (const el of document.querySelectorAll('.tc')) el.style.display = h ? 'none' : '';
  }
  document.addEventListener('touchstart', () => setHidden(false), { passive: true });
  function update() {
    const s = state() || '';
    if (s === current) return;
    current = s;
    for (const set of sets) set.remove();
    sets = [];
    releaseAll();
    const m = s.match(/^(game|split):(\d+)$/);
    if (!m) return;
    const game = GAMES[+m[2]];
    if (!game) return;
    if (m[1] === 'game') sets.push(makeSet('solo', game, 'solo'));
    else { sets.push(makeSet('p1', game, 'left')); sets.push(makeSet('p2', game, 'right')); }
    if (hidden) for (const el of document.querySelectorAll('.tc')) el.style.display = 'none';
  }
  return { update, press, setHidden };
}
