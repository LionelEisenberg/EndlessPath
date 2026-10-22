"""Lacquer and brass base (copied from lacquer_work/v2/gen2.py; only OUT, save() and the tile paths changed).

Round 2 notes: every sprite drawn at native size, saved at 2x nearest.

One object per panel (no shared 9-slice): the cultivator cabinet, the hanging goals
board, the zone cabinet with its drawers, the dock shelf. Grain, gloss and wear are
placed by hand below, not by a random generator.
"""
import math
from PIL import Image

SCRATCH = ("C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-endless-path-js-vs-godot-fe1f72/"
           "c2134538-305c-43cf-9f63-9a433ef4bec2/scratchpad/")
OUT = SCRATCH + "lacquer_full/assets/"
REPO = "C:/worktrees/EndlessPath/endless-path-js-vs-godot-fe1f72/"
TILES = REPO + "assets/sprites/tilemap/hex_tiles/forest/"


def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


CLEAR = (0, 0, 0, 0)
# lacquer ramp: 8x8_ui_elements_blood.png
INK = hx('150909')
DEEP = hx('230f0f')
LAC = hx('2c1414')
GRAIN = hx('321616')
GRAIN2 = hx('391919')
RAISED = hx('462020')
RIM_S = hx('612b2b')
RIM = hx('692f2f')
# brass, cream, tan: pixel_theme.tres; brass shade: ic_merchant.png
BRASS = hx('D4A84A')
BRASS_SH = hx('A66834')
CREAM = hx('F0E8D8')
TAN = hx('A89070')
# jade: ic_fern.png
JADE_HI = hx('AAECCE')
JADE = hx('5CC4A0')
JADE_SH = hx('2F6B4A')
JADE_OL = hx('102c1e')
# madra: the in-game orb / ic_dewdrop.png / character.png
M_HI = hx('E8F6FD')
M_PALE = hx('BBD5E7')
M_MID = hx('849BE4')
M_DEEP = hx('1C2F60')
M_OL = hx('16283e')
# vermilion: victory_icon.png #b64336, one step darker so cream text passes 4.5:1
VERM = hx('A83C30')
VERM_D = hx('7E2A22')


def new(w, h, c=CLEAR):
    return Image.new('RGBA', (w, h), c)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


SAVED = []


def save(img, name, s=2):
    """Every sprite is drawn at native size and written at 2x nearest, with the _ai suffix."""
    fn = 'lacquer_' + name + '_ai.png'
    img.resize((img.width * s, img.height * s), Image.NEAREST).save(OUT + fn)
    SAVED.append(fn)


def side_of(x, y, w, h):
    dt, db, dl, dr = y, h - 1 - y, x, w - 1 - x
    d = min(dt, db, dl, dr)
    s = sorted([(dt, 0), (dl, 1), (db, 2), (dr, 3)])[0][1]
    return d, ('lit' if s in (0, 1) else 'shade')


# ----------------------------------------------------------------------------
# Hand-placed details
# ----------------------------------------------------------------------------
def streak(img, x0, y, length, jogs=(), col=GRAIN):
    """One grain line. jogs: (offset, dy) pairs where the line steps up or down."""
    j = dict(jogs)
    for i in range(length):
        y += j.get(i, 0)
        put(img, x0 + i, y, col)


def gloss(img, y, segs):
    """Lacquer gloss: a 1 px (2 screen px) reflected band, broken into a few dashes."""
    for x0, x1, c in segs:
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def nail(img, x, y):
    put(img, x, y, INK)
    put(img, x + 1, y + 1, BRASS_SH)


def lit_mask(img, pts, edge):
    """Colour a brass shape lit from the top-left; `edge` pixels are left as ink."""
    w, h = img.size
    inner = lambda q: q in pts and q not in edge
    for (X, Y) in pts:
        if (X, Y) in edge:
            img.putpixel((X, Y), INK)
            continue
        if not inner((X, Y - 1)) or not inner((X - 1, Y)):
            c = CREAM
        elif not inner((X, Y + 1)) or not inner((X + 1, Y)):
            c = BRASS_SH
        else:
            c = BRASS
        img.putpixel((X, Y), c)
    for (X, Y) in list(pts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (X + dx, Y + dy)
            if 0 <= q[0] < w and 0 <= q[1] < h and q not in pts:
                img.putpixel(q, INK)


def dome(img, xa, ya):
    """2x2 domed nail head."""
    put(img, xa, ya, CREAM)
    put(img, xa + 1, ya, BRASS_SH)
    put(img, xa, ya + 1, BRASS_SH)
    put(img, xa + 1, ya + 1, INK)


def strap(img, corner, arm=16, th=6, lost_nail=False, worn=False):
    """Plain L-shaped brass corner strap over the molding, domed nails, 45-degree tips."""
    w, h = img.size
    m = set()
    for i in range(arm):
        for t in range(th):
            m.add((i, t))
            m.add((t, i))
    for k in range(1, th):          # 45-degree cut at each arm tip
        for j in range(k):
            m.discard((arm - 1 - j, k))
            m.discard((k, arm - 1 - j))

    def fl(p):
        x, y = p
        if corner in ('tr', 'br'):
            x = w - 1 - x
        if corner in ('bl', 'br'):
            y = h - 1 - y
        return (x, y)

    pts = {fl(p) for p in m}
    edge = {p for p in pts if p[0] in (0, w - 1) or p[1] in (0, h - 1)}
    lit_mask(img, pts, edge)
    for i, (nx, ny) in enumerate(((2, 2), (arm - 6, 2), (2, arm - 6))):
        X0, Y0 = fl((nx, ny))
        X1, Y1 = fl((nx + 1, ny + 1))
        xa, ya = min(X0, X1), min(Y0, Y1)
        if lost_nail and i == 1:
            put(img, xa + 1, ya + 1, INK)  # the nail is gone; only its hole is left
            continue
        dome(img, xa, ya)
    if worn:
        # the highlight rubbed off along the top arm, where hands catch it
        for i in range(6, 10):
            X, Y = fl((i, 1))
            put(img, X, Y, BRASS)


# ----------------------------------------------------------------------------
# Cabinet frame: a raised molding around a recessed lacquer field
# ----------------------------------------------------------------------------
def cabinet(w, h):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            elif d in (2, 3):
                c = RAISED
            elif d == 4:
                c = INK if s == 'lit' else RIM_S
            else:
                c = LAC
            img.putpixel((x, y), c)
    return img


def cultivator():
    w, h = 220, 126
    img = cabinet(w, h)
    # hand-placed grain under the lacquer
    streak(img, 12, 21, 54, ((19, 1), (41, -1)))
    streak(img, 70, 36, 30, ((12, 1),), GRAIN2)
    streak(img, 140, 14, 62, ((8, 1), (37, 1), (50, -1)))
    streak(img, 118, 58, 22, ())
    streak(img, 30, 74, 40, ((27, -1),))
    streak(img, 158, 86, 48, ((15, 1), (31, 1)), GRAIN2)
    streak(img, 62, 103, 66, ((22, -1), (44, -1)))
    streak(img, 180, 112, 26, ((9, 1),))
    # gloss, under the top molding
    gloss(img, 8, [(20, 92, RAISED), (96, 101, RAISED), (105, 106, RAISED)])
    gloss(img, 8, [(30, 41, RIM_S)])
    # a chip knocked out of the bottom molding
    put(img, 151, h - 2, RAISED)
    put(img, 152, h - 2, RAISED)
    put(img, 152, h - 3, LAC)
    # cord rings on the bottom molding, where the goals board hangs
    for cx in (30, 189):
        for (dx, dy) in ((0, 0), (1, 0), (-1, 1), (2, 1)):
            put(img, cx + dx, h - 3 + dy, BRASS_SH)
        put(img, cx, h - 3, BRASS)
        put(img, cx + 1, h - 3, BRASS)
    strap(img, 'tl', worn=True)
    strap(img, 'tr')
    strap(img, 'bl')
    strap(img, 'br')
    save(img, 'cult')


def goals_board():
    """A thinner board hung on two cords; no brass straps, chamfered corners."""
    w, bh, top = 220, 100, 10
    img = new(w, bh + top)
    board = new(w, bh)
    for y in range(bh):
        for x in range(w):
            d, s = side_of(x, y, w, bh)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            elif d == 2:
                c = INK if s == 'lit' else RIM_S
            else:
                c = LAC
            board.putpixel((x, y), c)
    # chamfer the four corners (2 px)
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, bh - 1, 1, -1), (w - 1, bh - 1, -1, -1)):
        put(board, cx, cy, CLEAR)
        put(board, cx + sx, cy, CLEAR)
        put(board, cx, cy + sy, CLEAR)
        put(board, cx + sx, cy + sy, INK)
        put(board, cx + 2 * sx, cy, INK)
        put(board, cx, cy + 2 * sy, INK)
    streak(board, 20, 30, 70, ((25, 1), (52, 1)))
    streak(board, 128, 22, 44, ((14, -1),), GRAIN2)
    streak(board, 40, 61, 36, ())
    streak(board, 150, 70, 50, ((20, 1), (38, -1)))
    streak(board, 90, 92, 58, ((30, 1),), GRAIN2)
    gloss(board, 5, [(52, 120, RAISED), (124, 128, RAISED), (132, 133, RAISED)])
    gloss(board, 5, [(60, 69, RIM_S)])
    img.paste(board, (0, top))
    # two cords from the cabinet above, each through a brass eyelet
    for cx in (30, 189):
        for y in range(0, top + 4):
            put(img, cx, y, BRASS_SH if (y // 2) % 2 == 0 else BRASS)
            put(img, cx + 1, y, INK)
        # eyelet
        for (dx, dy) in ((-1, 0), (2, 0), (-1, 1), (2, 1), (-1, 2), (2, 2), (0, 3), (1, 3)):
            put(img, cx + dx, top + 2 + dy, BRASS)
        put(img, cx - 1, top + 2, CREAM)
        put(img, cx + 2, top + 4, BRASS_SH)
        put(img, cx + 1, top + 5, BRASS_SH)
    save(img, 'goals')


def zone_cabinet():
    w, h = 220, 326
    img = cabinet(w, h)
    streak(img, 16, 30, 44, ((17, 1),))
    streak(img, 150, 52, 56, ((11, -1), (40, 1)), GRAIN2)
    streak(img, 60, 98, 34, ())
    streak(img, 9, 170, 28, ((14, 1),))
    streak(img, 196, 150, 16, ())
    streak(img, 200, 236, 14, ((6, 1),), GRAIN2)
    streak(img, 8, 262, 20, ())
    streak(img, 70, 318, 90, ((24, -1), (60, 1)))
    gloss(img, 8, [(24, 112, RAISED), (116, 122, RAISED), (126, 127, RAISED)])
    gloss(img, 8, [(34, 47, RIM_S)])
    strap(img, 'tl')
    strap(img, 'tr', worn=True)
    strap(img, 'bl')
    strap(img, 'br', lost_nail=True)
    save(img, 'cabinet')


# ----------------------------------------------------------------------------
# Drawers (activity cards) with a recessed icon socket
# ----------------------------------------------------------------------------
def socket(img, x0, y0, n=22):
    for y in range(n):
        for x in range(n):
            d, s = side_of(x, y, n, n)
            if d == 0:
                c = INK if s == 'lit' else RIM
            elif d == 1:
                c = INK if s == 'lit' else DEEP
            else:
                c = DEEP
            put(img, x0 + x, y0 + y, c)


def drawer(name, w, h, running=False):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            else:
                c = RAISED
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    socket(img, 3, 3)
    if running:
        # brass caps on this drawer only: it is the one in use
        for corner in ('tl', 'tr', 'bl', 'br'):
            m = set()
            for i in range(7):
                for t in range(3):
                    m.add((i, t))
                    m.add((t, i))
            m.discard((6, 2))
            m.discard((2, 6))

            def fl(p, corner=corner):
                x, y = p
                if corner in ('tr', 'br'):
                    x = w - 1 - x
                if corner in ('bl', 'br'):
                    y = h - 1 - y
                return (x, y)
            pts = {fl(p) for p in m}
            edge = {p for p in pts if p[0] in (0, w - 1) or p[1] in (0, h - 1)}
            lit_mask(img, pts, edge)
            X, Y = fl((0, 0))
            put(img, X, Y, CLEAR)
    save(img, name)


# ----------------------------------------------------------------------------
# Recessed tray for the Now strip and the dock shelf
# ----------------------------------------------------------------------------
def tray(name, w, h, field=DEEP):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK if s == 'lit' else RIM
            elif d == 1:
                c = INK if s == 'lit' else field
            else:
                c = field
            img.putpixel((x, y), c)
    save(img, name)
    return img


def brass_plate(name, w, h):
    """Little label plate riveted over an edge (the Now legend)."""
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = CREAM if s == 'lit' else BRASS_SH
            else:
                c = BRASS
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    put(img, 2, h // 2, INK)
    put(img, w - 3, h // 2, INK)
    save(img, name)


def tablet(name, w, h, ring=False):
    """Raised button. ring=True wraps it in the 2 px brass notification ring."""
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if ring:
                if d == 0:
                    c = BRASS_SH if s == 'shade' else BRASS
                elif d == 1:
                    c = INK
                elif d == 2:
                    c = RIM if s == 'lit' else DEEP
                else:
                    c = RAISED
            else:
                if d == 0:
                    c = INK
                elif d == 1:
                    c = RIM if s == 'lit' else DEEP
                else:
                    c = RAISED
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, name)


def nameboard(name, w=76, h=16):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            else:
                c = LAC
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    streak(img, 9, 4, 22, ((10, 1),))
    streak(img, 46, 12, 18, ())
    for x in (3, w - 4):
        put(img, x, h // 2 - 1, BRASS)
        put(img, x, h // 2, BRASS_SH)
    save(img, name)


# ----------------------------------------------------------------------------
# Seals: hand-cut chops, the worn bites placed by hand
# ----------------------------------------------------------------------------
def seal(name, w, h, bites, starved=()):
    """Cinnabar chop: a solid block, corners knocked off, worn bites cut by hand."""
    img = new(w, h, VERM)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    for (x, y) in bites:
        put(img, x, y, CLEAR)
    for (x, y) in starved:
        put(img, x, y, VERM_D)
    save(img, name)


# ----------------------------------------------------------------------------
# Progress: jade or Madra rods inlaid in a carved groove; abacus beads for XP
# ----------------------------------------------------------------------------
def rod(name, w, frac, hi, mid, sh):
    h = 5
    img = new(w, h, INK)
    for x in range(w):
        put(img, x, h - 1, RIM_S)  # lit lower lip of the groove
    put(img, w - 1, 0, INK)
    for y in range(h - 1):
        put(img, w - 1, y, RIM_S)
    fill = int(round(frac * (w - 2)))
    for x in range(1, 1 + fill):
        put(img, x, 1, hi)
        put(img, x, 2, mid)
        put(img, x, 3, sh)
    # rounded rod end
    if fill > 2:
        put(img, fill, 1, mid)
        put(img, fill, 3, INK)
    save(img, name)


def beads(name, n, lit):
    bw, gap = 5, 1
    w = n * (bw + gap) + 3
    h = 6
    img = new(w, h)
    # the wire, with brass end posts
    for x in range(w):
        put(img, x, 2, BRASS_SH)
        put(img, x, 3, INK)
    for x in (0, w - 1):
        for y in range(h):
            put(img, x, y, BRASS_SH if y else BRASS)
    for i in range(n):
        x0 = 2 + i * (bw + gap)
        on = i < lit
        face, top, bot = (JADE, JADE_HI, JADE_SH) if on else (RAISED, RIM, DEEP)
        for y in range(h):
            for x in range(bw):
                if (x in (0, bw - 1)) and y in (0, h - 1):
                    continue
                c = face
                if y == 0 or (y == 1 and x in (0, bw - 1)):
                    c = top
                if y == h - 1 or (y == h - 2 and x in (0, bw - 1)):
                    c = bot
                put(img, x0 + x, y, c)
    save(img, name)


def bead_ring(name, D=28, n=12, lit=5):
    """A string of 12 beads round the action icon; the lit beads step round once per tick."""
    img = new(D, D)
    c = (D - 1) / 2
    r = 11.0
    for a in range(720):
        t = a / 720 * 2 * math.pi
        put(img, int(round(c + r * math.cos(t))), int(round(c + r * math.sin(t))), INK)
    bead = [".##.", "####", "####", ".##."]
    for i in range(n):
        t = -math.pi / 2 + i * 2 * math.pi / n
        bx = int(round(c + r * math.cos(t) - 1.5))
        by = int(round(c + r * math.sin(t) - 1.5))
        on = i < lit
        face, top, bot = (JADE, JADE_HI, JADE_SH) if on else (RAISED, RIM, DEEP)
        for y in range(4):
            for x in range(4):
                if bead[y][x] != '#':
                    continue
                col = face
                if y == 0 or (x == 0 and y == 1):
                    col = top
                if y == 3 or (x == 3 and y == 2):
                    col = bot
                put(img, bx + x, by + y, col)
        for (x, y) in ((0, 0), (3, 0), (0, 3), (3, 3), (-1, 1), (-1, 2), (4, 1), (4, 2), (1, -1), (2, -1), (1, 4), (2, 4)):
            X, Y = bx + x, by + y
            if 0 <= X < D and 0 <= Y < D and img.getpixel((X, Y))[3] == 0:
                put(img, X, Y, INK)
    save(img, name)


# ----------------------------------------------------------------------------
# Orbs
# ----------------------------------------------------------------------------
def madra_orb(name, D=40, frac=46 / 260):
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    ri = R - 4.2
    top = c + ri - 2 * ri * frac
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > R - 0.3:
                continue
            ang = math.atan2(y - c, x - c)
            light = math.cos(ang + math.pi * 0.75)
            if r > R - 1.3:
                col = INK
            elif r > R - 3.2:
                col = BRASS
                if light > 0.6 and r > R - 2.2:
                    col = CREAM
                elif light < -0.3:
                    col = BRASS_SH
            elif r > ri:
                col = INK
            else:
                col = M_OL
                if y + 0.5 >= top:
                    depth = y + 0.5 - top
                    col = M_HI if depth < 1.0 else (M_PALE if y < D - 9 else M_MID)
            img.putpixel((x, y), col)
    # hard glint on the empty glass, upper left: a short arc of pixels
    for (x, y) in ((10, 14), (10, 13), (11, 12), (12, 11), (13, 10), (14, 10)):
        put(img, x, y, M_DEEP)
    put(img, 11, 12, M_MID)
    put(img, 12, 11, M_MID)
    save(img, name)


def core_orb(name, D=40, frac=0.32):
    """Carved lacquer socket (no brass); the swirl fills from the centre."""
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    rs = R * frac
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > R - 0.3:
                continue
            ang = math.atan2(y - c, x - c)
            light = math.cos(ang + math.pi * 0.75)
            if r > R - 1.3:
                col = INK
            elif r > R - 3.2:
                col = RIM if light > 0.2 else (DEEP if light < -0.2 else RAISED)
            elif r > R - 4.2:
                col = INK
            else:
                col = hx('110707')
                if r <= rs + 1.0 and r > rs:
                    col = M_HI  # white edge ring
                elif r <= rs:
                    t = (ang * 2 + r * 1.1) % (2 * math.pi)
                    col = M_PALE if t < math.pi else M_MID
                    if r < 1.2:
                        col = M_HI
            img.putpixel((x, y), col)
    save(img, name)


# ----------------------------------------------------------------------------
# Carved divider with end caps
# ----------------------------------------------------------------------------
def carved_line(name, w):
    img = new(w, 3)
    for x in range(3, w - 3):
        put(img, x, 1, INK)
        put(img, x, 2, RIM_S)
    for ex, sgn in ((1, 1), (w - 2, -1)):
        put(img, ex, 0, INK)
        put(img, ex - 1 * sgn, 1, INK)
        put(img, ex, 1, BRASS_SH)
        put(img, ex + 1 * sgn, 1, INK)
        put(img, ex, 2, RIM_S)
    save(img, name)


# ----------------------------------------------------------------------------
# 16 px icons redrawn to sit on the same grid as the ic_* set
# ----------------------------------------------------------------------------
def grid_icon(name, rows, pal):
    h = len(rows)
    w = len(rows[0])
    img = new(w, h)
    for y, row in enumerate(rows):
        assert len(row) == w, (name, y, len(row))
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((x, y), pal[ch])
    save(img, name)


WARM_OL = hx('341E0E')
GOLD_Y = hx('E3B95A')
GOLD_C = hx('C4884A')


def icons():
    coin = [
        "................",
        ".....oooooo.....",
        "...oohhyyyyoo...",
        "..ohyyyyyyyyco..",
        "..ohyyyyyyyyco..",
        ".ohyyyooooyyyco.",
        ".ohyyyo..oyyyco.",
        ".oyyyyo..oyyyco.",
        ".oyyyyo..oyyyco.",
        ".oyyyyooooyyccо.",
        "..oyyyyyyyyyco..",
        "..ocyyyyyyycco..",
        "...oocccccccoo..",
        ".....oooooo.....",
        "................",
        "................",
    ]
    coin = [r.replace('о', 'o') for r in coin]
    # a second coin peeking out behind, lower right, for a small pile
    coin = [
        "................",
        "....oooooo......",
        "..oohhyyyyoo....",
        ".ohyyyyyyyyco...",
        ".ohyyyyyyyyco...",
        "ohyyyooooyyycoo.",
        "ohyyyo..oyyycyyo",
        "oyyyyo..oyyycyyo",
        "oyyyyo..oyyycyco",
        "oyyyyooooyyccyco",
        ".oyyyyyyyyyco.co",
        ".ocyyyyyyycco.co",
        "..oocccccccoocco",
        "....oooooo.oooo.",
        "................",
        "................",
    ]
    grid_icon('ic_coin', coin, {'o': WARM_OL, 'h': CREAM, 'y': GOLD_Y, 'c': GOLD_C})

    star = [
        "................",
        ".......oo.......",
        "......ohyo......",
        "......ohyo......",
        ".....ohyyyo.....",
        "ooooo hyyyyooooo",
        "ohhhhhyyyyyyycco",
        ".ohyyyyyyyyyyco.",
        "..ohyyyyyyyyco..",
        "...oyyyyyyycco..",
        "...oyyyyyyycco..",
        "..oyyycoocyycco.",
        "..oyyco..ocycco.",
        ".oycoo....oocco.",
        ".ooo........ooo.",
        "................",
    ]
    star[5] = "oooooohyyyyooooo"
    grid_icon('ic_star', star, {'o': WARM_OL, 'h': CREAM, 'y': GOLD_Y, 'c': GOLD_C})

    SW_OL = hx('1D1830')
    SW_L = hx('B5BAC4')
    SW_M = hx('8A8F9A')
    GRIP = hx('6B4A2A')
    swords = [
        "oo............oo",
        "olo..........olo",
        "olmo........olmo",
        ".olmo......olmo.",
        "..olmo....olmo..",
        "...olmo..olmo...",
        "....olmoolmo....",
        ".....olmlmo.....",
        "......olmo......",
        ".....olmolmo....",
        "..oo.olmoolmo.oo",
        "..oyyolo..olyyo.",
        "...oyyo....oyyo.",
        "..obo.oo..oo.obo",
        ".obo..........ob",
        ".oo...........oo",
    ]
    swords = [
        "oo............oo",
        "olo..........olo",
        "olmo........olmo",
        ".olmo......olmo.",
        "..olmo....olmo..",
        "...olmo..olmo...",
        "....olmoolmo....",
        ".....olmlmo.....",
        "......olmo......",
        ".....olmolmo....",
        "..oooolmoolmoooo",
        "..oyyyolo.olyyyo",
        "...ooyyo..oyyoo.",
        "...obboo..oobbo.",
        "..obbo......obbo",
        "..ooo........ooo",
    ]
    grid_icon('ic_swords', swords, {'o': SW_OL, 'l': SW_L, 'm': SW_M, 'y': GOLD_Y, 'b': GRIP})

    core = [
        "................",
        ".....oooooo.....",
        "...oo......oo...",
        "..o..........o..",
        "..o....ww....o..",
        ".o....wppw....o.",
        ".o...wpmmpw...o.",
        ".o...wmpphw...o.",
        ".o...wpmpmw...o.",
        ".o....wmmw....o.",
        "..o....ww....o..",
        "..o..........o..",
        "...oo......oo...",
        ".....oooooo.....",
        "................",
        "................",
    ]
    # fill the dark disc
    filled = []
    for y, row in enumerate(core):
        inside = False
        r = list(row)
        xs = [i for i, ch in enumerate(row) if ch == 'o']
        if len(xs) >= 2:
            for x in range(xs[0] + 1, xs[-1]):
                if r[x] == '.':
                    r[x] = 'd'
        filled.append(''.join(r))
    filled[1] = ".....oooooo....."
    filled[13] = ".....oooooo....."
    filled[2] = "...oorrrrrroo..."
    filled[3] = "..ordddddddddo.."
    grid_icon('ic_core', filled, {'o': INK, 'r': RIM, 'd': hx('110707'), 'w': M_HI, 'p': M_PALE,
                                  'm': M_MID, 'h': M_HI})


def core_icon(name, D=16):
    img = new(D, D)
    c = (D - 1) / 2
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > 7.6:
                continue
            ang = math.atan2(y - c, x - c)
            light = math.cos(ang + math.pi * 0.75)
            if r > 6.6:
                col = INK
            elif r > 5.6:
                col = RIM if light > 0.1 else DEEP
            elif r > 4.7:
                col = hx('110707')
            elif r > 3.8:
                col = M_HI
            else:
                t = (ang * 2 + r * 1.3) % (2 * math.pi)
                col = M_PALE if t < math.pi else M_MID
                if r < 0.9:
                    col = M_HI
            img.putpixel((x, y), col)
    save(img, name)


def thumb():
    """42x48 hex thumbnail of hex_06_river with the brass current-zone outline."""
    src = Image.open(TILES + 'Hex_Forest_06_River.png').convert('RGBA')
    w, h = 21, 24
    small = src.resize((w, h), Image.BOX)
    mask = src.split()[3].resize((w, h), Image.BOX)
    pal = [hx('789C87'), hx('8DB389'), hx('BBD5E7'), hx('E8F6FD'), hx('121512'), hx('5F6D5F')]
    out = new(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            if mask.getpixel((x, y)) < 128:
                continue
            r, g, b, a = small.getpixel((x, y))
            best = min(pal, key=lambda p: (p[0] - r) ** 2 + (p[1] - g) ** 2 + (p[2] - b) ** 2)
            out.putpixel((x + 1, y + 1), best)
    # outline: brass ring around the hex, ink outside it
    pts = {(x, y) for y in range(h + 2) for x in range(w + 2) if out.getpixel((x, y))[3]}
    edge = [p for p in pts if any((p[0] + dx, p[1] + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        out.putpixel(p, BRASS)
    save(out, 'thumb')
    return out


def char_shadow():
    img = new(14, 3)
    for x in range(2, 12):
        put(img, x, 0, hx('5F6D5F'))
        put(img, x, 2, hx('5F6D5F'))
    for x in range(0, 14):
        put(img, x, 1, hx('5F6D5F'))
    put(img, 0, 1, CLEAR); put(img, 13, 1, CLEAR)
    save(img, 'char_shadow')


def fog():
    """Ground for the map fragment at native scale (shown 2x): the fog honeycomb."""
    W, H = 600, 350
    ground = hx('090e0e')
    near = hx('111a19')
    dash = hx('18'+'24'+'23')
    img = new(W, H, ground)
    mask = Image.open(TILES + 'Hex_Forest_00_Basic.png').convert('RGBA').split()[3]
    cx, cy = 300, 143  # current tile centre (screen 600, 286)
    for (dx, dy) in ((-166, 0), (166, 0), (-83, -144), (83, -144), (-83, 144), (83, 144), (-249, -144), (249, -144), (-249, 144), (249, 144)):
        tile = new(164, 190, near)
        img.paste(tile, (cx + dx - 82, cy + dy - 95), mask)
    # ink grass in the fog, placed by hand
    for (x, y, n) in ((205, 70, 6), (230, 252, 5), (382, 40, 7), (402, 262, 6), (186, 300, 5), (420, 214, 4), (172, 120, 5)):
        for i in range(n):
            put(img, x + i, y + (1 if i in (2, 3) else 0), dash)
    img.resize((W * 2, H * 2), Image.NEAREST).save(OUT + 'lacquer_fog_swatch_ai.png')


if __name__ == '__main__':
    cultivator()
    goals_board()
    zone_cabinet()
    drawer('drawer', 202, 28)
    drawer('drawer_run', 202, 28, running=True)
    drawer('drawer_tall', 202, 42)
    tray('now_tray', 202, 44)
    brass_plate('now_plate', 30, 11)
    bead_ring('ring')
    tray('dock', 120, 40)
    tablet('btn', 54, 32)
    tablet('btn_ring', 54, 32, ring=True)
    tablet('about', 40, 16)
    nameboard('nameboard')
    seal('seal_new', 26, 13, [(5, 0), (6, 0), (7, 0), (25, 5), (25, 6), (15, 12), (16, 12), (0, 9), (1, 0), (24, 12)],
         [(6, 1), (24, 6), (1, 9), (16, 11), (2, 11), (3, 11)])
    seal('seal_count', 12, 12, [(4, 0), (5, 0), (11, 7), (0, 8), (1, 11)], [(4, 1), (10, 7), (1, 8)])
    rod('rod_level', 84, 214 / 300, JADE_HI, JADE, JADE_SH)
    rod('rod_goal', 140, 0.32, JADE_HI, JADE, JADE_SH)
    rod('rod_madra', 98, 46 / 60, M_HI, M_PALE, M_MID)
    beads('beads_xp', 18, 17)
    madra_orb('orb_madra')
    core_orb('orb_core')
    carved_line('line', 204)
    icons()
    core_icon('ic_core')
    thumb()
    char_shadow()
    fog()
    print('ok')
