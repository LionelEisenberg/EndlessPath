"""Builds the whole Lacquer and brass kit into lacquer_full/assets/.

1. Clears assets/, 2. copies the user's own files byte for byte (names kept) and the mock's
placeholder icons (agent-made, so renamed *_ai.png), 3. runs the three generators.
Run from this folder: python build_all.py
"""
import hashlib
import os
import shutil

import lq_base as B

USER_FILES = {
    'Hex_Forest_06_River.png': 'assets/sprites/tilemap/hex_tiles/forest/Hex_Forest_06_River.png',
    'Hex_Forest_00_Basic.png': 'assets/sprites/tilemap/hex_tiles/forest/Hex_Forest_00_Basic.png',
    'main_character_spritesheet.png': 'assets/sprites/character/main_character_spritesheet.png',
    'inventory_icon.png': 'assets/sprites/ui/system_menu/inventory_icon.png',
    # revision 2: the user's own 16-art-px icons (64 px files, shown at 32 px) replace the
    # kit's coin, star, swords and character redraws
    'character_icon.png': 'assets/sprites/ui/system_menu/character_icon.png',
    'star_icon.png': 'assets/sprites/ui/system_menu/star_icon.png',
    'gold_icon.png': 'assets/sprites/ui/resources/gold_icon.png',
    'combat_icon.png': 'assets/sprites/ui/stat_icons/combat_icon.png',
    'BMEULJIROTTF.ttf': 'assets/fonts/BMEULJIROTTF.ttf',
    'YatraOne-Regular.ttf': 'assets/fonts/YatraOne-Regular.ttf',
}
PLACEHOLDERS = ['cycle', 'forage', 'well', 'merchant', 'story', 'dewdrop', 'fern']


def sha(p):
    with open(p, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    os.makedirs(B.OUT, exist_ok=True)
    for f in os.listdir(B.OUT):
        os.remove(B.OUT + f)
    for name, rel in USER_FILES.items():
        shutil.copyfile(B.REPO + rel, B.OUT + name)
        assert sha(B.REPO + rel) == sha(B.OUT + name)
    for n in PLACEHOLDERS:
        shutil.copyfile(B.SCRATCH + 'swatches/assets/ic_%s.png' % n, B.OUT + 'ic_%s_ai.png' % n)
    import kit_ui
    import kit_icons
    import kit_map
    kit_ui.run()
    kit_icons.run()
    kit_map.run()
    files = sorted(os.listdir(B.OUT))
    print(len(files), 'files in assets/')


if __name__ == '__main__':
    main()
