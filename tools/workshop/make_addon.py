#!/usr/bin/env python3
"""Builds the Steam Workshop version of the gamemode in build/addon/ from game/ (game/ is not changed).

A gamemode on the Workshop is laid out differently from a gamemodes/ folder:
  build/addon/addon.json                      what gmad needs: title, type "gamemode", tags
  build/addon/gamemodes/alletidersnisse/...   the gamemode's Lua and its .txt / logo / icon
  build/addon/materials, sound, resource/     the content, at the top of the addon
Only file types the Workshop accepts are taken (so not the website's lua.json / manifest.json)."""
import os, json, shutil
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
GAME = os.path.join(ROOT, 'game')
OUT = os.path.join(ROOT, 'build', 'addon')
NAME = 'alletidersnisse'

shutil.rmtree(OUT, ignore_errors=True)
gm = os.path.join(OUT, 'gamemodes', NAME)
shutil.copytree(os.path.join(GAME, 'gamemode'), os.path.join(gm, 'gamemode'))
for f in (NAME + '.txt', 'logo.png', 'icon24.png'):
    if os.path.exists(os.path.join(GAME, f)):
        shutil.copy2(os.path.join(GAME, f), os.path.join(gm, f))

ALLOWED = {
    'materials': ('.png', '.jpg', '.jpeg', '.vmt', '.vtf'),
    'sound': ('.mp3', '.wav', '.ogg'),
    'resource': ('.ttf',),
}
n = 0
for part, exts in ALLOWED.items():
    src = os.path.join(GAME, 'content', part)
    for root, _, files in os.walk(src):
        for f in files:
            if f.lower().endswith(exts):
                s = os.path.join(root, f)
                d = os.path.join(OUT, part, os.path.relpath(s, src))
                os.makedirs(os.path.dirname(d), exist_ok=True)
                shutil.copy2(s, d)
                n += 1
            else:
                print('left out (not allowed on the Workshop):', os.path.join(root, f))

with open(os.path.join(OUT, 'addon.json'), 'w') as fh:
    json.dump({'title': 'Alletiders Nisse', 'type': 'gamemode', 'tags': ['fun', 'cartoon'], 'ignore': []}, fh, indent=1)
print(f'addon built in build/addon: the gamemode + {n} content files')
