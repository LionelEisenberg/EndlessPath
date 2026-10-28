"""Round 5: all four inventory tabs in the settled pressed style.

Equipment is round 3's pressed-panel page. Consumables, Materials and the Journal follow the
decisions from the grill: a consumables list with the hotbar and details on the right page;
materials kept minimal; the Journal lists quest items with their quest, shown like the Goals
board plus the quest's flavour text.
"""
import sys
from PIL import Image

SCR = ('C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-inventory-panes-redesign-19cccc/'
       'ba061de5-a7a9-4a4d-8ee0-26f3eba841cf/scratchpad/')
REPO = 'C:/worktrees/EndlessPath/inventory-panes-redesign-19cccc/'
sys.path.insert(0, SCR + 'r1')
import gen_r1 as R  # noqa: E402
import gen_r2 as B  # noqa: E402
import gen_r3 as P  # noqa: E402
import icons_ai as IC  # noqa: E402
from gen_r1 import put, F, EUL, YATRA, rgb, art_canvas, flatten, wrap, INK, INK_D, INK_M, VERM, PAPER, OUT, CREAM  # noqa: E402
from gen_r3 import well, pressed_rule, SH1, HI, EMPTY, TRAY  # noqa: E402

MADRA_INK = rgb('1C2F60')
VERM_D = rgb('7E2A22')
CAPS = ['01_equipment.png', '02_consumables.png', '03_materials.png', '04_journal.png']
LEFT_C, RIGHT_C = 678, 1244


def T(im, xy, s, size, col, anchor='ls', spacing=0, font=None):
    R.text(im, xy, s, F(font or EUL, size), col, anchor=anchor, spacing=spacing)


def tab_base(t):
    """The clean book with tab t open: the side tabs from that tab's capture, pages cleared."""
    im = R.book_base()
    if t == 0:
        return im
    eq = Image.open(R.SCR + 'captures/' + CAPS[0]).convert('RGBA')
    ct = Image.open(R.SCR + 'captures/' + CAPS[t]).convert('RGBA')
    im.paste(ct.crop((290, 230, 420, 640)), (290, 230))
    clean = eq.crop((420, 400, 444, 401))
    for y in range(236, 324):                       # close the Equipment tab's lip
        im.paste(clean, (420, y))
    im.paste(eq.crop((420, 236, 444, 324)), (420, 236 + 98 * t))   # open tab t's lip
    return im


def ornament(art, cx):
    B.ornament_rule(art, cx // 2 - 68, cx // 2 + 68, 139)


def raised_tag(art, x0, y0, w, h):
    """A paper label stuck on: lit top and left edge, shaded bottom and right (the inverse of a well)."""
    for y in range(h):
        for x in range(w):
            c = HI if (y == 0 or x == 0) else SH1 if (y == h - 1 or x == w - 1) else PAPER
            put(art, x0 + x, y0 + y, c)


def seal(art, x0, y0, w, h):
    """A vermilion chop, its edge bitten in a few places."""
    bites = {(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (5, 0), (w - 1, 4), (9, h - 1), (0, 7)}
    for y in range(h):
        for x in range(w):
            if (x, y) in bites:
                continue
            c = VERM_D if (y == h - 1 or x == w - 1) else VERM
            put(art, x0 + x, y0 + y, c)


def tick_box(art, x0, y0, ticked):
    well(art, x0, y0, 11, 11, depth=1, floor=EMPTY)
    if ticked:
        for (x, y) in ((2, 5), (3, 6), (4, 7), (5, 6), (6, 5), (7, 4), (8, 3), (3, 5), (4, 6)):
            put(art, x0 + x, y0 + y, INK)


def marks(art, x0, y0, x1, y1):
    """Red printer's marks round the selected thing (screen px in, art px drawn)."""
    B.corner_marks(art, x0 // 2, y0 // 2, x1 // 2, y1 // 2, VERM)


def item_icon(name):
    if name in IC.ROWS:
        return IC.make(name)
    if name == 'crude_scale':
        return Image.open(REPO + 'assets/sprites/items/consumables/crude_scale.png').convert('RGBA')
    if name in ('fern', 'dewdrop'):
        im = Image.open(REPO + f'assets/ui/lacquer/icons/ic_{name}_ai.png').convert('RGBA')
        return im.resize((64, 64), Image.NEAREST)
    return R.icon(name)


def effect_line(im, x, y, parts):
    """parts: [(text, colour)], drawn in a row at 15 px."""
    for s, col in parts:
        T(im, (x, y), s, 15, col)
        x += round(F(EUL, 15).getlength(s))


# ----------------------------------------------------------------------------
# Consumables
# ----------------------------------------------------------------------------
CONSUMABLES = [   # the first is real; the rest stand in for a fuller pack (names from the game's own lore)
    ('crude_scale', 'Crude Scale', [('+20 Madra', MADRA_INK), (' · 10 s cooldown', INK_M)], 7),
    ('tea', 'Spirit Tea', [('+40 Madra', MADRA_INK), (' over 8 s', INK_M)], 3),
    ('vial', 'Greenleaf Tonic', [('+30 Health · 12 s cooldown', INK_M)], 12),
    ('pill', 'Mirror Pill', [('Turns the next technique back', INK_M)], 1),
    ('talisman', 'Ember Talisman', [('+25% damage for 10 s', INK_M)], 5),
    ('gourd', 'Healing Gourd', [('+60 Health · 30 s cooldown', INK_M)], 2),
    ('capsule', 'Iron Skin Pill', [('+10 Resilience for 20 s', INK_M)], 24),
    ('crude_scale', 'Barely Coalesced Scale', [('+20 Madra', MADRA_INK), (' · 10 s cooldown', INK_M)], 99),
]
HOTBAR = [0, 1, None, 2]


def consumables():
    im = tab_base(1)
    art = art_canvas()
    ornament(art, LEFT_C)
    rows = [300 + 80 * i for i in range(7)]
    for i, y in enumerate(rows):
        well(art, 452 // 2, y // 2, 36, 36)
        if i < 6:
            pressed_rule(art, 452 // 2, 880 // 2, (y + 76) // 2)
    well(art, 892 // 2, 300 // 2, 5, 276, depth=1, floor=EMPTY)        # the scroll groove
    for y in range(151, 151 + 240):
        put(art, 447, y, INK_M)
        put(art, 448, y, INK_M)
    marks(art, 444, 292, 884, 380)
    # right page: hotbar, hint, details panel
    ornament(art, RIGHT_C)
    hx = [1040, 1152, 1264, 1376]
    for x, slot in zip(hx, HOTBAR):
        well(art, x // 2, 316 // 2, 36, 36, depth=2 if slot is not None else 1,
             floor=P.FLOOR if slot is not None else EMPTY)
    pressed_rule(art, 506, 736, 249)
    well(art, 504, 256, 234, 156, floor=TRAY)                           # (1008, 512) to (1490, 824)
    well(art, 512, 264, 36, 36)
    for yy in (322, 337):
        pressed_rule(art, 512, 729, yy)
    flatten(im, art)

    for (key, name, eff, n), y in zip(CONSUMABLES, rows):
        im.alpha_composite(item_icon(key), (456, y + 4))
        T(im, (540, y + 30), name, 18, INK_D)
        effect_line(im, 540, y + 56, eff)
        T(im, (876, y + 46), f'×{n}', 20, INK_D, anchor='rs')
    over = Image.new('RGBA', (1920, 1080), (0, 0, 0, 0))
    oart = art_canvas()
    for x, slot in zip(hx, HOTBAR):
        if slot is not None:
            im.alpha_composite(item_icon(CONSUMABLES[slot][0]), (x + 4, 320))
            label = f'×{CONSUMABLES[slot][3]}'
            w = round(F(EUL, 13).getlength(label)) + 10
            w += w % 2
            raised_tag(oart, (x + 72 - w) // 2, (316 + 72 - 22) // 2, w // 2, 10)
    flatten(im, oart)
    del over
    for x, slot in zip(hx, HOTBAR):
        T(im, (x + 36, 418), str(hx.index(x) + 1), 18, INK_D, anchor='ms')
        if slot is not None:
            label = f'×{CONSUMABLES[slot][3]}'
            T(im, (x + 68, 382), label, 13, INK_D, anchor='rs')
    T(im, (LEFT_C, 262), 'Consumables', 38, INK_D, anchor='ms', font=YATRA)
    T(im, (RIGHT_C, 262), 'Hotbar', 38, INK_D, anchor='ms', font=YATRA)
    T(im, (RIGHT_C, 456), 'Drag a consumable onto a slot to carry it into combat.', 15, INK_M, anchor='ms')
    T(im, (RIGHT_C, 478), 'Click a slot to empty it.', 15, INK_M, anchor='ms')
    im.alpha_composite(item_icon('crude_scale'), (1028, 532))
    T(im, (1112, 568), 'Crude Scale', 30, INK_D, font=YATRA)
    T(im, (1114, 594), 'CONSUMABLE · IN SLOT 1', 13, INK_M, spacing=1)
    T(im, (1024, 640), 'RESTORES', 13, INK_M, spacing=1)
    T(im, (1458, 640), '+20 Madra', 18, MADRA_INK, anchor='rs')
    T(im, (1024, 670), 'COOLDOWN', 13, INK_M, spacing=1)
    T(im, (1458, 670), '10 s', 18, INK_D, anchor='rs')
    y = 712
    for line in wrap('A poorly-formed flake of madra, scarcely worth the name. Crude practitioners still find '
                     'a use for them.', F(EUL, 18), 434):
        T(im, (1024, y), line, 18, INK)
        y += 26
    T(im, (1024, 806), 'Drag it onto the hotbar', 15, INK_M)
    return im


# ----------------------------------------------------------------------------
# Materials
# ----------------------------------------------------------------------------
MATERIALS = [('fern', 'Spirit Fern', 4600), ('dewdrop', 'Dewdrop Tear', 3300)]


def materials():
    im = tab_base(2)
    art = art_canvas()
    ornament(art, LEFT_C)
    gx, gy, p = 452, 334, 76
    for i in range(36):
        owned = i < len(MATERIALS)
        well(art, (gx + (i % 6) * p) // 2, (gy + (i // 6) * p) // 2, 36, 36,
             depth=2 if owned else 1, floor=P.FLOOR if owned else EMPTY)
    marks(art, gx - 6, gy - 6, gx + 78, gy + 78)
    ornament(art, RIGHT_C)
    well(art, 504, 150, 234, 173, floor=TRAY)                           # (1008, 300) to (1490, 646)
    well(art, 512, 158, 36, 36)
    for yy in (282, 297, 312):
        pressed_rule(art, 512, 729, yy)
    flatten(im, art)

    oart = art_canvas()
    tags = []
    for i, (key, name, n) in enumerate(MATERIALS):
        x, y = gx + (i % 6) * p, gy + (i // 6) * p
        im.alpha_composite(item_icon(key), (x + 4, y + 4))
        label = f'×{n}'
        w = round(F(EUL, 13).getlength(label)) + 10
        w += w % 2
        raised_tag(oart, (x + 70 - w) // 2, (y + 48) // 2, w // 2, 10)
        tags.append((x + 66, y + 64, label))
    flatten(im, oart)
    for (x, y, label) in tags:
        T(im, (x, y), label, 13, INK_D, anchor='rs')
    T(im, (LEFT_C, 262), 'Materials', 38, INK_D, anchor='ms', font=YATRA)
    T(im, (LEFT_C, 316), '2 KINDS', 13, INK_M, anchor='ms', spacing=1)
    T(im, (RIGHT_C, 262), 'Spirit Fern', 38, INK_D, anchor='ms', font=YATRA)
    im.alpha_composite(item_icon('fern'), (1028, 320))
    T(im, (1114, 350), 'MATERIAL', 13, INK_M, spacing=1)
    T(im, (1112, 382), 'You have 4,600', 18, INK_D)
    y = 436
    for line in wrap('A fern that drinks the valley\'s aura. Its fronds curl toward a cultivator\'s core.',
                     F(EUL, 18), 434):
        T(im, (1024, y), line, 18, INK)
        y += 26
    for (label, val), yy in zip((('GATHERED BY', 'Spring Forest Foraging'), ('IN', 'Spirit Valley'),
                                 ('YIELD', '2–6 every 5 s')), (556, 586, 616)):
        T(im, (1024, yy), label, 13, INK_M, spacing=1)
        T(im, (1458, yy), val, 18, INK_D, anchor='rs')
    return im


# ----------------------------------------------------------------------------
# Journal
# ----------------------------------------------------------------------------
BELL = {'k': IC.K, 'B': IC._c('B07A3A'), 'b': IC._c('E0B070'), 'R': IC._c('6B4A2A')}
BELL_ROWS = [
    '................',
    '.......kk.......',
    '......kbbk......',
    '.....kBBBBk.....',
    '....kBbBBBBk....',
    '....kBbBBBBk....',
    '....kBbBBBBk....',
    '...kBbBBBBBBk...',
    '...kBBBBBBBBk...',
    '..kBBBBBBBBBBk..',
    '..kkkkkkkkkkkk..',
    '......kRRk......',
    '.......kk.......',
    '................',
    '................',
    '................',
]


def bell_icon():
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(BELL_ROWS):
        for x, ch in enumerate(row):
            if ch != '.':
                im.putpixel((x, y), BELL[ch])
    return im.resize((64, 64), Image.NEAREST)


def journal():
    im = tab_base(3)
    art = art_canvas()
    ornament(art, LEFT_C)
    rows = [334, 414]
    for y in rows:
        well(art, 452 // 2, y // 2, 36, 36)
    pressed_rule(art, 452 // 2, 880 // 2, (rows[0] + 76) // 2)
    seal(art, 810 // 2, (rows[0] + 22) // 2, 33, 13)                    # DONE on the finished one
    marks(art, 444, 326, 884, 414)
    ornament(art, RIGHT_C)
    well(art, 504, 150, 234, 98, floor=TRAY)                            # item: (1008, 300) to (1490, 496)
    well(art, 512, 158, 36, 36)
    well(art, 504, 256, 234, 132, floor=TRAY)                           # quest: (1008, 512) to (1490, 776)
    seal(art, 1390 // 2, 526 // 2, 33, 13)
    pressed_rule(art, 512, 729, 334)
    tick_box(art, 512, 343, True)
    tick_box(art, 512, 360, True)
    flatten(im, art)

    im.alpha_composite(item_icon('map'), (456, rows[0] + 4))
    im.alpha_composite(bell_icon(), (456, rows[1] + 4))
    T(im, (540, rows[0] + 30), 'Refugee Camp Map', 18, INK_D)
    T(im, (540, rows[0] + 56), 'Harden Your Core', 15, INK_M)
    T(im, (843, rows[0] + 40), 'DONE', 13, CREAM, anchor='ms', spacing=1)
    T(im, (540, rows[1] + 30), 'Tarnished Shrine Bell', 18, INK_D)
    T(im, (540, rows[1] + 56), 'The Broken Shrine', 15, INK_M)
    T(im, (876, rows[1] + 46), 'Step 1 of 3', 15, INK_M, anchor='rs')
    T(im, (LEFT_C, 262), 'Journal', 38, INK_D, anchor='ms', font=YATRA)
    T(im, (LEFT_C, 316), 'ITEMS OF CONSEQUENCE', 13, INK_M, anchor='ms', spacing=1)

    T(im, (RIGHT_C, 262), 'Refugee Camp Map', 38, INK_D, anchor='ms', font=YATRA)
    im.alpha_composite(item_icon('map'), (1028, 320))
    T(im, (1114, 350), 'QUEST ITEM', 13, INK_M, spacing=1)
    T(im, (1112, 380), 'From Old Vesh, in the broken shrine', 15, INK_M)
    T(im, (1024, 452), 'A', 46, VERM, font=YATRA)
    first = wrap('hand-drawn map leading to a camp of survivors hidden in the valley.', F(EUL, 18), 390)
    T(im, (1064, 436), first[0], 18, INK)
    y = 462
    rest = wrap(' '.join(first[1:]), F(EUL, 18), 390) if len(first) > 1 else []
    for line in rest:
        T(im, (1064, y), line, 18, INK)
        y += 26

    T(im, (1024, 544), 'QUEST', 13, INK_M, spacing=1)
    T(im, (1423, 544), 'DONE', 13, CREAM, anchor='ms', spacing=1)
    T(im, (1024, 580), 'Harden Your Core', 26, INK_D, font=YATRA)
    y = 610
    for line in wrap('Deepen your cultivation. Raise your Core Density to level 10, then report back to the '
                     'Celestial [INTERVENER].', F(EUL, 16), 434):
        T(im, (1024, y), line, 16, INK_M)
        y += 22
    T(im, (1062, 706), 'Reach Core Density level 10', 16, INK)
    T(im, (1458, 706), '10 / 10', 16, INK_D, anchor='rs')
    T(im, (1062, 740), 'Return to the Celestial [INTERVENER]', 16, INK)
    return im


def main():
    P.page(True, False).convert('RGB').save(OUT + 'r5_1_equipment.png')
    consumables().convert('RGB').save(OUT + 'r5_2_consumables.png')
    materials().convert('RGB').save(OUT + 'r5_3_materials.png')
    journal().convert('RGB').save(OUT + 'r5_4_journal.png')
    print('saved four tabs')


if __name__ == '__main__':
    main()
