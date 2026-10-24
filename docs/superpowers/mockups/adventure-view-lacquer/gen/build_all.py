"""Builds every texture the adventure view mock uses (python build_all.py, from this folder).

kit_adventure: the UI pieces. map_render: the map layers per state and zoom, and the spent glyphs.
veil_atlas: the user's forest atlas in the uncharted veil. hex_rim: the heavier rim of the player's
hex, for the adventure map only. stage: the combat stage and the placeholder fighters. The zone
kit's own textures are not copied: the mock loads them from ../zone-view-lacquer/, and the user's
art from ../../../assets/.

Then import_adventure_kit.py bakes the shadows and copies what the game uses into assets/.
"""
import adv_base as AB
import hex_rim
import kit_adventure
import map_render
import stage
import veil_atlas

if __name__ == '__main__':
    kit_adventure.run()
    map_render.run()
    veil_atlas.run()
    hex_rim.run()
    stage.run()
    print(len(AB.B.SAVED), 'textures in', AB.OUT)
