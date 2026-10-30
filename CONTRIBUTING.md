# Contributing

Suggestions are welcome – new levels, better levels, fixes, translations, or anything else that
makes the game better.

1. Fork the repository and make your change in `game/` (the Garry's Mod gamemode) or, for the
   website only, in `tools/src/`.
2. Try it: in Garry's Mod (copy `game/` into `garrysmod/gamemodes/alletidersnisse`) and/or on the
   website locally (see *Trying the website locally* below).
3. Open a pull request that says what you changed and why, with a screenshot if it changes how
   something looks.

**Please be patient:** changes are not added straight away. Every pull request is checked
thoroughly – that it works, fits the original game, and doesn't break saves – before it is merged,
and some won't be.

Keep the gamemode and the website the same game: `game/` must keep working unchanged in
Garry's Mod, so no website-only code there.

## Trying the website locally

```
cd tools && npm ci && npm run build && cd ..
pip install pillow && python tools/make_lists.py
python -m http.server
```

…and open http://localhost:8000.
