"""Round 2: B (Pressed), refined. Same content as round 1.

Changes from round 1's B:
- a real blind deboss: wells keep the paper's colour, with a two-step shadow on the top and
  left inner walls and a lit bottom and right wall; chamfered corners like a die
- empty wells are pressed shallow and owned ones deep, so what you own stands out
- the filter is printed words; only the one in use is pressed in
- a robed cultivator pressed into the page as a relief, with creases for collar, sash and
  sleeves, and printed leader lines from each gear well to what it dresses
- the details lead with the item pressed in at full size, then a printed spec table
- a variant with the book's cover in the lacquer ramp (style guide K1)
"""
import sys
from PIL import Image, ImageDraw

SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
sys.path.insert(0, SCR + 'r1')
import gen_r1 as R  # noqa: E402
from gen_r1 import (put, text, F, EUL, YATRA, rgb, art_canvas, flatten, icon, wrap, GRID_ITEMS,  # noqa: E402
                    SELECTED, GEAR, DETAIL, INK, INK_D, INK_M, VERM, PAPER, OUT)

FLOOR = rgb('F2DFC0')     # a hair darker than the page
SH1 = rgb('C4A67A')       # top and left inner wall, first step
SH2 = rgb('DCC29A')       # second step
HI = rgb('FFF9EE')        # lit bottom and right inner wall

COVER = {(162, 112, 100): rgb('692F2F'), (128, 72, 69): rgb('462020'), (101, 51, 60): rgb('2C1414')}


def well(art, x0, y0, w, h, depth=2, floor=FLOOR):
    corners = {(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)}
    for y in range(h):
        for x in range(w):
            if (x, y) in corners:
                continue
            if y == 0 or x == 0:
                c = SH1
            elif depth >= 2 and (y == 1 or x == 1):
                c = SH2
            elif y == h - 1 or x == w - 1:
                c = HI
            else:
                c = floor
            put(art, x0 + x, y0 + y, c)


def pressed_rule(art, x0, x1, y):
    for x in range(x0, x1 + 1):
        put(art, x, y, SH1)
        put(art, x, y + 1, HI)


def ornament_rule(art, x0, x1, y):
    cx = (x0 + x1) // 2
    for x in range(x0, x1 + 1):
        if abs(x - cx) > 5:
            put(art, x, y, INK_M)
    for d in range(4):
        for sx in (-1, 1):
            put(art, cx + sx * (3 - d), y - d, INK)
            put(art, cx + sx * (3 - d), y + d, INK)


def corner_marks(art, x0, y0, x1, y1, c, arm=5):
    for i in range(arm):
        for (cx, cy, sx, sy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
            put(art, cx + sx * i, cy, c)
            put(art, cx, cy + sy * i, c)


# ----------------------------------------------------------------------------
# the robed cultivator relief
# ----------------------------------------------------------------------------
def poly_mask(points, w, h):
    m = Image.new('1', (w, h), 0)
    ImageDraw.Draw(m).polygon(points, fill=1)
    return {(x, y) for y in range(h) for x in range(w) if m.getpixel((x, y))}


def ellipse_mask(box, w, h):
    m = Image.new('1', (w, h), 0)
    ImageDraw.Draw(m).ellipse(box, fill=1)
    return {(x, y) for y in range(h) for x in range(w) if m.getpixel((x, y))}


def cultivator_mask():
    """A standing cultivator in a long robe with wide sleeves and a topknot, 70 x 112 art px."""
    w, h = 70, 112
    pts = set()
    pts |= ellipse_mask((31, 0, 39, 7), w, h)                      # topknot
    pts |= ellipse_mask((27, 4, 43, 22), w, h)                     # head
    pts |= poly_mask([(32, 20), (38, 20), (39, 26), (31, 26)], w, h)             # neck
    pts |= poly_mask([(20, 26), (50, 26), (49, 50), (21, 50)], w, h)             # chest
    pts |= poly_mask([(21, 27), (14, 33), (8, 60), (12, 66), (24, 64), (25, 40)], w, h)   # left sleeve
    pts |= poly_mask([(49, 27), (56, 33), (62, 60), (58, 66), (46, 64), (45, 40)], w, h)  # right sleeve
    pts |= poly_mask([(22, 48), (48, 48), (55, 106), (15, 106)], w, h)           # skirt
    pts |= poly_mask([(22, 105), (32, 105), (32, 110), (21, 110)], w, h)         # shoes
    pts |= poly_mask([(38, 105), (48, 105), (49, 110), (38, 110)], w, h)
    creases = set()
    for i in range(10):                                            # collar: a V from the neck
        creases.add((31 + i // 2, 27 + i))
        creases.add((39 - i // 2, 27 + i))
    for x in range(22, 49):                                        # sash
        creases.add((x, 50))
    for y in range(34, 62):                                        # sleeve openings
        creases.add((24 - (y - 34) // 10, y))
        creases.add((46 + (y - 34) // 10, y))
    for y in range(52, 104):                                       # the robe's front fold
        creases.add((36 + (y - 52) // 26, y))
    return pts, creases, w, h


def relief(art, pts, creases, ox, oy):
    """Pressed in: the walls facing the light are shaded, the far walls lit, creases are folds."""
    for (x, y) in pts:
        top = (x, y - 1) not in pts or (x - 1, y) not in pts
        top2 = (x, y - 2) not in pts or (x - 2, y) not in pts
        low = (x, y + 1) not in pts or (x + 1, y) not in pts
        if top:
            c = SH1
        elif top2:
            c = SH2
        elif low:
            c = HI
        else:
            c = FLOOR
        put(art, ox + x, oy + y, c)
    for (x, y) in creases:
        if (x, y) in pts and (x, y - 1) in pts:
            put(art, ox + x, oy + y, SH1)
            if (x + 1, y) in pts and (x + 1, y) not in creases:
                put(art, ox + x + 1, oy + y, HI)


# ----------------------------------------------------------------------------
# the page
# ----------------------------------------------------------------------------
def base(cover):
    im = R.book_base()
    if cover == 'lacquer':
        px = im.load()
        for y in range(100, 980):
            for x in range(340, 1580):
                c = px[x, y][:3]
                if c in COVER:
                    px[x, y] = COVER[c]
    return im


GX, GY, PITCH = 452, 334, 76
SLOTS = [(1016, 300), (1016, 398), (1016, 496), (1400, 300), (1400, 398), (1400, 496)]
# mirrored to the figure: the main hand on the left with the figure's left sleeve, the off hand right
GEAR2 = [('Head', 'cultivators_cowl'), ('Main hand', 'iron_shortsword'), ('Accessory', 'dreadbeast_tooth_necklace'),
         ('Body', 'reinforced_robes'), ('Off hand', 'scripted_bark'), ('Accessory', 'leeching_ring')]


def option_b2(cover):
    im = base(cover)
    art = art_canvas()
    # ---------------- left page ----------------
    ornament_rule(art, 272, 408, 139)
    filt = [('ALL', True), ('WEAPONS', False), ('ARMOR', False), ('ACCESSORIES', False)]
    fx, lay = 456, []
    for label, on in filt:
        wpx = R.tracked_len(label, F(EUL, 13), 1) + 20
        wpx += wpx % 2
        lay.append((fx, wpx, label, on))
        fx += wpx + 14
    shift = (904 - (fx - 14)) // 2 // 2 * 2       # centre the row under the title
    lay = [(x + shift, wpx, label, on) for (x, wpx, label, on) in lay]
    for (x, wpx, label, on) in lay:
        if on:
            well(art, x // 2, 147, wpx // 2, 13)
    for i in range(36):
        owned = i < len(GRID_ITEMS)
        well(art, (GX + (i % 6) * PITCH) // 2, (GY + (i // 6) * PITCH) // 2, 36, 36,
             depth=2 if owned else 1, floor=FLOOR if owned else PAPER)
    sx, sy = (GX + (SELECTED % 6) * PITCH) // 2, (GY + (SELECTED // 6) * PITCH) // 2
    corner_marks(art, sx - 3, sy - 3, sx + 38, sy + 38, VERM)
    fy = 404
    well(art, 290, fy, 14, 14)                        # page 1, pressed
    well(art, 308, fy, 14, 14, depth=1, floor=PAPER)  # page 2
    well(art, 431, fy - 3, 21, 21)                    # discard
    for i in range(6, 15):
        put(art, 431 + i, fy - 3 + i, INK_M)
        put(art, 431 + 20 - i, fy - 3 + i, INK_M)
    # ---------------- right page ----------------
    ornament_rule(art, 552, 692, 139)
    pts, creases, w, h = cultivator_mask()
    ox, oy = 622 - w // 2, 150
    relief(art, pts, creases, ox, oy)
    for (x, y) in SLOTS:
        well(art, x // 2, y // 2, 36, 36)
    targets = [(ox + 33, oy + 12), (ox + 10, oy + 62), (ox + 28, oy + 51),
               (ox + 42, oy + 38), (ox + 60, oy + 62), (ox + 44, oy + 51)]
    for (x, y), t in zip(SLOTS, targets):
        start = (x // 2 + 39, y // 2 + 18) if x < 1200 else (x // 2 - 3, y // 2 + 18)
        R.dotted_line(art, start, t, INK_M, every=3)
    pressed_rule(art, 506, 742, 306)
    well(art, 506, 316, 36, 36)                       # the item, pressed in at full size
    for yy in (372, 387):
        pressed_rule(art, 506, 742, yy)
    flatten(im, art)

    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (GX + (i % 6) * PITCH + 4, GY + (i // 6) * PITCH + 4))
    for (x, y), (_, name) in zip(SLOTS, GEAR2):
        im.alpha_composite(icon(name), (x + 4, y + 4))
    im.alpha_composite(icon('makeshift_dagger'), (1016, 636))

    text(im, (678, 262), 'Equipment', F(YATRA, 38), INK_D, anchor='ms')
    for (x, wpx, label, on) in lay:
        text(im, (x + wpx // 2, 316), label, F(EUL, 13), INK_D if on else INK_M, anchor='ms', spacing=1)
    text(im, (568, 832), 'PAGE', F(EUL, 13), INK_M, anchor='rs', spacing=1)
    text(im, (594, 830), '1', F(EUL, 15), INK_D, anchor='ms')
    text(im, (630, 830), '2', F(EUL, 15), INK_M, anchor='ms')
    text(im, (848, 832), '11 / 36', F(EUL, 15), INK_M, anchor='rs')
    text(im, (1244, 262), 'Gear', F(YATRA, 38), INK_D, anchor='ms')
    for (x, y), (label, _) in zip(SLOTS, GEAR2):
        text(im, (x + 36, y + 94), label.upper(), F(EUL, 13), INK_M, anchor='ms', spacing=1)
    text(im, (1102, 664), DETAIL['name'], F(YATRA, 30), INK_D)
    text(im, (1104, 692), DETAIL['type'].upper(), F(EUL, 13), INK_M, spacing=1)
    yy = 736
    for label, val in DETAIL['stats']:
        text(im, (1012, yy), label.upper(), F(EUL, 13), INK_M, spacing=1)
        text(im, (1484, yy), val, F(EUL, 18), INK_D, anchor='rs')
        yy += 30
    yy = 812
    for line in wrap(DETAIL['desc'], F(EUL, 18), 472):
        text(im, (1012, yy), line, F(EUL, 18), INK)
        yy += 26
    text(im, (1012, 866), 'Right-click to wear it', F(EUL, 15), INK_M)
    return im


def main():
    option_b2('red').convert('RGB').save(OUT + 'r2_b2.png')
    print('saved')


if __name__ == '__main__':
    main()
