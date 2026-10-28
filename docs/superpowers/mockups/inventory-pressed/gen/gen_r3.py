"""Round 3: the refined B with darker pressing, and the text pressed in too.

Variants:
  panel    the details sit in a pressed panel, like items sit in pressed slots; text printed in ink
  letters  every word on the page is pressed into the paper (letterpress), no panel
  both     the panel and the pressed letters
All three press the slots, the figure and the panel darker than round 2.
"""
import sys

SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
sys.path.insert(0, SCR + 'r1')
import gen_r1 as R  # noqa: E402
import gen_r2 as B  # noqa: E402
from gen_r1 import (put, F, EUL, YATRA, rgb, art_canvas, flatten, icon, wrap, GRID_ITEMS,  # noqa: E402
                    SELECTED, DETAIL, INK, INK_D, INK_M, VERM, OUT)

# darker pressing (round 2 in comments)
FLOOR = rgb('E7CFA6')      # F2DFC0
SH1 = rgb('A9865A')        # C4A67A
SH2 = rgb('C8A97B')        # DCC29A
HI = rgb('FFF8EA')         # FFF9EE
EMPTY = rgb('EFDCBB')      # empty slots: pressed shallow, a step darker than the page
TRAY = rgb('EFDCBB')       # the details panel's floor
P_INK = rgb('5A4330')      # pressed letters: ink sunk into the paper


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


def relief(art, pts, creases, ox, oy):
    for (x, y) in pts:
        top = (x, y - 1) not in pts or (x - 1, y) not in pts
        top2 = (x, y - 2) not in pts or (x - 2, y) not in pts
        low = (x, y + 1) not in pts or (x + 1, y) not in pts
        c = SH1 if top else SH2 if top2 else HI if low else FLOOR
        put(art, ox + x, oy + y, c)
    for (x, y) in creases:
        if (x, y) in pts and (x, y - 1) in pts:
            put(art, ox + x, oy + y, SH1)
            if (x + 1, y) in pts and (x + 1, y) not in creases:
                put(art, ox + x + 1, oy + y, HI)


class Ink:
    """Draws text either printed (plain ink) or pressed (ink sunk in, with the cut's lit lower edge)."""

    def __init__(self, pressed):
        self.pressed = pressed

    def __call__(self, im, xy, s, font, fill, anchor='ls', spacing=0):
        if self.pressed:
            x, y = xy
            R.text(im, (x, y + 2), s, font, HI, anchor=anchor, spacing=spacing)
            fill = P_INK if fill in (INK, INK_D) else fill
        R.text(im, xy, s, font, fill, anchor=anchor, spacing=spacing)


GX, GY, PITCH = 452, 334, 76
SLOTS = B.SLOTS
GEAR2 = B.GEAR2


def page(panel, letters):
    im = B.base('red')
    art = art_canvas()
    T = Ink(letters)
    # ---------------- left page ----------------
    B.ornament_rule(art, 272, 408, 139)
    filt = [('ALL', True), ('WEAPONS', False), ('ARMOR', False), ('ACCESSORIES', False)]
    fx, lay = 456, []
    for label, on in filt:
        wpx = R.tracked_len(label, F(EUL, 13), 1) + 20
        wpx += wpx % 2
        lay.append((fx, wpx, label, on))
        fx += wpx + 14
    shift = (904 - (fx - 14)) // 2 // 2 * 2
    lay = [(x + shift, wpx, label, on) for (x, wpx, label, on) in lay]
    for (x, wpx, label, on) in lay:
        if on:
            well(art, x // 2, 147, wpx // 2, 13)
    for i in range(36):
        owned = i < len(GRID_ITEMS)
        well(art, (GX + (i % 6) * PITCH) // 2, (GY + (i // 6) * PITCH) // 2, 36, 36,
             depth=2 if owned else 1, floor=FLOOR if owned else EMPTY)
    sx, sy = (GX + (SELECTED % 6) * PITCH) // 2, (GY + (SELECTED // 6) * PITCH) // 2
    B.corner_marks(art, sx - 3, sy - 3, sx + 38, sy + 38, VERM)
    fy = 404
    well(art, 290, fy, 14, 14)
    well(art, 308, fy, 14, 14, depth=1, floor=EMPTY)
    well(art, 431, fy - 3, 21, 21)
    for i in range(6, 15):
        put(art, 431 + i, fy - 3 + i, INK_M)
        put(art, 431 + 20 - i, fy - 3 + i, INK_M)
    # ---------------- right page ----------------
    B.ornament_rule(art, 552, 692, 139)
    pts, creases, w, h = B.cultivator_mask()
    ox, oy = 622 - w // 2, 150
    relief(art, pts, creases, ox, oy)
    for (x, y) in SLOTS:
        well(art, x // 2, y // 2, 36, 36)
    targets = [(ox + 33, oy + 12), (ox + 10, oy + 62), (ox + 28, oy + 51),
               (ox + 42, oy + 38), (ox + 60, oy + 62), (ox + 44, oy + 51)]
    for (x, y), t in zip(SLOTS, targets):
        start = (x // 2 + 39, y // 2 + 18) if x < 1200 else (x // 2 - 3, y // 2 + 18)
        R.dotted_line(art, start, t, INK_M, every=3)
    if panel:
        well(art, 504, 303, 234, 136, floor=TRAY)      # the details panel, (1008, 606) 482x272
        well(art, 512, 311, 36, 36)                     # the item inside it
        for yy in (373, 387):
            pressed_rule(art, 512, 729, yy)
        icon_at, nx, rows, dy0, dw, hint = (1028, 626), 1112, (738, 766), 806, 434, 862
        sx0, sx1 = 1024, 1458
    else:
        pressed_rule(art, 506, 742, 306)
        well(art, 506, 316, 36, 36)
        for yy in (372, 387):
            pressed_rule(art, 506, 742, yy)
        icon_at, nx, rows, dy0, dw, hint = (1016, 636), 1102, (736, 766), 812, 472, 866
        sx0, sx1 = 1012, 1484
    flatten(im, art)

    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (GX + (i % 6) * PITCH + 4, GY + (i // 6) * PITCH + 4))
    for (x, y), (_, name) in zip(SLOTS, GEAR2):
        im.alpha_composite(icon(name), (x + 4, y + 4))
    im.alpha_composite(icon('makeshift_dagger'), icon_at)

    T(im, (678, 262), 'Equipment', F(YATRA, 38), INK_D, anchor='ms')
    for (x, wpx, label, on) in lay:
        T(im, (x + wpx // 2, 316), label, F(EUL, 13), INK_D if on else INK_M, anchor='ms', spacing=1)
    T(im, (568, 832), 'PAGE', F(EUL, 13), INK_M, anchor='rs', spacing=1)
    T(im, (594, 830), '1', F(EUL, 15), INK_D, anchor='ms')
    T(im, (630, 830), '2', F(EUL, 15), INK_M, anchor='ms')
    T(im, (848, 832), '11 / 72', F(EUL, 15), INK_M, anchor='rs')
    T(im, (1244, 262), 'Gear', F(YATRA, 38), INK_D, anchor='ms')
    for (x, y), (label, _) in zip(SLOTS, GEAR2):
        T(im, (x + 36, y + 94), label.upper(), F(EUL, 13), INK_M, anchor='ms', spacing=1)
    T(im, (nx, 662 if panel else 664), DETAIL['name'], F(YATRA, 30), INK_D)
    T(im, (nx + 2, 688 if panel else 692), DETAIL['type'].upper(), F(EUL, 13), INK_M, spacing=1)
    for (label, val), yy in zip(DETAIL['stats'], rows):
        T(im, (sx0, yy), label.upper(), F(EUL, 13), INK_M, spacing=1)
        T(im, (sx1, yy), val, F(EUL, 18), INK_D, anchor='rs')
    yy = dy0
    for line in wrap(DETAIL['desc'], F(EUL, 18), dw):
        T(im, (sx0, yy), line, F(EUL, 18), INK)
        yy += 26
    T(im, (sx0, hint), 'Right-click to wear it', F(EUL, 15), INK_M)
    return im


def main():
    for name, panel, letters in (('panel', True, False), ('letters', False, True), ('both', True, True)):
        page(panel, letters).convert('RGB').save(OUT + f'r3_{name}.png')
        print('saved', name)


if __name__ == '__main__':
    main()
