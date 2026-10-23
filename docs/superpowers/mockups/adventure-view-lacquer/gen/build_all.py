"""Builds every texture the adventure view mock uses (python build_all.py, from this folder).

kit_adventure: the UI pieces. map_render: the map layers per state and zoom. stage: the combat
stage and the placeholder fighters. The zone kit's own textures are not copied: the mock loads
them from ../zone-view-lacquer/, and the user's art from ../../../assets/.
"""
import adv_base as AB
import kit_adventure
import map_render
import stage

if __name__ == '__main__':
    kit_adventure.run()
    map_render.run()
    stage.run()
    print(len(AB.B.SAVED), 'textures in', AB.OUT)
