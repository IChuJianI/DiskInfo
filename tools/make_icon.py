from PIL import Image, ImageDraw, ImageFilter
import math
import os

SS = 4
SIZE = 1024
W = SIZE * SS
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(ROOT, 'icon-build')
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


def radial_ellipse(center, rx, ry, inner, outer):
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        c = lerp(inner, outer, t ** 0.9)
        d.ellipse([sc(center[0] - rx * t), sc(center[1] - ry * t),
                   sc(center[0] + rx * t), sc(center[1] + ry * t)], fill=(c[0], c[1], c[2], 255))
    return layer


def rounded_box(box, radius, top, bottom, outline=None, outline_width=0, outline_alpha=255):
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    x0, y0, x1, y1 = [sc(v) for v in box]
    grad = Image.new('RGBA', (1, y1 - y0))
    gp = grad.load()
    for y in range(y1 - y0):
        c = lerp(top, bottom, y / max(1, y1 - y0 - 1))
        gp[0, y] = (c[0], c[1], c[2], 255)
    grad = grad.resize((x1 - x0, y1 - y0), Image.BILINEAR)
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0, y0, x1, y1], radius=sc(radius), fill=255)
    layer.paste(grad, (x0, y0), mask.crop((x0, y0, x1, y1)))
    if outline is not None:
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle([x0, y0, x1, y1], radius=sc(radius),
                            outline=(outline[0], outline[1], outline[2], outline_alpha), width=sc(outline_width))
    return layer


def build_background():
    bg = vgradient(W, (58, 116, 246), (12, 60, 188)).convert('RGBA')
    glow = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = sc(512), sc(412), sc(660)
    for i in range(28, 0, -1):
        t = i / 28
        gd.ellipse([cx - r * t, cy - r * t, cx + r * t, cy + r * t], fill=(132, 176, 255, int(36 * (1 - t))))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(44)))
    return Image.alpha_composite(bg, glow).convert('RGB')


def shadow():
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(206), sc(700), sc(830), sc(820)], radius=sc(70), fill=(4, 20, 70, 118))
    return layer.filter(ImageFilter.GaussianBlur(sc(28)))


def front_edge():
    layer = rounded_box((190, 300, 834, 806), 64, (203, 215, 231), (143, 159, 181),
                        outline=(232, 240, 249), outline_width=3, outline_alpha=90)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(276), sc(752), sc(336), sc(771)], radius=sc(9), fill=(70, 84, 104, 255))
    d.rounded_rectangle([sc(284), sc(757), sc(328), sc(766)], radius=sc(4), fill=(36, 46, 60, 255))
    d.ellipse([sc(754), sc(744), sc(782), sc(772)], fill=(54, 214, 128, 255))
    return layer


def top_face():
    layer = rounded_box((190, 248, 834, 752), 64, (252, 253, 255), (214, 225, 240),
                        outline=(255, 255, 255), outline_width=3, outline_alpha=170)
    d = ImageDraw.Draw(layer)
    d.line([(sc(206), sc(748)), (sc(818), sc(748))], fill=(255, 255, 255, 120), width=sc(3))
    d.line([(sc(206), sc(752)), (sc(818), sc(752))], fill=(108, 124, 146, 90), width=sc(2))
    return layer


def well():
    box = (252, 306, 772, 700)
    layer = rounded_box(box, 48, (35, 48, 68), (16, 24, 37),
                        outline=(120, 140, 166), outline_width=3, outline_alpha=120)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([sc(box[0] - 8), sc(box[1] - 8), sc(box[2] + 8), sc(box[3] + 8)], radius=sc(54),
                        outline=(148, 164, 186, 60), width=sc(5))
    # recessed inner shadow along the top edge
    inner = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(inner).rounded_rectangle(
        [sc(box[0] + 2), sc(box[1] + 2), sc(box[2] - 2), sc(box[1] + 46)], radius=sc(40), fill=(0, 0, 0, 80))
    inner = inner.filter(ImageFilter.GaussianBlur(sc(14)))
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(48), fill=255)
    inner.putalpha(Image.composite(inner.getchannel('A'), Image.new('L', (W, W), 0), mask))
    layer = Image.alpha_composite(layer, inner)
    return layer


def platter():
    cx, cy, r = 466, 500, 158
    layer = radial_ellipse((cx, cy), r, r, (228, 237, 248), (139, 157, 181))
    d = ImageDraw.Draw(layer)
    d.ellipse([sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)], outline=(255, 255, 255, 120), width=sc(4))
    d.ellipse([sc(cx - r * 0.82), sc(cy - r * 0.82), sc(cx + r * 0.82), sc(cy + r * 0.82)],
              outline=(108, 126, 150, 20), width=sc(2))
    d.arc([sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)], 185, 262, fill=(255, 255, 255, 195), width=sc(8))
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
    ImageDraw.Draw(glow).arc(box, 196, 344, fill=(50, 218, 130, 120), width=sc(26))
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(sc(10))))
    d = ImageDraw.Draw(layer)
    d.arc(box, 196, 344, fill=(52, 220, 132, 255), width=sc(14))
    for ang in (196, 344):
        a = math.radians(ang)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        d.ellipse([sc(px - 7), sc(py - 7), sc(px + 7), sc(py + 7)], fill=(52, 220, 132, 255))
    return layer


def build_foreground():
    fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    for part in (shadow(), front_edge(), top_face(), well(), platter(), screws(), arm(), health_arc()):
        fg = Image.alpha_composite(fg, part)
    # keep the mark inside the safe radius for squircle/circle masks
    scale = 0.92
    fg = fg.resize((int(W * scale), int(W * scale)), Image.LANCZOS)
    canvas = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    canvas.paste(fg, ((W - fg.width) // 2, (W - fg.height) // 2))
    return canvas


bg = build_background()
fg = build_foreground()
bg_small = bg.resize((SIZE, SIZE), Image.LANCZOS)
fg_small = fg.resize((SIZE, SIZE), Image.LANCZOS)
comp = bg_small.copy()
comp.paste(fg_small, (0, 0), fg_small)

bg_small.save(os.path.join(OUT, 'background.png'))
fg_small.save(os.path.join(OUT, 'foreground.png'))
comp.save(os.path.join(OUT, 'composite.png'))

start = comp.resize((144, 144), Image.LANCZOS).convert('RGBA')
mask = Image.new('L', (144, 144), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, 143, 143], radius=34, fill=255)
start.putalpha(mask)
start.save(os.path.join(OUT, 'startIcon.png'))

# AppGallery: square, no baked corners, RGB
comp.save(os.path.join(OUT, 'store_icon_1024.png'))
comp.resize((216, 216), Image.LANCZOS).save(os.path.join(OUT, 'store_icon_216.png'))

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
print('background size/mode:', bg_small.size, bg_small.mode)
print('foreground size/mode:', fg_small.size, fg_small.mode)
print('transparent ratio:', round(float((a == 0).mean()) * 100, 1), '%')
print('bbox:', xs.min(), xs.max(), ys.min(), ys.max())
print('max radius:', round(float(rad), 1), '/512')
