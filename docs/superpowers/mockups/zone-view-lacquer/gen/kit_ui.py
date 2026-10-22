"""Lacquer and brass, full kit: the panel pieces (left column, zone chest, dock).

Extends lq_base.py (the swatch generator). Same rules: one native grid saved at 2x
nearest, grain and gloss placed by hand, lit from the top-left, no randomness.
"""
import math

from lq_base import (CLEAR, INK, DEEP, LAC, GRAIN, GRAIN2, RAISED, RIM_S, RIM, BRASS, BRASS_SH,
                     CREAM, TAN, JADE_HI, JADE, JADE_SH, M_HI, M_PALE, M_MID, M_DEEP, M_OL, VERM,
                     VERM_D, hx, new, put, rect, save, side_of, streak, gloss, lit_mask, dome,
                     strap, cabinet, socket, tray, brass_plate, tablet, seal, carved_line)
import lq_base as B

SOCKET = hx('110707')   # the darkest lacquer, inside carved sockets (swatch core orb)


# ----------------------------------------------------------------------------
# Small brass corner caps (the running drawer's caps, any size)
# ----------------------------------------------------------------------------
def caps(img, arm=7, th=3, corners=('tl', 'tr', 'bl', 'br'), x0=0, y0=0, w=None, h=None):
    w = w or img.width
    h = h or img.height
    for corner in corners:
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
        lit_mask(img, pts, edge)
        X, Y = fl((0, 0))
        put(img, X, Y, CLEAR)


# ----------------------------------------------------------------------------
# Zone chest: the zone panel, sized to its content (revision 2). Three slices: the top
# (header and Now tray, 128 px), a middle that repeats down (128 px), the bottom (48 px).
# ----------------------------------------------------------------------------
def chest():
    w, h = 220, 516
    img = cabinet(w, h)
    # grain in the top slice (rows 0-63) and the bottom slice (rows 492-515), placed by hand
    streak(img, 16, 30, 44, ((17, 1),))
    streak(img, 150, 52, 56, ((11, -1), (40, 1)), GRAIN2)
    streak(img, 62, 508, 96, ((24, -1), (60, 1)))
    streak(img, 150, 498, 40, ((13, 1),), GRAIN2)
    # gloss under the top molding, on the right this time (the cabinet's is on the left)
    gloss(img, 8, [(98, 168, RAISED), (172, 177, RAISED), (181, 182, RAISED)])
    gloss(img, 8, [(146, 155, RIM_S)])
    # a short sheen down the left stile, where the light also falls
    for y in range(36, 56):
        put(img, 6, y, RAISED)
    strap(img, 'tl')
    strap(img, 'tr', worn=True)
    strap(img, 'bl')
    strap(img, 'br', lost_nail=True)
    save(img.crop((0, 0, w, 64)), 'chest_top')
    save(img.crop((0, h - 24, w, h)), 'chest_bot')
    # the middle: the bare side profile, with grain kept inside the tile so it repeats cleanly
    prof = cabinet(w, 200)
    mid = new(w, 64)
    for y in range(64):
        for x in range(w):
            mid.putpixel((x, y), prof.getpixel((x, 100)))
    streak(mid, 9, 10, 22, ((9, 1),))
    streak(mid, 198, 22, 14, ((5, -1),))
    streak(mid, 8, 38, 18, ((7, 1),), GRAIN2)
    streak(mid, 196, 50, 16, ())
    streak(mid, 60, 30, 34, ((15, 1),))
    streak(mid, 120, 56, 44, ((20, -1),), GRAIN2)
    save(mid, 'chest_mid')


# ----------------------------------------------------------------------------
# Boards: log board (fixed), lore popover panel
# ----------------------------------------------------------------------------
def board_base(w, h, chamfer=True):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            elif d == 2:
                c = INK if s == 'lit' else RIM_S
            else:
                c = LAC
            img.putpixel((x, y), c)
    if chamfer:
        for (cx, cy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
            put(img, cx, cy, CLEAR)
            put(img, cx + sx, cy, CLEAR)
            put(img, cx, cy + sy, CLEAR)
            put(img, cx + sx, cy + sy, INK)
            put(img, cx + 2 * sx, cy, INK)
            put(img, cx, cy + 2 * sy, INK)
    return img


def log_board(n):
    """The log board for n lines (1-5): 74 + 26n px tall, so it hugs its lines."""
    w, h = 220, 37 + 13 * n
    img = board_base(w, h)
    streak(img, 140, 18, 40, ((13, -1),), GRAIN2)
    # grain under the lines, measured from the bottom so every height keeps the same marks
    for (x, dy, ln, jogs, col) in ((60, 12, 70, ((28, 1),), GRAIN2), (120, 36, 56, ((18, 1), (40, -1)), GRAIN),
                                   (30, 50, 30, (), GRAIN), (24, 78, 60, ((22, 1), (47, 1)), GRAIN)):
        if h - dy >= 26:
            streak(img, x, h - dy, ln, jogs, col)
    # gloss: a short run at the top right, away from the other boards' gloss
    gloss(img, 5, [(128, 170, RAISED), (174, 177, RAISED), (181, 181, RAISED)])
    gloss(img, 5, [(150, 156, RIM_S)])
    save(img, 'log%d' % n)


def lore_panel():
    w, h = 204, 132
    img = board_base(w, h)
    streak(img, 20, 22, 48, ((19, 1),))
    streak(img, 120, 34, 60, ((9, 1), (38, -1)), GRAIN2)
    streak(img, 16, 70, 36, ())
    streak(img, 104, 92, 70, ((26, 1), (51, -1)))
    streak(img, 30, 112, 52, ((20, -1),), GRAIN2)
    streak(img, 150, 122, 34, ())
    # plain frame (revision 2: brass marks only state); gloss on the right
    gloss(img, 5, [(112, 168, RAISED), (172, 174, RAISED)])
    gloss(img, 5, [(124, 129, RIM_S)])
    save(img, 'lore')


# ----------------------------------------------------------------------------
# Drawers (activity cards), 392 wide
# ----------------------------------------------------------------------------
def drawer_face(w, h, rim='lacquer'):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                if rim == 'brass':
                    c = BRASS if s == 'lit' else BRASS_SH
                else:
                    c = RIM if s == 'lit' else DEEP
            else:
                c = RAISED
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    # the socket sits on the drawer's middle row: y 6 in the 36 px drawers, 12 in the
    # 48 px tall ones (the user's review, 2026-10-22: centre the icon in the card)
    socket(img, 4, (h - 24) // 2, 24)
    return img


def drawers():
    W = 196
    save(drawer_face(W, 36), 'drawer')
    run = drawer_face(W, 36)
    caps(run)
    save(run, 'drawer_run')
    save(drawer_face(W, 48), 'drawer_tall')
    ready = drawer_face(W, 48, rim='brass')
    save(ready, 'drawer_tall_ready')


# ----------------------------------------------------------------------------
# 9-slice overlays: brass flash / pinned frame, hover lip
# ----------------------------------------------------------------------------
def frame_brass():
    n = 12
    img = new(n, n)
    for y in range(n):
        for x in range(n):
            d, s = side_of(x, y, n, n)
            if d == 0:
                c = INK
            elif d == 1:
                c = CREAM if s == 'lit' else BRASS_SH
            elif d == 2:
                c = BRASS
            elif d == 3:
                c = INK
            else:
                c = CLEAR
            img.putpixel((x, y), c)
    for p in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, 'frame_brass')


def token():
    """A small raised lacquer tag, 9-slice (slice 6 px): the map floaters sit on it."""
    n = 12
    img = new(n, n)
    for y in range(n):
        for x in range(n):
            d, s = side_of(x, y, n, n)
            if d == 0:
                c = INK
            elif d == 1:
                c = RIM if s == 'lit' else DEEP
            else:
                c = LAC
            img.putpixel((x, y), c)
    for p in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, 'token')


def frame_hover():
    n = 8
    img = new(n, n)
    for y in range(n):
        for x in range(n):
            d, s = side_of(x, y, n, n)
            if d == 0:
                c = INK
            elif d == 1:
                c = TAN if s == 'lit' else RIM_S
            else:
                c = CLEAR
            img.putpixel((x, y), c)
    for p in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, 'frame_hover')


# ----------------------------------------------------------------------------
# Tags: carved recess (IDLE ACTIVE SHOP STORY RUNNING), brass plate (ENTER),
# cinnabar seals (NEW, LOCKED), recess (UNKNOWN)
# ----------------------------------------------------------------------------
def recess(name, w, h, field=DEEP):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK if s == 'lit' else RIM_S
            elif d == 1:
                c = INK if s == 'lit' else field
            else:
                c = field
            img.putpixel((x, y), c)
    save(img, name)


def tags():
    recess('tag', 38, 11)
    brass_plate('tag_enter', 38, 11)
    recess('tag_wide', 44, 11)
    # NEW: cut to the tag height so it sits inline after a card title
    seal('seal_new_s', 22, 11, [(4, 0), (5, 0), (21, 4), (21, 5), (13, 10), (14, 10), (0, 7), (20, 10)],
         [(5, 1), (20, 5), (1, 7), (14, 9), (2, 9)])
    # LOCKED: a wider chop, room for the 8 px lock before the word
    seal('seal_locked', 44, 11, [(9, 0), (10, 0), (11, 0), (43, 3), (43, 4), (30, 10), (31, 10), (0, 6), (1, 0), (42, 10)],
         [(10, 1), (42, 4), (1, 6), (31, 9), (3, 9), (4, 9)])


# ----------------------------------------------------------------------------
# Buttons: About (and pressed), dock buttons (hover), close x, Show me
# ----------------------------------------------------------------------------
def pressed(name, w, h):
    """A tablet pushed into its socket: the rim swaps light and shade, the face drops a step."""
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = INK if s == 'lit' else RIM_S
            else:
                c = DEEP
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, name)


def buttons():
    tablet('about', 44, 18)
    pressed('about_open', 44, 18)
    tablet('btn', 54, 32)
    tablet('btn_ring', 54, 32, ring=True)
    hov = new(54, 32)
    for y in range(32):
        for x in range(54):
            d, s = side_of(x, y, 54, 32)
            hov.putpixel((x, y), INK if d == 0 else ((RIM if s == 'lit' else DEEP) if d == 1 else RAISED))
    for p in ((0, 0), (53, 0), (0, 31), (53, 31)):
        put(hov, p[0], p[1], CLEAR)
    caps(hov, arm=6, th=2)
    save(hov, 'btn_hover')
    tablet('showme', 52, 16)
    # close: a small raised tablet with a carved x
    for name, col in (('close', TAN), ('close_hover', CREAM)):
        w = h = 14
        img = new(w, h)
        for y in range(h):
            for x in range(w):
                d, s = side_of(x, y, w, h)
                img.putpixel((x, y), INK if d == 0 else ((RIM if s == 'lit' else DEEP) if d == 1 else RAISED))
        for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
            put(img, p[0], p[1], CLEAR)
        stroke = set()
        for i in range(6):
            stroke.add((4 + i, 4 + i))
            stroke.add((9 - i, 4 + i))
        for (x, y) in stroke:                      # carved: each cut throws an ink shadow below it
            if (x, y + 1) not in stroke:
                put(img, x, y + 1, INK)
        for (x, y) in stroke:
            put(img, x, y, col)
        save(img, name)


# ----------------------------------------------------------------------------
# Trays: Now strip (408 wide), dock shelf
# ----------------------------------------------------------------------------
def trays():
    tray('now_tray', 204, 44)
    d = board_base(238, 40)
    streak(d, 20, 33, 40, ((16, 1),))
    streak(d, 170, 6, 30, ((12, -1),), GRAIN2)
    gloss(d, 4, [(60, 92, RAISED), (96, 97, RAISED)])
    save(d, 'dock')
    brass_plate('now_plate', 30, 11)


# ----------------------------------------------------------------------------
# Scroll rail (track, thumb, end caps) and the edge lips
# ----------------------------------------------------------------------------
def rail():
    # track: a carved groove 6 px wide, tiled vertically
    t = new(6, 2)
    for y in range(2):
        for x, c in enumerate((INK, SOCKET, SOCKET, SOCKET, DEEP, RIM_S)):
            put(t, x, y, c)
    save(t, 'rail_track')
    # thumb: a brass bar, 3-slice vertically (2 native rows top and bottom)
    th = new(6, 6)
    for y in range(6):
        for x in range(6):
            if x in (0, 5) or y in (0, 5):
                c = INK
            elif y == 1:
                c = CREAM if x < 4 else BRASS
            elif y == 4:
                c = BRASS_SH
            else:
                c = CREAM if x == 1 else (BRASS_SH if x == 4 else BRASS)
            put(th, x, y, c)
    for p in ((0, 0), (5, 0), (0, 5), (5, 5)):
        put(th, p[0], p[1], CLEAR)
    save(th, 'rail_thumb')
    # end caps: an arrowhead, brass when the list can scroll that way, carved when it cannot
    head = ["..##..",
            ".####.",
            "######"]
    for name, on in (('rail_up_on', True), ('rail_up_off', False), ('rail_down_on', True), ('rail_down_off', False)):
        img = new(6, 7)
        for y in range(7):
            for x in range(6):
                d, s = side_of(x, y, 6, 7)
                img.putpixel((x, y), INK if d == 0 else (LAC if on else DEEP))
        up = 'up' in name
        rows = head if up else head[::-1]
        for yy, row in enumerate(rows):
            for xx, ch in enumerate(row):
                if ch != '#':
                    continue
                if not on:
                    c = RIM_S
                else:
                    c = CREAM if yy == 0 else (BRASS_SH if yy == 2 else BRASS)   # lit from above
                put(img, xx, 2 + yy, c)
        for (x, y) in ((0, 0), (5, 0), (0, 6), (5, 6)):
            put(img, x, y, CLEAR)
        save(img, name)
    # edge lips: a hard shelf shadow, then a two-step dither (no smooth fade)
    for name, flip in (('lip_top', False), ('lip_bottom', True)):
        w, h = 196, 5
        img = new(w, h)
        rows = []
        for y in range(h):
            row = []
            for x in range(w):
                if y == 0:
                    c = INK
                elif y == 1:
                    c = DEEP
                elif y == 2:
                    c = DEEP if x % 2 == 0 else CLEAR
                elif y == 3:
                    c = DEEP if x % 2 == 1 and x % 4 == 1 else CLEAR
                else:
                    c = DEEP if x % 4 == 3 and x % 8 == 3 else CLEAR
                row.append(c)
            rows.append(row)
        if flip:
            rows = rows[::-1]
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                put(img, x, y, c)
        save(img, name)


# ----------------------------------------------------------------------------
# Carved groove for group labels and the ACTIVITIES header (tiles horizontally)
# ----------------------------------------------------------------------------
def groove():
    g = new(2, 3)
    for x in range(2):
        put(g, x, 1, INK)
        put(g, x, 2, RIM_S)
    save(g, 'groove')
    cap = new(3, 3)   # brass pin at the groove's right end (carved_line's end cap)
    put(cap, 1, 0, INK)
    put(cap, 0, 1, INK)
    put(cap, 1, 1, BRASS_SH)
    put(cap, 2, 1, INK)
    put(cap, 1, 2, RIM_S)
    save(cap, 'groove_end')


# ----------------------------------------------------------------------------
# Progress: rods (empty / full pairs per width; the fill is the full rod clipped)
# ----------------------------------------------------------------------------
def rod_pair(name, w, hi, mid, sh):
    h = 5
    for kind in ('empty', 'full'):
        img = new(w, h, INK)
        for x in range(w):
            put(img, x, h - 1, RIM_S)
        for y in range(h - 1):
            put(img, w - 1, y, RIM_S)
        put(img, w - 1, 0, INK)
        if kind == 'full':
            for x in range(1, w - 1):
                put(img, x, 1, hi)
                put(img, x, 2, mid)
                put(img, x, 3, sh)
        save(img, name + '_' + kind)
    end = new(1, h)   # the rounded rod end, laid on the last filled column
    put(end, 0, 0, INK)
    put(end, 0, 1, mid)
    put(end, 0, 2, mid)
    put(end, 0, 3, INK)
    put(end, 0, 4, RIM_S)
    save(end, name + '_end')


def rods():
    rod_pair('rod_well', 154, JADE_HI, JADE, JADE_SH)
    rod_pair('rod_goal', 140, JADE_HI, JADE, JADE_SH)
    rod_pair('rod_adv', 76, M_HI, M_PALE, M_MID)


def beads_strip():
    """Abacus XP beads: 18 beads, one frame per lit count (0..18), stacked vertically."""
    n, bw, gap, h = 18, 5, 1, 6
    w = n * (bw + gap) + 3
    sheet = new(w, h * (n + 1))
    for lit in range(n + 1):
        oy = lit * h
        for x in range(w):
            put(sheet, x, oy + 2, BRASS_SH)
            put(sheet, x, oy + 3, INK)
        for x in (0, w - 1):
            for y in range(h):
                put(sheet, x, oy + y, BRASS_SH if y else BRASS)
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
                    put(sheet, x0 + x, oy + y, c)
    save(sheet, 'beads_xp_strip')


# ----------------------------------------------------------------------------
# Bead rings: the Now ring (13 frames) and the map ring on a lacquer disc (13 frames)
# ----------------------------------------------------------------------------
def ring_frame(D, c, r, lit, n=12, disc=None):
    img = new(D, D)
    if disc:
        R = disc
        for y in range(D):
            for x in range(D):
                rr = math.hypot(x - c, y - c)
                if rr <= R:
                    ang = math.atan2(y - c, x - c)
                    light = math.cos(ang + math.pi * 0.75)
                    if rr > R - 1:
                        col = INK
                    elif rr > R - 2:
                        col = RIM if light > 0.2 else (DEEP if light < -0.2 else RAISED)
                    else:
                        col = LAC
                    img.putpixel((x, y), col)
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
            if 0 <= X < D and 0 <= Y < D and (img.getpixel((X, Y))[3] == 0 or (disc and img.getpixel((X, Y)) == LAC)):
                put(img, X, Y, INK)
    return img


def brass_disc(D):
    """A lacquer disc in the Madra orb's brass rim: ink, 2 px brass lit from the top-left, ink."""
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > R - 0.3:
                continue
            light = math.cos(math.atan2(y - c, x - c) + math.pi * 0.75)
            if r > R - 1.3:
                col = INK
            elif r > R - 3.2:
                col = BRASS
                if light > 0.6 and r > R - 2.2:
                    col = CREAM
                elif light < -0.3:
                    col = BRASS_SH
            elif r > R - 4.2:
                col = INK
            else:
                col = LAC
            img.putpixel((x, y), col)
    return img


def ring_strips():
    D = 28
    c = (D - 1) / 2
    sheet = new(D * 13, D)
    for lit in range(13):
        sheet.paste(ring_frame(D, c, 11.0, lit), (lit * D, 0))
    save(sheet, 'ring_strip')
    # the map ring: 32 native (64 px), beads at r 9.6 inside the brass rim
    D = 32
    c = (D - 1) / 2
    sheet = new(D * 13, D)
    for lit in range(13):
        fr = brass_disc(D)
        beads = ring_frame(D, c, 9.6, lit)
        fr.paste(beads, (0, 0), beads)
        sheet.paste(fr, (lit * D, 0))
    save(sheet, 'map_ring_strip')


# ----------------------------------------------------------------------------
# Orbs as frame strips (the fill is a frame index, so it never leaves the grid)
# ----------------------------------------------------------------------------
def madra_orb_frame(k, D=40):
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    ri = R - 4.2
    top = c + ri + 0.5 - k        # k art rows of liquid
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
    for (x, y) in ((10, 14), (10, 13), (11, 12), (12, 11), (13, 10), (14, 10)):
        if img.getpixel((x, y)) == M_OL:
            put(img, x, y, M_DEEP)
    for (x, y) in ((11, 12), (12, 11)):
        if img.getpixel((x, y)) == M_DEEP:
            put(img, x, y, M_MID)
    return img


def core_orb_frame(k, phase, D=40):
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    rs = k
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
                col = SOCKET
                if k == 0:
                    # dormant: a dull Madra-blue pebble with a lit crescent and one glint
                    if r <= 4.4:
                        col = M_DEEP
                        if r > 1.6 and math.cos(ang + math.pi * 0.75) > 0.5:
                            col = M_MID
                    elif r <= 5.4:
                        col = M_OL
                elif r <= rs + 1.0 and r > rs:
                    col = M_HI
                elif r <= rs:
                    t = (ang * 2 + r * 1.1 + phase) % (2 * math.pi)
                    col = M_PALE if t < math.pi else M_MID
                    if r < 1.2:
                        col = M_HI
            img.putpixel((x, y), col)
    if k == 0:
        put(img, int(c) - 1, int(c) - 1, M_HI)
    return img


def orb_strips():
    D = 40
    sheet = new(D * 33, D)
    for k in range(33):
        sheet.paste(madra_orb_frame(k), (k * D, 0))
    save(sheet, 'orb_madra_strip')
    sheet = new(D * 17, D * 4)
    for p in range(4):
        for k in range(17):
            sheet.paste(core_orb_frame(k, -p * math.pi / 2), (k * D, p * D))   # 4 rows = one seamless turn
    save(sheet, 'orb_core_strip')


# ----------------------------------------------------------------------------
# Log bullets: a 5x5 inlaid diamond per line tone
# ----------------------------------------------------------------------------
def bullets():
    shape = ["..#..", ".###.", "#####", ".###.", "..#.."]
    tones = {'brass': (CREAM, BRASS, BRASS_SH), 'cream': (CREAM, CREAM, TAN),
             'madra': (M_HI, M_PALE, M_MID), 'tan': (TAN, TAN, hx('7A654C')),
             'dim': (hx('94806A'), hx('94806A'), hx('6E5C49'))}
    for name, (hi, mid, sh) in tones.items():
        img = new(5, 5)
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                if ch == '#':
                    c = mid
                    if x + y <= 3:
                        c = hi
                    if x + y >= 5 and (x >= 3 or y >= 3):
                        c = sh
                    put(img, x, y, c)
        save(img, 'bullet_' + name)


# ----------------------------------------------------------------------------
# Thumbnails: the zone header's hex, any tile
# ----------------------------------------------------------------------------
def thumb_of(tile_file, name):
    from PIL import Image
    src = Image.open(B.TILES + tile_file).convert('RGBA')
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
    pts = {(x, y) for y in range(h + 2) for x in range(w + 2) if out.getpixel((x, y))[3]}
    edge = [p for p in pts if any((p[0] + dx, p[1] + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        out.putpixel(p, BRASS)
    save(out, name)


def run():
    # kept from the swatch, regenerated with the same code (byte-identical pixels)
    B.cultivator()
    B.goals_board()
    B.seal('seal_count', 12, 12, [(4, 0), (5, 0), (11, 7), (0, 8), (1, 11)], [(4, 1), (10, 7), (1, 8)])
    B.carved_line('line', 204)
    B.char_shadow()
    # revision 2: the coin, star and swords icons are the user's own (gold_icon, star_icon,
    # combat_icon: 16 art px in 64 px files, shown at 32 px, on the grid), so B.icons() and
    # coin_src are no longer run
    B.core_icon('ic_core')
    B.thumb()
    # new
    chest()
    for n in range(1, 6):
        log_board(n)
    lore_panel()
    token()
    drawers()
    frame_brass()
    frame_hover()
    tags()
    buttons()
    trays()
    rail()
    groove()
    rods()
    beads_strip()
    ring_strips()
    orb_strips()
    bullets()
    thumb_of('Hex_Forest_00_Basic.png', 'thumb_basic')


if __name__ == '__main__':
    run()
    print(len(B.SAVED), 'ui textures')
