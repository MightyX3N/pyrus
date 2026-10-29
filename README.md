# Alletiders Nisse – på nettet

A fan remake of Pyrus' *Alletiders Nisse* (originally a Garry's Mod gamemode), playable in the browser.

## How it works

The Garry's Mod gamemode in `game/` is **exactly the same folder** as in
`garrysmod/gamemodes/alletidersnisse` – nothing in it is changed for the website.
The website runs it through a translation layer:

- `runtime/liblua5.1.wasm` – a real Lua 5.1 (the gamemode's Lua files run in it)
- `tools/src/gmod.lua` – the Garry's Mod functions the gamemode uses (surface, draw, sound, input, file, net, vgui …), made on top of the browser
- `tools/src/main.js` – the browser side: canvas drawing, pictures, fonts, Web Audio, keys and mouse, saving in the browser (localStorage)

Single player, the same-keyboard Duel and split screen all work. Kapløb (several players on a server) does not.

## Updating the game

1. Copy the gamemode folder (`garrysmod/gamemodes/alletidersnisse`) over `game/` in this repository.
2. Push. The GitHub Action (`.github/workflows/pages.yml`) builds and publishes the site by itself.

## Changing the translation layer

Edit `tools/src/`. To try it locally:

```
cd tools && npm ci && npm run build && cd ..
pip install pillow && python tools/make_lists.py
python -m http.server
```

…and open http://localhost:8000.

## First-time setup on GitHub

Settings → Pages → Build and deployment → Source: **GitHub Actions**.

## The domain: pyrus.lol

At the domain registrar (DNS):

| Type | Name | Value |
|---|---|---|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| AAAA | @ | 2606:50c0:8000::153 |
| AAAA | @ | 2606:50c0:8001::153 |
| AAAA | @ | 2606:50c0:8002::153 |
| AAAA | @ | 2606:50c0:8003::153 |
| CNAME | www | YOUR-GITHUB-NAME.github.io |

On GitHub: first verify the domain (your profile Settings → Pages → Add a domain), then in this
repository Settings → Pages → Custom domain: `pyrus.lol`, and when it offers it, tick *Enforce HTTPS*.
(With the Actions workflow no CNAME file is needed.)
