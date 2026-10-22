"""Lacquer and brass, full kit: the map pieces at zoom 2.

Fog tiers, the veiled locked and uncharted tiles, the current/open zone rims, hover and
pinned brackets, map plates, map popovers. Tile art is the user's forest hex set, read
from the repo and never written back; every output is a new _ai file.
"""
import math
from collections import deque

from PIL import Image

import geom
import lq_base as B
from lq_base import (CLEAR, INK, DEEP, LAC, GRAIN, GRAIN2, RAISED, RIM_S, RIM, BRASS, BRASS_SH,
                     CREAM, TAN, VERM, VERM_D, hx, new, put, save, side_of, streak, gloss, lit_mask, dome)
from kit_ui import caps

GROUND = hx('090e0e')     # the screen behind the map (swatch)
TAN_SH = hx('7A654C')

# fog ramps (dark teal, the swatch's ground family): line, shade, base, light
FOG = {
    1: (hx('0c1312'), hx('111a19'), hx('16211f'), hx('1d2b28')),
    2: (hx('182423'), hx('0f1716'), hx('111a19'), hx('131d1c')),
    3: (hx('0d1514'), hx('0d1514'), hx('0d1514'), hx('0d1514')),
}
# veiled zone tiles: desaturated stone-green for a locked zone, deep fog-teal for uncharted
VEIL_LOCKED = (hx('151a18'), hx('39423e'), hx('4b5550'), hx('5f6a65'), hx('76827c'))
VEIL_LOCKED_HOVER = (hx('181e1c'), hx('414b46'), hx('55605a'), hx('6a7670'), hx('828f88'))
VEIL_UNCH = (hx('0b1211'), hx('16211f'), hx('1c2927'), hx('243431'), hx('2d3f3b'))
VEIL_UNCH_HOVER = (hx('0d1514'), hx('1a2624'), hx('212f2c'), hx('2a3b37'), hx('344843'))


def tile(name):
    return Image.open(B.TILES + geom.TILE_FILE[name]).convert('RGBA')


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def classify(img):
    """Per pixel: None (clear), 0 line, 1 shade, 2 base, 3 light, 4 brightest."""
    w, h = img.size
    out = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            p = img.getpixel((x, y))
            if p[3] < 128:
                continue
            L = lum(p)
            out[y][x] = 0 if L < 70 else (1 if L < 128 else (2 if L < 158 else (3 if L < 200 else 4)))
    return out


MASK_SRC = None


def mask():
    global MASK_SRC
    if MASK_SRC is None:
        a = tile('00_Basic').split()[3]
        MASK_SRC = {(x, y) for y in range(a.height) for x in range(a.width) if a.getpixel((x, y)) >= 128}
    return MASK_SRC


def ring_dist(pts, w, h, maxd=5):
    """Chebyshev distance from a point set, out to maxd."""
    dist = {p: 0 for p in pts}
    q = deque(pts)
    while q:
        x, y = q.popleft()
        d = dist[(x, y)]
        if d >= maxd:
            continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if 0 <= n[0] < w and 0 <= n[1] < h and n not in dist:
                    dist[n] = d + 1
                    q.append(n)
    return dist


# hex polygon in tile pixels (from the Basic tile's alpha), for dash lengths along the rim
HEX = [(81.5, 4), (159.5, 47), (159.5, 142.5), (81.5, 185), (4, 142.5), (4, 47)]


def arc(x, y, poly=HEX):
    best, s_best, s0 = 1e9, 0, 0
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy)
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / (L * L)))
        px, py = ax + t * dx, ay + t * dy
        d = math.hypot(x - px, y - py)
        if d < best:
            best, s_best = d, s0 + t * L
        s0 += L
    return s_best


def light_of(x, y, cx=81.5, cy=94.5):
    nx, ny = x - cx, y - cy
    L = math.hypot(nx, ny) or 1
    return (nx * -0.6 + ny * -0.8) / L


# ----------------------------------------------------------------------------
# Zone rims (overlays the size of a tile, laid at the tile's own top-left)
# ----------------------------------------------------------------------------
def rims():
    m = mask()
    w, h = 164, 190
    dist = ring_dist(m, w, h, 4)
    cur = new(w, h)
    opn = new(w, h)
    for (x, y), d in dist.items():
        if d == 0:
            continue
        li = light_of(x, y)
        if d == 1:
            put(cur, x, y, CREAM if li > 0.35 else (BRASS if li > -0.35 else BRASS_SH))
            put(opn, x, y, BRASS_SH if li > -0.2 else hx('7A4C26'))
        elif d == 2:
            put(cur, x, y, BRASS if li > 0.35 else BRASS_SH)
            put(opn, x, y, INK)
        elif d == 3:
            put(cur, x, y, INK)
        elif d == 4:
            # a lacquer collar on the grout: the current hex sits in a red-lacquered setting
            put(cur, x, y, RIM if li > 0.35 else LAC)
    save(cur, 'hex_current')
    save(opn, 'hex_open')
    # revision 2: hover and pinned are rim swaps in the same language, not brackets.
    # hex_hover replaces hex_open on an open hex you can travel to (outside the hex);
    # the veiled tiles carry their own dashed / dotted rim outside, so their hover and
    # pinned rims sit just inside the hex.
    hov = new(w, h)
    for (x, y), d in dist.items():
        li = light_of(x, y)
        if d == 1:
            put(hov, x, y, CREAM if li > 0.35 else (BRASS if li > -0.35 else BRASS_SH))
        elif d == 2:
            put(hov, x, y, INK)
    save(hov, 'hex_hover')
    outside = {(x, y) for y in range(h) for x in range(w) if (x, y) not in m}
    din = ring_dist(outside, w, h, 4)
    hin = new(w, h)
    pin = new(w, h)
    for (x, y), d in din.items():
        if (x, y) not in m:
            continue
        li = light_of(x, y)
        lit = CREAM if li > 0.35 else (BRASS if li > -0.35 else BRASS_SH)
        if d == 1:
            put(hin, x, y, lit)
            put(pin, x, y, lit)
        elif d == 2:
            put(hin, x, y, INK)
            put(pin, x, y, BRASS if li > -0.2 else BRASS_SH)
        elif d == 3:
            put(pin, x, y, INK)
    save(hin, 'hex_hover_in')
    save(pin, 'hex_pinned_in')


# ----------------------------------------------------------------------------
# Veiled tiles: locked (desaturated + dashed vermilion rim), uncharted (dark + dotted rim)
# ----------------------------------------------------------------------------
def veiled(src_name, ramp, rim):
    src = tile(src_name)
    cls = classify(src)
    w, h = src.size
    out = new(w, h)
    for y in range(h):
        for x in range(w):
            c = cls[y][x]
            if c is not None:
                out.putpixel((x, y), ramp[c])
    m = mask()
    dist = ring_dist(m, w, h, 3)
    for (x, y), d in dist.items():
        if d == 0:
            continue
        s = arc(x, y)
        if rim == 'dash':
            on = (s % 14) < 9
            if d in (1, 2) and on:
                put(out, x, y, VERM if (d == 1 and light_of(x, y) > -0.2) else VERM_D)
            elif d == 3 and on:
                put(out, x, y, INK)
        elif rim == 'dot':
            if d == 1 and (s % 8) < 2.5:
                put(out, x, y, TAN)
    return out, cls


def zone_tiles():
    for name, ramp in (('tile_locked', VEIL_LOCKED), ('tile_locked_hover', VEIL_LOCKED_HOVER)):
        img, _ = veiled('20_Stones', ramp, 'dash')
        save(img, name)
    for name, ramp in (('tile_uncharted', VEIL_UNCH), ('tile_uncharted_hover', VEIL_UNCH_HOVER)):
        img, cls = veiled('08_Mountains2', ramp, 'dot')
        save(img, name)


# ----------------------------------------------------------------------------
# Brackets: hover (three, like the game's selector frame 0) and pinned (six, with nails)
# ----------------------------------------------------------------------------
def brackets():
    W, H = 184, 210
    cx, cy = 92, 105
    # the tile hex grown by about 8 px, snapped to 2:1 stair steps
    V = {'t': (92, 6), 'tr': (176, 48), 'br': (176, 162), 'b': (92, 204), 'bl': (8, 162), 'tl': (8, 48)}
    arms = {  # vertex: two arm directions as (sx, sy, kind)
        't': ((-1, 1, 'd'), (1, 1, 'd')),
        'tr': ((-1, -1, 'd'), (0, 1, 'v')),
        'br': ((0, -1, 'v'), (-1, 1, 'd')),
        'b': ((-1, -1, 'd'), (1, -1, 'd')),
        'bl': ((0, -1, 'v'), (1, 1, 'd')),
        'tl': ((1, -1, 'd'), (0, 1, 'v')),
    }

    def draw(which, L, th, nails, name):
        img = new(W, H)
        pts = set()
        for v in which:
            vx, vy = V[v]
            for (sx, sy, kind) in arms[v]:
                for i in range(L):
                    if kind == 'd':
                        x, y = vx + sx * i, vy + sy * (i // 2)
                        for t in range(th):   # thicken toward the hex centre
                            yy = y + (t if cy > y else -t)
                            pts.add((x, yy))
                    else:
                        x, y = vx, vy + sy * i
                        for t in range(th):
                            xx = x + (t if cx > x else -t)
                            pts.add((xx, y))
        edge = set()
        lit_mask(img, pts, edge)
        if nails:
            for v in which:
                vx, vy = V[v]
                ox = 0 if vx == cx else (1 if vx < cx else -2)
                oy = 1 if vy < cy else -2
                if vx == cx:
                    ox = -1
                dome(img, vx + ox, vy + oy)
        save(img, name)

    draw(('t', 'bl', 'br'), 14, 2, False, 'bracket_hover')
    draw(('t', 'tr', 'br', 'b', 'bl', 'tl'), 18, 3, True, 'bracket_pinned')


# ----------------------------------------------------------------------------
# Map plates (248x52): current, open, locked (+hover), uncharted (+hover)
# ----------------------------------------------------------------------------
def plate(name, kind, hover=False):
    w, h = 124, 26
    img = new(w, h)
    field = DEEP if kind == 'uncharted' else LAC
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                if kind == 'locked':
                    c = (VERM if s == 'lit' else VERM_D)
                elif kind == 'uncharted':
                    c = (RIM_S if hover else RAISED) if s == 'lit' else INK
                else:
                    c = (RIM_S if hover else RIM) if s == 'lit' else DEEP
            elif d == 2 and kind == 'locked' and hover:
                c = VERM_D
            else:
                c = field
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    if kind != 'uncharted':
        streak(img, 12, 5, 26, ((11, 1),))
        streak(img, 78, 20, 30, ((14, -1),), GRAIN2)
    else:
        streak(img, 90, 6, 16, (), hx('281111'))
    if kind == 'current':
        for x in (3, w - 4):
            put(img, x, h // 2 - 1, BRASS)
            put(img, x, h // 2, BRASS_SH)
    save(img, name)


def plates():
    plate('plate_current', 'current')
    plate('plate_current_hover', 'current', hover=True)
    plate('plate_open', 'open')
    plate('plate_open_hover', 'open', hover=True)
    plate('plate_locked', 'locked')
    plate('plate_locked_hover', 'locked', hover=True)
    plate('plate_uncharted', 'uncharted')
    plate('plate_uncharted_hover', 'uncharted', hover=True)


# ----------------------------------------------------------------------------
# Map popovers: a lacquer card with a notch toward its hex; pinned ones get brass caps
# ----------------------------------------------------------------------------
def popover(name, h, side, pinned):
    pw = 132
    w = pw + 4
    x0 = 0 if side == 'right' else 4
    img = new(w, h)
    for y in range(h):
        for x in range(pw):
            d, s = side_of(x, y, pw, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            elif d == 2:
                c = INK if s == 'lit' else RIM_S
            else:
                c = LAC
            put(img, x0 + x, y, c)
    for (cx, cy) in ((0, 0), (pw - 1, 0), (0, h - 1), (pw - 1, h - 1)):
        put(img, x0 + cx, cy, CLEAR)
    streak(img, x0 + 14, 18, 40, ((15, 1),))
    streak(img, x0 + 70, h - 10, 48, ((20, -1),), GRAIN2)
    if h > 60:
        gloss(img, 5, [(x0 + 70, x0 + 112, RAISED), (x0 + 116, x0 + 117, RAISED)])
    else:
        gloss(img, 4, [(x0 + 54, x0 + 84, RAISED)])
    if pinned:
        caps(img, arm=7, th=3, x0=x0, y0=0, w=pw, h=h)
    # notch: a 4 px wedge cut through the rim, 9 rows tall, at the card's middle
    ny = h // 2
    for k in range(0, 5):              # k = columns from the rim outward (k=0 is the rim's outer column)
        half = 4 - k
        for dy in range(-half, half + 1):
            if side == 'right':
                X = x0 + pw - 1 + k
                Xin = [x0 + pw - 1 - j for j in range(3)]
            else:
                X = x0 - k
                Xin = [x0 + j for j in range(3)]
            Y = ny + dy
            edge = abs(dy) == half
            if k == 0:
                for xi in Xin:          # open the rim where the wedge joins the card
                    if abs(dy) < 4:
                        put(img, xi, Y, LAC)
            put(img, X, Y, INK if edge else LAC)
    # light the wedge's upper edge, shade its lower edge, as the rim is
    for k in range(0, 4):
        half = 4 - k
        X = (x0 + pw - 1 + k) if side == 'right' else (x0 - k)
        if half >= 1:
            put(img, X, ny - half + 1, RIM)
            put(img, X, ny + half - 1, DEEP)
    save(img, name)


def popovers():
    popover('pop_locked', 86, 'right', True)
    popover('pop_locked_preview', 66, 'right', False)
    popover('pop_uncharted', 56, 'left', True)
    popover('pop_uncharted_preview', 56, 'left', False)


# ----------------------------------------------------------------------------
# Fog: per-tier atlases (one cell per pool tile) and full-screen composites per state
# ----------------------------------------------------------------------------
def fog_tile(art, tier):
    src = tile(art)
    cls = classify(src)
    w, h = src.size
    out = new(w, h)
    ramp = FOG[tier]
    for y in range(h):
        for x in range(w):
            c = cls[y][x]
            if c is None:
                continue
            out.putpixel((x, y), ramp[min(3, c)])
    return out


def fog():
    cache = {}
    for tier in (1, 2, 3):
        sheet = new(164 * len(geom.POOL), 190)
        for i, art in enumerate(geom.POOL):
            t = fog_tile(art, tier)
            cache[(art, tier)] = t
            sheet.paste(t, (i * 164, 0))
        save(sheet, 'fog_t%d_atlas' % tier)
    for state in geom.STATES:
        screen = Image.new('RGBA', (1920, 1080), GROUND)
        for (c, tier, art) in geom.fog_cells(state):
            t = cache[(art, tier)].resize((328, 380), Image.NEAREST)
            screen.paste(t, geom.tile_tl(*c), t)
        fn = 'lacquer_fog_%s_ai.png' % state
        screen.convert('RGB').save(B.OUT + fn)
        B.SAVED.append(fn)


def run():
    rims()
    zone_tiles()
    plates()
    popovers()
    fog()


if __name__ == '__main__':
    run()
