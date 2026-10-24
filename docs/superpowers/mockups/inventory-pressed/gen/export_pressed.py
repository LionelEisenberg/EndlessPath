"""Writes the pressed page pieces the inventory book preloads, as agent-drawn art (every file ends in _ai).

    python -I docs/superpowers/mockups/inventory-pressed/gen/export_pressed.py

Each piece is drawn at art resolution (1 art px = 2 screen px) and saved scaled 2x with nearest
neighbour, so a 72 x 72 texture is a 36 x 36 drawing. The three placeholder item icons are 16 art px
drawings saved 4x, so they come out 64 x 64.

The drawing code is copied from the mockup generators with the final round's softer pieces and
palette baked in. Those scripts import each other through the authoring session's scratch folder,
so this file does not import them:

    rounded, soft_well, soft_rule, soft_tag         gen_r6.py
    ornament_rule, corner_marks, cultivator_mask    gen_r2.py
    relief                                          gen_r3.py
    seal, tick_box                                  gen_r5.py
    dotted_line                                     gen_r1.py
    the gear leaders and the discard cross          gen_r7.py, equipment()
    the placeholder map icon                        icons_ai.py

Two things differ from the copies, both for the panel (see PANEL_RADIUS and panel_piece): soft_well
takes an optional radius, and the panel's 9-slice source steadies two pixels.
"""
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[5]
PRESSED_DIR = REPO / 'assets/sprites/ui/book/pressed'
MATERIALS_DIR = REPO / 'assets/sprites/items/materials'
QUEST_ITEMS_DIR = REPO / 'assets/sprites/items/quest_items'
LACQUER_ICONS_DIR = REPO / 'assets/ui/lacquer/icons'


# ----------------------------------------------------------------------------
# palette (spec: Palette)
# ----------------------------------------------------------------------------
def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PAPER = rgb('F7E6CA')
INK = rgb('3B2A20')
INK_M = rgb('7D5F47')         # muted ink on the paper: the title ornament, the leader lines
INK_M_PANEL = rgb('765A43')   # muted ink inside a slot or panel: the scroll thumb, the discard cross
VERM = rgb('A83C30')
VERM_D = rgb('7E2A22')
FLOOR = rgb('E7CFA6')         # inside a slot that holds something
EMPTY = rgb('EFDCBB')         # inside an empty slot and inside a panel
SH1 = rgb('B9996F')           # wall shadow, first step
SH2 = rgb('D3B98F')           # wall shadow, second step
HI = rgb('FBF1DE')            # lit edge


# ----------------------------------------------------------------------------
# primitives
# ----------------------------------------------------------------------------
def canvas(w, h):
    """A transparent art canvas of w x h art px."""
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def dotted_line(img, a, b, c, every=2):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(0, n + 1, every):
        put(img, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


# ----------------------------------------------------------------------------
# pressed and raised pieces (gen_r6)
# ----------------------------------------------------------------------------
def rounded(w, h, r):
    cut = {1: [(0, 0)], 2: [(0, 0), (1, 0), (0, 1)], 3: [(0, 0), (1, 0), (2, 0), (0, 1), (0, 2)]}[r]
    out = set()
    for (x, y) in cut:
        out |= {(x, y), (w - 1 - x, y), (x, h - 1 - y), (w - 1 - x, h - 1 - y)}
    return {(x, y) for y in range(h) for x in range(w)} - out


def soft_well(art, x0, y0, w, h, depth=2, floor=FLOOR, radius=None):
    """A well pressed into the paper. Without a radius the corners follow the well's size, as in the mockup."""
    r = radius or (3 if min(w, h) >= 60 else 2 if min(w, h) >= 20 else 1)
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


# ----------------------------------------------------------------------------
# printed pieces (gen_r2, gen_r5)
# ----------------------------------------------------------------------------
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
    soft_well(art, x0, y0, 11, 11, depth=1, floor=EMPTY)
    if ticked:
        for (x, y) in ((2, 5), (3, 6), (4, 7), (5, 6), (6, 5), (7, 4), (8, 3), (3, 5), (4, 6)):
            put(art, x0 + x, y0 + y, INK)


# ----------------------------------------------------------------------------
# the robed cultivator relief (gen_r2, gen_r3)
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


# ----------------------------------------------------------------------------
# the placeholder map icon (icons_ai)
# ----------------------------------------------------------------------------
MAP_PALETTE = {'k': rgb('2B1D14'), 'M': rgb('EED9A8'), 'm': rgb('C9A86A'), 'R': rgb('B83A2E'), 'g': rgb('5E8F4E')}
MAP_ROWS = [
    '................',
    '.kkkkkkkkkkkkkk.',
    'kMMMMMMMMMMMMMMk',
    'kMmMMMMMMMMMMmMk',
    'kMMRMMMMMMMMMMMk',
    'kMMMRMMMMgMMMMMk',
    'kMMMMRMMgggMMMMk',
    'kMMMMMRMMgMMMMMk',
    'kMMMMMMRMMMMMMMk',
    'kMMMMMMMRMMRMRMk',
    'kMMMMMMMMRMMRMMk',
    'kMMMMMMMMMMRMRMk',
    'kMmMMMMMMMMMMmMk',
    '.kkkkkkkkkkkkkk.',
    '................',
    '................',
]


# ----------------------------------------------------------------------------
# the pieces
# ----------------------------------------------------------------------------
# A panel is a 9-slice source here (16 x 16 art px), but in the mockup it is 100+ art px wide, where
# soft_well rounds its corners by 3 (6 screen px, spec: Pieces). Drawn at 16 px it would get 1 (a 2 px
# cut), so the panel names its radius.
PANEL_RADIUS = 3
SLOT_SIZE = 36                # art px, a 72 px slot
CROSS_SIZE = 14               # art px, 28 px: holds gen_r7's 13 px cross when centred on a slot
# The gear column's slots, as gen_r7.SLOTS: screen px, the top left of each 72 x 72 slot.
GEAR_SLOTS = [(1016, 300), (1016, 398), (1016, 496), (1400, 300), (1400, 398), (1400, 496)]
# The gear plate's rectangle on the mockup's 960 x 540 art canvas: screen (1008, 300), 468 x 268.
GEAR_PLATE_RECT = (504, 150, 234, 134)


def well_piece(w, h, depth, floor, radius=None):
    art = canvas(w, h)
    soft_well(art, 0, 0, w, h, depth=depth, floor=floor, radius=radius)
    return art


def panel_piece():
    """The panel's 9-slice source: 4 art px corners round an 8 x 8 stretch.

    With rounded corners soft_well also shades the pixel two beyond a cut corner on the right wall (row 4)
    and on the bottom wall (column 4). At 4 px margins that pixel is the first one stretched, so it would
    repeat along the whole wall. Here it takes its neighbour's value instead, which is the only way a
    stretched panel differs from the mockup's.
    """
    art = well_piece(16, 16, depth=2, floor=EMPTY, radius=PANEL_RADIUS)
    art.putpixel((15, 4), art.getpixel((15, 5)))
    art.putpixel((4, 15), art.getpixel((5, 15)))
    return art


def rule_piece():
    art = canvas(4, 2)
    soft_rule(art, 0, 3, 0)
    return art


def thumb_piece():
    return Image.new('RGBA', (2, 4), INK_M_PANEL)


def ornament_piece():
    art = canvas(136, 7)
    ornament_rule(art, 0, 135, 3)
    return art


def marks_piece():
    art = canvas(16, 16)
    corner_marks(art, 0, 0, 15, 15, VERM)
    return art


def tag_piece():
    art = canvas(6, 10)
    soft_tag(art, 0, 0, 6, 10)
    return art


def seal_piece():
    art = canvas(33, 13)
    seal(art, 0, 0, 33, 13)
    return art


def tick_box_piece(ticked):
    art = canvas(11, 11)
    tick_box(art, 0, 0, ticked)
    return art


def cross_piece():
    """The discard cross, as gen_r7.equipment() draws it on its 36 px slot: offsets 12 to 24, 13 px long.

    The texture is a CROSS_SIZE square that the game centres on the slot, so gen_r7's offsets move by
    the texture's own offset inside the slot. The crossing keeps its single pixel.
    """
    art = canvas(CROSS_SIZE, CROSS_SIZE)
    shift = (SLOT_SIZE - CROSS_SIZE) // 2
    for i in range(12, 25):
        put(art, i - shift, i - shift, INK_M_PANEL)
        put(art, SLOT_SIZE - i - shift, i - shift, INK_M_PANEL)
    return art


def gear_plate_piece():
    """The cultivator relief and the six dotted leaders, as gen_r7.equipment() draws them.

    Drawn on the mockup's own 960 x 540 canvas and cut out at the plate's rectangle, so each pixel sits
    where the mockup has it. The slot wells are not in it: the game draws those as nodes.
    """
    art = canvas(960, 540)
    pts, creases, w, h = cultivator_mask()
    ox, oy = 622 - w // 2, 150
    relief(art, pts, creases, ox, oy)
    targets = [(ox + 33, oy + 12), (ox + 10, oy + 62), (ox + 28, oy + 51),
               (ox + 42, oy + 38), (ox + 60, oy + 62), (ox + 44, oy + 51)]
    for (x, y), t in zip(GEAR_SLOTS, targets):
        start = (x // 2 + 39, y // 2 + 18) if x < 1200 else (x // 2 - 3, y // 2 + 18)
        dotted_line(art, start, t, INK_M, every=3)
    px, py, pw, ph = GEAR_PLATE_RECT
    left, top, right, bottom = art.getbbox()
    if left < px or top < py or right > px + pw or bottom > py + ph:
        raise ValueError(f'the gear plate would lose pixels: drawn {art.getbbox()}, plate {GEAR_PLATE_RECT}')
    return art.crop((px, py, px + pw, py + ph))


def map_icon_piece():
    art = canvas(16, 16)
    for y, row in enumerate(MAP_ROWS):
        for x, ch in enumerate(row):
            if ch != '.':
                art.putpixel((x, y), MAP_PALETTE[ch])
    return art


def lacquer_icon_piece(name):
    return Image.open(LACQUER_ICONS_DIR / f'ic_{name}_ai.png').convert('RGBA')


# ----------------------------------------------------------------------------
# output
# ----------------------------------------------------------------------------
def save(art, path, scale):
    """Saves the art px drawing scaled up with nearest neighbour, and prints where it went."""
    path.parent.mkdir(parents=True, exist_ok=True)
    art.resize((art.width * scale, art.height * scale), Image.NEAREST).save(path)
    print(path.relative_to(REPO).as_posix())


def main():
    pressed = [
        ('pressed_slot_deep_ai.png', well_piece(36, 36, depth=2, floor=FLOOR)),
        ('pressed_slot_shallow_ai.png', well_piece(36, 36, depth=1, floor=EMPTY)),
        ('pressed_page_deep_ai.png', well_piece(14, 14, depth=2, floor=FLOOR)),
        ('pressed_page_shallow_ai.png', well_piece(14, 14, depth=1, floor=EMPTY)),
        ('pressed_panel_ai.png', panel_piece()),
        ('pressed_lozenge_ai.png', well_piece(12, 13, depth=2, floor=FLOOR)),
        ('pressed_rule_ai.png', rule_piece()),
        ('pressed_groove_ai.png', well_piece(5, 12, depth=1, floor=EMPTY)),
        ('pressed_thumb_ai.png', thumb_piece()),
        ('title_ornament_ai.png', ornament_piece()),
        ('printer_marks_ai.png', marks_piece()),
        ('paper_tag_ai.png', tag_piece()),
        ('seal_ai.png', seal_piece()),
        ('tick_box_ai.png', tick_box_piece(False)),
        ('tick_box_ticked_ai.png', tick_box_piece(True)),
        ('printed_cross_ai.png', cross_piece()),
        ('gear_plate_ai.png', gear_plate_piece()),
    ]
    for name, art in pressed:
        save(art, PRESSED_DIR / name, 2)
    save(lacquer_icon_piece('fern'), MATERIALS_DIR / 'spirit_fern_ai.png', 4)
    save(lacquer_icon_piece('dewdrop'), MATERIALS_DIR / 'dewdrop_tear_ai.png', 4)
    save(map_icon_piece(), QUEST_ITEMS_DIR / 'refugee_camp_map_ai.png', 4)


if __name__ == '__main__':
    main()
