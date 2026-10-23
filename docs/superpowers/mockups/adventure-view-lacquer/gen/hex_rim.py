"""Adventure view: the player's hex wears a heavier brass rim (the adventure map only).

The zone kit's current rim (kit_map.rims(), lacquer_hex_current_ai.png) is four rings around the
hex: cream and brass, brass, ink, and a lacquer collar. At the adventure map's zoom 1 that is 2 px of
brass, and the developer asked for the player's hex to be a pixel or two heavier. This rim has two
more px of brass: six rings, rings 1 to 4 brass by the zone rim's light side and shadow side rule
(ring 1 with the cream highlight, as the zone rim's), ring 5 ink, ring 6 the lacquer collar.

Six rings do not fit outside the hex. A tile leaves a 4 px margin around its hex (the hex spans
x 4-159 and y 4-184 of 164x190), so the ink and the collar would be cut off along the flat sides and
at the corners, and a larger file would change the rim's size and push it into the neighbouring
hex's grout. The brass takes the two px just inside the hex's edge instead (the tile's outermost
two px, plain ground, never art), and the ink and the collar stay exactly where the zone rim's are.
Counted from the inside: rings 1 and 2 lie in the hex, rings 3 and 4 are the zone rim's two brass
rings, rings 5 and 6 its ink and its collar. The file stays the tile's 164x190 and the rim never
reaches past where the zone rim does.

Reuses the zone kit's helpers (kit_map.mask(), ring_dist() and light_of(), and its colours); nothing
is copied. Drawn at native size and written at 2x to the mock folder like every kit piece;
import_adventure_kit.py halves it into assets/ui/lacquer/map/ (map space, 164x190), where the
adventure's CurrentRim shows it. The zone map keeps lacquer_hex_current_ai.png.
"""
import adv_base as AB   # puts the zone kit's gen/ folder on sys.path, and points its save() and its tile path at this repo
import kit_map as KM    # the zone kit's map pieces: mask(), ring_dist(), light_of()
from adv_base import CREAM, BRASS, BRASS_SH, INK, RIM, LAC, new, put, save

W, H = 164, 190   # one tile, in map space
INSIDE = 2        # rings of brass inside the hex's edge
OUTSIDE = 4       # the zone rim's rings outside it: two of brass, the ink, the collar
KIT_NAME = 'hex_current_heavy'   # written as lacquer_hex_current_heavy_ai.png


def ring_colour(ring, light):
    """The colour of ring 1 (the innermost) to 6 (the collar) at a pixel `light` lit (kit_map.light_of())."""
    if ring == 1:       # the highlight ring, as the zone rim's first
        return CREAM if light > 0.35 else (BRASS if light > -0.35 else BRASS_SH)
    if ring <= 4:       # brass: the zone rim's second ring's rule
        return BRASS if light > 0.35 else BRASS_SH
    if ring == 5:
        return INK
    return RIM if light > 0.35 else LAC   # the lacquer collar on the grout


def heavy_current_rim():
    """The six rings at native size: two inside the hex's edge, the zone rim's four outside it."""
    hexagon = KM.mask()
    outside = {(x, y) for y in range(H) for x in range(W) if (x, y) not in hexagon}
    distance_out = KM.ring_dist(hexagon, W, H, OUTSIDE)    # 1-4 from the hex's edge, outside it
    distance_in = KM.ring_dist(outside, W, H, INSIDE)      # 1-2 from the hex's edge, inside it
    rim = new(W, H)
    for y in range(H):
        for x in range(W):
            if (x, y) in hexagon:
                ring = INSIDE + 1 - distance_in[(x, y)] if (x, y) in distance_in else 0
            else:
                ring = INSIDE + distance_out[(x, y)] if (x, y) in distance_out else 0
            if ring:
                put(rim, x, y, ring_colour(ring, KM.light_of(x, y)))
    return rim


def run():
    """Write lacquer_hex_current_heavy_ai.png (2x) to the mock folder."""
    save(heavy_current_rim(), KIT_NAME)


if __name__ == '__main__':
    run()
    print('ok')
