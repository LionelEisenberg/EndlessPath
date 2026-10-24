"""Adventure view: the user's forest atlas in the uncharted veil (the map's revealed, unvisited tiles).

hex_forest_atlas.png is a grid of 164x190 tiles in HexForestAtlas order. This writes
hex_forest_veil_atlas_ai.png: the same size, with every visible pixel mapped onto the uncharted
veil's ramp by map_render.veil(), and the dotted tan rim of the kit's uncharted tile
(map_render.rim_dots()) laid over each tile. Every tile keeps its cell, so one HexForestAtlas.pick()
coord reads either atlas. The user's atlas is only read.

import_adventure_kit.py copies the result next to the user's atlas.
"""
from adv_base import Image, ASSETS, save_as
from map_render import veil, rim_dots

FOREST_ATLAS = ASSETS + 'sprites/tilemap/hex_tiles/forest/hex_forest_atlas.png'


def veil_atlas() -> Image.Image:
    """The forest atlas in the veil ramp, the rim dots over each cell that holds a tile."""
    atlas = Image.open(FOREST_ATLAS).convert('RGBA')
    dots = rim_dots()
    cell_w, cell_h = dots.size                      # one tile: 164x190
    assert atlas.width % cell_w == 0 and atlas.height % cell_h == 0, atlas.size
    out = veil(atlas)
    for y in range(0, atlas.height, cell_h):
        for x in range(0, atlas.width, cell_w):
            cell = atlas.crop((x, y, x + cell_w, y + cell_h))
            if cell.getchannel('A').getbbox():      # the atlas' unused cell stays empty
                out.alpha_composite(dots, (x, y))
    return out


def run() -> None:
    """Write the veil atlas to the mock folder, 1:1 (the import step copies it on)."""
    save_as(veil_atlas(), 'hex_forest_veil_atlas_ai.png', s=1)


if __name__ == '__main__':
    run()
    print('ok')
