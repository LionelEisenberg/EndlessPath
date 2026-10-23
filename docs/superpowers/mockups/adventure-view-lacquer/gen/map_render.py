"""Adventure view mock: the map layer, pre-rendered per state and zoom (1920x1080, saved 1:1).

Grill round 2 (2026-10-22): the map runs at zoom 1, fixed, today's density, so a run's explored
area fits the columns layout's map window.
At zoom 1 the user's forest tiles show at 1x. Encounter markers are no longer drawn here: like
the zone map's MapMarkers, they live in a screen-space layer at the kit's 2x grid, so the mock
can swap marker styles. This writes their positions to adv_map_markers.js.

Drawn here: the user's forest tiles where the player has been, a veil (the kit's uncharted ramp
and dotted tan rim) over revealed tiles, the kit's fog tiers elsewhere (tier = hex distance to the
nearest tile you can see, capped at 3), the brass current-hex rim, the inner hover rim on a hovered
veiled hex, the zone map's route dots, and the user's character on the kit's shadow.

Hex maths: pointy-top, axial (q, r). One tile is 164x190 art px; columns 164 apart, rows 142.5.
"""
import json
import math

from adv_base import (Image, OUT, ZONE_KIT, ASSETS, GROUND, VEIL_LOCKED, VEIL_UNCHARTED, save_as, lum)

FOREST = ASSETS + 'sprites/tilemap/hex_tiles/forest/'
VARIANTS = ['00_Basic', '01_Town1', '02_Town2', '03_City1', '04_City2', '05_Farms', '06_River',
            '07_Mountains1', '08_Mountains2', '09_Clearing1', '10_Clearing2', '11_Lake1', '12_Lake2',
            '13_Castle1', '14_Castle2', '15_Ruin1', '16_Ruin2', '17_Tower', '18_Hole', '19_Dead',
            '20_Stones', '21_Ravine', '22_Cave']
GLYPHS = {
    'combat': ASSETS + 'sprites/ui/stat_icons/combat_icon.png',
    'elite': ASSETS + 'sprites/adventure/encounter_glyphs/elite.png',
    'rest': ASSETS + 'sprites/adventure/encounter_glyphs/rest-sheet.png',      # frame 0 of 5
    'boss': ASSETS + 'sprites/adventure/encounter_glyphs/boss_spritesheet.png',  # frame 0 of 7
}

# A Shallow Woods run (axial q, r) -> (encounter kind, forest variant). The boss is 5 from the start.
MAP = {
    (0, 0): ('start', 0),
    (-1, 0): ('none', 9),
    (-2, 0): ('combat', 12),     # Amorphous Spirit, cleared
    (-3, 1): ('elite', 8),       # Ravenous Dreadbeast
    (-2, -1): ('none', 10),
    (0, -1): ('combat', 7),      # Starving Dreadbeast, cleared
    (1, -1): ('none', 11),
    (0, 1): ('none', 5),
    (-1, 2): ('combat', 20),
    (-1, 3): ('rest', 1),        # Refugee Camp
    (1, -2): ('combat', 15),     # Amorphous Spirit, cleared
    (2, -2): ('none', 0),
    (1, -3): ('none', 21),
    (2, -3): ('rest', 6),        # Aura Well, cleared
    (3, -4): ('none', 9),
    (2, -4): ('combat', 16),     # Amorphous Spirit: the mock's encounter
    (3, -5): ('boss', 17),       # Manifested Spirit
    (1, -4): ('elite', 19),      # Coalescing Spirit
    (2, -5): ('none', 22),
}
BASE_VISITED = [(0, 0), (-1, 0), (-2, 0), (0, -1), (1, -2), (2, -3)]
BASE_CLEARED = [(-2, 0), (0, -1), (1, -2), (2, -3)]
STATES = {
    'walk': dict(visited=BASE_VISITED, current=(2, -3), cleared=BASE_CLEARED, hover=(2, -4)),
    'encounter': dict(visited=BASE_VISITED + [(2, -4)], current=(2, -4), cleared=BASE_CLEARED, hover=None),
}
CENTRE = (960, 470)   # the current hex's centre on screen
NEIGHBOURS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]


def dist(a, b):
    return (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[0] + a[1] - b[0] - b[1])) // 2


def load(path):
    return Image.open(path).convert('RGBA')


def halve(img):
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


def forest(i):
    return load(FOREST + 'Hex_Forest_%s.png' % VARIANTS[i])


def veil(tile):
    """The forest tile in the uncharted veil ramp, by brightness band (palette state, no alpha)."""
    out = tile.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            v = lum(p)
            k = 0 if v < 40 else 1 if v < 100 else 2 if v < 150 else 3 if v < 170 else 4
            px[x, y] = VEIL_UNCHARTED[k]
    return out


def spent(glyph):
    """A cleared encounter's glyph in the darker steps of the kit's locked (desaturated) veil."""
    out = glyph.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            v = lum(p)
            k = 0 if v < 60 else 1 if v < 140 else 2 if v < 200 else 3
            px[x, y] = VEIL_LOCKED[k]
    return out


def spent_light(glyph):
    """The same, in the veil's lighter steps: a cleared glyph inside a dark lacquer coin."""
    out = glyph.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            v = lum(p)
            k = 1 if v < 60 else 2 if v < 140 else 3 if v < 200 else 4
            px[x, y] = VEIL_LOCKED[k]
    return out


def fog_cell(tier, art):
    atlas = load(ASSETS + 'ui/lacquer/map/lacquer_fog_t%d_atlas_ai.png' % tier)
    return atlas.crop((art * 164, 0, art * 164 + 164, 190))


def fog_art(q, r):
    h = abs((q * 73856093) ^ (r * 19349663)) % 100
    return 0 if h < 60 else 1 + (h % 8)


def world_of(q, r, cq, cr, centre):
    """Tile centre in zoom-1 px, the current tile at `centre`."""
    dq, dr = q - cq, r - cr
    return centre[0] + 164 * (dq + dr / 2.0), centre[1] + 142.5 * dr


def rim_dots():
    """The dotted tan rim of the kit's uncharted tile, at map scale (the kit file is 2x)."""
    src = halve(load(ZONE_KIT + 'lacquer_tile_uncharted_ai.png'))
    out = Image.new('RGBA', src.size, (0, 0, 0, 0))
    s, d = src.load(), out.load()
    for y in range(out.height):
        for x in range(out.width):
            if s[x, y][:3] in ((0xA8, 0x90, 0x70), (0x7A, 0x65, 0x4C)):
                d[x, y] = s[x, y]
    return out


def route(a, b, cq, cr, centre):
    """The zone map's route: six dots 12 map px apart across the shared rim."""
    ax, ay = world_of(a[0], a[1], cq, cr, centre)
    bx, by = world_of(b[0], b[1], cq, cr, centre)
    length = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / length, (by - ay) / length
    return [(int(round(ax + ux * (length / 2 + 12 * (i - 2.5)) - 2)), int(round(ay + uy * (length / 2 + 12 * (i - 2.5)) - 2)))
            for i in range(6)]


def render(state_name, zoom):
    """Draw at zoom 1 on a canvas 1/zoom the screen's size, then scale it to 1920x1080 with nearest
    sampling, as a Camera2D zoom with nearest filtering does."""
    st = STATES[state_name]
    visited, current, cleared = set(st['visited']), st['current'], set(st['cleared'])
    revealed = {(v[0] + d[0], v[1] + d[1]) for v in visited for d in NEIGHBOURS}
    revealed = {c for c in revealed if c in MAP and c not in visited}
    seen = visited | revealed
    cq, cr = current
    W, H = int(round(1920 / zoom)), int(round(1080 / zoom))
    centre = (CENTRE[0] / zoom, CENTRE[1] / zoom)
    img = Image.new('RGBA', (W, H), GROUND)
    dots = rim_dots()

    cells = []
    for r in range(cr - 10, cr + 11):
        for q in range(cq - 14, cq + 15):
            x, y = world_of(q, r, cq, cr, centre)
            if -100 < x < W + 100 and -120 < y < H + 120:
                cells.append((r, q, int(math.floor(x + 0.5)), int(math.floor(y + 0.5))))
    for r, q, x, y in sorted(cells):
        tl = (x - 82, y - 95)
        c = (q, r)
        if c in visited:
            img.alpha_composite(forest(MAP[c][1]), tl)
        elif c in revealed:
            img.alpha_composite(veil(forest(MAP[c][1])), tl)
            img.alpha_composite(dots, tl)
        else:
            tier = min(3, min(dist(c, s) for s in seen))
            img.alpha_composite(fog_cell(tier, fog_art(q, r)), tl)

    x, y = (int(math.floor(v + 0.5)) for v in world_of(cq, cr, cq, cr, centre))
    img.alpha_composite(halve(load(ZONE_KIT + 'lacquer_hex_current_ai.png')), (x - 82, y - 95))
    if st['hover']:
        hx_, hy_ = (int(math.floor(v + 0.5)) for v in world_of(st['hover'][0], st['hover'][1], cq, cr, centre))
        img.alpha_composite(halve(load(ZONE_KIT + 'lacquer_hex_hover_in_ai.png')), (hx_ - 82, hy_ - 95))
        dot = halve(load(ZONE_KIT + 'lacquer_route_dot_lit_ai.png'))
        for p in route(current, st['hover'], cq, cr, centre):
            img.alpha_composite(dot, p)
    # The character keeps its 2x size at zoom 1 (32x48, like the markers) so it reads on a 1x tile.
    sheet = load(ASSETS + 'sprites/character/main_character_spritesheet.png')
    char = sheet.crop((64, 48, 80, 72)).resize((32, 48), Image.NEAREST)
    img.alpha_composite(load(ZONE_KIT + 'lacquer_char_shadow_ai.png'), (x - 14, y + 46))
    img.alpha_composite(char, (x - 16, y + 2))

    if zoom != 1:
        img = img.resize((1920, 1080), Image.NEAREST)
    tag = str(zoom).replace('.', '')
    save_as(img, 'adv_map_%s_z%s_ai.png' % (state_name, tag), s=1)

    markers = []
    for c in sorted(seen):
        kind = MAP[c][0]
        mx, my = world_of(c[0], c[1], cq, cr, centre)
        sx, sy = even(mx * zoom), even(my * zoom)
        if c in visited:
            if kind not in GLYPHS:
                continue
            state = 'current' if c == current and c not in cleared else ('cleared' if c in cleared else 'known')
            if c == current and c in cleared:
                state = 'cleared_here'
        elif kind == 'boss':
            state = 'boss'
        else:
            state = 'unknown'
        markers.append(dict(x=sx, y=sy, kind=kind if state != 'unknown' else 'unknown', state=state))
    hover = None
    if st['hover']:
        hx_, hy_ = world_of(st['hover'][0], st['hover'][1], cq, cr, centre)
        hover = dict(x=even(hx_ * zoom), y=even(hy_ * zoom))
    return dict(markers=markers, hover=hover, tile_w=even(164 * zoom), tile_h=even(190 * zoom))


def even(v):
    return int(round(v / 2.0)) * 2


def spent_glyphs():
    for kind, path in GLYPHS.items():
        g = load(path)
        if g.width > 64:
            g = g.crop((0, 0, 64, 64))
        save_as(spent_light(g), 'adv_glyph_%s_spent_light_ai.png' % kind, s=1)   # inside a cleared coin


def run():
    data = {}
    for state in STATES:
        data['%s_z1' % state] = render(state, 1)
    with open(OUT + 'adv_map_markers.js', 'w', encoding='utf-8') as f:
        f.write('// Written by gen/map_render.py: screen positions of the map markers per state and zoom.\n')
        f.write('window.ADV_MAP = ' + json.dumps(data, indent=1) + ';\n')
    spent_glyphs()


if __name__ == '__main__':
    run()
    print('ok')
