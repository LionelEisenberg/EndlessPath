"""Round 1 mockups: the Equipment spread drawn three ways (plus today's capture).

A  Inked    - the book stays; everything on the page is drawn in ink on the paper
B  Pressed  - the book stays; slots and figure are pressed into the paper, labels printed
C  Lacquer  - no book; a lacquer board in the map gap, like the cycling board

Art is drawn on a half-resolution canvas (1 art px = 2 screen px) and scaled 2x nearest,
so every line sits on the game's 2x grid. Text is drawn at screen resolution.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

REPO = 'C:/worktrees/EndlessPath/inventory-panes-redesign-19cccc/'
SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
OUT = REPO + '.superpowers/brainstorm/1894-1792809964/content/'
sys.path.insert(0, REPO + 'docs/superpowers/mockups/zone-view-lacquer/gen')
import lq_base as L  # noqa: E402

YATRA = REPO + 'assets/fonts/YatraOne-Regular.ttf'
EUL = REPO + 'assets/fonts/BMEULJIROTTF.ttf'
_F = {}


def F(path, size):
    if (path, size) not in _F:
        _F[(path, size)] = ImageFont.truetype(path, size)
    return _F[(path, size)]


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PAPER = rgb('F7E6CA')
INK_D = rgb('33261A')
INK = rgb('3B2A20')
INK_M = rgb('7D5F47')
RULE = rgb('A0825F')
VERM = rgb('A83C30')
CREAM = rgb('F0E8D8')
TAN = rgb('A89070')
BRASS = rgb('D4A84A')
SHADOW = rgb('050707')
# pressed paper
FLOOR = rgb('EEDAB8')
SHADE = rgb('D2B98F')
SHADE2 = rgb('E2CCA6')
LIGHT = rgb('FFF6E6')


def icon(name):
    return Image.open(REPO + f'assets/sprites/items/equipment/{name}.png').convert('RGBA')


GRID_ITEMS = ['cultivators_cowl', 'dreadbeast_tooth_necklace', 'reinforced_robes', 'makeshift_dagger',
              'scripted_bark', 'makeshift_dagger', 'dreadbeast_tooth_necklace', 'leeching_ring',
              'makeshift_dagger', 'dreadbeast_tooth_necklace', 'cultivators_cowl']
SELECTED = 3   # the dagger in row 1, column 4
GEAR = [('Head', 'cultivators_cowl'), ('Body', 'reinforced_robes'), ('Accessory', 'dreadbeast_tooth_necklace'),
        ('Main hand', 'iron_shortsword'), ('Off hand', 'scripted_bark'), ('Accessory', 'leeching_ring')]
DETAIL = {
    'name': 'Makeshift Dagger',
    'type': 'Main hand · weapon',
    'stats': [('Strength', '+3'), ('Agility', '+2')],
    'desc': 'A simple iron blade, well-balanced for a beginner.',
}


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def art_canvas():
    return Image.new('RGBA', (960, 540), (0, 0, 0, 0))


def flatten(base, art):
    base.alpha_composite(art.resize((1920, 1080), Image.NEAREST))


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def hline(img, x0, x1, y, c, steps=()):
    """A hand-ruled horizontal line: straight, with a one-pixel step where the hand drifted."""
    s = dict(steps)
    for x in range(x0, x1 + 1):
        y += s.get(x, 0)
        put(img, x, y, c)


def vline(img, x, y0, y1, c, steps=()):
    s = dict(steps)
    for y in range(y0, y1 + 1):
        x += s.get(y, 0)
        put(img, x, y, c)


def dotted_h(img, x0, x1, y, c, gap=2):
    for x in range(x0, x1 + 1, gap):
        put(img, x, y, c)


def dotted_line(img, a, b, c, every=2):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(0, n + 1, every):
        put(img, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def loop(img, x0, y0, x1, y1, c):
    """A red-pencil loop: an ellipse with the stroke overshooting where it closes."""
    ImageDraw.Draw(img).ellipse((x0, y0, x1, y1), outline=c, width=1)
    cx = (x0 + x1) // 2
    for i in range(6):
        put(img, cx + 4 + i, y0 - 1 + (i // 3), c)


def tracked_len(s, font, spacing):
    return sum(round(font.getlength(ch)) + spacing for ch in s) - spacing


def text(img, xy, s, font, fill, anchor='ls', spacing=0):
    d = ImageDraw.Draw(img)
    if not spacing:
        d.text(xy, s, font=font, fill=fill, anchor=anchor)
        return
    x, y = xy
    if anchor[0] == 'm':
        x -= tracked_len(s, font, spacing) // 2
    elif anchor[0] == 'r':
        x -= tracked_len(s, font, spacing)
    for ch in s:
        d.text((x, y), ch, font=font, fill=fill, anchor='l' + anchor[1])
        x += round(font.getlength(ch)) + spacing


def wrap(s, font, width):
    lines, cur = [], ''
    for w in s.split():
        t = (cur + ' ' + w).strip()
        if font.getlength(t) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def silhouette_mask():
    """The gear selector's figure (the peach pixels of the user's portrait), as a set of art px."""
    im = Image.open(REPO + 'assets/sprites/inventory/gear_selector/gear_selector_portrait.png').convert('RGBA')
    pts = {(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[:3] == (241, 187, 142)}
    x0 = min(p[0] for p in pts)
    y0 = min(p[1] for p in pts)
    pts = {(x - x0, y - y0) for x, y in pts}
    return pts, max(p[0] for p in pts) + 1, max(p[1] for p in pts) + 1


def outline_of(pts):
    out = set()
    for (x, y) in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in pts:
                out.add((x, y))
                break
    return out


def book_base():
    im = Image.open(SCR + 'captures/01_equipment.png').convert('RGBA')
    d = ImageDraw.Draw(im)
    d.rectangle((440, 206, 924, 884), fill=PAPER)
    d.rectangle((1000, 206, 1488, 884), fill=PAPER)
    return im


def slot_positions():
    left, right = 1016, 1396
    return [(left, 290), (left, 392), (left, 494), (right, 290), (right, 392), (right, 494)]


def filter_layout(labels, size, spacing, pad, gap, x_left):
    out, x = [], x_left
    for label, on in labels:
        w = tracked_len(label, F(EUL, size), spacing) + 2 * pad
        w += w % 2
        out.append((x, w, (label, on)))
        x += w + gap
    return out


# ----------------------------------------------------------------------------
# A  Inked: the page is a field journal
# ----------------------------------------------------------------------------
def option_a():
    im = book_base()
    art = art_canvas()
    # title underline: the pen lands heavy and lifts off in dashes
    hline(art, 228, 330, 137, INK, steps=((300, -1),))
    put(art, 228, 138, INK)
    put(art, 229, 138, INK)
    for x in (333, 334, 337, 341):
        put(art, x, 136, INK)
    loop(art, 222, 143, 250, 160, VERM)              # the filter in use
    gx, gy, p = 230, 166, 37                          # 6x6 cells of 74 px from (460, 332)
    for i in range(7):
        st = ((gx + 70 + 9 * i, 1 if i % 2 else -1),) if i in (2, 5) else ()
        hline(art, gx - 2, gx + 6 * p + 2, gy + i * p, RULE, steps=st)
        st = ((gy + 60 + 11 * i, 1 if i % 2 else -1),) if i in (1, 4) else ()
        vline(art, gx + i * p, gy - 2, gy + 6 * p + 2, RULE, steps=st)
    c, r = SELECTED % 6, SELECTED // 6
    loop(art, gx + c * p - 4, gy + r * p - 4, gx + (c + 1) * p + 4, gy + (r + 1) * p + 4, VERM)
    loop(art, 276, 403, 290, 418, VERM)               # page 1
    bx, by = 433, 399                                 # discard box with a cross
    for i in range(21):
        put(art, bx + i, by, INK)
        put(art, bx + i, by + 20, INK)
        put(art, bx, by + i, INK)
        put(art, bx + 20, by + i, INK)
    for i in range(4, 17):
        put(art, bx + i, by + i, INK_M)
        put(art, bx + 20 - i, by + i, INK_M)
    # right page
    hline(art, 506, 556, 137, INK, steps=((540, -1),))
    put(art, 506, 138, INK)
    for x in (559, 560, 563):
        put(art, x, 136, INK)
    pts, w, h = silhouette_mask()                     # the figure, sketched in outline
    fx, fy = 623 - w // 2, 150
    for (x, y) in outline_of(pts):
        put(art, fx + x, fy + y, INK)
    slots = slot_positions()
    for (sx, sy) in slots:                            # hand-ruled boxes, 76 px
        ax, ay = sx // 2, sy // 2
        hline(art, ax - 1, ax + 38, ay, INK)
        hline(art, ax - 1, ax + 38, ay + 38, INK, steps=((ax + 20, 1),) if sx > 1200 else ())
        vline(art, ax, ay - 1, ay + 38, INK)
        vline(art, ax + 38, ay - 1, ay + 39 if sx > 1200 else ay + 38, INK)
    head, chest = (fx + w // 2, fy + 10), (fx + w // 2, fy + 40)
    targets = [head, chest, (fx + w // 2 - 4, fy + 25), (fx + w - 6, fy + 62), (fx + 6, fy + 62),
               (fx + w // 2 + 4, fy + 27)]
    for (sx, sy), t in zip(slots, targets):
        start = (sx // 2 + 40, sy // 2 + 19) if sx < 1200 else (sx // 2 - 2, sy // 2 + 19)
        dotted_line(art, start, t, RULE, every=3)
    hline(art, 506, 742, 308, INK_M, steps=((620, 1), (700, -1)))
    flatten(im, art)

    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (466 + 74 * (i % 6), 338 + 74 * (i // 6)))
    for (sx, sy), (_, name) in zip(slots, GEAR):
        im.alpha_composite(icon(name), (sx + 6, sy + 6))

    text(im, (456, 262), 'Equipment', F(YATRA, 38), INK_D)
    for x, s, col in [(460, 'All', INK_D), (524, 'Weapons', INK_M), (634, 'Armor', INK_M),
                      (716, 'Accessories', INK_M)]:
        text(im, (x, 312), s, F(EUL, 18), col)
    text(im, (912, 312), '11 / 36', F(EUL, 18), INK_M, anchor='rs')
    text(im, (460, 832), 'Page', F(EUL, 16), INK_M)
    text(im, (566, 832), '1', F(EUL, 18), INK_D, anchor='ms')
    text(im, (610, 832), '2', F(EUL, 18), INK_M, anchor='ms')
    text(im, (856, 832), 'Discard', F(EUL, 16), INK_M, anchor='rs')
    text(im, (1012, 262), 'Gear', F(YATRA, 38), INK_D)
    for (sx, sy), (label, _) in zip(slots, GEAR):
        text(im, (sx + 38, sy + 98), label, F(EUL, 15), INK_M, anchor='ms')
    details_book(im, 1012, 666, inked=True)
    return im


def details_book(im, x, y, inked):
    text(im, (x, y), DETAIL['name'], F(YATRA, 30), INK_D)
    if inked:
        text(im, (x, y + 28), DETAIL['type'], F(EUL, 16), INK_M)
    else:
        text(im, (x, y + 28), DETAIL['type'].upper(), F(EUL, 13), INK_M, spacing=1)
    art = art_canvas()
    yy = y + 66
    for label, _ in DETAIL['stats']:
        lw = round(F(EUL, 18).getlength(label))
        if inked:
            dotted_h(art, (x + lw + 10) // 2, (1484 - 34) // 2, (yy - 4) // 2, RULE)
        else:
            for xx in range(x // 2, 1484 // 2 + 1):
                put(art, xx, (yy + 8) // 2, SHADE)
        yy += 30
    flatten(im, art)
    yy = y + 66
    for label, val in DETAIL['stats']:
        text(im, (x, yy), label, F(EUL, 18), INK)
        text(im, (1484, yy), val, F(EUL, 18), INK_D, anchor='rs')
        yy += 30
    yy += 14
    for line in wrap(DETAIL['desc'], F(EUL, 18), 470):
        text(im, (x, yy), line, F(EUL, 18), INK)
        yy += 26
    text(im, (x, 866), 'Right-click to wear it', F(EUL, 15), INK_M)


# ----------------------------------------------------------------------------
# B  Pressed: slots and figure are pressed into the paper; labels are printed
# ----------------------------------------------------------------------------
def deboss(art, x0, y0, w, h, deep=False):
    """A well pressed into the paper: shaded top and left inside edges, lit bottom and right."""
    for y in range(h):
        for x in range(w):
            if y == 0 or x == 0:
                c = SHADE
            elif deep and (y == 1 or x == 1):
                c = SHADE
            elif y == h - 1 or x == w - 1:
                c = LIGHT
            else:
                c = SHADE2 if deep else FLOOR
            put(art, x0 + x, y0 + y, c)


def deboss_mask(art, pts, ox, oy):
    for (x, y) in pts:
        if (x, y - 1) not in pts or (x - 1, y) not in pts:
            c = SHADE
        elif (x, y + 1) not in pts or (x + 1, y) not in pts:
            c = LIGHT
        else:
            c = FLOOR
        put(art, ox + x, oy + y, c)


def corner_marks(art, x0, y0, x1, y1, c, arm=5):
    for i in range(arm):
        for (cx, cy, sx, sy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
            put(art, cx + sx * i, cy, c)
            put(art, cx, cy + sy * i, c)


def ornament_rule(art, x0, x1, y):
    cx = (x0 + x1) // 2
    for x in range(x0, x1 + 1):
        if abs(x - cx) > 5:
            put(art, x, y, INK_M)
    for d in range(4):
        put(art, cx - 3 + d, y - d, INK)
        put(art, cx - 3 + d, y + d, INK)
        put(art, cx + 3 - d, y - d, INK)
        put(art, cx + 3 - d, y + d, INK)


def option_b():
    im = book_base()
    art = art_canvas()
    ornament_rule(art, 276, 412, 139)
    filt = filter_layout([('ALL', True), ('WEAPONS', False), ('ARMOR', False), ('ACCESSORIES', False)],
                         13, 1, 12, 8, 460)
    for (x, wpx, (label, on)) in filt:
        deboss(art, x // 2, 146, wpx // 2, 14, deep=on)
    gx, gy = 460, 330
    for i in range(36):
        deboss(art, (gx + (i % 6) * 76) // 2, (gy + (i // 6) * 76) // 2, 36, 36)
    sx, sy = (gx + (SELECTED % 6) * 76) // 2, (gy + (SELECTED // 6) * 76) // 2
    corner_marks(art, sx - 2, sy - 2, sx + 37, sy + 37, VERM)
    deboss(art, 270, 403, 14, 14, deep=True)          # page 1 pressed in
    deboss(art, 288, 403, 14, 14)
    deboss(art, 435, 400, 21, 21)                     # discard well
    for i in range(5, 16):
        put(art, 435 + i, 400 + i, INK_M)
        put(art, 435 + 20 - i, 400 + i, INK_M)
    ornament_rule(art, 552, 692, 139)
    pts, w, h = silhouette_mask()
    deboss_mask(art, pts, 623 - w // 2, 150)
    for (sx2, sy2) in slot_positions():
        deboss(art, (sx2 + 2) // 2, (sy2 + 2) // 2, 36, 36)
    for x in range(506, 743):
        put(art, x, 304, INK_M)
        put(art, x, 306, INK_M)
    flatten(im, art)

    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (gx + (i % 6) * 76 + 4, gy + (i // 6) * 76 + 4))
    for (sx2, sy2), (_, name) in zip(slot_positions(), GEAR):
        im.alpha_composite(icon(name), (sx2 + 6, sy2 + 6))

    text(im, (688, 262), 'Equipment', F(YATRA, 38), INK_D, anchor='ms')
    for (x, wpx, (label, on)) in filt:
        text(im, (x + wpx // 2, 314), label, F(EUL, 13), INK_D if on else INK_M, anchor='ms', spacing=1)
    text(im, (528, 830), 'PAGE', F(EUL, 13), INK_M, anchor='rs', spacing=1)
    text(im, (554, 828), '1', F(EUL, 15), INK_D, anchor='ms')
    text(im, (590, 828), '2', F(EUL, 15), INK_M, anchor='ms')
    text(im, (862, 830), '11 / 36', F(EUL, 15), INK_M, anchor='rs')
    text(im, (1244, 262), 'Gear', F(YATRA, 38), INK_D, anchor='ms')
    for (sx2, sy2), (label, _) in zip(slot_positions(), GEAR):
        text(im, (sx2 + 38, sy2 + 98), label.upper(), F(EUL, 13), INK_M, anchor='ms', spacing=1)
    details_book(im, 1012, 666, inked=False)
    return im


# ----------------------------------------------------------------------------
# C  Lacquer: a board in the map gap, the zone view's furniture around it
# ----------------------------------------------------------------------------
BX, BY, BW, BH = 488, 150, 944, 676                   # screen px, all even


def raised(art, x0, y0, w, h):
    for y in range(h):
        for x in range(w):
            d, s = L.side_of(x, y, w, h)
            if d == 0:
                c = L.INK
            elif d == 1:
                c = L.RIM if s == 'lit' else L.DEEP
            else:
                c = L.RAISED
            put(art, x0 + x, y0 + y, c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(art, x0 + p[0], y0 + p[1], (0, 0, 0, 0))


def recessed(art, x0, y0, w, h, field=None):
    field = field or L.DEEP
    for y in range(h):
        for x in range(w):
            d, s = L.side_of(x, y, w, h)
            if d == 0:
                c = L.INK if s == 'lit' else L.RIM_S
            elif d == 1:
                c = L.INK if s == 'lit' else field
            else:
                c = field
            put(art, x0 + x, y0 + y, c)


def brass_plate(art, x0, y0, w, h):
    for y in range(h):
        for x in range(w):
            d, s = L.side_of(x, y, w, h)
            if d == 0:
                c = L.INK
            elif d == 1:
                c = L.CREAM if s == 'lit' else L.BRASS_SH
            else:
                c = L.BRASS
            put(art, x0 + x, y0 + y, c)


def caps(art, x0, y0, w, h, arm=6, th=3):
    for corner in ('tl', 'tr', 'bl', 'br'):
        m = set()
        for i in range(arm):
            for t in range(th):
                m.add((i, t))
                m.add((t, i))
        m.discard((arm - 1, th - 1))
        m.discard((th - 1, arm - 1))

        def fl(p, corner=corner):
            x, y = p
            if corner in ('tr', 'br'):
                x = w - 1 - x
            if corner in ('bl', 'br'):
                y = h - 1 - y
            return (x0 + x, y0 + y)
        pts = {fl(p) for p in m}
        edge = {p for p in pts if p[0] in (x0, x0 + w - 1) or p[1] in (y0, y0 + h - 1)}
        L.lit_mask(art, pts, edge)


def brass_frame(art, x0, y0, w, h):
    """The kit's steady brass frame (selected), 2 art px thick."""
    for y in range(h):
        for x in range(w):
            d, s = L.side_of(x, y, w, h)
            if d == 0:
                put(art, x0 + x, y0 + y, L.INK)
            elif d == 1:
                put(art, x0 + x, y0 + y, L.CREAM if s == 'lit' else L.BRASS)
            elif d == 2:
                put(art, x0 + x, y0 + y, L.BRASS_SH)


def board(art):
    ax, ay, w, h = BX // 2, BY // 2, BW // 2, BH // 2
    for y in range(h):                                  # the 4 px hard shadow
        for x in range(w):
            put(art, ax + x + 2, ay + y + 2, SHADOW)
    cab = L.cabinet(w, h)
    for (x, y, ln, jogs) in ((30, 40, 70, ((20, 1),)), (300, 70, 90, ((40, -1),)), (120, 250, 110, ((60, 1),)),
                             (380, 300, 60, ())):
        L.streak(cab, x, y, ln, jogs)
    L.gloss(cab, 7, [(40, 70, L.RIM_S), (74, 80, L.RIM_S)])
    for corner in ('tl', 'tr', 'bl', 'br'):
        L.strap(cab, corner)
    art.alpha_composite(cab, (ax, ay))


def carved_outline(art, pts, ox, oy):
    """The figure carved into the board: an ink channel with a lit lip below it."""
    edge = outline_of(pts)
    for (x, y) in edge:
        put(art, ox + x, oy + y, L.INK)
    for (x, y) in edge:
        if (x, y + 1) not in edge and (x, y + 1) in pts:
            put(art, ox + x, oy + y + 1, L.RIM_S)


def option_c():
    im = Image.open(SCR + 'captures/00_zone.png').convert('RGBA')
    art = art_canvas()
    board(art)
    # tabs across the top: the open one pulled out with brass caps
    tabs = [('Equipment', True), ('Consumables', False), ('Materials', False), ('Journal', False)]
    tx = BX + 24
    tab_boxes = []
    for label, on in tabs:
        w = 32 + 8 + round(F(EUL, 17).getlength(label)) + 24
        w += w % 2
        if on:
            raised(art, (tx - 2) // 2, (BY + 22) // 2, w // 2, 24)
            caps(art, (tx - 2) // 2, (BY + 22) // 2, w // 2, 24)
        else:
            raised(art, tx // 2, (BY + 24) // 2, w // 2, 24)
        tab_boxes.append((tx, w, label, on))
        tx += w + 8
    # carved line under the tabs
    for x in range((BX + 20) // 2, (BX + BW - 20) // 2):
        put(art, x, (BY + 84) // 2, L.INK)
        put(art, x, (BY + 84) // 2 + 1, L.RIM_S)
    # left: filter tags, 6x6 sockets of 72 with 4 gaps, footer
    filt = filter_layout([('ALL', True), ('WEAPONS', False), ('ARMOR', False), ('ACCESSORIES', False)],
                         13, 1, 10, 8, BX + 24)
    for (x, wpx, (label, on)) in filt:
        (brass_plate if on else recessed)(art, x // 2, (BY + 104) // 2, wpx // 2, 11)
    gx, gy = BX + 24, BY + 146
    for i in range(36):
        L.socket(art, (gx + (i % 6) * 76) // 2, (gy + (i // 6) * 76) // 2, 36)
    sx, sy = gx + (SELECTED % 6) * 76, gy + (SELECTED // 6) * 76
    brass_frame(art, (sx - 4) // 2, (sy - 4) // 2, 40, 40)
    fy = gy + 6 * 76 + 6
    brass_plate(art, (gx + 64) // 2, fy // 2, 14, 13)
    recessed(art, (gx + 96) // 2, fy // 2, 14, 13)
    L.socket(art, (gx + 452 - 40) // 2, (fy - 4) // 2, 20)
    # right: section label + groove, the carved figure, six sockets, the details tray
    rx = BX + 24 + 452 + 24
    rw = BX + BW - 24 - rx
    for x in range((rx + 70) // 2, (rx + rw) // 2):
        put(art, x, (BY + 126) // 2, L.INK)
        put(art, x, (BY + 126) // 2 + 1, L.RIM_S)
    pts, w, h = silhouette_mask()
    cx = rx + rw // 2
    carved_outline(art, pts, cx // 2 - w // 2, (BY + 150) // 2)
    sock = [(rx, BY + 150), (rx, BY + 248), (rx, BY + 346),
            (rx + rw - 72, BY + 150), (rx + rw - 72, BY + 248), (rx + rw - 72, BY + 346)]
    for (x, y) in sock:
        L.socket(art, x // 2, y // 2, 36)
    tray_y = BY + 460
    recessed(art, rx // 2, tray_y // 2, rw // 2, (BY + BH - 24 - tray_y) // 2)
    flatten(im, art)

    for (x, w, label, on) in tab_boxes:
        y = BY + 22 if on else BY + 24
        ic = Image.open(REPO + 'assets/ui/lacquer/icons/' + {
            'Equipment': 'ic_merchant_ai.png', 'Consumables': 'ic_well_ai.png',
            'Materials': 'ic_forage_ai.png', 'Journal': 'ic_story_ai.png'}[label]).convert('RGBA')
        ic = ic.resize((32, 32), Image.NEAREST) if ic.width == 16 else ic
        im.alpha_composite(ic, ((x - 2 if on else x) + 12, y + 8))
        text(im, ((x - 2 if on else x) + 52, y + 30), label, F(EUL, 17), CREAM if on else TAN)
    close = Image.open(REPO + 'assets/ui/lacquer/lacquer_close_ai.png').convert('RGBA')
    im.alpha_composite(close, (BX + BW - 24 - close.width, BY + 30))
    for (x, wpx, (label, on)) in filt:
        text(im, (x + wpx // 2, BY + 121), label, F(EUL, 13), L.INK if on else TAN, anchor='ms', spacing=1)
    text(im, (gx + 452, BY + 122), '11 / 36', F(EUL, 15), TAN, anchor='rs')
    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (gx + (i % 6) * 76 + 4, gy + (i // 6) * 76 + 4))
    text(im, (gx, fy + 21), 'Page', F(EUL, 15), TAN)
    text(im, (gx + 78, fy + 20), '1', F(EUL, 15), L.INK, anchor='ms')
    text(im, (gx + 110, fy + 20), '2', F(EUL, 15), TAN, anchor='ms')
    im.alpha_composite(close, (gx + 452 - 40 + 6, fy - 4 + 6))
    text(im, (gx + 452 - 52, fy + 21), 'Discard', F(EUL, 15), TAN, anchor='rs')
    text(im, (rx, BY + 134), 'Gear', F(YATRA, 22), BRASS)
    for (x, y), (label, name) in zip(sock, GEAR):
        im.alpha_composite(icon(name), (x + 4, y + 4))
        text(im, (x + 36, y + 92), label, F(EUL, 15), TAN, anchor='ms')
    ty = tray_y + 34
    text(im, (rx + 16, ty), DETAIL['name'], F(EUL, 17), CREAM)
    text(im, (rx + 16, ty + 24), DETAIL['type'], F(EUL, 15), TAN)
    yy = ty + 56
    for label, val in DETAIL['stats']:
        text(im, (rx + 16, yy), label, F(EUL, 15), TAN)
        text(im, (rx + rw - 16, yy), val, F(EUL, 15), CREAM, anchor='rs')
        yy += 22
    yy += 10
    for line in wrap(DETAIL['desc'], F(EUL, 16), rw - 32):
        text(im, (rx + 16, yy), line, F(EUL, 16), CREAM)
        yy += 22
    return im


def main():
    today = Image.open(SCR + 'captures/01_equipment.png').convert('RGBA')
    for name, im in (('r1_today', today), ('r1_a_inked', option_a()), ('r1_b_pressed', option_b()),
                     ('r1_c_lacquer', option_c())):
        im.convert('RGB').save(OUT + name + '.png')
        print('saved', name)


if __name__ == '__main__':
    main()
