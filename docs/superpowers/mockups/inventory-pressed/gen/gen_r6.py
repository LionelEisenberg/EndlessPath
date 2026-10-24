"""Round 6: the four tabs, a little less sharp and a little less square.

- corners rounded: 2 art px on slots, 3 on panels, 1 on the small tags and key wells
- gentler walls: the shadow and the lit edge sit closer to the paper, so edges read softer
Everything else is round 5.
"""
import sys

SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
sys.path.insert(0, SCR + 'r1')
import gen_r1 as R  # noqa: E402
import gen_r3 as P  # noqa: E402
import gen_r5 as Q  # noqa: E402
from gen_r1 import put, rgb, PAPER, OUT  # noqa: E402

SH1 = rgb('B9996F')    # round 5: A9865A
SH2 = rgb('D3B98F')    # C8A97B
HI = rgb('FBF1DE')     # FFF8EA


def rounded(w, h, r):
    cut = {1: [(0, 0)], 2: [(0, 0), (1, 0), (0, 1)], 3: [(0, 0), (1, 0), (2, 0), (0, 1), (0, 2)]}[r]
    out = set()
    for (x, y) in cut:
        out |= {(x, y), (w - 1 - x, y), (x, h - 1 - y), (w - 1 - x, h - 1 - y)}
    return {(x, y) for y in range(h) for x in range(w)} - out


def soft_well(art, x0, y0, w, h, depth=2, floor=None):
    floor = floor or P.FLOOR
    r = 3 if min(w, h) >= 60 else 2 if min(w, h) >= 20 else 1
    pts = rounded(w, h, r)
    for (x, y) in pts:
        top = (x, y - 1) not in pts or (x - 1, y) not in pts
        top2 = (x, y - 2) not in pts or (x - 2, y) not in pts
        low = (x, y + 1) not in pts or (x + 1, y) not in pts
        if top:
            c = SH1
        elif depth >= 2 and top2:
            c = SH2
        elif low:
            c = HI
        else:
            c = floor
        put(art, x0 + x, y0 + y, c)


def soft_rule(art, x0, x1, y):
    for x in range(x0, x1 + 1):
        put(art, x, y, SH2 if x in (x0, x1) else SH1)
        put(art, x, y + 1, HI)


def soft_tag(art, x0, y0, w, h):
    pts = rounded(w, h, 1)
    for (x, y) in pts:
        top = (x, y - 1) not in pts or (x - 1, y) not in pts
        low = (x, y + 1) not in pts or (x + 1, y) not in pts
        put(art, x0 + x, y0 + y, HI if top else SH1 if low else PAPER)


for mod in (P, Q):
    mod.well = soft_well
    mod.pressed_rule = soft_rule
    mod.SH1, mod.HI = SH1, HI
P.SH2 = SH2
Q.raised_tag = soft_tag


def main():
    P.page(True, False).convert('RGB').save(OUT + 'r6_1_equipment.png')
    Q.consumables().convert('RGB').save(OUT + 'r6_2_consumables.png')
    Q.materials().convert('RGB').save(OUT + 'r6_3_materials.png')
    Q.journal().convert('RGB').save(OUT + 'r6_4_journal.png')
    print('saved four tabs, softer')


if __name__ == '__main__':
    main()
