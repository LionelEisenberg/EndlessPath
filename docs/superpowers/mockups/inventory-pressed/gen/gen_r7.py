"""Round 7: the Equipment page after the builder check.

- the details panel shows the longest real item (Dreadbeast Tooth Necklace): its name wraps
  beside the icon, its description runs two lines
- the gear slots keep their 98 px pitch; the two-column bonuses make the room instead
- bonuses in two columns, so two bonuses take one row and four take two
- the discard slot is a full 72 px slot, so it can show an item it holds
Uses round 6's softer pieces.
"""
import sys

SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
sys.path.insert(0, SCR + 'r1')
import gen_r6  # noqa: E402,F401  (patches the softer pieces into gen_r3 and gen_r5)
import gen_r1 as R  # noqa: E402
import gen_r2 as B  # noqa: E402
import gen_r3 as P  # noqa: E402
from gen_r1 import put, F, EUL, YATRA, art_canvas, flatten, icon, wrap, GRID_ITEMS, INK, INK_D, INK_M, VERM, OUT  # noqa: E402

GX, GY, PITCH = 452, 334, 76
SLOTS = [(1016, 300), (1016, 398), (1016, 496), (1400, 300), (1400, 398), (1400, 496)]
GEAR2 = B.GEAR2
SELECTED = 1   # the necklace, row 1 column 2
ITEM = {
    'icon': 'dreadbeast_tooth_necklace',
    'name': 'Dreadbeast Tooth Necklace',
    'type': 'ACCESSORY',
    'stats': [('STRENGTH', '+2'), ('AGILITY', '+2')],
    'desc': 'A small dreadbeast tooth, fashioned around a leather strap.',
}


def T(im, xy, s, size, col, anchor='ls', spacing=0, font=None):
    R.text(im, xy, s, F(font or EUL, size), col, anchor=anchor, spacing=spacing)


def equipment():
    im = B.base('red')
    art = art_canvas()
    well, rule = P.well, P.pressed_rule
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
             depth=2 if owned else 1, floor=P.FLOOR if owned else P.EMPTY)
    sx, sy = (GX + (SELECTED % 6) * PITCH) // 2, (GY + (SELECTED // 6) * PITCH) // 2
    B.corner_marks(art, sx - 3, sy - 3, sx + 38, sy + 38, VERM)
    well(art, 556 // 2, 818 // 2, 14, 14)                      # page 1, pressed deep
    well(art, 592 // 2, 818 // 2, 14, 14, depth=1, floor=P.EMPTY)
    well(art, 832 // 2, 796 // 2, 36, 36, depth=1, floor=P.EMPTY)   # discard, a full slot
    for i in range(12, 25):
        put(art, 416 + i, 398 + i, INK_M)
        put(art, 416 + 36 - i, 398 + i, INK_M)
    # ---------------- right page ----------------
    B.ornament_rule(art, 552, 692, 139)
    pts, creases, w, h = B.cultivator_mask()
    ox, oy = 622 - w // 2, 150
    P.relief(art, pts, creases, ox, oy)
    for (x, y) in SLOTS:
        well(art, x // 2, y // 2, 36, 36)
    targets = [(ox + 33, oy + 12), (ox + 10, oy + 62), (ox + 28, oy + 51),
               (ox + 42, oy + 38), (ox + 60, oy + 62), (ox + 44, oy + 51)]
    for (x, y), t in zip(SLOTS, targets):
        start = (x // 2 + 39, y // 2 + 18) if x < 1200 else (x // 2 - 3, y // 2 + 18)
        R.dotted_line(art, start, t, INK_M, every=3)
    well(art, 504, 303, 234, 136, floor=P.TRAY)                # (1008, 606) to (1476, 878)
    well(art, 512, 311, 36, 36)                                 # the item at (1024, 622)
    rule(art, 512, 729, 380)                                    # under the bonus row
    flatten(im, art)

    for i, name in enumerate(GRID_ITEMS):
        im.alpha_composite(icon(name), (GX + (i % 6) * PITCH + 4, GY + (i // 6) * PITCH + 4))
    for (x, y), (_, name) in zip(SLOTS, GEAR2):
        im.alpha_composite(icon(name), (x + 4, y + 4))
    im.alpha_composite(icon(ITEM['icon']), (1028, 626))

    T(im, (678, 262), 'Equipment', 38, INK_D, anchor='ms', font=YATRA)
    for (x, wpx, label, on) in lay:
        T(im, (x + wpx // 2, 316), label, 13, INK_D if on else INK_M, anchor='ms', spacing=1)
    T(im, (536, 838), 'PAGE', 13, INK_M, anchor='rs', spacing=1)
    T(im, (570, 838), '1', 15, INK_D, anchor='ms')
    T(im, (606, 838), '2', 15, INK_M, anchor='ms')
    T(im, (816, 838), '11 / 72', 15, INK_M, anchor='rs')
    T(im, (1244, 262), 'Gear', 38, INK_D, anchor='ms', font=YATRA)
    for (x, y), (label, _) in zip(SLOTS, GEAR2):
        T(im, (x + 36, y + 94), label.upper(), 13, INK_M, anchor='ms', spacing=1)
    y = 654
    for line in wrap(ITEM['name'], F(YATRA, 30), 346):
        T(im, (1112, y), line, 30, INK_D, font=YATRA)
        y += 34
    T(im, (1114, y - 8), ITEM['type'], 13, INK_M, spacing=1)
    cols = [(1024, 1232), (1250, 1458)]
    for (label, val), (x0, x1) in zip(ITEM['stats'], cols):
        T(im, (x0, 752), label, 13, INK_M, spacing=1)
        T(im, (x1, 752), val, 18, INK_D, anchor='rs')
    y = 798
    for line in wrap(ITEM['desc'], F(EUL, 18), 434):
        T(im, (1024, y), line, 18, INK)
        y += 26
    T(im, (1024, 866), 'Right-click to wear it', 15, INK_M)
    return im


def main():
    equipment().convert('RGB').save(OUT + 'r7_1_equipment.png')
    print('saved')


if __name__ == '__main__':
    main()
