// Moving saves between devices – there is no server, so the data travels itself:
//  * a QR code (a link with the player's progress packed into it) to carry on on a phone
//  * a file with everything saved on this device (all players and the highscores), and loading one
import qrcode from 'qrcode-generator';

const DATA = 'gmdata:';
const PDIR = DATA + 'alletidersnisse/players/';
const HS = DATA + 'alletidersnisse/highscores.json';

// packing: JSON → deflate → base64url (and back)
async function pack(obj) {
  const bytes = new TextEncoder().encode(JSON.stringify(obj));
  const zipped = new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('deflate-raw'))).arrayBuffer());
  let bin = '';
  for (const b of zipped) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
async function unpack(s) {
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
  const bytes = Uint8Array.from(bin, c => c.charCodeAt(0));
  const text = await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).text();
  return JSON.parse(text);
}

function readJSON(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } }

// the highscore lists, merged: same entry once, best first, ten per list (like the game)
function mergeHS(into, add) {
  for (const [key, door] of Object.entries(add || {})) {
    if (!door || !Array.isArray(door.list)) continue;
    const cur = into[key] || { list: [] };
    if (door.lower !== undefined) cur.lower = door.lower;
    const seen = new Set(cur.list.map(e => e.id || `${e.sid}:${e.v}:${e.t}`));
    for (const e of door.list) {
      const id = e.id || `${e.sid}:${e.v}:${e.t}`;
      if (!seen.has(id)) { seen.add(id); cur.list.push(e); }
    }
    cur.list.sort((a, b) => a.v === b.v ? (a.t || 0) - (b.t || 0) : (cur.lower ? a.v - b.v : b.v - a.v));
    cur.list = cur.list.slice(0, 10);
    into[key] = cur;
  }
  return into;
}

// what goes along: one player (by its save key), or everything
function collect(onlyKey) {
  const out = { app: 'pyrus', v: 1, players: {}, hs: {}, other: {} };
  const hs = readJSON(HS) || {};
  let sid = null;
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (!k || !k.startsWith(DATA)) continue;
    if (k.startsWith(PDIR)) {
      if (onlyKey && k !== onlyKey) continue;
      out.players[k.slice(PDIR.length)] = readJSON(k);
    } else if (k !== HS && !onlyKey) out.other[k.slice(DATA.length)] = localStorage.getItem(k);
  }
  if (onlyKey) sid = onlyKey.slice(PDIR.length).replace(/\.json$/, '');
  for (const [key, door] of Object.entries(hs)) {
    if (!door || !Array.isArray(door.list)) continue;
    const list = sid ? door.list.filter(e => e.sid === sid) : door.list;
    if (list.length) out.hs[key] = { lower: door.lower, list };
  }
  return out;
}

function apply(data) {
  let n = 0;
  for (const [file, rec] of Object.entries(data.players || {})) {
    if (!/^\d+\.json$/.test(file) || !rec) continue;
    localStorage.setItem(PDIR + file, JSON.stringify(rec));
    n++;
  }
  // settings and the rest only from a full file, and only what isn't set here already
  for (const [k, v] of Object.entries(data.other || {})) {
    if (localStorage.getItem(DATA + k) === null) localStorage.setItem(DATA + k, v);
  }
  localStorage.setItem(HS, JSON.stringify(mergeHS(readJSON(HS) || {}, data.hs)));
  return n;
}

function doors(rec) { return rec && rec.prog && rec.prog.doors ? Object.values(rec.prog.doors).filter(d => d && d.done).length : 0; }

const CSS = `
#tr-row { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
#tr-row button { cursor: pointer; font: 800 14px system-ui, sans-serif; color: #fff1cf; background: rgba(0,0,0,.25); border: 2px solid rgba(255,215,106,.45); border-radius: 20px; padding: 7px 14px; }
#tr-row button:hover { border-color: #ffd76a; }
#tr-modal { position: fixed; inset: 0; z-index: 40; display: flex; align-items: center; justify-content: center; background: rgba(10,2,4,.75); padding: 16px; box-sizing: border-box; }
#tr-modal .box { background: #fff8e8; color: #3a1a08; border-radius: 22px; padding: 22px 24px; max-width: 420px; width: 100%; text-align: center; font: 700 16px/1.4 system-ui, sans-serif; box-shadow: 0 10px 40px rgba(0,0,0,.5); }
#tr-modal h2 { margin: 0 0 6px; font: 400 30px Georgia, serif; color: #8a1a20; }
#tr-modal .qr { margin: 14px auto; width: min(300px, 70vw); aspect-ratio: 1; }
#tr-modal .qr svg { width: 100%; height: 100%; display: block; }
#tr-modal .small { font-size: 13px; opacity: .7; }
#tr-modal button { cursor: pointer; margin-top: 12px; font: 800 16px system-ui, sans-serif; color: #fff; background: #c8102e; border: 0; border-radius: 30px; padding: 10px 26px; }
`;

export function setupTransfer({ T, lang, currentKey, refresh, setName }) {
  const st = document.createElement('style');
  st.textContent = CSS;
  document.head.appendChild(st);

  function modal(html) {
    const m = document.createElement('div');
    m.id = 'tr-modal';
    m.innerHTML = `<div class="box">${html}<br><button>${T('close')}</button></div>`;
    m.addEventListener('click', e => { if (e.target === m || e.target.tagName === 'BUTTON') m.remove(); });
    document.body.appendChild(m);
    return m;
  }
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  // the QR code for the chosen player
  async function showQR() {
    const key = currentKey();
    const rec = key && readJSON(key);
    if (!rec) { modal(`<h2>${T('qrTitle')}</h2><p>${T('qrNone')}</p>`); return; }
    const data = await pack(collect(key));
    const url = location.origin + location.pathname + '#load=' + data;
    let svg = '';
    try {
      const q = qrcode(0, 'L');
      q.addData(url);
      q.make();
      svg = q.createSvgTag({ cellSize: 4, margin: 2, scalable: true });
    } catch (e) { svg = ''; }
    if (!svg) { modal(`<h2>${T('qrTitle')}</h2><p>${T('qrBig')}</p>`); return; }
    modal(`<h2>${T('qrTitle')}</h2><div>${esc(rec.name)} · ${doors(rec)} ${T(doors(rec) === 1 ? 'door' : 'doors')}</div>
      <div class="qr">${svg}</div><div>${T('qrHow')}</div><div class="small">${T('qrNote')}</div>`);
  }

  // a file with everything
  function exportFile() {
    const blob = new Blob([JSON.stringify(collect(null), null, 1)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'pyrus-gem-' + new Date().toISOString().slice(0, 10) + '.json';
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }
  function importFile() {
    const inp = document.createElement('input');
    inp.type = 'file'; inp.accept = '.json,application/json';
    inp.addEventListener('change', async () => {
      const f = inp.files && inp.files[0];
      if (!f) return;
      try {
        const data = JSON.parse(await f.text());
        if (data.app !== 'pyrus') throw new Error('not a save');
        const names = Object.values(data.players || {}).map(r => r && r.name).filter(Boolean);
        if (!confirm(T('loadAsk').replace('%s', names.join(', ') || '–'))) return;
        const n = apply(data);
        refresh();
        modal(`<h2>${T('loaded')}</h2><p>${T('loadedN').replace('%d', n)}</p>`);
      } catch (e) { modal(`<h2>${T('loadFail')}</h2><p class="small">${esc(e.message)}</p>`); }
    });
    inp.click();
  }

  // the buttons under the player list
  const row = document.createElement('div');
  row.id = 'tr-row';
  const mk = (k, fn) => { const b = document.createElement('button'); b.dataset.tr = k; b.addEventListener('click', e => { e.stopPropagation(); fn(); }); row.appendChild(b); return b; };
  mk('qrBtn', showQR); mk('exportBtn', exportFile); mk('importBtn', importFile);
  const go = document.getElementById('go');
  go.parentNode.insertBefore(row, go.nextSibling);
  function texts() { for (const b of row.querySelectorAll('button')) b.textContent = T(b.dataset.tr); }
  texts();

  // opened from a QR code: take the player over
  (async () => {
    const m = location.hash.match(/^#load=([A-Za-z0-9_-]+)$/);
    if (!m) return;
    history.replaceState(null, '', location.pathname + location.search);
    try {
      const data = await unpack(m[1]);
      if (data.app !== 'pyrus') throw new Error('not a save');
      const rec = Object.values(data.players || {})[0];
      const name = rec && rec.name;
      const file = Object.keys(data.players || {})[0];
      const here = file && readJSON(PDIR + file);
      const ask = here ? T('qrReplace') : T('qrAsk');
      if (!confirm(ask.replace('%s', `${name || '?'} (${doors(rec)} ${T(doors(rec) === 1 ? 'door' : 'doors')})`))) return;
      apply(data);
      if (name) setName(name);
      refresh();
    } catch (e) { modal(`<h2>${T('loadFail')}</h2><p class="small">${esc(e.message)}</p>`); }
  })();

  return { texts };
}
