"""Lacquer and brass: the Tribulation's pieces (2026-10-24).

Builds on the zone kit's generators (../../zone-view-lacquer/gen/lq_base.py) with the same rules:
every piece is drawn at native size (1 art px) and saved at 2x nearest with the _ai suffix, lit
from the top-left, grain and gloss placed by hand, nothing random. The review copies go to the
folder above this one (docs/superpowers/mockups/tribulation-lacquer/, which Godot ignores), and
import_pieces() copies them into the project:

  assets/ui/lacquer/tribulation/
    lacquer_trib_board9_ai.png      164x164  the strapped board, a 9-slice, its 4 px shadow baked
    lacquer_trib_ring_strip_ai.png  544x272  the brass ring the breaths cross, normal and lit
    lacquer_trib_core_strip_ai.png  512x768  the core: 4 radii across, 6 states down
    lacquer_trib_pip_strip_ai.png    40x20   a crack pip, empty and cracked
  assets/ui/lacquer/
    lacquer_rod_core_{empty,full}_ai.png  152x10  the goal rod less 128 px of its flat middle

The band rule, which the stage (scenes/tribulation/tribulation_stage.gd) draws its spheres by: a
cell at offset (x, y) from a frame's centre corner lies in the band [inner, outer) when
inner <= hypot(x + 0.5, y + 0.5) < outer. The ring and the cores are drawn by it, so the ring's
middle is the stage's R (65 art px, 130 px) and a core of radius r is 2 (r + 1) art px across.

Angles are the kit's (lq_base): measured in the image, from 3 o'clock, clockwise, so -60 degrees
points up and to the right.

Run from the repo root: python docs/superpowers/mockups/tribulation-lacquer/gen/kit_tribulation.py
"""
import math
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..', '..')) + os.sep
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '..', '..', 'zone-view-lacquer', 'gen')))

import lq_base as B  # noqa: E402

B.OUT = os.path.normpath(os.path.join(HERE, '..')) + os.sep

from lq_base import (INK, DEEP, GRAIN, GRAIN2, RAISED, RIM_S, BRASS, BRASS_SH, CREAM, TAN,  # noqa: E402
                     M_HI, M_PALE, M_MID, M_DEEP, VERM, VERM_D,
                     hx, new, put, save, streak, gloss, strap, cabinet)

SOCKET = hx('110707')
TAN_SH = hx('7A654C')
WARM_OL = hx('341E0E')

LACQUER = REPO + 'assets/ui/lacquer/'
TRIBULATION = LACQUER + 'tribulation/'


def in_band(x, y, inner, outer):
    """The band rule: the cell at offset (x, y) from a centre corner lies in [inner, outer)."""
    return inner <= math.hypot(x + 0.5, y + 0.5) < outer


def toward_light(x, y):
    """The cosine between the cell's direction from the centre corner and the light's (the
    top-left): 1 toward the light, -1 away from it (lq_base's cos(ang + 0.75 pi))."""
    d = math.hypot(x + 0.5, y + 0.5)
    return -((x + 0.5) + (y + 0.5)) / (d * math.sqrt(2))


# ----------------------------------------------------------------------------
# The board: anchor furniture, a strapped cabinet like the cycling board, cut as a
# 9-slice. Its grain, gloss and sheen stay in the 28 art px corners, so the rows and
# columns between them are uniform and stretch on the grid.
# ----------------------------------------------------------------------------
BOARD = 80
CORNER = 28
BOARD_STREAKS = (
    # (x0, y, length, jogs, colour), each inside one corner square
    (9, 19, 16, ((7, 1),), GRAIN),
    (55, 15, 15, ((6, -1),), GRAIN2),
    (53, 23, 11, (), GRAIN),
    (10, 57, 15, ((9, -1),), GRAIN),
    (12, 68, 12, (), GRAIN2),
    (54, 60, 18, ((8, 1),), GRAIN2),
    (57, 69, 10, (), GRAIN),
)


def board():
    img = cabinet(BOARD, BOARD)
    for x0, y, length, jogs, col in BOARD_STREAKS:
        streak(img, x0, y, length, jogs, col)
    # the gloss under the top molding, a short run of the cycling board's dash
    gloss(img, 8, [(9, 22, RAISED), (24, 25, RAISED), (27, 27, RAISED)])
    gloss(img, 8, [(11, 14, RIM_S)])
    for y in range(52, 61):               # a short sheen down the left stile
        put(img, 6, y, RAISED)
    strap(img, 'tl', worn=True)
    strap(img, 'tr')
    strap(img, 'bl')
    strap(img, 'br', lost_nail=True)
    _check_board(img)
    save(img, 'trib_board9')


def _check_board(img):
    """The 9-slice's middle rows and columns are uniform, so the board stretches without a seam."""
    px = img.load()
    lo, hi = CORNER, BOARD - CORNER
    for y in range(BOARD):
        assert len({px[x, y] for x in range(lo, hi)}) == 1, f'board: row {y} is not uniform in the middle'
    for x in range(BOARD):
        assert len({px[x, y] for y in range(lo, hi)}) == 1, f'board: column {x} is not uniform in the middle'


# ----------------------------------------------------------------------------
# The ring: cast brass on the band rule, the breaths' target at R. Frame 0 is brass lit
# from the top-left (its lower-right half in shade), frame 1 the lit frame of a hit, one
# step brighter: cream where the brass was, brass where the shade was.
# ----------------------------------------------------------------------------
RING = 136
RING_INK_IN = (63, 64)
RING_BRASS = (64, 66)
RING_INK_OUT = (66, 67)


def ring_frame(lit):
    img = new(RING, RING)
    c = RING // 2
    for j in range(RING):
        for i in range(RING):
            x, y = i - c, j - c
            if in_band(x, y, *RING_INK_IN) or in_band(x, y, *RING_INK_OUT):
                col = INK
            elif in_band(x, y, *RING_BRASS):
                shade = (x + 0.5) + (y + 0.5) > 0
                if lit:
                    col = BRASS if shade else CREAM
                else:
                    col = BRASS_SH if shade else BRASS
            else:
                continue
            img.putpixel((i, j), col)
    return img


def ring():
    strip = new(RING * 2, RING)
    for frame, lit in enumerate((False, True)):
        strip.paste(ring_frame(lit), (frame * RING, 0))
    _check_ring(strip)
    save(strip, 'trib_ring_strip')


def _check_ring(strip):
    """Both frames are opaque exactly on the band rule's [63, 67), the stage's R give or take 2 art px."""
    c = RING // 2
    for frame in range(2):
        for j in range(RING):
            for i in range(RING):
                opaque = strip.getpixel((frame * RING + i, j))[3] > 0
                assert opaque == in_band(i - c, j - c, RING_INK_IN[0], RING_INK_OUT[1]), \
                    f'ring frame {frame}: cell {i},{j} is off the band'


# ----------------------------------------------------------------------------
# The core, 4 radii across and 6 states down, in 64 art px frames round the centre corner
# (32, 32). The whole core is the cabinet core's two-armed swirl (lq_base.core_orb) lit from
# the top-left as a ball: three light zones, the arms a step brighter than the ground in
# each. Cracks run in from the rim. The spent core is the same disc carved and dead, the
# passed core the same disc in brass.
# ----------------------------------------------------------------------------
CORE = 64
CORE_RADII = (17, 21, 25, 29)
CRACK_ANGLES = (-60, 160, 70)
SPENT_CRACK_ANGLE = 250
CRACK_END = 0.6                      # a crack runs from the rim to 60% of the radius
# The kinks along a crack: (fraction of the radius, angle off the crack's line in degrees).
# One shape for every crack, so each reads as the same kind of break at any size.
CRACK_KINKS = ((1.0, 0.0), (0.87, 5.0), (0.74, -3.0), (CRACK_END, 3.0))
# The light, from the top-left and toward the viewer; the zones are cut on its cosine with a
# ball's normal, so the lit zone is a highlight up and left of the middle (a wider one cuts a
# straight-edged wedge across the swirl) and the shade a crescent on the lower right.
LIGHT = (-1.0, -1.0, 1.6)
LIT_ZONE = 0.92
SHADE_ZONE = 0.30
SWIRL_TWIST = 1.1                    # core_orb's: radians a px out, so the arms stay ~3 px wide

# One tone ramp per state, darkest to lightest. The whole core's is the Madra ramp and the
# others swap it colour for colour: the passed core is the whole one in brass, and the spent
# one carved lacquer (its lit zone's arms in the rim shade, so the carving carries through the
# light), with a tan rim and dull cracks.
MADRA_RAMP = (M_DEEP, M_MID, M_PALE, M_HI)
CARVED_RAMP = (SOCKET, DEEP, RAISED, RIM_S)
BRASS_RAMP = (WARM_OL, BRASS_SH, BRASS, CREAM)


def _light_cos(x, y, r):
    """The light's cosine with a ball's normal at the cell (x, y) of a core of radius r."""
    n = math.sqrt(sum(v * v for v in LIGHT))
    lx, ly, lz = (v / n for v in LIGHT)
    u, v = (x + 0.5) / r, (y + 0.5) / r
    z = math.sqrt(max(0.0, 1.0 - u * u - v * v))
    return u * lx + v * ly + z * lz


def _on_arm(x, y):
    """core_orb's swirl: two arms turning out from the centre."""
    ang = math.atan2(y + 0.5, x + 0.5)
    d = math.hypot(x + 0.5, y + 0.5)
    return (ang * 2 + d * SWIRL_TWIST) % (2 * math.pi) < math.pi


def core_tones(r):
    """The whole core as tone steps, 0 (darkest) to 3, by cell offset; the outline is None."""
    tones = {}
    c = CORE // 2
    for j in range(CORE):
        for i in range(CORE):
            x, y = i - c, j - c
            d = math.hypot(x + 0.5, y + 0.5)
            if d >= r + 1:
                continue
            if d >= r:
                tones[(x, y)] = None
                continue
            s = _light_cos(x, y, r)
            ground = 2 if s > LIT_ZONE else (1 if s > SHADE_ZONE else 0)
            tones[(x, y)] = ground + (1 if _on_arm(x, y) else 0)
            if d < 1.2:
                tones[(x, y)] = 3            # core_orb's bright centre
    _fill_slivers(tones)
    _fill_specks(tones)
    return tones


SLIVER_PASSES = 8
SPECK_CELLS = 4


def _fill_slivers(tones):
    """Gives every 1-cell sliver the tone its two agreeing neighbours share: a cell whose left and
    right (or, failing those, upper and lower) neighbours agree on another tone. The light zones
    leave such slivers where they cut the swirl's arms (the swirl alone leaves none), and in the
    shade they draw stepped dark hairlines that read as cracks on a whole core. Each pass reads
    the last one's tones, so the result does not depend on the order of the cells."""
    for _ in range(SLIVER_PASSES):
        fills = {}
        for (x, y), tone in tones.items():
            if tone is None:
                continue
            for dx, dy in ((1, 0), (0, 1)):
                a, b = tones.get((x - dx, y - dy)), tones.get((x + dx, y + dy))
                if a is not None and a == b and a != tone:
                    fills[(x, y)] = a
                    break
        if not fills:
            return
        tones.update(fills)
    raise AssertionError(f'core: slivers left after {SLIVER_PASSES} passes')


def _fill_specks(tones):
    """Gives a speck of up to SPECK_CELLS cells the tone round it, when one tone encloses it: what
    a sliver's fill can leave of a hairline (a dark dot on the r = 17 core), a pit on a whole core.
    The bright centre is core_orb's and stays."""
    seen = set()
    for start, tone in list(tones.items()):
        if tone is None or start in seen:
            continue
        speck, queue = [start], [start]
        seen.add(start)
        while queue:
            x, y = queue.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in seen and tones.get(n) == tone:
                    seen.add(n)
                    speck.append(n)
                    queue.append(n)
        cells = set(speck)
        around = {tones.get(n, None) for x, y in speck
                  for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if n not in cells}
        if len(speck) <= SPECK_CELLS and len(around) == 1 and None not in around and (0, 0) not in cells:
            fill = around.pop()
            for cell in speck:
                tones[cell] = fill


def _crack_cells(angle, r):
    """A jagged 1 px line from the rim in to CRACK_END of the radius, as 8-connected cells."""
    pts = []
    for f, off in CRACK_KINKS:
        a = math.radians(angle + off)
        pts.append((f * r * math.cos(a), f * r * math.sin(a)))
    cells = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = int(math.hypot(x1 - x0, y1 - y0) * 8) + 1
        for k in range(steps + 1):
            t = k / steps
            cell = (math.floor(x0 + (x1 - x0) * t), math.floor(y0 + (y1 - y0) * t))
            if not cells or cells[-1] != cell:
                cells.append(cell)
    # drop the inner corner of every L, so the line is one px wide
    i = 1
    while i < len(cells) - 1:
        (ax, ay), (bx, by) = cells[i - 1], cells[i + 1]
        if abs(ax - bx) == 1 and abs(ay - by) == 1:
            del cells[i]
        else:
            i += 1
    return [cell for cell in cells if math.hypot(cell[0] + 0.5, cell[1] + 0.5) < r]


def _crack_edge(angle, cells):
    """The crack's lit lip, on the side away from the light: below where the line runs across,
    to its right where it runs up or down (a diagonal step goes by the whole crack's line), so
    the lip follows the crack round its jogs."""
    a = math.radians(angle)
    crack_across = abs(math.cos(a)) > abs(math.sin(a))
    edge = []
    for k, (x, y) in enumerate(cells):
        (ax, ay), (bx, by) = cells[max(k - 1, 0)], cells[min(k + 1, len(cells) - 1)]
        dx, dy = abs(bx - ax), abs(by - ay)
        across = dx > dy if dx != dy else crack_across
        edge.append((x, y + 1) if across else (x + 1, y))
    return edge


def core_frame(r, state, cracks):
    """One frame: state is 'whole', 'spent' or 'passed'; cracks the angles to break it at."""
    ramp = {'whole': MADRA_RAMP, 'spent': CARVED_RAMP, 'passed': BRASS_RAMP}[state]
    tones = core_tones(r)
    img = new(CORE, CORE)
    c = CORE // 2
    for (x, y), tone in tones.items():
        img.putpixel((x + c, y + c), INK if tone is None else ramp[tone])
    if state == 'spent':
        # the dead core's rim, a tan ring inside the outline, lit from the top-left
        for (x, y), tone in tones.items():
            if tone is not None and math.hypot(x + 0.5, y + 0.5) >= r - 1:
                img.putpixel((x + c, y + c), TAN if toward_light(x, y) > -0.25 else TAN_SH)
    crack_set = set()
    lines = []
    for angle in cracks:
        cells = _crack_cells(angle, r)
        crack_set.update(cells)
        lines.append((angle, cells))
    for angle, cells in lines:
        for (x, y) in _crack_edge(angle, cells):
            if (x, y) in crack_set or math.hypot(x + 0.5, y + 0.5) >= r - (1 if state == 'spent' else 0):
                continue
            img.putpixel((x + c, y + c), VERM if state == 'whole' else VERM_D)
    for (x, y) in crack_set:
        img.putpixel((x + c, y + c), INK)
    return img


CORE_ROWS = (
    ('whole', ()),
    ('whole', CRACK_ANGLES[:1]),
    ('whole', CRACK_ANGLES[:2]),
    ('whole', CRACK_ANGLES),
    ('spent', CRACK_ANGLES + (SPENT_CRACK_ANGLE,)),
    ('passed', ()),
)


def core():
    strip = new(CORE * len(CORE_RADII), CORE * len(CORE_ROWS))
    for row, (state, cracks) in enumerate(CORE_ROWS):
        for col, r in enumerate(CORE_RADII):
            strip.paste(core_frame(r, state, cracks), (col * CORE, row * CORE))
    _check_core(strip)
    save(strip, 'trib_core_strip')


def _check_core(strip):
    """Every state of a column keeps the whole core's footprint, 2 (r + 1) art px across."""
    c = CORE // 2
    for col, r in enumerate(CORE_RADII):
        for row in range(len(CORE_ROWS)):
            for j in range(CORE):
                for i in range(CORE):
                    opaque = strip.getpixel((col * CORE + i, row * CORE + j))[3] > 0
                    assert opaque == in_band(i - c, j - c, 0, r + 1), f'core {col},{row}: cell {i},{j}'


# ----------------------------------------------------------------------------
# Crack pips: a carved socket, one per crack the trial allows; a crack lights one with a
# vermilion chip.
# ----------------------------------------------------------------------------
PIP = 10
# The chip: a jagged crack from the top right to the bottom left, vermilion, its shaded side
# (to the right, away from the light) a step darker. Cells of the 10 px frame.
PIP_CHIP = ((6, 1), (5, 2), (5, 3), (4, 4), (5, 5), (4, 6), (3, 7))
PIP_CHIP_SHADE = ((6, 2), (6, 3), (5, 4), (6, 5), (5, 6), (4, 7))


def pip_frame(cracked):
    img = new(PIP, PIP)
    c = PIP // 2
    for j in range(PIP):
        for i in range(PIP):
            x, y = i - c, j - c
            if in_band(x, y, 4, 5):
                col = INK if toward_light(x, y) > -0.1 else RIM_S
            elif in_band(x, y, 0, 4):
                col = SOCKET
            else:
                continue
            img.putpixel((i, j), col)
    if cracked:
        for cell in PIP_CHIP:
            img.putpixel(cell, VERM)
        for cell in PIP_CHIP_SHADE:
            img.putpixel(cell, VERM_D)
    return img


def pips():
    strip = new(PIP * 2, PIP)
    for frame, cracked in enumerate((False, True)):
        strip.paste(pip_frame(cracked), (frame * PIP, 0))
    save(strip, 'trib_pip_strip')


# ----------------------------------------------------------------------------
# The card's rod: the goal rod (already 2x) with its flat middle cut out, so it keeps the
# goal rod's ends and its end cap (lacquer_rod_goal_end_ai.png) as it is.
# ----------------------------------------------------------------------------
GOAL_ROD = 280
ROD_CUT = (76, 204)                  # columns [76, 204) go


def rod(part):
    goal = Image.open(LACQUER + f'lacquer_rod_goal_{part}_ai.png').convert('RGBA')
    assert goal.width == GOAL_ROD, f'the goal rod is {goal.width} wide, not {GOAL_ROD}'
    lo, hi = ROD_CUT
    cut = {tuple(goal.getpixel((x, y)) for y in range(goal.height)) for x in range(lo, hi)}
    assert len(cut) == 1, f'rod_goal_{part}: the columns cut out are not identical'
    out = new(goal.width - (hi - lo), goal.height)
    out.paste(goal.crop((0, 0, lo, goal.height)), (0, 0))
    out.paste(goal.crop((hi, 0, goal.width, goal.height)), (lo, 0))
    fn = f'lacquer_rod_core_{part}_ai.png'
    out.save(B.OUT + fn)
    B.SAVED.append(fn)


# ----------------------------------------------------------------------------
# Into the project
# ----------------------------------------------------------------------------
SHADOW_BIG = (4, (0x05, 0x07, 0x07))


def bake_shadow(src, dst, offset, rgb):
    """Hard drop shadow (STYLE_GUIDE rule 6): the silhouette in the shadow colour at +offset,
    under the art. Written out as in cycling-view-lacquer/gen/import_cycling.py, whose module
    reads sys.argv when it loads."""
    img = Image.open(src).convert('RGBA')
    w, h = img.size
    out = Image.new('RGBA', (w + offset, h + offset), (0, 0, 0, 0))
    shadow = Image.new('RGBA', (w, h), rgb + (255,))
    shadow.putalpha(img.getchannel('A'))
    out.alpha_composite(shadow, (offset, offset))
    out.alpha_composite(img, (0, 0))
    out.save(dst)
    print(f'shadow {offset}px {os.path.basename(src)} -> {w + offset}x{h + offset}')


def import_pieces():
    """Copies the pieces the game loads into assets/ui/lacquer/, the board with its shadow baked."""
    os.makedirs(TRIBULATION, exist_ok=True)
    bake_shadow(B.OUT + 'lacquer_trib_board9_ai.png', TRIBULATION + 'lacquer_trib_board9_ai.png', *SHADOW_BIG)
    for fn in ('lacquer_trib_ring_strip_ai.png', 'lacquer_trib_core_strip_ai.png', 'lacquer_trib_pip_strip_ai.png'):
        shutil.copy2(B.OUT + fn, TRIBULATION + fn)
        print(f'copy {fn} -> assets/ui/lacquer/tribulation/')
    for part in ('empty', 'full'):
        fn = f'lacquer_rod_core_{part}_ai.png'
        shutil.copy2(B.OUT + fn, LACQUER + fn)
        print(f'copy {fn} -> assets/ui/lacquer/')


def run():
    board()
    ring()
    core()
    pips()
    rod('empty')
    rod('full')
    import_pieces()


if __name__ == '__main__':
    run()
    print(len(B.SAVED), 'tribulation textures:', ', '.join(B.SAVED))
