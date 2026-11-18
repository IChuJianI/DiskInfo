#!/usr/bin/env python3
"""Compose DiskInfo store promo images in the XBiGOD visual language.

The in-device UI is a faithful PIL render of the ArkUI layout (sidebar 280vp,
dashboard cards, device info grid, thermal chart, SMART table, SettingsPage
cards, floating tab bar); only sample disk data and marketing copy are staged.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, 'icon-build/startIcon.png')
OUT = os.path.join(ROOT, 'store/promo')
FONT_PATH = '/system/fonts/HarmonyOS_Sans_SC.ttf'
SS = 2

# dark palette from entry/src/main/resources/dark/element/color.json
PAGE = (16, 16, 20)
CARD = (28, 28, 30)
T1 = (230, 230, 235)
T2 = (153, 153, 158)
T3 = (102, 102, 108)
DIV = (38, 38, 41)
ACCENT = (82, 145, 255)
ACCENT_BG = (39, 51, 75)
GOOD = (61, 208, 104)
CAUTION = (255, 184, 77)
BAD = (255, 107, 94)
CHIP = (45, 45, 49)
TABBAR = (41, 41, 46)

# promo canvas palette
HEAD = (244, 247, 252)
HEAD_ACCENT = (108, 164, 255)
DESC = (166, 176, 190)
CHIP_BG = (9, 13, 22)
CHIP_LINE = (30, 40, 60)
CHIP_TEXT = (214, 224, 238)
CHECK_RING = (70, 110, 180)
CHECK_TEXT = (200, 212, 228)
FOOT = (101, 112, 128)
EYEBROW = (127, 176, 236)

MODEL = 'Samsung SSD 870 EVO 1TB'
SECOND_MODEL = 'Seagate One Touch 2TB'
SERIAL = 'S6PTNX0T912345'

_fonts = {}


def font(size, weight='Regular'):
    key = (max(1, int(round(size))), weight)
    if key not in _fonts:
        face = ImageFont.truetype(FONT_PATH, key[0])
        try:
            face.set_variation_by_name(weight)
        except Exception:
            pass
        _fonts[key] = face
    return _fonts[key]


class P:
    """Painter taking vp coordinates and scaling them by ss."""

    def __init__(self, img, ss=SS):
        self.img = img
        self.ss = ss
        self.d = ImageDraw.Draw(img)

    def px(self, v):
        return v * self.ss

    def text(self, xy, s, size, fill, weight='Regular', anchor='ls'):
        self.d.text((self.px(xy[0]), self.px(xy[1])), s, font=font(size * self.ss, weight),
                    fill=fill, anchor=anchor)

    def rect(self, box, fill=None, outline=None, width=1, radius=0):
        coords = [self.px(box[0]), self.px(box[1]), self.px(box[2]), self.px(box[3])]
        w = max(1, int(round(self.px(width))))
        if radius > 0:
            self.d.rounded_rectangle(coords, radius=self.px(radius), fill=fill,
                                     outline=outline, width=w)
        else:
            self.d.rectangle(coords, fill=fill, outline=outline, width=w)

    def line(self, xy, fill, width=1):
        self.d.line([(self.px(xy[0]), self.px(xy[1])), (self.px(xy[2]), self.px(xy[3]))],
                    fill=fill, width=max(1, int(round(self.px(width)))))

    def poly(self, points, fill, width=1):
        coords = [(self.px(x), self.px(y)) for (x, y) in points]
        self.d.line(coords, fill=fill, width=max(1, int(round(self.px(width)))), joint='curve')

    def polygon(self, points, fill):
        self.d.polygon([(self.px(x), self.px(y)) for (x, y) in points], fill=fill)

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse([self.px(box[0]), self.px(box[1]), self.px(box[2]), self.px(box[3])],
                       fill=fill, outline=outline, width=max(1, int(round(self.px(width)))))

    def arc(self, box, start, end, fill, width=1):
        self.d.arc([self.px(box[0]), self.px(box[1]), self.px(box[2]), self.px(box[3])],
                   start=start, end=end, fill=fill,
                   width=max(1, int(round(self.px(width)))))

    def text_width(self, s, size, weight='Regular'):
        return font(size * self.ss, weight).getlength(s) / self.ss


_icons = {}


def icon_image(size):
    key = int(round(size))
    if key not in _icons:
        src = Image.open(ICON).convert('RGBA')
        _icons[key] = src.resize((key, key), Image.LANCZOS)
    return _icons[key]


# ── small vector glyphs (approximations of the sys.symbol set) ─────────

def icon_house(p, cx, cy, s, color, width=1.8):
    w = s * 0.82
    h = s * 0.74
    p.poly([(cx - w / 2, cy - 1), (cx, cy - h / 2 - 2), (cx + w / 2, cy - 1)], color, width)
    p.poly([(cx - w / 2 + 1.4, cy - 2.2), (cx - w / 2 + 1.4, cy + h / 2 - 2),
            (cx + w / 2 - 1.4, cy + h / 2 - 2), (cx + w / 2 - 1.4, cy - 2.2)], color, width)
    p.rect([cx - 2.6, cy + h / 2 - 7.4, cx + 2.6, cy + h / 2 - 2], outline=color, width=width * 0.8)


def icon_drive(p, cx, cy, s, color, width=1.6):
    w = s * 0.96
    h = s * 0.6
    p.rect([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=2.6,
           outline=color, width=width)
    p.line([cx - w / 2 + 2.4, cy + h / 2 - 4.2, cx + w / 2 - 2.4, cy + h / 2 - 4.2],
           color, width * 0.85)
    p.ellipse([cx + w / 2 - 6.4, cy + h / 2 - 7.2, cx + w / 2 - 3.6, cy + h / 2 - 4.4],
              fill=color)


def icon_gear(p, cx, cy, s, color, width=1.6):
    r = s * 0.28
    p.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=2.2)
    for i in range(8):
        a = i * math.pi / 4
        p.line([cx + math.cos(a) * (r - 1.0), cy + math.sin(a) * (r - 1.0),
                cx + math.cos(a) * (r + 3.8), cy + math.sin(a) * (r + 3.8)], color, 3.4)
    p.ellipse([cx - 2.4, cy - 2.4, cx + 2.4, cy + 2.4], outline=color, width=1.6)


def icon_refresh(p, cx, cy, s, color, width=1.8):
    r = s * 0.33
    p.arc([cx - r, cy - r, cx + r, cy + r], 55, 312, color, width)
    a = math.radians(312)
    tx = cx + r * math.cos(a)
    ty = cy + r * math.sin(a)
    dx = -math.sin(a)
    dy = math.cos(a)
    tip = (tx + dx * 5.2, ty + dy * 5.2)
    bx = tx - dx * 2.0
    by = ty - dy * 2.0
    p.polygon([tip, (bx - dy * 4.0, by + dx * 4.0), (bx + dy * 4.0, by - dx * 4.0)], color)


def icon_pulse(p, cx, cy, s, color, width=1.7):
    w = s * 0.4
    p.poly([(cx - w, cy + 1), (cx - w * 0.46, cy + 1), (cx - w * 0.18, cy - s * 0.26),
            (cx + w * 0.14, cy + s * 0.24), (cx + w * 0.4, cy + 1), (cx + w, cy + 1)],
           color, width)


def icon_info(p, cx, cy, s, color, width=1.7):
    r = s * 0.36
    p.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=width)
    p.ellipse([cx - 1.1, cy - r * 0.58, cx + 1.1, cy - r * 0.58 + 2.2], fill=color)
    p.line([cx, cy - r * 0.18, cx, cy + r * 0.58], color, width)


def icon_chevron(p, cx, cy, s, color, direction='right', width=1.9):
    if direction == 'right':
        p.poly([(cx - s * 0.28, cy - s * 0.5), (cx + s * 0.24, cy), (cx - s * 0.28, cy + s * 0.5)],
               color, width)
    elif direction == 'left':
        p.poly([(cx + s * 0.28, cy - s * 0.5), (cx - s * 0.24, cy), (cx + s * 0.28, cy + s * 0.5)],
               color, width)
    else:
        p.poly([(cx - s * 0.5, cy - s * 0.24), (cx, cy + s * 0.28), (cx + s * 0.5, cy - s * 0.24)],
               color, width)


def icon_check(p, cx, cy, s, color, width=2.2):
    p.poly([(cx - s * 0.42, cy + s * 0.02), (cx - s * 0.1, cy + s * 0.34),
            (cx + s * 0.46, cy - s * 0.34)], color, width)


def icon_check_circle(p, cx, cy, s, ring, tick, width=2):
    p.ellipse([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], outline=ring, width=width)
    icon_check(p, cx, cy, s * 0.62, tick, width * 1.1)


def icon_shield_check(p, cx, cy, s, color, width=1.5):
    h = s * 0.5
    w = s * 0.4
    p.poly([(cx - w, cy - h + 1), (cx, cy - h), (cx + w, cy - h + 1),
            (cx + w * 0.82, cy + h * 0.32), (cx, cy + h),
            (cx - w * 0.82, cy + h * 0.32), (cx - w, cy - h + 1)], color, width)
    icon_check(p, cx, cy + s * 0.02, s * 0.42, color, width * 1.2)


# ── app screen helpers ────────────────────────────────────────────────

class Screen:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.img = Image.new('RGBA', (int(w * SS), int(h * SS)), PAGE)
        self.p = P(self.img)

    def finish(self):
        return self.img.resize((int(self.w), int(self.h)), Image.LANCZOS)


def draw_status(p, w, h, camera=False):
    p.text((28, h / 2 + 1), '10:24', 15, T1, 'Medium', 'lm')
    bx = w - 30
    p.rect([bx - 24, h / 2 - 5.5, bx, h / 2 + 5.5], radius=2, outline=T1, width=1.2)
    p.rect([bx - 21.5, h / 2 - 3, bx - 5, h / 2 + 3], radius=1, fill=T1)
    p.rect([bx + 1, h / 2 - 2, bx + 2.4, h / 2 + 2], fill=T1)
    wx = w - 84
    for radius in (9, 6.5, 4):
        cy = h / 2 + 6
        p.arc([wx - radius, cy - radius, wx + radius, cy + radius], 225, 315, T1, 1.4)
    p.ellipse([wx - 1.4, h / 2 + 4.4, wx + 1.4, h / 2 + 7.2], fill=T1)
    if camera:
        p.ellipse([w / 2 - 4.2, h / 2 - 4.2, w / 2 + 4.2, h / 2 + 4.2], fill=(7, 7, 9))


def draw_menus(p, right, cy):
    icon_refresh(p, right - 107, cy, 22, T1)
    icon_pulse(p, right - 67, cy, 22, T1)
    icon_gear(p, right - 27, cy, 22, T1)


def draw_back(p, cx, cy, color=T1):
    icon_chevron(p, cx, cy, 18, color, 'left')


def draw_sidebar(p, x, y, w, h):
    p.rect([x, y, x + w, y + h], fill=CARD)
    p.img.alpha_composite(icon_image(40), (int(p.px(x + 16)), int(p.px(y + 20))))
    p.text((x + 66, y + 51), 'DiskInfo', 17, T1, 'Bold')
    p.text((x + 66, y + 68), '硬盘健康监测', 11, T3)

    # home (not selected)
    icon_house(p, x + 33, y + 98, 22, T1)
    p.text((x + 50, y + 103), '首页', 15, T1)
    # disks (selected)
    p.rect([x + 8, y + 122, x + w - 8, y + 162], radius=8, fill=ACCENT_BG)
    icon_drive(p, x + 33, y + 142, 22, ACCENT)
    p.text((x + 50, y + 147), '硬盘', 15, ACCENT, 'Medium')
    icon_chevron(p, x + w - 26, y + 142, 16, T3, 'down')

    items = [(MODEL, 'USB · 1.00 TB', GOOD, True), (SECOND_MODEL, 'USB · 2.00 TB', GOOD, False)]
    iy = y + 166
    for title, sub, health, selected in items:
        if selected:
            p.rect([x + 18, iy, x + w - 18, iy + 46], radius=10, fill=ACCENT_BG)
        p.ellipse([x + 38, iy + 17, x + 47, iy + 26], fill=health)
        p.text((x + 56, iy + 20), title, 13, T1)
        p.text((x + 56, iy + 36), sub, 11, T3)
        iy += 52

    p.text((x + 16, y + h - 64), '上次扫描 10:24:36', 10, T3)
    icon_info(p, x + 33, y + h - 42, 22, T1)
    p.text((x + 50, y + h - 37), '关于', 15, T1)


def draw_head(p, x, y, w, chips):
    cy = y
    if chips:
        tw1 = p.text_width(MODEL, 12)
        cw1 = 10 + 7 + 6 + tw1 + 10
        p.rect([x, cy, x + cw1, cy + 28], radius=14, fill=CARD)
        p.ellipse([x + 10, cy + 10.5, x + 17, cy + 17.5], fill=GOOD)
        p.text((x + 23, cy + 19), MODEL, 12, T1)
        tw2 = p.text_width(SECOND_MODEL, 12)
        cx2 = x + cw1 + 8
        cw2 = 10 + 7 + 6 + tw2 + 10
        p.rect([cx2, cy, cx2 + cw2, cy + 28], radius=14, fill=CHIP)
        p.ellipse([cx2 + 10, cy + 10.5, cx2 + 17, cy + 17.5], fill=GOOD)
        p.text((cx2 + 23, cy + 19), SECOND_MODEL, 12, T1)
        cy += 38

    p.text((x, cy + 21), MODEL, 20, T1, 'SemiBold')
    p.text((x, cy + 39), 'USB · 1.00 TB', 12, T3)
    tw = p.text_width('良好', 12, 'Medium')
    p.ellipse([x + w - tw - 15, cy + 13, x + w - tw - 6, cy + 22], fill=GOOD)
    p.text((x + w, cy + 21), '良好', 12, T2, 'Medium', 'rs')
    p.text((x, cy + 58), '上次扫描 10:24:36', 10, T3)
    return cy + 66


def draw_overview(p, x, y, w, cols, gap):
    items = [('健康状态', '良好', GOOD, None), ('温度', '41 °C', T1, None),
             ('剩余寿命', '97 %', T1, None), ('通电时间', '1,284 小时', T1, '632 次')]
    cw = (w - gap * (cols - 1)) / cols
    rows = int(math.ceil(len(items) / float(cols)))
    for index, (label, value, color, sub) in enumerate(items):
        r = index // cols
        c = index % cols
        cx = x + c * (cw + gap)
        cy = y + r * (96 + gap)
        p.rect([cx, cy, cx + cw, cy + 96], radius=16, fill=CARD)
        p.text((cx + 16, cy + 31), label, 12, T2)
        if index == 0:
            p.ellipse([cx + 16, cy + 49, cx + 28, cy + 61], fill=color)
            p.text((cx + 34, cy + 66), value, 24, color, 'Bold')
        elif index == 3:
            p.text((cx + 16, cy + 62), value, 20, T1, 'Bold')
            if sub:
                p.text((cx + 16, cy + 79), sub, 11, T3)
        else:
            p.text((cx + 16, cy + 66), value, 24, T1, 'Bold')
            if sub:
                p.text((cx + 16, cy + 79), sub, 11, T3)
    return rows * 96 + (rows - 1) * gap


INFO_ENTRIES = [('型号', MODEL), ('容量', '1.00 TB'), ('总线', 'USB'), ('接口', 'UASP (SATA)'),
                ('传输模式', 'SATA/600'), ('外形规格', '2.5 英寸'), ('转速', '固态硬盘'),
                ('固件', 'SVT02B6Q'), ('序列号', SERIAL), ('功能', 'SMART, NCQ, TRIM')]


def draw_info(p, x, y, w):
    rows = int(math.ceil(len(INFO_ENTRIES) / 2.0))
    h = 18 + 20 + 10 + rows * 32 + (rows - 1) * 14 + 18
    p.rect([x, y, x + w, y + h], radius=16, fill=CARD)
    p.text((x + 18, y + 33), '设备信息', 15, T1, 'Medium')
    inner = w - 36
    colw = (inner - 18) / 2.0
    top = y + 49
    for index, (label, value) in enumerate(INFO_ENTRIES):
        c = index % 2
        r = index // 2
        cx = x + 18 + c * (colw + 18)
        ty = top + r * 46
        p.text((cx, ty + 11), label, 11, T3)
        p.text((cx, ty + 28), value, 13, T1)
    return h


TEMPS = [40, 41, 41, 42, 41, 40, 41, 43, 43, 42, 41, 42, 42, 41, 40, 41, 42, 44, 43, 42,
         41, 41, 40, 41, 42, 43, 42, 41, 41, 40]


def draw_chart(p, x, y, w):
    h = 216
    p.rect([x, y, x + w, y + h], radius=16, fill=CARD)
    p.text((x + 18, y + 33), '温度历史', 15, T1, 'Medium')
    p.text((x + w - 96, y + 33), '最低 40 °C', 11, T3, 'Regular', 'rs')
    p.text((x + w - 18, y + 33), '最高 44 °C', 11, T3, 'Regular', 'rs')
    left = x + 18
    top = y + 49
    cw = w - 36
    ch = 150
    bottom = top + ch
    for i in range(4):
        ly = top + 14 + (bottom - top - 28) * i / 3.0
        p.line([left, ly, left + cw, ly], (52, 52, 56), 1)
    lo = min(TEMPS)
    hi = max(TEMPS)
    span = max(hi - lo, 4)
    step = cw / float(len(TEMPS) - 1)
    points = []
    for i, value in enumerate(TEMPS):
        points.append((left + i * step, bottom - 14 - (value - lo) / span * (ch - 28)))
    p.poly(points, ACCENT, 2)
    p.ellipse([points[-1][0] - 3, points[-1][1] - 3, points[-1][0] + 3, points[-1][1] + 3],
              fill=ACCENT)
    p.text((left + 6, top + 18), str(hi), 11, (128, 128, 128))
    p.text((left + 6, bottom - 4), str(lo), 11, (128, 128, 128))
    return h


SMART_ROWS = [('01', '读取错误率', '100', '100', '0', '0', False),
              ('02', '吞吐性能', '100', '100', '0', '0', False),
              ('05', '重新分配扇区计数', '100', '100', '10', '0', False),
              ('09', '通电时间(小时)', '99', '99', '0', '1,284', False),
              ('0C', '通电次数', '99', '99', '0', '632', False),
              ('0D', '软读取错误率探针', '100', '100', '0', '0', False),
              ('C0', '不安全关机计数', '99', '99', '0', '12', False),
              ('C2', '温度', '59', '40', '0', '41', False),
              ('C4', '扇区位置重分配事件计数', '100', '100', '0', '0', False),
              ('C5', '有待处置扇区数', '100', '100', '0', '0', False),
              ('C6', '不可校正的扇区数', '100', '100', '0', '0', False),
              ('F1', '主机总计写入', '99', '99', '0', '7.31 TB', False),
              ('F2', '主机总计读取', '99', '99', '0', '12.84 TB', False),
              ('FF', '剩余寿命', '97', '97', '10', '3', False)]


def draw_smart(p, x, y, w):
    inner = w - 36
    table_w = max(500, inner)
    rows = len(SMART_ROWS)
    table_h = 28 + 1 + rows * 33
    h = 18 + 20 + 10 + table_h + 18
    p.rect([x, y, x + w, y + h], radius=16, fill=CARD)
    p.text((x + 18, y + 33), 'SMART 属性', 15, T1, 'Medium')

    layer = Image.new('RGBA', (int(table_w * SS), int(table_h * SS)), (0, 0, 0, 0))
    tp = P(layer)
    raw_w = 132
    col = 68
    name_w = table_w - 44 - col * 3 - raw_w
    tp.text((0, 19), 'ID', 11, T3)
    tp.text((44, 19), '属性名称', 11, T3)
    right0 = 44 + name_w
    tp.text((right0 + col, 19), '当前值', 11, T3, 'Regular', 'rs')
    tp.text((right0 + col * 2, 19), '最差值', 11, T3, 'Regular', 'rs')
    tp.text((right0 + col * 3, 19), '阈值', 11, T3, 'Regular', 'rs')
    tp.text((table_w, 19), '原始值', 11, T3, 'Regular', 'rs')
    tp.line([0, 28, table_w, 28], DIV, 1)
    for index, row in enumerate(SMART_ROWS):
        rid, name, cur, worst, thr, raw, warn = row
        top = 29 + index * 33
        tp.text((0, top + 21), rid, 12, T2)
        tp.text((44, top + 21), name, 12, T1)
        tp.text((right0 + col, top + 21), cur, 12, BAD if warn else T1, 'Regular', 'rs')
        tp.text((right0 + col * 2, top + 21), worst, 12, T2, 'Regular', 'rs')
        tp.text((right0 + col * 3, top + 21), thr, 12, T2, 'Regular', 'rs')
        tp.text((table_w, top + 21), raw, 12, T2, 'Regular', 'rs')
        tp.line([0, top + 32, table_w, top + 32], DIV, 1)

    crop = layer.crop((0, 0, int(inner * SS), int(table_h * SS)))
    p.img.alpha_composite(crop, (int(p.px(x + 18)), int(p.px(y + 49))))
    return h


def draw_dashboard(p, x, y, w, chips, cols, gap):
    cy = draw_head(p, x, y, w, chips)
    cy += gap
    marks = {'cards': cy}
    cy += draw_overview(p, x, cy, w, cols, 12)
    cy += gap
    marks['info'] = cy
    cy += draw_info(p, x, cy, w)
    cy += gap
    marks['chart'] = cy
    cy += draw_chart(p, x, cy, w)
    cy += gap
    marks['smart'] = cy
    draw_smart(p, x, cy, w)
    return marks


def draw_group(p, x, y, label):
    p.text((x + 16, y + 35), label, 13, T3)
    return y + 45


def draw_nav_card(p, x, y, w, title, subtitle):
    p.rect([x, y, x + w, y + 76], radius=16, fill=CARD)
    if len(subtitle) > 0:
        p.text((x + 16, y + 32), title, 16, T1, 'Medium')
        p.text((x + 16, y + 53), subtitle, 12, T2)
    else:
        p.text((x + 16, y + 43), title, 16, T1, 'Medium')
    icon_chevron(p, x + w - 24, y + 38, 16, T3, 'right')
    return y + 86


def draw_settings_root(p, x, y, w, show_about):
    gy = draw_group(p, x, y, '通用')
    gy = draw_nav_card(p, x, gy, w, '语言', '跟随系统')
    gy = draw_nav_card(p, x, gy, w, '外观', '跟随系统 · 蓝色')
    gy = draw_group(p, x, gy, '检测')
    gy = draw_nav_card(p, x, gy, w, '核心设置', '')
    if show_about:
        gy = draw_group(p, x, gy, '关于')
        gy = draw_nav_card(p, x, gy, w, '关于', '')
    return gy


def draw_settings_appearance(p, x, y, w):
    gy = draw_group(p, x, y, '主题模式')
    rows = [('跟随系统', True), ('浅色', False), ('深色', False)]
    card_h = 52 * len(rows) + (len(rows) - 1)
    p.rect([x, gy, x + w, gy + card_h], radius=16, fill=CARD)
    for index, (label, checked) in enumerate(rows):
        if index > 0:
            p.line([x + 16, gy + index * 53 - 0.5, x + w - 16, gy + index * 53 - 0.5], DIV, 1)
        p.text((x + 16, gy + index * 53 + 31), label, 15, T1)
        if checked:
            icon_check(p, x + w - 26, gy + index * 53 + 26, 18, ACCENT, 2)
    gy += card_h + 22
    gy = draw_group(p, x, gy, '按钮色彩')
    sw_h = 16 + 34 + 6 + 11 + 14
    p.rect([x, gy, x + w, gy + sw_h], radius=16, fill=CARD)
    swatches = [('蓝色', ACCENT, True), ('红色', (232, 80, 92), False),
                ('紫色', (165, 120, 255), False), ('青绿色', (38, 187, 172), False)]
    for index, (label, color, checked) in enumerate(swatches):
        cx = x + w * (index + 0.5) / 4.0
        cy = gy + 16 + 17
        p.ellipse([cx - 17, cy - 17, cx + 17, cy + 17], fill=color)
        if checked:
            icon_check(p, cx, cy, 16, (255, 255, 255), 2)
        p.text((cx, cy + 17 + 6 + 11), label, 11, T1 if checked else T3, 'Regular', 'ms')
    return gy + sw_h


def draw_select(p, x, y, w, value):
    p.rect([x, y, x + w, y + 30], radius=8, fill=(30, 30, 34), outline=(54, 54, 60), width=1)
    p.text((x + 12, y + 19), value, 13, T1)
    icon_chevron(p, x + w - 16, y + 15, 12, T3, 'down')


def draw_toggle(p, x, y, on):
    p.rect([x, y, x + 40, y + 24], radius=12, fill=ACCENT if on else (58, 58, 62))
    knob_x = x + 20 if on else x + 2
    p.ellipse([knob_x, y + 2, knob_x + 20, y + 22], fill=(255, 255, 255))


def draw_settings_detection(p, x, y, w):
    gy = draw_group(p, x, y, '显示')
    rows = [('刷新间隔', '10 s', 'select', 140), ('温度单位', '摄氏度 (°C)', 'select', 160),
            ('原始值显示', '十进制', 'select', 160), ('隐藏序列号', '', 'toggle', 40)]
    p.rect([x, gy, x + w, gy + 52 * 4], radius=16, fill=CARD)
    for index, (label, value, kind, cw) in enumerate(rows):
        ry = gy + index * 52
        if index > 0:
            p.line([x + 16, ry - 0.5, x + w - 16, ry - 0.5], DIV, 1)
        p.text((x + 16, ry + 32), label, 15, T1)
        if kind == 'select':
            draw_select(p, x + w - 16 - cw, ry + 11, cw, value)
        else:
            draw_toggle(p, x + w - 16 - cw, ry + 14, False)
    gy += 52 * 4
    gy = draw_group(p, x, gy, '硬盘状态阈值')
    rows = [('温度告警值', '55 °C', 140), ('重映射扇区 (05)', '1', 140),
            ('待映射扇区 (C5)', '1', 140), ('无法修正扇区 (C6)', '1', 140),
            ('寿命告警水平', '10', 140)]
    p.rect([x, gy, x + w, gy + 52 * len(rows)], radius=16, fill=CARD)
    for index, (label, value, cw) in enumerate(rows):
        ry = gy + index * 52
        if index > 0:
            p.line([x + 16, ry - 0.5, x + w - 16, ry - 0.5], DIV, 1)
        p.text((x + 16, ry + 32), label, 15, T1)
        draw_select(p, x + w - 16 - cw, ry + 11, cw, value)
    return gy + 52 * len(rows)


def wrap_lines(p, text, size, max_w, weight='Regular'):
    lines = []
    cur = ''
    for ch in text:
        if not cur or p.text_width(cur + ch, size, weight) <= max_w:
            cur += ch
        else:
            lines.append(cur)
            cur = ch
    if cur:
        lines.append(cur)
    return lines


HOME_INTRO = 'DiskInfo 读取外接 USB 硬盘的 SMART 数据，实时显示健康状态、温度、通电时间与剩余寿命。'


def draw_home(p, x, y, w):
    cx = x + w / 2.0
    top = y + 16
    p.img.alpha_composite(icon_image(80), (int(p.px(cx - 40)), int(p.px(top + 24))))
    brand_y = top + 24 + 80 + 12
    p.text((cx, brand_y), 'DiskInfo', 26, T1, 'Bold', 'mt')
    p.text((cx, brand_y + 40), '硬盘健康监测', 14, T2, 'Regular', 'mt')
    intro_top = brand_y + 40 + 19 + 12
    intro = wrap_lines(p, HOME_INTRO, 14, w)
    for index, line in enumerate(intro):
        p.text((cx, intro_top + index * 22), line, 14, T2, 'Regular', 'mt')
    gy = intro_top + len(intro) * 22 + 8 + 20
    p.text((x, gy), '使用步骤', 15, T1, 'Medium', 'lt')
    card_top = gy + 21 + 8
    steps = [('1', '连接硬盘', '用 USB 连接外接硬盘或硬盘盒，按系统提示允许访问。'),
             ('2', '自动读取', '应用按设置的间隔自动扫描，识别型号、容量、温度与 SMART 属性。'),
             ('3', '查看健康', '在「硬盘」页查看各项指标，读取异常时到诊断页排查。')]
    row_h = 88
    card_h = row_h * 3
    p.rect([x, card_top, x + w, card_top + card_h], radius=16, fill=CARD)
    for index, (num, title, desc) in enumerate(steps):
        ty = card_top + index * row_h
        p.ellipse([x + 16, ty + 14, x + 44, ty + 42], fill=ACCENT_BG)
        p.text((x + 30, ty + 33), num, 13, ACCENT, 'Medium', 'ms')
        p.text((x + 56, ty + 14), title, 15, T1, 'Medium', 'lt')
        desc_lines = wrap_lines(p, desc, 13, w - 32 - 40)
        for line_index, line in enumerate(desc_lines):
            p.text((x + 56, ty + 38 + line_index * 18), line, 13, T2, 'Regular', 'lt')
        if index < 2:
            p.line([x + 56, ty + row_h - 0.5, x + w - 16, ty + row_h - 0.5], DIV, 0.5)
    return card_top + card_h


def draw_tabbar(p, w, h, active):
    if w >= 840:
        bar_w = 420
    elif w >= 600:
        bar_w = 360
    else:
        bar_w = 328
    x = (w - bar_w) / 2.0
    y = h - 16 - 56
    p.rect([x, y, x + bar_w, y + 56], radius=28, fill=TABBAR)
    p.rect([x + 0.5, y + 0.5, x + bar_w - 0.5, y + 55.5], radius=28,
           outline=(58, 58, 64), width=1)
    half = (bar_w - 12) / 2.0
    for index, label in enumerate(['首页', '硬盘']):
        tx = x + 6 + index * half
        selected = (index == 0) == (active == 'home')
        if selected:
            p.rect([tx, y + 6, tx + half, y + 50], radius=22, fill=ACCENT_BG)
        color = ACCENT if selected else T2
        ccx = tx + half / 2.0
        if index == 0:
            icon_house(p, ccx, y + 24, 20, color, 1.8)
        else:
            icon_drive(p, ccx, y + 24, 20, color)
        p.text((ccx, y + 43), label, 10, color, 'Regular', 'ms')


# ── screens ───────────────────────────────────────────────────────────

def render_phone(view):
    scr = Screen(400, 700)
    p = scr.p
    p.rect([0, 0, 400, 86], fill=CARD)
    p.rect([0, 86, 400, 700], fill=PAGE)
    draw_status(p, 400, 30, camera=True)
    p.line([0, 85.5, 400, 85.5], DIV, 1)

    title = {'home': '首页', 'dashboard': '硬盘', 'smart': '硬盘', 'settings': '外观'}[view]
    if view == 'settings':
        draw_back(p, 18, 58)
        p.text((200, 58), title, 20, T1, 'SemiBold', 'ms')
    else:
        p.text((200, 58), title, 20, T1, 'SemiBold', 'ms')
        draw_menus(p, 400, 58)

    layer = Image.new('RGBA', (int(400 * SS), int(2000 * SS)), (0, 0, 0, 0))
    lp = P(layer)
    if view == 'home':
        draw_home(lp, 16, 0, 368)
        scroll = 0
    elif view == 'settings':
        draw_settings_appearance(lp, 16, 4, 368)
        scroll = 0
    else:
        marks = draw_dashboard(lp, 16, 8, 368, True, 2, 12)
        scroll = 0 if view == 'dashboard' else marks['chart'] - 8

    viewport = 614
    crop = layer.crop((0, int(scroll * SS), int(400 * SS), int((scroll + viewport) * SS)))
    scr.img.alpha_composite(crop, (0, int(86 * SS)))
    draw_tabbar(p, 400, 700, 'home' if view == 'home' else 'disks')
    return scr.finish()


def render_tablet(view):
    scr = Screen(1120, 746)
    p = scr.p
    p.rect([0, 0, 1120, 86], fill=CARD)
    p.rect([0, 86, 1120, 746], fill=PAGE)
    draw_status(p, 1120, 30)
    p.line([0, 85.5, 1120, 85.5], DIV, 1)

    if view == 'appearance':
        draw_back(p, 18, 58)
        p.text((560, 58), '外观', 20, T1, 'SemiBold', 'ms')
    else:
        p.text((560, 58), '硬盘', 20, T1, 'SemiBold', 'ms')
        draw_menus(p, 1120, 58)

    layer = Image.new('RGBA', (int(1120 * SS), int(2000 * SS)), (0, 0, 0, 0))
    lp = P(layer)
    if view == 'appearance':
        draw_settings_appearance(lp, 24, 4, 1072)
        scroll = 0
    else:
        marks = draw_dashboard(lp, 24, 8, 1072, True, 4, 14)
        scroll = 0 if view == 'dashboard' else marks['smart'] - 12

    viewport = 660
    crop = layer.crop((0, int(scroll * SS), int(1120 * SS), int((scroll + viewport) * SS)))
    scr.img.alpha_composite(crop, (0, int(86 * SS)))
    draw_tabbar(p, 1120, 746, 'disks')
    return scr.finish()


def render_pc(view):
    scr = Screen(1440, 810)
    p = scr.p
    p.rect([0, 0, 1440, 810], fill=PAGE)
    draw_sidebar(p, 0, 0, 280, 810)
    p.line([279.5, 0, 279.5, 810], DIV, 1)
    p.rect([280, 0, 1440, 56], fill=CARD)
    p.line([280, 55.5, 1440, 55.5], DIV, 1)

    if view == 'detection':
        draw_back(p, 298, 28)
        p.text((324, 28), '核心设置', 20, T1, 'SemiBold', 'lm')
    else:
        p.text((296, 28), '硬盘', 20, T1, 'SemiBold', 'lm')
        draw_menus(p, 1440, 28)

    layer = Image.new('RGBA', (int(1440 * SS), int(2000 * SS)), (0, 0, 0, 0))
    lp = P(layer)
    if view == 'detection':
        draw_settings_detection(lp, 304, 4, 1112)
        scroll = 0
    else:
        marks = draw_dashboard(lp, 304, 0, 1112, False, 4, 14)
        scroll = 0 if view == 'dashboard' else marks['smart'] - 8

    viewport = 754
    crop = layer.crop((0, int(scroll * SS), int(1440 * SS), int((scroll + viewport) * SS)))
    scr.img.alpha_composite(crop, (0, int(56 * SS)))
    return scr.finish()


# ── device frames ─────────────────────────────────────────────────────

def laptop_frame(app, screen_w=1160, screen_h=653):
    screen = app.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 12
    fw, fh = screen_w + bezel * 2, screen_h + bezel * 2
    frame = Image.new('RGBA', (fw, fh + 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, fw - 1, fh - 1], radius=20, fill=(20, 22, 25, 255))
    d.rounded_rectangle([1, 1, fw - 2, fh - 2], radius=19, outline=(48, 52, 58, 255), width=2)
    mask = Image.new('L', (screen_w * 2, screen_h * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w * 2 - 1, screen_h * 2 - 1],
                                          radius=10, fill=255)
    mask = mask.resize((screen_w, screen_h), Image.LANCZOS)
    frame.paste(screen, (bezel, bezel), mask)
    d = ImageDraw.Draw(frame)
    d.ellipse([fw / 2.0 - 2.5, bezel / 2.0 - 2.5, fw / 2.0 + 2.5, bezel / 2.0 + 2.5],
              fill=(10, 12, 14, 255))
    base_w = fw + 136
    base_x = (fw - base_w) / 2.0
    d.rounded_rectangle([base_x, fh - 2, base_x + base_w, fh + 30], radius=12, fill=(42, 46, 50, 255))
    d.rectangle([base_x + 12, fh - 2, base_x + base_w - 12, fh + 3], fill=(64, 69, 74, 255))
    d.rounded_rectangle([fw / 2.0 - 110, fh + 1, fw / 2.0 + 110, fh + 11], radius=5,
                        fill=(15, 17, 19, 255))
    d.line([base_x + 3, fh + 30, base_x + base_w - 3, fh + 30], fill=(22, 24, 26, 255), width=2)
    return frame


def tablet_frame(app, screen_w=1120, screen_h=746):
    bezel = 24
    fw, fh = screen_w + bezel * 2, screen_h + bezel * 2
    frame = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, fw - 1, fh - 1], radius=40, fill=(20, 22, 25, 255))
    d.rounded_rectangle([1, 1, fw - 2, fh - 2], radius=39, outline=(54, 60, 66, 255), width=2)
    mask = Image.new('L', (screen_w * 2, screen_h * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w * 2 - 1, screen_h * 2 - 1],
                                          radius=36, fill=255)
    mask = mask.resize((screen_w, screen_h), Image.LANCZOS)
    frame.paste(app, (bezel, bezel), mask)
    d = ImageDraw.Draw(frame)
    d.ellipse([fw / 2.0 - 3.5, bezel / 2.0 - 3.5, fw / 2.0 + 3.5, bezel / 2.0 + 3.5],
              fill=(8, 10, 12, 255))
    return frame


def phone_frame(app, screen_w=720, screen_h=1260):
    screen = app.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 24
    fw, fh = screen_w + bezel * 2, screen_h + bezel * 2
    frame = Image.new('RGBA', (fw + 5, fh), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, fw - 1, fh - 1], radius=62, fill=(18, 20, 24, 255))
    d.rounded_rectangle([1, 1, fw - 2, fh - 2], radius=61, outline=(50, 55, 62, 255), width=2)
    mask = Image.new('L', (screen_w * 2, screen_h * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w * 2 - 1, screen_h * 2 - 1],
                                          radius=44, fill=255)
    mask = mask.resize((screen_w, screen_h), Image.LANCZOS)
    frame.paste(screen, (bezel, bezel), mask)
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([fw + 1, 300, fw + 4, 392], radius=2, fill=(44, 48, 54, 255))
    return frame


# ── promo composition ─────────────────────────────────────────────────

def make_glow_background(width, height, core, wide):
    small_w, small_h = 480, 320
    base = Image.new('RGB', (small_w, small_h), (5, 8, 14))
    px = base.load()
    cx, cy = core
    wx, wy = wide
    for y in range(small_h):
        for x in range(small_w):
            nx = x / float(small_w)
            ny = y / float(small_h)
            d1 = math.hypot(nx - cx, (ny - cy) * 0.85)
            d2 = math.hypot(nx - wx, (ny - wy) * 0.7)
            g1 = max(0.0, 1.0 - d1 / 0.62) ** 2
            g2 = max(0.0, 1.0 - d2 / 1.05) ** 2
            r = 5 + 13 * g1 + 8 * g2
            g = 8 + 38 * g1 + 24 * g2
            b = 14 + 112 * g1 + 64 * g2
            px[x, y] = (int(min(255, r)), int(min(255, g)), int(min(255, b)))
    img = base.resize((width, height), Image.LANCZOS)
    noise = Image.effect_noise((width, height), 7).convert('L')
    noise_rgba = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    noise_rgba.putalpha(noise.point(lambda v: int(v * 0.035)))
    img = img.convert('RGBA')
    img.alpha_composite(noise_rgba)
    return img


def cast_shadow(canvas, box, blur):
    shadow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([box[0], box[1], box[2], box[3]], fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow)


def draw_brand(canvas, p, left, top):
    canvas.alpha_composite(icon_image(64), (left, top))
    name_x = left + 64 + 18
    p.text((name_x, top + 45), 'DiskInfo', 40, HEAD, 'SemiBold')
    name_w = p.text_width('DiskInfo', 40, 'SemiBold')
    pill_x = name_x + name_w + 16
    p.rect([pill_x, top + 13, pill_x + 66, top + 51], radius=19, fill=(12, 15, 22),
           outline=(35, 42, 55), width=1)
    p.text((pill_x + 33, top + 33), '1.0', 22, (147, 160, 180), 'Regular', 'mm')


def draw_brand_phone(canvas, p, width):
    icon = icon_image(60)
    name = 'DiskInfo'
    nw = p.text_width(name, 38, 'SemiBold')
    total = 60 + 18 + nw + 16 + 66
    x = (width - total) / 2.0
    top = 56
    canvas.alpha_composite(icon, (int(x), top))
    p.text((x + 78, top + 44), name, 38, HEAD, 'SemiBold')
    pill_x = x + 78 + nw + 16
    p.rect([pill_x, top + 10, pill_x + 66, top + 48], radius=19, fill=(12, 15, 22),
           outline=(35, 42, 55), width=1)
    p.text((pill_x + 33, top + 30), '1.0', 22, (147, 160, 180), 'Regular', 'mm')


def draw_badge(p, right, top, label='本地读取'):
    tw = p.text_width(label, 20)
    w = 34 + tw + 40
    x = right - w
    p.rect([x, top, right, top + 40], radius=20, fill=(10, 13, 20), outline=(32, 42, 60), width=1)
    p.ellipse([x + 18, top + 15, x + 28, top + 25], fill=HEAD_ACCENT)
    p.text((x + 36, top + 21), label, 20, (183, 196, 212))


def draw_copy(p, spec, tablet):
    if tablet:
        eyebrow_y, line1_y, line2_y = 188, 300, 402
        desc_y, chips_y, check_y, footer_y = 445, 536, 632, 1180
    else:
        eyebrow_y, line1_y, line2_y = 158, 265, 357
        desc_y, chips_y, check_y, footer_y = 408, 482, 580, 1025

    p.line([110, eyebrow_y - 10, 150, eyebrow_y - 10], HEAD_ACCENT, 3)
    p.text((160, eyebrow_y), spec['eyebrow'], 22, EYEBROW, 'Medium')

    p.text((108, line1_y), spec['line1'], 92, HEAD, 'Bold')
    p.text((108, line2_y), spec['line2'], 92, HEAD_ACCENT, 'Bold')

    dy = desc_y
    for line in spec['desc']:
        p.text((110, dy), line, 30, DESC)
        dy += 42

    cx = 110
    for chip in spec['chips']:
        tw = p.text_width(chip, 21)
        w = 18 + 10 + 12 + tw + 18
        p.rect([cx, chips_y, cx + w, chips_y + 44], radius=22, fill=CHIP_BG,
               outline=CHIP_LINE, width=1)
        p.ellipse([cx + 18, chips_y + 17, cx + 28, chips_y + 27], fill=HEAD_ACCENT)
        p.text((cx + 40, chips_y + 23), chip, 21, CHIP_TEXT)
        cx += w + 12

    for index, row in enumerate(spec['checks']):
        cy = check_y + index * 52 + 13
        icon_check_circle(p, 123, cy, 26, CHECK_RING, HEAD_ACCENT, 2)
        p.text((152, cy + 9), row, 26, CHECK_TEXT)

    p.text((110, footer_y), 'DiskInfo 1.0', 24, FOOT)
    p.text((520, footer_y), spec['footer'], 24, FOOT)


def draw_copy_phone(p, width, spec):
    cx = width / 2.0
    dash = 18
    tw = p.text_width(spec['eyebrow'], 22)
    group = dash + 10 + tw
    start = cx - group / 2.0
    p.line([start, 141, start + dash, 141], HEAD_ACCENT, 3)
    p.text((start + dash + 10, 150), spec['eyebrow'], 22, EYEBROW, 'Medium')
    p.text((cx, 236), spec['line1'], 82, HEAD, 'Bold', 'ms')
    p.text((cx, 330), spec['line2'], 82, HEAD_ACCENT, 'Bold', 'ms')

    dy = 384
    for line in spec['desc']:
        p.text((cx, dy), line, 26, DESC, 'Regular', 'ms')
        dy += 36

    widths = [p.text_width(chip, 21) + 58 for chip in spec['chips']]
    total = sum(widths) + 12 * (len(widths) - 1)
    x = cx - total / 2.0
    for chip, w in zip(spec['chips'], widths):
        p.rect([x, 448, x + w, 492], radius=22, fill=CHIP_BG, outline=CHIP_LINE, width=1)
        p.ellipse([x + 18, 465, x + 28, 475], fill=HEAD_ACCENT)
        p.text((x + 40, 471), chip, 21, CHIP_TEXT)
        x += w + 12

    p.text((60, 1872), 'DiskInfo 1.0', 22, FOOT)
    p.text((1020, 1872), spec['footer'], 22, FOOT, 'Regular', 'rs')


def compose_pc(spec):
    W, H = 1920, 1080
    canvas = make_glow_background(W, H, (0.70, 0.46), (0.25, 0.52))
    cast_shadow(canvas, (700, 860, 1850, 975), 45)
    canvas.alpha_composite(laptop_frame(render_pc(spec['view'])), (690, 200))
    p = P(canvas, 1)
    draw_brand(canvas, p, 110, 62)
    draw_badge(p, 1810, 74)
    draw_copy(p, spec, False)
    return canvas.convert('RGB')


def compose_tablet(spec):
    W, H = 1920, 1280
    canvas = make_glow_background(W, H, (0.70, 0.45), (0.22, 0.52))
    cast_shadow(canvas, (740, 960, 1840, 1090), 45)
    canvas.alpha_composite(tablet_frame(render_tablet(spec['view'])), (700, 232))
    p = P(canvas, 1)
    draw_brand(canvas, p, 110, 68)
    draw_badge(p, 1810, 80)
    draw_copy(p, spec, True)
    return canvas.convert('RGB')


def compose_phone(spec):
    W, H = 1080, 1920
    canvas = make_glow_background(W, H, (0.5, 0.42), (0.5, 1.0))
    cast_shadow(canvas, (150, 1710, 950, 1820), 42)
    canvas.alpha_composite(phone_frame(render_phone(spec['view'])), (153, 520))
    p = P(canvas, 1)
    draw_brand_phone(canvas, p, W)
    draw_badge(p, 1016, 62)
    draw_copy_phone(p, W, spec)
    return canvas.convert('RGB')


PC = [
    {'name': 'pc_01_dashboard', 'view': 'dashboard', 'eyebrow': '电脑端',
     'line1': '外接硬盘', 'line2': '健康一屏掌握',
     'desc': ['插上 USB 硬盘即可读取 SMART 数据', '型号、温度、寿命与属性同屏呈现'],
     'chips': ['USB 直读', '侧栏导航', '实时温度'],
     'checks': ['健康状态与剩余寿命一目了然', '温度历史持续采样', '完整 SMART 属性表'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
    {'name': 'pc_02_smart', 'view': 'smart', 'eyebrow': '电脑端',
     'line1': 'SMART 全表', 'line2': '原始值尽览',
     'desc': ['当前值、最差值、阈值与原始值逐行对照', '列宽随窗格自适应，长值自动省略'],
     'chips': ['SATA / NVMe', '原始值', '阈值告警'],
     'checks': ['内置 SATA 与 NVMe 属性字典', '阈值异常即时标红', '原始值支持十六进制'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
    {'name': 'pc_03_settings', 'view': 'detection', 'eyebrow': '电脑端',
     'line1': '检测参数', 'line2': '精细调校',
     'desc': ['刷新间隔、温度单位与硬盘状态阈值', '全部集中在核心设置里逐项调整'],
     'chips': ['刷新间隔', '温度单位', '阈值告警'],
     'checks': ['刷新间隔 5–60 秒可选', '摄氏度与华氏度自由切换', '五项阈值与温度告警'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
]

TABLET = [
    {'name': 'tablet_01_dashboard', 'view': 'dashboard', 'eyebrow': '平板端',
     'line1': '大屏仪表', 'line2': '数据一望而知',
     'desc': ['宽屏自动铺开概览卡片与设备信息', '温度曲线即时呈现，属性表向下展开'],
     'chips': ['宽屏布局', '四栏概览', '实时刷新'],
     'checks': ['概览卡片自适应排布', '设备信息双栏呈现', '首页与硬盘一键切换'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
    {'name': 'tablet_02_smart', 'view': 'smart', 'eyebrow': '平板端',
     'line1': 'SMART 属性', 'line2': '一览无余',
     'desc': ['完整属性表在宽屏上舒展排布', '当前、最差、阈值与原始值并列对照'],
     'chips': ['完整属性', '并行对照', '原始值'],
     'checks': ['列宽随窗口自适应', '阈值告警即时标红', '支持十进制与十六进制'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
    {'name': 'tablet_03_appearance', 'view': 'appearance', 'eyebrow': '平板端',
     'line1': '三种主题', 'line2': '四种色彩',
     'desc': ['跟随系统、浅色或深色，随时切换', '强调色一键更换，整套界面同步'],
     'chips': ['跟随系统', '深色模式', '强调色'],
     'checks': ['主题选择即时生效', '强调色全局统一', '七种界面语言'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
]

PHONE = [
    {'name': 'phone_01_home', 'view': 'home', 'eyebrow': '手机端',
     'line1': '插上硬盘', 'line2': '即刻体检',
     'desc': ['读取外接 USB 硬盘的 SMART 数据', '无需驱动，所有信息本机处理'],
     'chips': ['USB 直读', '即插即用', '本机处理'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_02_dashboard', 'view': 'dashboard', 'eyebrow': '手机端',
     'line1': '外接硬盘', 'line2': '状态尽在掌心',
     'desc': ['健康、温度、寿命与通电时间一屏呈现', '设备信息与完整 SMART 属性随手可查'],
     'chips': ['概览卡片', '实时温度', '悬浮页签'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_03_smart', 'view': 'smart', 'eyebrow': '手机端',
     'line1': 'SMART 全表', 'line2': '逐项细看',
     'desc': ['当前值、最差值、阈值与原始值逐行对照', '滑动查看全部属性，异常项自动标红'],
     'chips': ['全属性', '原始值', '阈值告警'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_04_settings', 'view': 'settings', 'eyebrow': '手机端',
     'line1': '主题与色彩', 'line2': '随你心意',
     'desc': ['跟随系统、浅色、深色三种主题模式', '蓝色、红色、紫色、青绿色四种强调色'],
     'chips': ['三种主题', '四种色彩', '即时生效'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for spec in PC:
        image = compose_pc(spec)
        target = os.path.join(OUT, spec['name'] + '.png')
        image.save(target)
        print(target, image.size)
    for spec in TABLET:
        image = compose_tablet(spec)
        target = os.path.join(OUT, spec['name'] + '.png')
        image.save(target)
        print(target, image.size)
    for spec in PHONE:
        image = compose_phone(spec)
        target = os.path.join(OUT, spec['name'] + '.png')
        image.save(target)
        print(target, image.size)


if __name__ == '__main__':
    main()
