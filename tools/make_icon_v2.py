from PIL import Image, ImageDraw, ImageFilter
import math
import os

SS = 4
SIZE = 1024
W = SIZE * SS
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'icon-build-v2')
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)


def sc(v):
    return v * SS


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def vgradient(size, top, bottom):
    img = Image.new('RGB', (1, size), top)
    px = img.load()
    for y in range(size):
        px[0, y] = lerp(top, bottom, y / (size - 1))
    return img.resize((size, size), Image.BILINEAR)


def radial_ellipse(size, center, rx, ry, inner, outer, cx_off=0):
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 48
    for i in range(steps, 0, -1):
        t = i / steps
        c = lerp(inner, outer, t ** 0.85)
        d.ellipse([sc(center[0] - rx * t), sc(center[1] - ry * t),
                   sc(center[0] + rx * t), sc(center[1] + ry * t)], fill=(c[0], c[1], c[2], 255))
    return layer


def build_background():
    bg = vgradient(W, (58, 116, 246), (12, 60, 188)).convert('RGBA')
    glow = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = sc(512), sc(420), sc(660)
    for i in range(28, 0, -1):
        t = i / 28
        gd.ellipse([cx - r * t, cy - r * t, cx + r * t, cy + r * t], fill=(132, 176, 255, int(36 * (1 - t))))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(44)))
    bg = Image.alpha_composite(bg, glow)
    return bg.convert('RGB')


CX, CY = 512, 486
RX, RY = 286, 178
THICK = 54


def disc_shadow():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([sc(CX - RX + 8), sc(CY + 78), sc(CX + RX + 8), sc(CY + RY + THICK + 74)],
              fill=(4, 20, 70, 120))
    return layer.filter(ImageFilter.GaussianBlur(sc(30)))


def disc_edge():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 30
    for i in range(steps, 0, -1):
        t = i / steps
        c = lerp((186, 202, 222), (105, 124, 150), t)
        off = THICK * (1 - t)
        d.ellipse([sc(CX - RX), sc(CY + off - RY), sc(CX + RX), sc(CY + off + RY)], fill=(c[0], c[1], c[2], 255))
    return layer


def disc_top():
    layer = radial_ellipse(W, (CX, CY), RX, RY, (245, 249, 254), (188, 203, 222))
    d = ImageDraw.Draw(layer)
    # rim
    d.ellipse([sc(CX - RX), sc(CY - RY), sc(CX + RX), sc(CY + RY)], outline=(255, 255, 255, 170), width=sc(4))
    d.ellipse([sc(CX - RX + 4), sc(CY - RY + 3), sc(CX + RX - 4), sc(CY + RY - 3)], outline=(158, 175, 197, 120), width=sc(2))
    # fine concentric rings
    for k in (0.94, 0.86, 0.78, 0.70, 0.62, 0.54):
        d.ellipse([sc(CX - RX * k), sc(CY - RY * k), sc(CX + RX * k), sc(CY + RY * k)],
                  outline=(120, 138, 162, 24), width=sc(2))
    # outer sheen arc top-left
    d.arc([sc(CX - RX), sc(CY - RY), sc(CX + RX), sc(CY + RY)], 186, 268, fill=(255, 255, 255, 200), width=sc(7))
    # inner well
    irx, iry = RX * 0.44, RY * 0.44
    d.ellipse([sc(CX - irx), sc(CY - iry), sc(CX + irx), sc(CY + iry)], outline=(146, 162, 184, 70), width=sc(3))
    # spindle
    d.ellipse([sc(CX - 54), sc(CY - 34), sc(CX + 54), sc(CY + 34)], fill=(222, 231, 243, 255))
    d.ellipse([sc(CX - 54), sc(CY - 34), sc(CX + 54), sc(CY + 34)], outline=(140, 156, 179, 220), width=sc(3))
    d.ellipse([sc(CX - 30), sc(CY - 19), sc(CX + 30), sc(CY + 19)], fill=(178, 192, 211, 255))
    d.ellipse([sc(CX - 11), sc(CY - 7), sc(CX + 11), sc(CY + 7)], fill=(96, 111, 133, 255))
    return layer


def pulse():
    pts = [(190, 606), (330, 606), (368, 598), (396, 606), (452, 606), (486, 556),
           (520, 470), (560, 700), (596, 606), (660, 606), (700, 596), (736, 606), (838, 606)]
    pts = [(int(x), int(y)) for x, y in pts]
    glow = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line([(sc(x), sc(y)) for x, y in pts], fill=(46, 224, 138, 120), width=sc(44), joint='curve')
    glow = glow.filter(ImageFilter.GaussianBlur(sc(14)))
    layer = Image.alpha_composite(Image.new('RGBA', (W, W), (0, 0, 0, 0)), glow)
    d = ImageDraw.Draw(layer)
    d.line([(sc(x), sc(y)) for x, y in pts], fill=(48, 226, 141, 255), width=sc(30), joint='curve')
    for x, y in pts:
        d.ellipse([sc(x - 15), sc(y - 15), sc(x + 15), sc(y + 15)], fill=(48, 226, 141, 255))
    # soften ends: taper by masking outer 40px with background? keep round caps
    return layer


def build_foreground():
    fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    fg = Image.alpha_composite(fg, disc_shadow())
    fg = Image.alpha_composite(fg, disc_edge())
    fg = Image.alpha_composite(fg, disc_top())
    fg = Image.alpha_composite(fg, pulse())
    return fg


bg = build_background()
fg = build_foreground()
bg_small = bg.resize((SIZE, SIZE), Image.LANCZOS)
fg_small = fg.resize((SIZE, SIZE), Image.LANCZOS)
comp = bg_small.copy()
comp.paste(fg_small, (0, 0), fg_small)

bg_small.save(os.path.join(OUT, 'background.png'))
fg_small.save(os.path.join(OUT, 'foreground.png'))
comp.save(os.path.join(OUT, 'composite.png'))
for s in (512, 288, 144, 96, 64, 48):
    comp.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'preview_%d.png' % s))
    sq = comp.resize((s, s), Image.LANCZOS).convert('RGBA')
    m = Image.new('L', (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], radius=max(2, int(s * 0.24)), fill=255)
    sq.putalpha(m)
    sq.save(os.path.join(OUT, 'squircle_%d.png' % s))

import numpy as np
a = np.array(fg_small)[:, :, 3]
ys, xs = np.nonzero(a > 8)
rad = np.sqrt((xs - 512) ** 2 + (ys - 512) ** 2).max()
print('transparent:', round(float((a == 0).mean()) * 100, 1), '%')
print('bbox:', xs.min(), xs.max(), ys.min(), ys.max())
print('max radius:', round(float(rad), 1), '/512')
