"""Lacquer and brass, full kit: icons drawn on the same grid as the swatch's 16 px icons.

16x16 icons show at 32x32 (dock), 8x8 minis show at 16x16 (plate lines, the Now strip's
material line, the adventure card's Madra line, the LOCKED seal). Map glyphs (lock, ?)
are larger and carry a baked 1 px ink shadow (2 screen px, hard, lower right).
Every pixel is placed from the strings below.
"""
from lq_base import (CLEAR, INK, BRASS, BRASS_SH, CREAM, TAN, JADE_HI, JADE, JADE_SH, JADE_OL,
                     M_HI, M_PALE, M_MID, M_OL, hx, new, put, save)

# skin and armour ramps sampled from the user's own system_menu icons
SKIN_HI, SKIN, SKIN_SH, SKIN_OL = hx('ffd1ab'), hx('e7a581'), hx('cf7957'), hx('17111a')
ARM_W, ARM_L, ARM_M, ARM_D, ARM_OL = hx('ffffff'), hx('bfddd1'), hx('95adb4'), hx('86718c'), hx('2e1c2c')
WARM_OL = hx('341E0E')
GOLD_Y = hx('E3B95A')
TAN_SH = hx('7A654C')
# ic_forage / ic_well / ic_dewdrop palettes (the mock's placeholder icons)
LEAF_OL, LEAF_D, LEAF_M, LEAF_H, STEM = hx('17240f'), hx('3f7a3a'), hx('6bab5e'), hx('a8d98f'), hx('8a6a3a')
WELL_OL, ST_D, ST_M, ST_L, CR_D, CR_M, CR_H = (hx('1d1830'), hx('5d616b'), hx('8a8f9a'), hx('b5bac4'),
                                              hx('967ae6'), hx('c4b2ff'), hx('f4f0ff'))
DEW_OL, DEW_D, DEW_M, DEW_H = hx('16283e'), hx('4f8fc4'), hx('8ec9f0'), hx('e9f7ff')
SW_OL, SW_L, SW_M, GRIP = hx('1D1830'), hx('B5BAC4'), hx('8A8F9A'), hx('6B4A2A')


def sprite(name, rows, pal):
    h, w = len(rows), len(rows[0])
    img = new(w, h)
    for y, row in enumerate(rows):
        assert len(row) == w, (name, y, row, len(row))
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((x, y), pal[ch])
    save(img, name)
    return img


def icons16():
    # revision 2: the user's own hand-and-sparkles design at 16 art px, in its palette,
    # with the inventory bag's full ink outline
    sprite('ic_abilities', [
        "................",
        ".........a......",
        "........aWb.....",
        "...a.....d......",
        "..aWb........a..",
        "...d........aWb.",
        ".............d..",
        "................",
        ".......oo.......",
        "......ojwo.oo...",
        ".....okjjoojwo..",
        "..ooookjjojjko..",
        ".ommmkjjjjjjlo..",
        ".okkjjjjjjjlo...",
        ".ojjjjjjjloo....",
        ".ooooooooo......",
    ], {'o': SKIN_OL, 'j': SKIN_HI, 'k': SKIN, 'l': SKIN_SH, 'm': hx('d4815f'), 'w': hx('ffe5d0'),
        'a': hx('ffcf68'), 'W': hx('ffffff'), 'b': hx('ffbf36'), 'd': hx('ffa31f')})


def icons16_rev1():
    sprite('ic_character', [
        "................",
        "......oooo......",
        ".....owwllo.....",
        "....owllllmo....",
        "....oloooodo....",
        "....olmmmmdo....",
        ".....olmmdo.....",
        "......oddo......",
        "...oooommoooo...",
        "..owwllyyllmdo..",
        ".owllllyylllmdo.",
        ".ollllmmmmmmmdo.",
        ".olmmmmmmmmmddo.",
        ".ommmmmmmmmdddo.",
        ".oooooooooooooo.",
        "................",
    ], {'o': ARM_OL, 'w': ARM_W, 'l': ARM_L, 'm': ARM_M, 'd': ARM_D, 'y': GOLD_Y})

    sprite('ic_abilities', [
        "................",
        "......OOOO......",
        ".....OHHMMO.....",
        "....OHHMMMDO....",
        "....OHMMMMDO....",
        "....OMMMMDDO....",
        ".....OMMDDO.....",
        "......OOOO......",
        ".oo.........oo..",
        "osho.......osso.",
        "osssoo...oossso.",
        ".oshsssssssssso.",
        "..osssssssssdo..",
        "...oossssddoo...",
        ".....oooooo.....",
        "................",
    ], {'o': SKIN_OL, 'h': SKIN_HI, 's': SKIN, 'd': SKIN_SH,
        'O': M_OL, 'H': M_HI, 'M': M_PALE, 'D': M_MID})


def minis():
    sprite('mini_madra', [
        "....oo..",
        "...odco.",
        "..odfco.",
        ".odffcco",
        ".odfdceo",
        ".oddcceo",
        "..odeeo.",
        "...ooo..",
    ], {'o': hx('2e1c2c'), 'f': hx('b9bffb'), 'd': hx('849be4'), 'c': hx('2877c4'), 'e': hx('284ec4')})
    sprite('mini_dewdrop', [
        "...oo...",
        "..ohmo..",
        ".ohmmmo.",
        "ohmmmmdo",
        "ommmmmdo",
        "ommmmddo",
        ".oddddo.",
        "..oooo..",
    ], {'o': DEW_OL, 'h': DEW_H, 'm': DEW_M, 'd': DEW_D})
    sprite('mini_forage', [
        "....ooo.",
        "...ohhmo",
        "..ohhmmo",
        ".ohmmmdo",
        ".ommmddo",
        ".ommddo.",
        "osoooo..",
        "s.......",
    ], {'o': LEAF_OL, 'h': LEAF_H, 'm': LEAF_M, 'd': LEAF_D, 's': STEM})
    sprite('mini_fern', [
        "....oo..",
        "...ohmo.",
        ".oo.odo.",
        "ohmoso..",
        "omdos.oo",
        ".oos.ohm",
        "..s..omd",
        ".s....oo",
    ], {'o': JADE_OL, 'h': JADE_HI, 'm': JADE, 'd': JADE_SH, 's': JADE_SH})
    sprite('mini_well', [
        "...oo...",
        "..ohco..",
        "..ocvo..",
        "oooooooo",
        "olllmmdo",
        ".olmmdo.",
        ".olmmdo.",
        ".oooooo.",
    ], {'o': WELL_OL, 'h': CR_H, 'c': CR_M, 'v': CR_D, 'l': ST_L, 'm': ST_M, 'd': ST_D})
    sprite('mini_swords', [
        "oo....oo",
        "olo..olo",
        ".olooml.",
        "..olmo..",
        "..omlo..",
        ".oyooyo.",
        "obo..obo",
        "oo....oo",
    ], {'o': hx('3a453b'), 'l': hx('d8d1cf'), 'm': hx('aaaca4'), 'y': hx('ffcc45'), 'b': hx('734438')})
    sprite('mini_lock', [
        "..oooo..",
        ".osssso.",
        ".os..so.",
        "oooooooo",
        "ocbbbbso",
        "obbiibso",
        "obbiisso",
        "oooooooo",
    ], {'o': INK, 's': BRASS_SH, 'c': CREAM, 'b': BRASS, 'i': INK})


def shade_shape(img, pts, hi, mid, sh, ol, shadow=None):
    """Fill a set of points lit from the top-left, outline it, and cast a 1 px hard shadow."""
    w, h = img.size
    inside = lambda q: q in pts
    if shadow:
        for (X, Y) in pts:
            for dx, dy in ((1, 1), (2, 1), (1, 2), (2, 2)):
                q = (X + dx, Y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h and not inside(q):
                    img.putpixel(q, shadow)
    for (X, Y) in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (X + dx, Y + dy)
            if 0 <= q[0] < w and 0 <= q[1] < h and not inside(q):
                img.putpixel(q, ol)
    for (X, Y) in pts:
        if not inside((X, Y - 1)) or not inside((X - 1, Y)):
            c = hi
        elif not inside((X, Y + 1)) or not inside((X + 1, Y)):
            c = sh
        else:
            c = mid
        img.putpixel((X, Y), c)


def glyph_lock():
    w, h = 22, 26
    img = new(w, h)
    pts = set()
    # body: 16 x 11, corners knocked off
    for y in range(11, 22):
        for x in range(3, 19):
            if (x, y) in ((3, 11), (18, 11), (3, 21), (18, 21)):
                continue
            pts.add((x, y))
    # shackle: a closed U, 3 px thick
    cx, cy = 10.5, 8.0
    import math
    for y in range(1, 11):
        for x in range(4, 18):
            r = math.hypot(x - cx, (y - cy) * 1.0)
            if y <= cy and 3.4 <= r <= 6.4:
                pts.add((x, y))
            elif y > cy and (5 <= x <= 7 or 14 <= x <= 16):
                pts.add((x, y))
    shade_shape(img, pts, CREAM, BRASS, BRASS_SH, INK, shadow=INK)
    # the body's top edge is a separate plate: ink seam under the shackle's legs
    for x in range(4, 18):
        if (x, 11) in pts:
            put(img, x, 11, CREAM if x < 11 else BRASS)
    for x in range(4, 18):
        put(img, x, 12, BRASS_SH if x > 4 else CREAM)
    # keyhole
    for (x, y) in ((10, 14), (11, 14), (9, 15), (10, 15), (11, 15), (12, 15), (10, 16), (11, 16),
                   (10, 17), (11, 17), (10, 18), (11, 18)):
        put(img, x, y, INK)
    put(img, 12, 16, BRASS_SH)
    # two rivets
    for (x, y) in ((5, 19), (16, 19)):
        put(img, x, y, CREAM)
        put(img, x + 1, y + 1, BRASS_SH)
    save(img, 'glyph_lock')


def glyph_unknown():
    rows = [
        "..######..",
        ".########.",
        "###....###",
        "##......##",
        "........##",
        ".......###",
        "......###.",
        ".....###..",
        "....###...",
        "....##....",
        "....##....",
        "..........",
        "....##....",
        "....##....",
    ]
    w, h = 14, 18
    img = new(w, h)
    pts = {(x + 2, y + 2) for y, row in enumerate(rows) for x, ch in enumerate(row) if ch == '#'}
    shade_shape(img, pts, CREAM, TAN, TAN_SH, INK, shadow=INK)
    save(img, 'glyph_unknown')


def glyph_twinkle():
    """Revision 2: a 3-frame pixel twinkle by the ? glyph, in place of the glimmer sweep."""
    sheet = new(21, 7)
    f1 = {(3, 2): TAN, (2, 3): TAN, (3, 3): CREAM, (4, 3): TAN, (3, 4): TAN}
    f2 = {(3, 0): TAN, (3, 1): CREAM, (3, 2): CREAM, (0, 3): TAN, (1, 3): CREAM, (2, 3): CREAM,
          (3, 3): CREAM, (4, 3): CREAM, (5, 3): CREAM, (6, 3): TAN, (3, 4): CREAM, (3, 5): CREAM, (3, 6): TAN}
    for k, f in ((1, f1), (2, f2)):
        for (x, y), c in f.items():
            put(sheet, 7 * k + x, y, c)
    save(sheet, 'glyph_twinkle_strip')


def route_dots():
    for name, (c, sh) in (('route_dot', (TAN, TAN_SH)), ('route_dot_lit', (CREAM, BRASS))):
        img = new(4, 4)
        for (x, y) in ((1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)):
            put(img, x, y, INK)
        put(img, 1, 1, c)
        put(img, 2, 1, c)
        put(img, 1, 2, c)
        put(img, 2, 2, sh)
        save(img, name)


def chevron():
    """The 'Show me' arrow: Euljiro's U+203A has no outline, so it is drawn."""
    sprite('chev', [
        "oo...",
        "oco..",
        ".obo.",
        "..obo",
        ".obso",
        "osso.",
        "oo...",
    ], {'o': INK, 'c': CREAM, 'b': CREAM, 's': TAN})


def run():
    chevron()
    icons16()
    minis()
    glyph_lock()
    glyph_unknown()
    glyph_twinkle()
    route_dots()


if __name__ == '__main__':
    run()
