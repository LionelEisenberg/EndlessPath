"""Shared setup for the adventure view mock's generators.

Imports the zone kit's primitives (docs/superpowers/mockups/zone-view-lacquer/gen/) and points
their save() at this folder, so every new piece is drawn with the same rims, grain and palette.
Same rules as the zone kit: drawn at native size, saved at 2x nearest, lit from the top-left,
hand-placed detail, no randomness. Every file ends in _ai.

The vitals ramps below (health, stamina) are a PROPOSAL for style guide question G2; they are
not in the kit's palette yet.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOCKS = os.path.dirname(os.path.dirname(HERE))          # docs/superpowers/mockups/
REPO = os.path.dirname(os.path.dirname(os.path.dirname(MOCKS)))
ZONE_GEN = os.path.join(MOCKS, 'zone-view-lacquer', 'gen')
ZONE_KIT = os.path.join(MOCKS, 'zone-view-lacquer') + '/'
OUT = os.path.join(MOCKS, 'adventure-view-lacquer') + '/'
ASSETS = os.path.join(REPO, 'assets') + '/'

sys.path.insert(0, ZONE_GEN)
import lq_base as B  # noqa: E402
import kit_ui as K   # noqa: E402

B.OUT = OUT          # lq_base.save() writes lacquer_<name>_ai.png here
B.TILES = ASSETS + 'sprites/tilemap/hex_tiles/forest/'   # the user's forest tiles the zone kit's helpers read (kit_map.mask()): this repo's, not the zone kit's authoring session's

from lq_base import (CLEAR, INK, DEEP, LAC, GRAIN, GRAIN2, RAISED, RIM_S, RIM, BRASS,  # noqa: E402,F401
                     BRASS_SH, CREAM, TAN, JADE_HI, JADE, JADE_SH, JADE_OL, M_HI, M_PALE, M_MID,
                     M_DEEP, M_OL, VERM, VERM_D, hx, new, put, rect, save, side_of, streak, gloss,
                     lit_mask, dome, strap, cabinet, socket, tray, brass_plate, tablet, seal,
                     carved_line)
from kit_ui import SOCKET, caps, board_base, recess, pressed, rod_pair, drawer_face  # noqa: E402,F401
from PIL import Image  # noqa: E402

TAN_SH = hx('7A654C')
DIM = hx('94806A')
SHADOW = hx('050707')
GROUND = hx('090E0E')

# Proposed vitals ramps (G2). Hi, pale (text), mid, deep, outline: the same five roles as the
# Madra ramp, so an orb or rod recolours one for one.
H_HI, H_PALE, H_MID, H_DEEP, H_OL = hx('FFD9D2'), hx('E8737A'), hx('B8304A'), hx('5A1626'), hx('3A0E18')
S_HI, S_PALE, S_MID, S_DEEP, S_OL = hx('EEF5C8'), hx('C9DB86'), hx('8FAE3E'), hx('3E5418'), hx('1E2A0C')
MADRA_RAMP = (M_HI, M_PALE, M_MID, M_DEEP, M_OL)
HEALTH_RAMP = (H_HI, H_PALE, H_MID, H_DEEP, H_OL)
STAMINA_RAMP = (S_HI, S_PALE, S_MID, S_DEEP, S_OL)

# Locked veil, the kit's desaturated ramp: the "spent" palette for cleared glyphs.
VEIL_LOCKED = (hx('151A18'), hx('39423E'), hx('4B5550'), hx('5F6A65'), hx('76827C'))
# Uncharted veil, dark to light: the veil over a revealed tile whose content is unknown.
VEIL_UNCHARTED = (hx('0B1211'), hx('16211F'), hx('1C2927'), hx('243431'), hx('2D3F3B'))
FOG_T1 = (hx('0C1312'), hx('111A19'), hx('16211F'), hx('1D2B28'))   # line, shade, base, light
FOG_T2 = (hx('182423'), hx('0F1716'), hx('111A19'), hx('131D1C'))
FOG_T3 = hx('0D1514')


def save_as(img, filename, s=2):
    """Save outside the lacquer_ prefix (stage, sprites, map layers), still _ai, at s x nearest."""
    assert filename.endswith('_ai.png'), filename
    if s != 1:
        img = img.resize((img.width * s, img.height * s), Image.NEAREST)
    img.save(OUT + filename)
    B.SAVED.append(filename)


def recolour(img, mapping):
    """Swap exact RGBA colours (palette state, never a tint)."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p in mapping:
                px[x, y] = mapping[p]
    return out


def rows(img, x0, y0, art, legend):
    """Draw pixel rows: one character per pixel, '.' or ' ' is clear (aseprite draw_rows style)."""
    for j, line in enumerate(art):
        for i, ch in enumerate(line):
            if ch in '. ':
                continue
            put(img, x0 + i, y0 + j, legend[ch])


def lum(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
