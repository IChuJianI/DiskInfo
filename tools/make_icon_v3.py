from PIL import Image, ImageDraw, ImageFilter
import math
import os

SS = 4
SIZE = 1024
W = SIZE * SS
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'icon-build-v3')
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


def radial_ellipse(size, center, rx, ry, inner, outer):
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        c = lerp(inner, outer, t ** 0.9)
        d.ellipse([sc(center[0] - rx * t), sc(center[1] - ry * t),
                   sc(center[0] + rx * t), sc(center[1] + ry * t)], fill=(c[0], c[1], c[2], 255))
    return layer


def vgrad_box(size, box, top, bottom, alpha=255):
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    x0, y0, x1, y1 = [sc(v) for v in box]
    grad = Image.new('RGBA', (1, y1 - y0))
    gp = grad.load()
    for y in range(y1 - y0):
        c = lerp(top, bottom, y / max(1, y1 - y0 - 1))
        gp[0, y] = (c[0], c[1], c[2], alpha)
    grad = grad.resize((x1 - x0, y1 - y0), Image.BILINEAR)
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0, y0, x1, y1], radius=sc(60), fill=255)
    layer.paste(grad, (x0, y0), mask.crop((x0, y0, x1, y1)))
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
    return Image.alpha_composite(bg, glow).convert('RGB')


def shadow():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(206), sc(700), sc(830), sc(820)], radius=sc(70), fill=(4, 20, 70, 120))
    return layer.filter(ImageFilter.GaussianBlur(sc(28)))


def front_edge():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    box = (190, 300, 834, 806)
    grad = vgrad_box(W, box, (203, 215, 231), (143, 159, 181))
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(64), fill=255)
    layer = Image.composite(grad, layer, mask)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(196), sc(306), sc(828), sc(800)], radius=sc(58), outline=(232, 240, 249, 90), width=sc(3))
    # usb-c
    d.rounded_rectangle([sc(276), sc(752), sc(336), sc(771)], radius=sc(9), fill=(70, 84, 104, 255))
    d.rounded_rectangle([sc(284), sc(757), sc(328), sc(766)], radius=sc(4), fill=(36, 46, 60, 255))
    # led
    d.ellipse([sc(756), sc(746), sc(780), sc(770)], fill=(54, 214, 128, 255))
    return layer


def top_face():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    box = (190, 248, 834, 752)
    grad = vgrad_box(W, box, (252, 253, 255), (214, 225, 240))
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(64), fill=255)
    layer = Image.composite(grad, layer, mask)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(64),
                        outline=(255, 255, 255, 170), width=sc(3))
    d.line([(sc(206), sc(748)), (sc(818), sc(748))], fill=(255, 255, 255, 120), width=sc(3))
    d.line([(sc(206), sc(752)), (sc(818), sc(752))], fill=(108, 124, 146, 90), width=sc(2))
    return layer


def well():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    box = (252, 306, 772, 700)
    grad = vgrad_box(W, box, (35, 48, 68), (16, 24, 37))
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(48), fill=255)
    layer = Image.composite(grad, layer, mask)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(48),
                        outline=(120, 140, 166, 120), width=sc(3))
    d.rounded_rectangle([sc(box[0] - 8), sc(box[1] - 8), sc(box[2] + 8), sc(box[3] + 8)], radius=sc(54),
                        outline=(148, 164, 186, 60), width=sc(5))
    return layer


def platter():
    cx, cy, r = 466, 500, 158
    layer = radial_ellipse(W, (cx, cy), r, r, (226, 235, 246), (138, 156, 180))
    d = ImageDraw.Draw(layer)
    d.ellipse([sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)], outline=(255, 255, 255, 120), width=sc(4))
    for k in (0.90, 0.80, 0.70):
        d.ellipse([sc(cx - r * k), sc(cy - r * k), sc(cx + r * k), sc(cy + r * k)],
                  outline=(110, 128, 152, 26), width=sc(2))
    d.arc([sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)], 185, 265, fill=(255, 255, 255, 190), width=sc(7))
    d.ellipse([sc(cx - 44), sc(cy - 44), sc(cx + 44), sc(cy + 44)], fill=(214, 225, 239, 255))
    d.ellipse([sc(cx - 44), sc(cy - 44), sc(cx + 44), sc(cy + 44)], outline=(134, 151, 174, 220), width=sc(3))
    d.ellipse([sc(cx - 22), sc(cy - 22), sc(cx + 22), sc(cy + 22)], fill=(166, 181, 201, 255))
    d.ellipse([sc(cx - 8), sc(cy - 8), sc(cx + 8), sc(cy + 8)], fill=(88, 102, 124, 255))
    return layer


def arm():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pivot = (686, 640)
    tip = (540, 540)
    vx, vy = tip[0] - pivot[0], tip[1] - pivot[1]
    ln = math.hypot(vx, vy)
    ux, uy = vx / ln, vy / ln
    px, py = -uy, ux
    hw = 15
    poly = [
        (pivot[0] + px * hw, pivot[1] + py * hw),
        (tip[0] + px * hw * 0.7, tip[1] + py * hw * 0.7),
        (tip[0] + ux * 14 + px * hw * 0.7, tip[1] + uy * 14 + py * hw * 0.7),
        (tip[0] + ux * 14 - px * hw * 0.7, tip[1] + uy * 14 - py * hw * 0.7),
        (tip[0] - px * hw * 0.7, tip[1] - py * hw * 0.7),
        (pivot[0] - px * hw, pivot[1] - py * hw),
    ]
    d.polygon([(sc(x), sc(y)) for x, y in poly], fill=(214, 224, 237, 255))
    d.line([(sc(poly[0][0]), sc(poly[0][1])), (sc(poly[1][0]), sc(poly[1][1]))], fill=(255, 255, 255, 200), width=sc(3))
    d.line([(sc(poly[5][0]), sc(poly[5][1])), (sc(poly[4][0]), sc(poly[4][1]))], fill=(126, 142, 165, 255), width=sc(3))
    hx, hy = tip[0] + ux * 16, tip[1] + uy * 16
    d.ellipse([sc(hx - 13), sc(hy - 9), sc(hx + 13), sc(hy + 9)], fill=(236, 242, 250, 255),
              outline=(124, 141, 164, 255), width=sc(2))
    d.ellipse([sc(pivot[0] - 38), sc(pivot[1] - 38), sc(pivot[0] + 38), sc(pivot[1] + 38)], fill=(196, 208, 224, 255))
    d.ellipse([sc(pivot[0] - 28), sc(pivot[1] - 28), sc(pivot[0] + 28), sc(pivot[1] + 28)], fill=(236, 242, 250, 255))
    d.ellipse([sc(pivot[0] - 9), sc(pivot[1] - 9), sc(pivot[0] + 9), sc(pivot[1] + 9)], fill=(146, 162, 184, 255))
    return layer


def screws():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, cy in ((228, 286), (796, 286), (228, 714), (796, 714)):
        d.ellipse([sc(cx - 12), sc(cy - 12), sc(cx + 12), sc(cy + 12)], fill=(203, 214, 229, 255))
        d.ellipse([sc(cx - 5), sc(cy - 5), sc(cx + 5), sc(cy + 5)], fill=(146, 162, 183, 255))
    return layer


def health_arc():
    cx, cy, r = 466, 500, 158
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    box = [sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)]
    glow = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).arc(box, 196, 344, fill=(50, 218, 130, 120), width=sc(24))
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(sc(10))))
    d = ImageDraw.Draw(layer)
    d.arc(box, 196, 344, fill=(52, 220, 132, 255), width=sc(13))
    for ang in (196, 344):
        a = math.radians(ang)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        d.ellipse([sc(px - 6.5), sc(py - 6.5), sc(px + 6.5), sc(py + 6.5)], fill=(52, 220, 132, 255))
    return layer


def build_foreground():
    fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    for part in (shadow(), front_edge(), top_face(), well(), platter(), screws(), arm(), health_arc()):
        fg = Image.alpha_composite(fg, part)
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
