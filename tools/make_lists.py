#!/usr/bin/env python3
"""Makes the two lists the website needs from the gamemode folder in game/:
  game/lua.json      every Lua file of the gamemode (the browser loads them all in one go)
  game/manifest.json the pixel size of every picture (GMod's Material() needs it at once)
Run from anywhere:  python3 tools/make_lists.py   (needs Pillow: pip install pillow)
The gamemode files themselves are never changed."""
import os, json
from PIL import Image
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
GAME = os.path.join(ROOT, 'game')

lua = {}
for root, _, files in os.walk(os.path.join(GAME, 'gamemode')):
    for f in sorted(files):
        if f.endswith('.lua'):
            p = os.path.join(root, f)
            rel = os.path.relpath(p, GAME).replace(os.sep, '/')
            with open(p, encoding='utf-8', errors='replace') as fh:
                lua['alletidersnisse/' + rel] = fh.read()
with open(os.path.join(GAME, 'lua.json'), 'w', encoding='utf-8') as fh:
    json.dump(lua, fh, ensure_ascii=False, separators=(',', ':'))

images = {}
mat = os.path.join(GAME, 'content', 'materials')
for root, _, files in os.walk(mat):
    for f in sorted(files):
        if f.lower().endswith(('.png', '.jpg', '.jpeg')):
            p = os.path.join(root, f)
            try:
                with Image.open(p) as im:
                    images[os.path.relpath(p, mat).replace(os.sep, '/')] = list(im.size)
            except Exception as e:
                print('skipped', p, e)
with open(os.path.join(GAME, 'manifest.json'), 'w') as fh:
    json.dump({'images': images}, fh, separators=(',', ':'))
print(f'{len(lua)} Lua files, {len(images)} pictures')
