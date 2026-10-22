"""Map geometry for the 1920x1080 zone view at map zoom 2 (tiles 164x190 shown 328x380).

Pointy-top, odd-r offset coordinates (odd rows, negative ones included, shift half a hex
right), Spirit Valley at (0, 0) centred on screen (960, 702). Column step 328, row step 285.
"""
CX, CY = 960, 702
COL, ROW, HALF = 328, 285, 164
TILE_W, TILE_H = 328, 380

ZONES = {
    'valley': (0, 0),        # Spirit Valley, current zone (Hex_Forest_06_River)
    'test': (-1, 0),         # Test Zone, open-zone demo (Hex_Forest_00_Basic)
    'advancement': (0, -1),  # Advancement Zone, locked demo (Hex_Forest_20_Stones)
    'uncharted': (0, -2),    # Uncharted, locked demo (Hex_Forest_08_Mountains2)
}

# fog art, placed by hand on the cells that show in the open map; every other cell is Basic
FOG_ART = {
    (-1, -2): '21_Ravine', (0, -2): '11_Lake1', (1, -2): '07_Mountains1',
    (-2, -1): '12_Lake2', (1, -1): '19_Dead',
    (-1, 0): '11_Lake1', (1, 0): '21_Ravine', (2, 0): '09_Clearing1',
    (-2, 1): '22_Cave', (0, 1): '12_Lake2', (-1, -3): '09_Clearing1', (1, -3): '18_Hole',
}
POOL = ['00_Basic', '07_Mountains1', '09_Clearing1', '11_Lake1', '12_Lake2', '18_Hole', '19_Dead',
        '21_Ravine', '22_Cave']
TILE_FILE = {k: 'Hex_Forest_%s.png' % k for k in POOL}
TILE_FILE.update({'06_River': 'Hex_Forest_06_River.png', '20_Stones': 'Hex_Forest_20_Stones.png',
                  '08_Mountains2': 'Hex_Forest_08_Mountains2.png'})


def odd(row):
    return row % 2 != 0


def centre(col, row):
    return (CX + COL * col + (HALF if odd(row) else 0), CY + ROW * row)


def tile_tl(col, row):
    x, y = centre(col, row)
    return (x - TILE_W // 2, y - TILE_H // 2)


def hex_distance(a, b):
    ax = a[0] - (a[1] - (a[1] & 1)) // 2
    bx = b[0] - (b[1] - (b[1] & 1)) // 2
    dx = ax - bx
    dz = a[1] - b[1]
    return max(abs(dx), abs(dz), abs(dx + dz))


def screen_cells():
    """Every lattice cell whose 328x380 tile touches the 1920x1080 screen."""
    cells = []
    for row in range(-4, 3):
        for col in range(-5, 5):
            x, y = tile_tl(col, row)
            if x < 1920 and x + TILE_W > 0 and y < 1080 and y + TILE_H > 0:
                cells.append((col, row))
    return cells


STATES = {
    # name: (open-zone demo, locked & uncharted demo)
    'base': (False, False),
    'open': (True, False),
    'locked': (False, True),
    'both': (True, True),
}


def state_zones(state):
    demo, locked = STATES[state]
    zones = ['valley'] + (['test'] if demo else []) + (['advancement', 'uncharted'] if locked else [])
    # charted = zones you know the shape of: the current/open zones and a locked one.
    # The uncharted hex is a zone tile (not fog) but does not chart the fog around it.
    charted = [ZONES[z] for z in zones if z != 'uncharted']
    return zones, charted


def fog_cells(state):
    zones, charted = state_zones(state)
    taken = {ZONES[z] for z in zones}
    out = []
    for c in screen_cells():
        if c in taken:
            continue
        tier = min(3, min(hex_distance(c, z) for z in charted))
        out.append((c, tier, FOG_ART.get(c, '00_Basic')))
    return out


if __name__ == '__main__':
    print(len(screen_cells()), 'cells')
    for st in STATES:
        f = fog_cells(st)
        print(st, len(f), sorted(f, key=lambda t: (t[0][1], t[0][0])))
    # the mock's hand-placed tiers for the locked demo, to compare with the rule above
    mock = {(-1, -3): 2, (0, -3): 2, (1, -3): 2, (-1, -2): 2, (1, -2): 1, (2, -2): 2, (-2, -1): 2,
            (-1, -1): 1, (1, -1): 1, (2, -1): 2, (-2, 0): 2, (-1, 0): 1, (1, 0): 1, (2, 0): 2,
            (-2, 1): 2, (-1, 1): 1, (0, 1): 1, (1, 1): 2, (-1, 2): 2, (0, 2): 2, (1, 2): 2}
    rule = {c: t for c, t, _ in fog_cells('locked')}
    diff = {c: (mock[c], rule.get(c)) for c in mock if mock[c] != rule.get(c)}
    print('mock vs rule (locked):', diff)
