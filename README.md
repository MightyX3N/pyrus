# Alletiders Nisse

**Play it at [pyrus.lol](https://pyrus.lol)**

A fan remake of *Alletiders Nisse*, the Pyrus Christmas calendar CD-ROM, built as a Garry's Mod
gamemode and playable straight in the browser.

Pyrus and Gyldenkål are back in the attic: open a door in the calendar every day in December,
play the day's game, earn pebernødder and decorate the tree with what you buy in Pyntekassen.
The seasons are open all year.

## What's in it

- **The Christmas calendar** – all 24 door games, remade from the original: Op og Hop,
  Bibliote-Kandis, Huskespil, Gåseflyvning, Kæmpe Kålkamp, Skubbespil, Kærlighedsflugten, Rumtur,
  Kriblekrable-ord, Pyntekassen and the rest, with the original voices, music and sound.
- **Two looks** – a modern, cleaned-up interface, or *classic*, which follows the CD-ROM's own
  screens and layout.
- **Pyntekassen and the Scrapbog** – spend pebernødder on decorations, and look back at pictures,
  trophies and highscores.
- **Summer holiday** – a beach to explore with Surfing, Is-tårnet, Fiskekonkurrencen and Sandslottet.
- **Halloween** – a haunted house with Græskarskæring, Spøgelsesjagt, Slik eller ballade and
  Spøgelseslabyrinten.
- **Difficulties and trophies** – every season game has Easy, Normal and Hard, a highscore list for
  each, and bronze, silver and gold trophies.
- **Duel** – two players on one keyboard. The keyboard games are played split screen at the same
  time (W A S D against the arrow keys); the mouse games take turns.
- **Danish and English**, with subtitles for everything that is said.

## Play it in Garry's Mod

The `game/` folder in this repository is the whole gamemode, so you can play it in Garry's Mod too:

1. Download the repository (**Code → Download ZIP**) and unpack it.
2. Copy the `game` folder into `garrysmod/gamemodes/` and rename it to **`alletidersnisse`**
   (the name matters – the gamemode finds its pictures and sounds by it).
   On Steam that is usually `Steam/steamapps/common/GarrysMod/garrysmod/gamemodes/`.
3. Start Garry's Mod, pick **Alletiders Nisse** in the gamemode list in the bottom right corner of
   the main menu, and start a game on any map.

In Garry's Mod you also get Kapløb, the race between several players, when you host it for friends.

The gamemode will also come to the **Steam Workshop** later, so it can be installed with a single
click.

## How it runs in the browser

The website does not have its own version of the game. `game/` is the Garry's Mod gamemode folder
exactly as it is installed in `garrysmod/gamemodes/alletidersnisse`, and the browser runs those
same Lua files through a small translation layer:

- **Lua 5.1 in WebAssembly** runs the gamemode's code unchanged.
- **`tools/src/gmod.lua`** recreates the parts of Garry's Mod the gamemode uses – `surface`,
  `draw`, `render`, `input`, `sound`, `file`, `net`, `vgui`, hooks and timers – on top of the
  browser. The server half of the gamemode (saving, highscores, duels) runs in the same Lua,
  talking to the client through a local `net`.
- **`tools/src/main.js`** is the browser side: it draws each frame on a canvas, loads the pictures
  and fonts, plays sound with Web Audio, passes on keys and the mouse, and keeps the saves in the
  browser.

Because of this, the Garry's Mod version and the website are always the same game, and updating
the site is just a matter of updating `game/`.

## Layout

| Path | What it is |
|---|---|
| `game/` | The Garry's Mod gamemode, unchanged |
| `game/lua.json`, `game/manifest.json` | Generated lists of the gamemode's Lua files and picture sizes |
| `tools/` | The translation layer's source, and the script that makes the lists |
| `runtime/` | The built translation layer and the Lua engine |
| `.github/workflows/pages.yml` | Builds and publishes the site on every push |

## Not on the website

Kapløb, the race between several players on a server, needs Garry's Mod multiplayer and is only
in the gamemode.

## Credits

*Alletiders Nisse* and Pyrus belong to their original creators (TV 2 and the team behind Pyrus),
as do the characters, voices, music and original artwork. This is an unofficial, non-commercial fan project made
out of love for the original, and it is not affiliated with or endorsed by them.

The Lua engine is [wasmoon-lua5.1](https://github.com/JX3BOX/wasmoon-lua5.1) (MIT).
