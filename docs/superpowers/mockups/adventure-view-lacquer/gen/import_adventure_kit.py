"""Copy the adventure view's PR 1 textures from the mock into the Godot project.

Run build_all.py first, then this one (python import_adventure_kit.py).

Screen-space pieces (drawn at 2x, shown at file size) go to assets/ui/lacquer/. The boards, the
slot and the keycap get their hard drop shadow baked in by the zone kit's bake_shadow() (kit rule 3:
4 px #050707 on the tech dock and the plain board, 2 px #150909 on the slot and keycap), so their
files are 2 or 4 px larger than the kit rect. The marker tokens strip is shadowed one coin at a
time, so each 52x52 coin becomes its own 54x54 frame. Recessed or inset pieces (trays, timers,
sockets, minis, rods) cast no shadow and are copied as drawn. The health orb is frame 0 of the
mock's health strip. The spent glyphs and the veil atlas go next to the user's art they come from.

Stops with an error, before it writes anything, when a source is missing from the mock folder.
"""
import shutil
import tempfile
from pathlib import Path

from PIL import Image

import adv_base as AB   # puts the zone kit's gen/ folder on sys.path, where import_kit lives
from import_kit import SHADOW_BIG, SHADOW_SMALL, bake_shadow

MOCK = Path(AB.OUT)
UI = Path(AB.ASSETS) / 'ui' / 'lacquer'
GLYPHS = Path(AB.ASSETS) / 'sprites' / 'adventure' / 'encounter_glyphs'
FOREST = Path(AB.ASSETS) / 'sprites' / 'tilemap' / 'hex_tiles' / 'forest'

# Pieces that cast a shadow: kit name -> the zone kit's (offset, colour).
SHADOWED = {
    'tdock': SHADOW_BIG,
    'board9': SHADOW_BIG,
    'slot': SHADOW_SMALL,
    'keycap': SHADOW_SMALL,
}
# Pieces copied as drawn: kit names.
PLAIN = ['cast_tray', 'timer', 'timer_low', 'socket_buff', 'socket_glyph',
         'mini_health', 'mini_stamina', 'mini_hourglass'] + \
        [f'rod_{rod}_{part}' for rod in ('stamina', 'cast') for part in ('empty', 'full', 'end')]
TOKENS = 'lacquer_marker_tokens_ai.png'         # four 52x52 coins side by side
COINS, COIN = 4, 52
ORB_STRIP = 'lacquer_orb_health_strip_ai.png'   # 33 frames of 80x80
ORB = 80
SPENT = [f'adv_glyph_{kind}_spent_light_ai.png' for kind in ('combat', 'elite', 'rest', 'boss', 'treasure', 'trap')]
VEIL_ATLAS = 'hex_forest_veil_atlas_ai.png'


def kit_file(name: str) -> str:
    """The file name of a kit piece, in the mock and in the project."""
    return f'lacquer_{name}_ai.png'


def check_sources() -> None:
    """Stop with the list of every mock file the import reads that is not there."""
    names = [kit_file(n) for n in list(SHADOWED) + PLAIN] + [TOKENS, ORB_STRIP, VEIL_ATLAS] + SPENT
    missing = [n for n in names if not (MOCK / n).exists()]
    if missing:
        raise SystemExit(f'missing sources in {MOCK} (run build_all.py first): {missing}')


def copy_as_drawn(name: str, dest: Path) -> None:
    """Copy one mock file into a project folder unchanged."""
    shutil.copy2(MOCK / name, dest / name)
    print(f'copied {name} -> {dest.name}/')


def shadow_tokens() -> None:
    """Each coin gets its own 2 px shadow (a frame stays square), then the frames sit side by side."""
    offset, rgb = SHADOW_SMALL
    strip = Image.open(MOCK / TOKENS).convert('RGBA')
    assert strip.size == (COINS * COIN, COIN), f'{TOKENS} is {strip.size}'
    frame = COIN + offset
    out = Image.new('RGBA', (COINS * frame, frame), (0, 0, 0, 0))
    with tempfile.TemporaryDirectory() as tmp:
        for i in range(COINS):
            bare, shadowed = Path(tmp) / f'coin{i}.png', Path(tmp) / f'coin{i}_shadowed.png'
            strip.crop((i * COIN, 0, (i + 1) * COIN, COIN)).save(bare)
            bake_shadow(bare, shadowed, offset, rgb)
            with Image.open(shadowed) as coin:
                out.paste(coin, (i * frame, 0))
    out.save(UI / TOKENS)
    print(f'tokens {TOKENS} -> {out.width}x{out.height}')


def crop_orb() -> None:
    """The health orb is the first frame of the mock's strip."""
    strip = Image.open(MOCK / ORB_STRIP).convert('RGBA')
    assert strip.height == ORB and strip.width % ORB == 0, f'{ORB_STRIP} is {strip.size}'
    strip.crop((0, 0, ORB, ORB)).save(UI / kit_file('orb_health'))
    print(f'cropped frame 0 of {ORB_STRIP} -> {kit_file("orb_health")}')


def main() -> None:
    """Import everything PR 1 draws on."""
    check_sources()
    for name, (offset, rgb) in SHADOWED.items():
        bake_shadow(MOCK / kit_file(name), UI / kit_file(name), offset, rgb)
    for name in PLAIN:
        copy_as_drawn(kit_file(name), UI)
    shadow_tokens()
    crop_orb()
    for name in SPENT:
        copy_as_drawn(name, GLYPHS)
    copy_as_drawn(VEIL_ATLAS, FOREST)


if __name__ == '__main__':
    main()
