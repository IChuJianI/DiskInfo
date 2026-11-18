#!/usr/bin/env python3
"""Promo sheets built on real app screenshots.

Chrome, title bars, sidebars and tab bars come from captures of the installed
app; only the disk data modules (overview cards, info grid, chart, SMART table)
are drawn, because no real USB disk was attached when the screenshots were
taken. Layout constants mirror entry/src/main/ets (OverviewCards, DeviceInfoGrid,
ThermalChart, SmartTable, Index.dashboard).
"""

import os
import sys
import math

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_promo import (P, make_glow_background, cast_shadow, draw_brand,
                        draw_brand_phone, draw_badge, draw_copy, draw_copy_phone,
                        laptop_frame, HEAD, HEAD_ACCENT, CHIP_TEXT, CHIP_BG,
                        CHIP_LINE, FOOT, EYEBROW)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'store/promo')
DEBUG = os.path.join(ROOT, 'tools/promo_debug')
SHOT_DIR = os.environ.get('DISKINFO_SHOT_DIR') or os.path.join(
    os.path.expanduser('~'), 'Download', '新建文件夹 2')

SHOTS = {
    ('pc', 'home'): 'screenshot_20261116_163656_com.52wfun.diskinfo.jpg',
    ('pc', 'core'): 'screenshot_20261116_163717_com.52wfun.diskinfo.jpg',
    ('pc', 'disk'): 'screenshot_20261116_163744_com.52wfun.diskinfo.jpg',
    ('tab', 'home'): 'screenshot_20261116_163805_com.52wfun.diskinfo.jpg',
    ('tab', 'disk'): 'screenshot_20261116_163812_com.52wfun.diskinfo.jpg',
    ('tab', 'core'): 'screenshot_20261116_163822_com.52wfun.diskinfo.jpg',
    ('ph', 'home'): 'screenshot_20261116_163833_com.52wfun.diskinfo.jpg',
    ('ph', 'disk'): 'screenshot_20261116_163839_com.52wfun.diskinfo.jpg',
    ('ph', 'core'): 'screenshot_20261116_163847_com.52wfun.diskinfo.jpg',
}

INSET = 10
D = 1.9  # px per vp on this display, derived from 52vp settings rows ~= 100px

PAGE = (16, 16, 20)
CARD = (28, 28, 30)
T1 = (232, 232, 233)
T2 = (164, 164, 165)
T3 = (119, 119, 120)
DIV = (62, 62, 64)
GOOD = (61, 208, 104)
CHART = (10, 89, 247)
GRID = (128, 128, 128)
SCAN_OP = (118, 118, 118)

MODEL = 'Samsung SSD 870 EVO 1TB'
BUS_CAP = 'USB · 1.00 TB'
HEALTH = '良好'

INFO = [('型号', MODEL), ('容量', '1.00 TB'), ('总线', 'USB'), ('接口', 'UASP (SATA)'),
        ('传输模式', 'SATA/600'), ('外形规格', '2.5 英寸'), ('转速', '固态硬盘'),
        ('固件', 'SVT02B6Q'), ('序列号', 'S6PTNX0T912345'), ('功能', 'SMART, NCQ, TRIM')]

TEMPS = [41, 42, 41, 40, 41, 43, 44, 43, 42, 41, 42, 43, 42]

SMART = [
    ('01', '读取错误率', '100', '100', '0', '0'),
    ('02', '吞吐性能', '100', '100', '0', '0'),
    ('03', '启动时间', '100', '100', '0', '0'),
    ('04', '启动-停止次数', '99', '99', '0', '632'),
    ('05', '重新分配扇区计数', '100', '100', '10', '0'),
    ('06', '读取通道余量', '100', '100', '10', '0'),
    ('07', '寻址错误率', '100', '100', '0', '0'),
    ('08', '寻址时间性能', '100', '100', '0', '0'),
    ('09', '通电时间(小时)', '99', '99', '0', '1,284'),
    ('0A', '启动重试次数', '100', '100', '0', '0'),
    ('0B', '重新校准重试次数', '100', '100', '0', '0'),
    ('0C', '通电次数', '99', '99', '0', '632'),
    ('0D', '软读取错误率探针', '100', '100', '0', '0'),
    ('C0', '不安全关机计数', '99', '99', '0', '12'),
    ('C2', '温度', '59', '40', '0', '41'),
    ('C4', '扇区位置重分配事件计数', '100', '100', '0', '0'),
    ('C5', '有待处置扇区数', '100', '100', '0', '0'),
    ('C6', '不可校正的扇区数', '100', '100', '0', '0'),
    ('F1', '主机总计写入', '99', '99', '0', '7.31 TB'),
    ('F2', '主机总计读取', '99', '99', '0', '12.84 TB'),
    ('FF', '剩余寿命', '97', '97', '10', '3'),
]


def load_shot(kind, page):
    img = Image.open(os.path.join(SHOT_DIR, SHOTS[(kind, page)])).convert('RGB')
    w, h = img.size
    return img.crop((INSET, INSET, w - INSET, h - INSET))


def row_median(img, y, x0, x1, step=7):
    px = img.load()
    vals = []
    for x in range(x0, x1, step):
        r, g, b = px[x, y]
        vals.append(r + g + b)
    vals.sort()
    return vals[len(vals) // 2]


def header_bottom(img, x0):
    w, h = img.size
    for y in range(40, min(160, h)):
        if row_median(img, y, x0 + 30, w - 30) < 70:
            return y
    return 100


def sidebar_edge(img):
    """Find the vertical divider between sidebar (#1C1C1E) and content."""
    import numpy as np
    a = np.asarray(img.convert('L')).astype(int)
    h, w = a.shape
    band = a[150:h - 150, 380:min(780, w)]
    count = ((band > 45) & (band < 130)).sum(axis=0)
    idx = int(np.argmax(count))
    if count[idx] > 0.85 * band.shape[0]:
        return 380 + idx
    return 0


def find_tab_bar(img):
    """Return padded bbox of the floating tab bar in the cropped capture."""
    import numpy as np
    a = np.asarray(img).astype(int)
    h, w, _ = a.shape
    y0 = h - 220
    m = a[y0:, :, :].sum(axis=2) > 78
    cols = m.sum(axis=0)
    rows = m.sum(axis=1)
    xs = np.where(cols > 40)[0]
    ys = np.where(rows > 200)[0]
    if len(xs) == 0 or len(ys) == 0:
        return None
    return (int(xs.min()), int(y0 + ys.min()), int(xs.max() + 1), int(y0 + ys.max() + 1))


def capsule_mask(size, radius, scale=4):
    w, h = size
    mask = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1],
                                           radius=radius * scale, fill=255)
    return mask.resize((w, h), Image.LANCZOS)


class Vp:
    """vp painter anchored at the content origin, scaled by D."""

    def __init__(self, img):
        self.p = P(img, D)

    def text(self, xy, s, size, fill, weight='Regular', anchor='ls'):
        self.p.text(xy, s, size, fill, weight, anchor)

    def width(self, s, size, weight='Regular'):
        return self.p.text_width(s, size, weight)

    def rect(self, box, fill=None, outline=None, width=1, radius=0):
        self.p.rect(box, fill, outline, width, radius)

    def line(self, xy, fill, width=1):
        self.p.line(xy, fill, width)

    def poly(self, pts, fill, width=1):
        self.p.poly(pts, fill, width)

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.p.ellipse(box, fill, outline, width)

    def dot(self, cx, cy, r, fill, scale=4):
        w = max(1, int(round(2 * r * self.p.ss)))
        mask = Image.new('L', (w * scale, w * scale), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, w * scale - 1, w * scale - 1], fill=255)
        mask = mask.resize((w, w), Image.LANCZOS)
        stamp = Image.new('RGBA', (w, w), tuple(fill) + (255,))
        self.p.img.paste(stamp, (int(round((cx - r) * self.p.ss)),
                                 int(round((cy - r) * self.p.ss))), mask)


def fit(v, s, size, weight, width):
    if v.width(s, size, weight) <= width:
        return s
    while s and v.width(s + '…', size, weight) > width:
        s = s[:-1]
    return s + '…'


def wrap_words(v, s, size, weight, width, max_lines):
    words = s.split(' ')
    lines = []
    cur = ''
    for word in words:
        trial = word if not cur else cur + ' ' + word
        if v.width(trial, size, weight) <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    if len(lines) > max_lines:
        lines = lines[:max_lines]
        lines[-1] = fit(v, lines[-1] + '…', size, weight, width)
    return lines


def draw_head(v, cw, scan, y=0):
    health_w = 9 + 6 + v.width(HEALTH, 12, 'Medium')
    v.text((0, y + 21), fit(v, MODEL, 20, 'Bold', cw - 10 - health_w), 20, T1, 'Bold')
    v.text((0, y + 44), BUS_CAP, 12, T3)
    dot_x = cw - health_w
    v.dot(dot_x + 4.5, y + 24, 4.5, GOOD)
    v.text((dot_x + 15, y + 28), HEALTH, 12, T2, 'Medium')
    v.text((0, y + 68), '上次扫描 ' + scan, 10, T3)
    return 72


def draw_overview(v, cw, cols, y):
    gut = 12
    cw_card = (cw - gut * (cols - 1)) / cols
    cards = [
        ('健康状态', '良好', 24, GOOD, 'health', None),
        ('温度', '41 °C', 24, T1, None, None),
        ('剩余寿命', '97 %', 24, T1, None, None),
        ('通电时间', '1,284 小时', 20, T1, None, '632 次'),
    ]
    for i, (label, value, vs, color, kind, sub) in enumerate(cards):
        r, c = divmod(i, cols)
        x = c * (cw_card + gut)
        yy = y + r * 108
        v.rect([x, yy, x + cw_card, yy + 96], fill=CARD, radius=16)
        lh = vs * 1.32
        block = 16 + 6 + lh + (15 if sub else 0)
        top = yy + (96 - block) / 2.0
        v.text((x + 16, top + 12), label, 12, T2)
        base = top + 16 + 6 + vs * 0.98
        if kind == 'health':
            v.dot(x + 16 + 6, base - vs * 0.35, 6, color)
            v.text((x + 36, base), value, vs, color, 'Bold')
        else:
            v.text((x + 16, base), value, vs, color, 'Bold')
            if sub:
                v.text((x + 16, base + 16), sub, 11, T3)
    rows = (len(cards) + cols - 1) // cols
    return 96 * rows + 12 * (rows - 1)


def draw_info(v, cw, y):
    pad = 18
    col_w = (cw - pad * 2 - 18) / 2.0
    cells = []
    for label, value in INFO:
        lines = wrap_words(v, value, 13, 'Regular', col_w, 2)
        cells.append((label, lines))
    rows = (len(cells) + 1) // 2
    row_hs = []
    for r in range(rows):
        pair = cells[r * 2:r * 2 + 2]
        hs = [15 + 4 + 17 * len(lines) for _, lines in pair]
        row_hs.append(max(hs))
    height = pad * 2 + 20 + 14 + sum(row_hs) + 14 * (rows - 1)
    v.rect([0, y, cw, y + height], fill=CARD, radius=16)
    v.text((pad, y + pad + 16), '设备信息', 15, T1, 'Medium')
    top = y + pad + 20 + 14
    for i, (label, lines) in enumerate(cells):
        r, c = divmod(i, 2)
        x = pad + c * (col_w + 18)
        yy = top + sum(row_hs[:r]) + 14 * r
        v.text((x, yy + 11), fit(v, label, 11, 'Regular', col_w), 11, T3)
        for j, line in enumerate(lines):
            v.text((x, yy + 30 + j * 17), line, 13, T1)
    return height


def draw_chart(v, cw, y):
    pad = 18
    height = 216
    v.rect([0, y, cw, y + height], fill=CARD, radius=16)
    v.text((pad, y + pad + 15), '温度历史', 15, T1, 'Medium')
    right = cw - pad
    v.text((right, y + pad + 12), '44 °C', 11, T3, 'Regular', 'rs')
    w44 = v.width('44 °C', 11)
    v.text((right - w44 - 4, y + pad + 12), '最高', 11, T3, 'Regular', 'rs')
    wl = v.width('最高', 11)
    v.text((right - w44 - 4 - wl - 16, y + pad + 12), '40 °C', 11, T3, 'Regular', 'rs')
    w40 = v.width('40 °C', 11)
    v.text((right - w44 - 4 - wl - 16 - w40 - 4, y + pad + 12), '最低', 11, T3, 'Regular', 'rs')

    cx0, cx1 = pad, cw - pad
    cy0 = y + pad + 20 + 10
    ch = 150
    lo = min(TEMPS)
    hi = max(TEMPS)
    if hi - lo < 4:
        hi = lo + 4
    top = 14
    bottom = ch - 14
    for i in range(4):
        gy = cy0 + top + (bottom - top) * i / 3.0
        v.line([cx0, gy, cx1, gy], (50, 50, 53), 1)
    step = (cx1 - cx0) / (len(TEMPS) - 1)
    pts = []
    for i, t in enumerate(TEMPS):
        px = cx0 + i * step
        py = cy0 + bottom - (t - lo) / (hi - lo) * (bottom - top)
        pts.append((px, py))
    v.poly(pts, CHART, 2)
    lx, ly = pts[-1]
    v.dot(lx, ly, 3, CHART)
    v.text((cx0 + 6, cy0 + top + 11), str(hi), 11, SCAN_OP)
    v.text((cx0 + 6, cy0 + bottom - 1), str(lo), 11, SCAN_OP)
    return height


def draw_smart(v, cw, y):
    pad = 18
    inner = cw - pad * 2
    table_w = max(500.0, inner)
    head_h = 28
    row_h = 32
    body_h = head_h + 1 + len(SMART) * (row_h + 1)
    height = pad * 2 + 20 + 10 + body_h
    v.rect([0, y, cw, y + height], fill=CARD, radius=16)
    v.text((pad, y + pad + 15), 'SMART 属性', 15, T1, 'Medium')

    table = Image.new('RGBA', (int(round(table_w * D)), int(round(body_h * D))), (0, 0, 0, 0))
    tv = Vp(table)
    tw = table_w
    id_w, col_w, raw_w = 44, 68, 132
    name_w = tw - id_w - col_w * 3 - raw_w

    tv.text((0, 19), 'ID', 11, T3)
    tv.text((id_w, 19), '属性名称', 11, T3)
    for i, label in enumerate(['当前值', '最差值', '阈值']):
        tv.text((id_w + name_w + col_w * i + col_w, 19), label, 11, T3, 'Regular', 'rs')
    tv.text((tw, 19), '原始值', 11, T3, 'Regular', 'rs')
    tv.line([0, head_h, tw, head_h], DIV, 1)

    for i, (rid, name, cur, worst, thr, raw) in enumerate(SMART):
        top = head_h + 1 + i * (row_h + 1)
        tv.text((0, top + 21), rid, 12, T2)
        tv.text((id_w, top + 21), fit(tv, name, 12, 'Regular', name_w), 12, T1)
        tv.text((id_w + name_w + col_w, top + 21), cur, 12, T1, 'Regular', 'rs')
        tv.text((id_w + name_w + col_w * 2, top + 21), worst, 12, T2, 'Regular', 'rs')
        tv.text((id_w + name_w + col_w * 3, top + 21), thr, 12, T2, 'Regular', 'rs')
        tv.text((tw, top + 21), raw, 12, T2, 'Regular', 'rs')
        tv.line([0, top + row_h, tw, top + row_h], DIV, 1)

    # clip to the card's inner width (table keeps minWidth 500 like SmartTable)
    clip_px = int(round(min(inner, table_w) * D))
    clipped = table.crop((0, 0, clip_px, table.size[1]))
    v.p.img.paste(clipped, (int(round(pad * D)), int(round((y + pad + 20 + 10) * D))), clipped)
    return height


def build_content(kind, page, cw_px):
    """Render the disk page content at px width cw_px; return (image, smart_y)."""
    pad = {'ph': 16, 'tab': 20, 'pc': 24}[kind]
    gap = 12 if kind == 'ph' else 14
    cw = cw_px / D
    cols = 2 if kind == 'ph' else 4
    scan = '16:37:27' if kind == 'pc' else '16:39:52'

    img = Image.new('RGBA', (int(round(cw_px)), 4200), PAGE + (255,))
    v = Vp(img)
    v.p.img = img
    y = pad
    y += draw_head(v, cw, scan, y) + gap
    y += draw_overview(v, cw, cols, y) + gap
    y += draw_info(v, cw, y) + gap
    y += draw_chart(v, cw, y) + gap
    smart_y = y
    y += draw_smart(v, cw, y)
    total = int(round((y + (96 if kind != 'pc' else 24)) * D))
    return img.crop((0, 0, img.size[0], min(total, img.size[1]))), smart_y


def build_screen(kind, page):
    """Real capture with its content area replaced by a staged disk page."""
    base = load_shot(kind, 'disk')
    w, h = base.size
    x0 = sidebar_edge(base) if kind == 'pc' else 0
    # PC has a filled title bar + divider to detect; mobile bars share the page
    # colour, so anchor content just below the 56vp mini title bar instead.
    hy = header_bottom(base, x0) + 1 if kind == 'pc' else int(round(56 * D))

    bar = None
    bar_mask = None
    if kind != 'pc':
        disk_base = load_shot(kind, 'disk')
        bbox = find_tab_bar(disk_base)
        if bbox:
            bar = disk_base.crop(bbox)
            bar_mask = capsule_mask(bar.size, min(bar.size) / 2.0)

    screen = base.copy()
    flat = Image.new('RGB', (w - x0, h - hy), PAGE)
    screen.paste(flat, (x0, hy))

    pad = {'ph': 16, 'tab': 20, 'pc': 24}[kind]
    pad_px = int(round(pad * D))
    content, smart_y = build_content(kind, page, w - x0 - pad_px * 2)
    view_h = h - hy
    scroll = 0
    if page == 'smart':
        scroll = max(0, int(round(smart_y * D)) - int(round(10 * D)))
        if bar is not None:
            # nudge so the floating bar's top edge lands on a row divider
            row0 = int(round((smart_y + 18 + 20 + 10 + 29) * D))
            pitch = 33 * D
            local = (bbox[1] - hy) + scroll - row0
            delta = -(local % pitch)
            if delta < -pitch / 2:
                delta += pitch
            scroll = max(0, int(round(scroll + delta)))
    crop = content.crop((0, min(scroll, content.size[1] - 1), content.size[0],
                         min(scroll + view_h, content.size[1])))
    screen.paste(crop, (x0 + pad_px, hy))

    if bar is not None:
        screen.paste(bar, (bbox[0], bbox[1]), bar_mask)
    return screen


def window_card(app, radius=26):
    w, h = app.size
    scale = 4
    mask = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1],
                                           radius=radius * scale, fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)
    card = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    card.paste(app.convert('RGBA'), (0, 0), mask)
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=radius - 1,
                        outline=(255, 255, 255, 30), width=2)
    return card


PC = [
    {'name': 'pc_01_dashboard', 'page': 'dashboard', 'eyebrow': '电脑端',
     'line1': '外接硬盘', 'line2': '健康一屏掌握',
     'desc': ['插上 USB 硬盘即可读取 SMART 数据', '型号、温度、寿命与属性同屏呈现'],
     'chips': ['USB 直读', '侧栏导航', '实时温度'],
     'checks': ['健康状态与剩余寿命一目了然', '温度历史持续采样', '完整 SMART 属性表'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
    {'name': 'pc_02_smart', 'page': 'smart', 'eyebrow': '电脑端',
     'line1': 'SMART 全表', 'line2': '原始值尽览',
     'desc': ['当前值、最差值、阈值与原始值逐行对照', '列宽随窗格自适应，长值自动省略'],
     'chips': ['SATA / NVMe', '原始值', '阈值告警'],
     'checks': ['内置 SATA 与 NVMe 属性字典', '阈值异常即时标红', '原始值支持十六进制'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
    {'name': 'pc_03_settings', 'page': 'core', 'eyebrow': '电脑端',
     'line1': '检测参数', 'line2': '精细调校',
     'desc': ['刷新间隔、温度单位与硬盘状态阈值', '全部集中在核心设置里逐项调整'],
     'chips': ['刷新间隔', '温度单位', '阈值告警'],
     'checks': ['刷新间隔 5–60 秒可选', '摄氏度与华氏度自由切换', '五项阈值与温度告警'],
     'footer': '鸿蒙电脑 · 外接硬盘健康监测'},
]

TABLET = [
    {'name': 'tablet_01_dashboard', 'page': 'dashboard', 'eyebrow': '平板端',
     'line1': '大屏仪表', 'line2': '数据一望而知',
     'desc': ['宽屏自动铺开概览卡片与设备信息', '温度曲线即时呈现，属性表向下展开'],
     'chips': ['宽屏布局', '四栏概览', '实时刷新'],
     'checks': ['概览卡片自适应排布', '设备信息双栏呈现', '首页与硬盘一键切换'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
    {'name': 'tablet_02_smart', 'page': 'smart', 'eyebrow': '平板端',
     'line1': 'SMART 属性', 'line2': '一览无余',
     'desc': ['完整属性表在宽屏上舒展排布', '当前、最差、阈值与原始值并列对照'],
     'chips': ['完整属性', '并行对照', '原始值'],
     'checks': ['列宽随窗口自适应', '阈值告警即时标红', '支持十进制与十六进制'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
    {'name': 'tablet_03_settings', 'page': 'core', 'eyebrow': '平板端',
     'line1': '检测参数', 'line2': '精细调校',
     'desc': ['刷新间隔、温度单位与硬盘状态阈值', '全部集中在核心设置里逐项调整'],
     'chips': ['刷新间隔', '温度单位', '阈值告警'],
     'checks': ['刷新间隔 5–60 秒可选', '摄氏度与华氏度自由切换', '五项阈值与温度告警'],
     'footer': '鸿蒙平板 · 外接硬盘健康监测'},
]

PHONE = [
    {'name': 'phone_01_home', 'page': 'home', 'eyebrow': '手机端',
     'line1': '插上硬盘', 'line2': '即刻体检',
     'desc': ['读取外接 USB 硬盘的 SMART 数据', '无需驱动，所有信息本机处理'],
     'chips': ['USB 直读', '即插即用', '本机处理'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_02_dashboard', 'page': 'dashboard', 'eyebrow': '手机端',
     'line1': '外接硬盘', 'line2': '状态尽在掌心',
     'desc': ['健康、温度、寿命与通电时间一屏呈现', '设备信息与完整 SMART 属性随手可查'],
     'chips': ['概览卡片', '实时温度', '悬浮页签'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_03_smart', 'page': 'smart', 'eyebrow': '手机端',
     'line1': 'SMART 全表', 'line2': '逐项细看',
     'desc': ['当前值、最差值、阈值与原始值逐行对照', '滑动查看全部属性，异常项自动标红'],
     'chips': ['全属性', '原始值', '阈值告警'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
    {'name': 'phone_04_settings', 'page': 'core', 'eyebrow': '手机端',
     'line1': '检测参数', 'line2': '精细调校',
     'desc': ['刷新间隔、温度单位与硬盘状态阈值', '全部集中在核心设置里逐项调整'],
     'chips': ['刷新间隔', '温度单位', '阈值告警'],
     'checks': [], 'footer': '鸿蒙手机 · 外接硬盘健康监测'},
]


def screen_for(kind, page):
    if page in ('home', 'core'):
        return load_shot(kind, page)
    key = (kind, page)
    if key not in _cache:
        _cache[key] = build_screen(kind, page)
    return _cache[key]


_cache = {}


def compose_pc(spec):
    W, H = 1920, 1080
    canvas = make_glow_background(W, H, (0.70, 0.46), (0.25, 0.52))
    screen = screen_for('pc', spec['page'])
    frame = laptop_frame(screen, 1160, int(round(1160 * screen.size[1] / screen.size[0])))
    cast_shadow(canvas, (700, 862, 1850, 985), 45)
    canvas.alpha_composite(frame, (690, 180))
    p = P(canvas, 1)
    draw_brand(canvas, p, 110, 62)
    draw_badge(p, 1810, 74)
    draw_copy(p, spec, False)
    return canvas.convert('RGB')


def compose_tablet(spec):
    W, H = 1920, 1280
    canvas = make_glow_background(W, H, (0.70, 0.45), (0.22, 0.52))
    screen = screen_for('tab', spec['page'])
    card = window_card(screen.resize((1080, int(round(1080 * screen.size[1] / screen.size[0]))),
                                     Image.LANCZOS))
    cast_shadow(canvas, (760, 1060, 1820, 1175), 45)
    canvas.alpha_composite(card, (740, 230))
    p = P(canvas, 1)
    draw_brand(canvas, p, 110, 68)
    draw_badge(p, 1810, 80)
    draw_copy(p, spec, True)
    return canvas.convert('RGB')


def compose_phone(spec):
    W, H = 1080, 1920
    canvas = make_glow_background(W, H, (0.5, 0.42), (0.5, 1.0))
    screen = screen_for('ph', spec['page'])
    card = window_card(screen.resize((770, int(round(770 * screen.size[1] / screen.size[0]))),
                                     Image.LANCZOS))
    cast_shadow(canvas, (170, 1720, 930, 1835), 42)
    canvas.alpha_composite(card, (155, 520))
    p = P(canvas, 1)
    draw_brand_phone(canvas, p, W)
    draw_badge(p, 1016, 62)
    draw_copy_phone(p, W, spec)
    return canvas.convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(DEBUG, exist_ok=True)
    for kind, page, name in [('pc', 'dashboard', 'pc_disk'), ('pc', 'smart', 'pc_smart'),
                             ('tab', 'dashboard', 'tab_disk'), ('tab', 'smart', 'tab_smart'),
                             ('ph', 'dashboard', 'ph_disk'), ('ph', 'smart', 'ph_smart')]:
        screen_for(kind, page).save(os.path.join(DEBUG, name + '.png'))
    for specs, fn in ((PC, compose_pc), (TABLET, compose_tablet), (PHONE, compose_phone)):
        for spec in specs:
            image = fn(spec)
            target = os.path.join(OUT, spec['name'] + '.png')
            image.save(target)
            print(target, image.size)


if __name__ == '__main__':
    main()
