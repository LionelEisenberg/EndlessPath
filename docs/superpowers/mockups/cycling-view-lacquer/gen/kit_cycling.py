"""Lacquer and brass: the cycling view pieces for the round-1 mock (2026-10-22).

Builds on the zone kit's generators (../../zone-view-lacquer/gen/lq_base.py and kit_ui.py)
with the same rules: every piece is drawn at native size (1 art px) and saved at 2x nearest
with the _ai suffix, lit from the top-left, grain and gloss placed by hand, no randomness.
Output goes to the folder above this one (docs/superpowers/mockups/cycling-view-lacquer/).

The game's kit differs from the mock's in a few textures, written to game/ (see game_kit
below): the mock keeps the approved round-1 art, and import_cycling.py takes those from game/.

The body figures are traced from the user's own outlines, which stay untouched:
assets/sprites/cycling/cycling_technique_outline.png (standing; the game shows it at 500x832,
stretched 1.3867x down, and every technique's curve is authored on that footprint) and
assets/sprites/cycling/Cycling_Technique_Background.webp (seated, unused today).

Run: python kit_cycling.py
"""
import math
import os
import sys
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..', '..')) + os.sep
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '..', '..', 'zone-view-lacquer', 'gen')))

import lq_base as B  # noqa: E402

B.OUT = os.path.normpath(os.path.join(HERE, '..')) + os.sep

from lq_base import (CLEAR, INK, DEEP, GRAIN2, RAISED, RIM_S, RIM, BRASS, BRASS_SH, CREAM, TAN,  # noqa: E402
                     JADE_HI, JADE, JADE_SH, JADE_OL, M_HI, M_PALE, M_MID, M_DEEP, M_OL,
                     hx, new, put, save, streak, gloss, lit_mask, strap, cabinet, tablet)
import kit_ui as K  # noqa: E402

SOCKET = hx('110707')
TAN_SH = hx('7A654C')
WARM_OL = hx('341E0E')


# ----------------------------------------------------------------------------
# Body figures, traced from the user's outlines
# ----------------------------------------------------------------------------
def _line_from_alpha(path, size, thresh):
    a = Image.open(path).convert('RGBA').split()[3].resize(size, Image.BOX)
    w, h = size
    return {(x, y) for y in range(h) for x in range(w) if a.getpixel((x, y)) >= thresh}


def _line_from_dark(path, size, thresh):
    g = Image.open(path).convert('L').resize(size, Image.BOX)
    w, h = size
    return {(x, y) for y in range(h) for x in range(w) if g.getpixel((x, y)) <= thresh}


def _fill(line, w, h, open_pockets=0):
    """The line plus everything it encloses. Enclosed pockets bigger than open_pockets px,
    other than the largest (the body), stay open: the seated figure's arm gaps."""
    seen = set()
    enclosed = []
    for y in range(h):
        for x in range(w):
            if (x, y) in line or (x, y) in seen:
                continue
            comp, border = [], False
            q = deque([(x, y)])
            seen.add((x, y))
            while q:
                cx, cy = q.popleft()
                comp.append((cx, cy))
                if cx in (0, w - 1) or cy in (0, h - 1):
                    border = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (cx + dx, cy + dy)
                    if 0 <= n[0] < w and 0 <= n[1] < h and n not in line and n not in seen:
                        seen.add(n)
                        q.append(n)
            if not border:
                enclosed.append(comp)
    enclosed.sort(key=len, reverse=True)
    sil = set(line)
    for i, comp in enumerate(enclosed):
        if open_pockets and i > 0 and len(comp) > open_pockets:
            continue
        sil.update(comp)
    return sil


def carve(sil, w, h):
    """A figure cut into the board: the upper and left walls fall into shadow (ink, two px),
    the lower and right walls catch the light (rim shade), the floor is the deep field."""
    img = new(w, h)
    out = lambda p: p not in sil  # noqa: E731
    for (x, y) in sil:
        if out((x, y - 1)) or out((x - 1, y)):
            c = INK
        elif out((x, y + 1)) or out((x + 1, y)):
            c = RIM
        elif out((x, y - 2)) or out((x - 2, y)):
            c = INK
        else:
            c = DEEP
        img.putpixel((x, y), c)
    return img


def bodies():
    std = REPO + 'assets/sprites/cycling/cycling_technique_outline.png'
    w, h = 250, 416                       # 500x832 on screen, the game's footprint
    line = _line_from_alpha(std, (w, h), 96)
    sil = _fill(line, w, h)
    save(carve(sil, w, h), 'cyc_body_carved')
    # brass inlay: the outline itself as a brass wire set into the board
    wire = _line_from_alpha(std, (w, h), 128)
    img = new(w, h)
    lit_mask(img, wire, set())
    save(img, 'cyc_body_brass')

    seated = REPO + 'assets/sprites/cycling/Cycling_Technique_Background.webp'
    w2 = h2 = 250                         # 500x500 on screen
    line2 = _line_from_dark(seated, (w2, h2), 150)
    sil2 = _fill(line2, w2, h2, open_pockets=40)
    save(carve(sil2, w2, h2), 'cyc_body_seated')


# ----------------------------------------------------------------------------
# The Madra ball: 8 frames, a two-armed swirl turning half a revolution (10 frames / s)
# ----------------------------------------------------------------------------
def ball_frame(k, n=8, D=30):
    img = new(D, D)
    c = (D - 1) / 2
    R = D / 2
    ph = k * math.pi / n
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > R - 0.3:
                continue
            ang = math.atan2(y - c, x - c)
            if r > R - 1.3:
                col = INK
            elif r > R - 2.3:
                col = M_OL
            else:
                lx, ly = (x - c) / R, (y - c) / R
                s = -(lx + ly) * 0.7071           # +1 toward the light (top-left)
                base = M_PALE
                if s < -0.18:
                    base = M_MID
                if s < -0.62 and r > R - 4.6:
                    base = M_DEEP
                t = (2 * ang + r * 0.36 - 2 * ph) % (2 * math.pi)
                arm = t < 1.05 and r > 2.2
                if arm:
                    col = {M_PALE: M_HI, M_MID: M_PALE, M_DEEP: M_MID}[base]
                else:
                    col = base
            img.putpixel((x, y), col)
    # the glint stays put while the swirl turns: lit from the top-left, and a
    # larger ball moves it out with its edge
    s = (D - 30) // 2
    for (gx, gy) in ((8, 6), (9, 6), (7, 7), (8, 7), (7, 8)):
        put(img, gx + s, gy + s, M_HI)
    return img


def ball():
    D, n = 30, 8
    strip = new(D * n, D)
    for k in range(n):
        strip.paste(ball_frame(k, n, D), (k * D, 0))
    save(strip, 'cyc_ball_strip')
    # rings round the ball: frame 0 brass (ready: click to cycle), frame 1 tan dots (tracking)
    R = 40
    rings = new(R * 2, R)
    _ready_ring(rings, 0, R, 0)
    c = (R - 1) / 2
    for y in range(R):
        for x in range(R):
            if 16.8 < math.hypot(x - c, y - c) <= 17.8 and (x + y) % 2 == 0:
                rings.putpixel((R + x, y), TAN)
    save(rings, 'cyc_ball_rings')


def _ready_ring(img, ox, cell, grow):
    """The brass ring round a ready ball, its radii grown by `grow` px, in the `cell` px frame at ox."""
    c = (cell - 1) / 2
    for y in range(cell):
        for x in range(cell):
            r = math.hypot(x - c, y - c) - grow
            light = math.cos(math.atan2(y - c, x - c) + math.pi * 0.75)
            col = None
            if 15.6 < r <= 16.6:
                col = INK
            elif 16.6 < r <= 18.6:
                col = BRASS
                if light > 0.5 and r <= 17.6:
                    col = CREAM
                elif light < -0.35:
                    col = BRASS_SH
            elif 18.6 < r <= 19.6:
                col = INK
            if col:
                img.putpixel((ox + x, y), col)


# ----------------------------------------------------------------------------
# Cycling zones: a carved socket on the groove; 6 frames
# idle (dotted tan rim), active (brass rim: click now), spent, PERFECT, GOOD, OK
# ----------------------------------------------------------------------------
STUDS = {
    'perfect': (CREAM, BRASS, BRASS_SH),
    'good': (CREAM, CREAM, TAN),
    'ok': (TAN, TAN, TAN_SH),
}


def zone_frame(kind, D=24, solid_idle=False):
    img = new(D, D)
    c = (D - 1) / 2
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            light = math.cos(math.atan2(y - c, x - c) + math.pi * 0.75)
            col = None
            if r <= 8.6:
                col = SOCKET
                if r > 7.6:
                    col = INK if light > -0.1 else RIM_S
                if kind in STUDS and r <= 6.1:
                    hi, mid, sh = STUDS[kind]
                    col = mid
                    if r > 5.1:
                        col = hi if light > 0.35 else (sh if light < -0.3 else mid)
                elif kind in STUDS and r <= 7.1:
                    col = INK
            elif kind == 'idle' and 9.6 < r <= 10.6 and (solid_idle or (x + y) % 2 == 0):
                col = TAN
            elif kind == 'active':
                if 8.6 < r <= 10.6:
                    col = BRASS
                    if light > 0.5 and r <= 9.6:
                        col = CREAM
                    elif light < -0.35:
                        col = BRASS_SH
                elif 10.6 < r <= 11.6:
                    col = INK
            if col:
                img.putpixel((x, y), col)
    return img


def zones():
    kinds = ['idle', 'active', 'spent', 'perfect', 'good', 'ok']
    D = 24
    strip = new(D * len(kinds), D)
    for i, k in enumerate(kinds):
        strip.paste(zone_frame(k, D), (i * D, 0))
    save(strip, 'cyc_zone_strip')


# ----------------------------------------------------------------------------
# Pellets: the kit's Madra pellet recoloured for XP (jade, or the tier tones)
# ----------------------------------------------------------------------------
def pellets():
    src = Image.open(REPO + 'assets/ui/lacquer/lacquer_madra_pellet_ai.png').convert('RGBA')
    src = src.resize((6, 6), Image.NEAREST)
    ramps = {
        'cyc_pellet_jade': (JADE_HI, JADE, JADE_SH, JADE_OL),
        'cyc_pellet_brass': (CREAM, BRASS, BRASS_SH, WARM_OL),
        'cyc_pellet_cream': (CREAM, CREAM, TAN, TAN_SH),
        'cyc_pellet_tan': (CREAM, TAN, TAN_SH, WARM_OL),
    }
    for name, (hi, mid, sh, deep) in ramps.items():
        m = {M_HI[:3]: hi, M_PALE[:3]: mid, M_MID[:3]: sh, M_DEEP[:3]: deep}
        img = new(6, 6)
        for y in range(6):
            for x in range(6):
                p = src.getpixel((x, y))
                if p[3]:
                    img.putpixel((x, y), m.get(p[:3], p))
        save(img, name)


# ----------------------------------------------------------------------------
# Technique icons, 16 art px (shown at 32): the shape of each technique's path
# ----------------------------------------------------------------------------
def curve_icon(name, fn, n=600, brush=2):
    core = set()
    for i in range(n + 1):
        x, y = fn(i / n)
        if brush == 1:
            core.add((int(round(x)), int(round(y))))
            continue
        x0, y0 = int(math.floor(x - 0.5)), int(math.floor(y - 0.5))
        core |= {(x0, y0), (x0 + 1, y0), (x0, y0 + 1), (x0 + 1, y0 + 1)}
    img = new(16, 16)
    for (x, y) in core:
        if (x, y - 1) not in core or (x - 1, y) not in core:
            col = M_HI
        elif (x, y + 1) not in core or (x + 1, y) not in core:
            col = M_MID
        else:
            col = M_PALE
        put(img, x, y, col)
    for (x, y) in core:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in core and 0 <= q[0] < 16 and 0 <= q[1] < 16:
                put(img, q[0], q[1], INK)
    save(img, name)


def tech_icons():
    tau = 2 * math.pi
    curve_icon('ic_tech_foundation', lambda t: (7.5 + 4.2 * math.sin(2 * tau * t), 7.5 + 5.6 * math.sin(tau * t)))
    curve_icon('ic_tech_smooth', lambda t: (7.5 + 5.8 * math.sin(tau * t), 7.5 + 3.4 * math.sin(2 * tau * t)))
    # a whirlpool: one px wire, so the turns stay apart at 16 art px
    curve_icon('ic_tech_torrent', lambda t: (7.5 + (1.0 + 5.6 * t) * math.cos(tau * 1.75 * t + 0.6),
                                             7.5 + (1.0 + 5.6 * t) * math.sin(tau * 1.75 * t + 0.6)), brush=1)


# ----------------------------------------------------------------------------
# Buttons: the Auto toggle (raised = off, pressed with brass caps = on)
# ----------------------------------------------------------------------------
def toggle():
    w, h = 60, 18
    tablet('cyc_auto', w, h)
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            d, s = B.side_of(x, y, w, h)
            if d == 0:
                c = INK
            elif d == 1:
                c = INK if s == 'lit' else RIM_S
            else:
                c = DEEP
            img.putpixel((x, y), c)
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        put(img, p[0], p[1], CLEAR)
    K.caps(img, arm=5, th=2)
    save(img, 'cyc_auto_on')


# ----------------------------------------------------------------------------
# Boards: anchor furniture, so all three get the chunky corner straps
# ----------------------------------------------------------------------------
def board(name, w, h, streaks, gloss_x):
    img = cabinet(w, h)
    for s in streaks:
        streak(img, *s)
    g0 = gloss_x
    gloss(img, 8, [(g0, g0 + 70, RAISED), (g0 + 74, g0 + 79, RAISED), (g0 + 83, g0 + 84, RAISED)])
    gloss(img, 8, [(g0 + 10, g0 + 22, RIM_S)])
    for y in range(36, 60):               # a short sheen down the left stile
        put(img, 6, y, RAISED)
    strap(img, 'tl', worn=True)
    strap(img, 'tr')
    strap(img, 'bl')
    strap(img, 'br', lost_nail=True)
    save(img, name)


def boards():
    # A, in the map gap: hugs the figure (560x1032)
    board('cyc_board_a', 280, 516, [
        (14, 40, 36, ((14, 1),)), (220, 64, 44, ((9, 1), (30, -1)), GRAIN2), (10, 300, 22, ()),
        (236, 268, 30, ((12, 1),)), (16, 452, 40, ((20, -1),), GRAIN2), (190, 488, 70, ((28, 1),)),
        (40, 500, 60, ((24, -1), (44, 1))),
    ], 150)
    # B, the modal board (1040x1032)
    board('cyc_board_b', 520, 516, [
        (14, 40, 36, ((14, 1),)), (290, 300, 120, ((40, 1), (90, -1))), (330, 470, 70, ((22, 1),), GRAIN2),
        (296, 330, 96, ((30, -1),)), (10, 300, 22, ()), (400, 420, 90, ((26, 1), (60, 1)), GRAIN2),
        (40, 500, 60, ((24, -1), (44, 1))), (290, 494, 150, ((50, 1), (110, -1))),
    ], 380)
    # C, the full-screen room (1872x1032)
    board('cyc_board_c', 936, 516, [
        (20, 260, 160, ((40, 1), (110, -1))), (30, 470, 180, ((60, 1),), GRAIN2), (40, 500, 60, ((24, -1),)),
        (300, 40, 50, ((20, 1),)), (640, 70, 40, ((16, -1),), GRAIN2), (300, 488, 70, ((28, 1),)),
        (620, 470, 60, ((30, 1),)), (720, 300, 190, ((50, -1), (130, 1))), (740, 120, 150, ((60, 1),), GRAIN2),
        (720, 500, 190, ((70, -1),)),
    ], 640)


def side_trays():
    """C: the room's two side compartments, recessed trays like the Now tray (440x848)."""
    B.tray('cyc_tray_side', 220, 424)


# ----------------------------------------------------------------------------
# Opaque 2-step dither backdrop (G1's lean): a 4x4 screen-px tile, two #050707 cells
# ----------------------------------------------------------------------------
def dither():
    img = Image.new('RGBA', (4, 4), (0, 0, 0, 0))
    for (x0, y0) in ((0, 0), (2, 2)):
        for y in range(2):
            for x in range(2):
                img.putpixel((x0 + x, y0 + y), (0x05, 0x07, 0x07, 255))
    fn = 'lacquer_cyc_dither_ai.png'
    img.save(B.OUT + fn)
    B.SAVED.append(fn)


# ----------------------------------------------------------------------------
# The game's kit (the review of 2026-10-23). The mock keeps the approved round-1
# art; these textures differ from it, so they go to game/, and import_cycling.py
# copies them into the project from there.
#   the ball strip: the eight swirl frames across and three breathing sizes down
#     (30, 32 and 34 px balls, 60, 64 and 68 on screen), each centred in a 34 px cell;
#   the ball rings: in 44 px cells, the brass ready ring, the tracking ring drawn
#     solid (the checkerboard dots read as broken), and the ready ring grown by 1
#     and 2 px for the breathing ball;
#   the zone strip: the idle rim drawn solid, for the same reason.
# ----------------------------------------------------------------------------
GAME_DIR = 'game'
BREATH_SIZES = (30, 32, 34)
GAME_BALL_CELL = 34
GAME_RING_CELL = 44


def _save_game(img, name):
    """Saves into game/ next to the mock's pieces, at 2x with the _ai suffix as save() does."""
    out = B.OUT
    B.OUT = os.path.join(out, GAME_DIR) + os.sep
    os.makedirs(B.OUT, exist_ok=True)
    try:
        save(img, name)
    finally:
        B.OUT = out


def game_ball():
    n, cell = 8, GAME_BALL_CELL
    strip = new(cell * n, cell * len(BREATH_SIZES))
    for row, D in enumerate(BREATH_SIZES):
        off = (cell - D) // 2
        for k in range(n):
            strip.paste(ball_frame(k, n, D), (k * cell + off, row * cell + off))
    _save_game(strip, 'cyc_ball_strip')


def game_rings():
    cell = GAME_RING_CELL
    rings = new(cell * 4, cell)
    for frame, grow in ((0, 0), (2, 1), (3, 2)):
        _ready_ring(rings, frame * cell, cell, grow)
    c = (cell - 1) / 2
    for y in range(cell):
        for x in range(cell):
            if 16.8 < math.hypot(x - c, y - c) <= 17.8:
                rings.putpixel((cell + x, y), TAN)
    _save_game(rings, 'cyc_ball_rings')


def game_zones():
    kinds = ['idle', 'active', 'spent', 'perfect', 'good', 'ok']
    D = 24
    strip = new(D * len(kinds), D)
    for i, k in enumerate(kinds):
        strip.paste(zone_frame(k, D, solid_idle=True), (i * D, 0))
    _save_game(strip, 'cyc_zone_strip')


def game_kit():
    game_ball()
    game_rings()
    game_zones()


def run():
    bodies()
    ball()
    zones()
    pellets()
    tech_icons()
    toggle()
    boards()
    side_trays()
    dither()
    game_kit()


if __name__ == '__main__':
    run()
    print(len(B.SAVED), 'cycling textures:', ', '.join(B.SAVED))
