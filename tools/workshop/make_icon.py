#!/usr/bin/env python3
"""Makes the Workshop preview picture (tools/workshop/icon.jpg, 512 x 512 JPG, 4:2:0) from the game's own
pictures: the attic, the three nisser at the table, the logo, a garland – in an orange frame."""
import os
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
MAT = os.path.join(HERE, '..', '..', 'game', 'content', 'materials', 'alletidersnisse')
REAL = {'bg/menu.jpg': (1920, 1080), 'ui/bordscene.png': (1500, 1193), 'ui/logo.png': (863, 653), 'ui/br_baubles.png': (1200, 740)}
def pic(p):
    im = Image.open(os.path.join(MAT, p)).convert('RGBA')
    return im.resize(REAL[p], Image.LANCZOS)   # the files are stored stretched to power-of-two sizes
S, B = 512, 16
out = Image.new('RGBA', (S, S))
# the attic, a little soft and warm
bg = pic('bg/menu.jpg')
bg = bg.crop((520, 0, 520 + 1080, 1080)).resize((S, S), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3))
bg = ImageEnhance.Brightness(bg).enhance(0.75)
out.alpha_composite(bg)
# a warm glow behind the three
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(glow)
d.ellipse((40, 200, 472, 560), fill=(255, 190, 90, 120))
out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
# the table scene, big, at the bottom
sc = pic('ui/bordscene.png')
sc = sc.crop(sc.getbbox())
w = 560
sc = sc.resize((w, int(sc.height * w / sc.width)), Image.LANCZOS)
out.alpha_composite(sc, ((S - w) // 2, S - sc.height + 40))
# a garland across the top
br = pic('ui/br_baubles.png')
br = br.crop(br.getbbox())
bw = 300
br = br.resize((bw, int(br.height * bw / br.width)), Image.LANCZOS)
out.alpha_composite(br, (-30, -10))
out.alpha_composite(br.transpose(Image.FLIP_LEFT_RIGHT), (S - bw + 30, -10))
# the logo
lg = pic('ui/logo.png')
lg = lg.crop(lg.getbbox())
lw = 290
lg = lg.resize((lw, int(lg.height * lw / lg.width)), Image.LANCZOS)
sh = Image.new('RGBA', lg.size, (0, 0, 0, 0))
sh.putalpha(lg.getchannel('A').point(lambda a: a * 0.6))
out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)), ((S - lw) // 2 + 4, 30 + 8))
out.alpha_composite(lg, ((S - lw) // 2, 30))
# the orange frame, like the other addons
d = ImageDraw.Draw(out)
d.rectangle((0, 0, S - 1, S - 1), outline=(255, 122, 0, 255), width=B)
out.convert('RGB').save(os.path.join(HERE, 'icon.jpg'), quality=92, subsampling=2)
print('icon.jpg')
