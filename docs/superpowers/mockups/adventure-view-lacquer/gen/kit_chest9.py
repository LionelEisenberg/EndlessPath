"""The 9-slice pieces the chest's growing boards need (python kit_chest9.py, from this folder).

The developer's rule: no text is ever cut off, so a board that held its text in a fixed-size
texture grows with it instead. A board grows when its art is a 9-slice: the rim and the corners are
drawn once, the edges between them are flat along their length and the middle is one colour, so a
NinePatchRect (or a StyleBoxTexture) can stretch it to any height without a seam. This script
checks each texture the boards stand on and draws only the pieces that were not clean already:

* The trays are clean as they are. lacquer_now_tray_ai.png (408x88: the Here tray, the zone chest's
  Now strip) and lacquer_cast_tray_ai.png (476x44: the cast tray) are 4 px of ink on the top and
  left, a 2 px lit rim on the bottom and right and one flat fill, with no baked shadow (a tray is
  carved in). NinePatchRect margins left 4, top 4, right 2, bottom 2 on the existing files; no new
  art. audit() proves it pixel by pixel.
* The choice drawer's face is not: its carved 48x48 socket is baked in at (8, 12), which a stretch
  would smear. drawer9 is the face without the socket, a 9-slice (margins 4 once drawn, 4 4 6 6
  with the 2 px shadow baked in), and socket_drawer is the socket on its own, a TextureRect that
  stays centred as the face grows. Stretched to the zone card's 392x72 with the socket put back at
  (8, 12), the pair is pixel for pixel the zone kit's drawer (compose_drawer() proves it), so a
  drawer of 72 px looks as it did.
* The Now strip narrows by 16 px so its right edge lines up with the cards' (the cards keep their
  392 for the list's rail), and its rod with it. rod_now_{empty,full,end} are the Aura Well rod
  with 16 px taken out of its flat middle: 308 -> 292 wide, 152 -> 144 steps (2 + 2 k, plus the
  2 px end cap).

Same rules as the zone kit (docs/superpowers/mockups/zone-view-lacquer/gen/): drawn at native size,
nothing random, every file ends in _ai, nothing the user drew is touched. Pieces are drawn into
the mock folder (../) from the zone kit's unshadowed files; import_all() bakes the drawer's 2 px
shadow with the zone kit's bake_shadow() and copies the pieces into assets/ui/lacquer/. This file
stands alone (it imports only the zone kit's import_kit, for the shadow), so the other generators
here are left as they are.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
MOCKS = HERE.parent.parent                          # docs/superpowers/mockups/
REPO = MOCKS.parent.parent.parent
OUT = MOCKS / 'adventure-view-lacquer'              # where the pieces are drawn
ZONE_KIT = MOCKS / 'zone-view-lacquer'              # the unshadowed zone kit
UI = REPO / 'assets' / 'ui' / 'lacquer'             # what the game loads

sys.path.insert(0, str(MOCKS / 'zone-view-lacquer' / 'gen'))
from import_kit import SHADOW_SMALL, bake_shadow  # noqa: E402

# The zone card's drawer: 392x72 with a 48x48 carved socket at (8, 12).
DRAWER = (392, 72)
SOCKET_BOX = (8, 12, 56, 60)
# Its rim, in art px x 2: the lit rim and the outline up top and left, the shaded rim and the
# outline at the bottom and right.
RIM = 4
# How much flat middle the 9-slice keeps (any size will do; this one is small).
KEEP = 12
# The Aura Well rod and how much of its flat middle the Now strip gives up.
WELL_ROD = 308
CUT = 16

# The trays' 9-slice margins (left, top, right, bottom) and the files that use them.
TRAY_MARGINS = (4, 4, 2, 2)
TRAYS = ('lacquer_now_tray_ai.png', 'lacquer_cast_tray_ai.png')
# The pieces this script draws.
DRAWER9 = 'lacquer_drawer9_ai.png'
SOCKET_DRAWER = 'lacquer_socket_drawer_ai.png'
ROD_NOW = [f'lacquer_rod_now_{part}_ai.png' for part in ('empty', 'full', 'end')]


def load(path: Path) -> Image.Image:
    """An image as RGBA."""
    return Image.open(path).convert('RGBA')


def pixels(img: Image.Image) -> list:
    """Every pixel of an image, row by row (getdata() goes away in Pillow 14)."""
    return list(img.get_flattened_data() if hasattr(img, 'get_flattened_data') else img.getdata())


def colours(img: Image.Image, box: tuple) -> set:
    """The set of distinct pixels in a box (left, top, right, bottom)."""
    return set(pixels(img.crop(box)))


def audit_nine_slice(name: str, img: Image.Image, margins: tuple) -> list:
    """What stops img from being a clean 9-slice with margins (left, top, right, bottom): empty
    when the edges are flat along their length and the middle is one colour."""
    left, top, right, bottom = margins
    w, h = img.size
    problems = []
    flat = {
        'top edge': ((left, 0, w - right, top), 'x'),
        'bottom edge': ((left, h - bottom, w - right, h), 'x'),
        'left edge': ((0, top, left, h - bottom), 'y'),
        'right edge': ((w - right, top, w, h - bottom), 'y'),
    }
    for label, (box, axis) in flat.items():
        strip = img.crop(box)
        sw, sh = strip.size
        px = strip.load()
        if axis == 'x':
            lines = {tuple(px[x, y] for y in range(sh)) for x in range(sw)}
        else:
            lines = {tuple(px[x, y] for x in range(sw)) for y in range(sh)}
        if len(lines) > 1:
            problems.append(f'{name}: the {label} changes along its length ({len(lines)} kinds of line)')
    if len(colours(img, (left, top, w - right, h - bottom))) > 1:
        problems.append(f'{name}: the middle is not one colour')
    return problems


def audit() -> None:
    """The trays are 9-slices as they are: stop if either is not."""
    for name in TRAYS:
        problems = audit_nine_slice(name, load(UI / name), TRAY_MARGINS)
        if problems:
            raise SystemExit('\n'.join(problems))
        print(f'{name}: a clean 9-slice, margins {TRAY_MARGINS} (left, top, right, bottom), no new art')


def nine_slice(img: Image.Image, margins: tuple, size: tuple) -> Image.Image:
    """img stretched to size the way NinePatchRect does it: corners copied, edges and middle
    stretched (nearest)."""
    left, top, right, bottom = margins
    w, h = img.size
    out_w, out_h = size
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    cells = [
        ((0, 0, left, top), (0, 0, left, top)),
        ((w - right, 0, w, top), (out_w - right, 0, out_w, top)),
        ((0, h - bottom, left, h), (0, out_h - bottom, left, out_h)),
        ((w - right, h - bottom, w, h), (out_w - right, out_h - bottom, out_w, out_h)),
        ((left, 0, w - right, top), (left, 0, out_w - right, top)),
        ((left, h - bottom, w - right, h), (left, out_h - bottom, out_w - right, out_h)),
        ((0, top, left, h - bottom), (0, top, left, out_h - bottom)),
        ((w - right, top, w, h - bottom), (out_w - right, top, out_w, out_h - bottom)),
        ((left, top, w - right, h - bottom), (left, top, out_w - right, out_h - bottom)),
    ]
    for (sl, st, sr, sb), (dl, dt, dr, db) in cells:
        piece = img.crop((sl, st, sr, sb)).resize((dr - dl, db - dt), Image.NEAREST)
        out.paste(piece, (dl, dt))
    return out


def draw_drawer9(zone_drawer: Image.Image) -> Image.Image:
    """The zone drawer's face without its socket, as small as a 9-slice goes: the four corners and
    the four flat edges copied from the card, the middle one flat colour."""
    w, h = zone_drawer.size
    assert (w, h) == DRAWER, f'the zone drawer is {w}x{h}, not {DRAWER}'
    face = {zone_drawer.getpixel((w // 2, h // 2))}
    assert len(colours(zone_drawer, (SOCKET_BOX[2], RIM, w - RIM, h - RIM))) == 1, 'the face is not flat'
    side = RIM + KEEP
    size = (side + RIM, side + RIM)
    out = Image.new('RGBA', size)
    out.paste(zone_drawer.crop((0, 0, RIM, RIM)), (0, 0))
    out.paste(zone_drawer.crop((w - RIM, 0, w, RIM)), (size[0] - RIM, 0))
    out.paste(zone_drawer.crop((0, h - RIM, RIM, h)), (0, size[1] - RIM))
    out.paste(zone_drawer.crop((w - RIM, h - RIM, w, h)), (size[0] - RIM, size[1] - RIM))
    # The edges are flat along their length: one column or row of each, repeated.
    for x in range(RIM, RIM + KEEP):
        out.paste(zone_drawer.crop((RIM, 0, RIM + 1, RIM)), (x, 0))
        out.paste(zone_drawer.crop((RIM, h - RIM, RIM + 1, h)), (x, size[1] - RIM))
    for y in range(RIM, RIM + KEEP):
        out.paste(zone_drawer.crop((0, RIM, RIM, RIM + 1)), (0, y))
        out.paste(zone_drawer.crop((w - RIM, RIM, w, RIM + 1)), (size[0] - RIM, y))
    out.paste(Image.new('RGBA', (KEEP, KEEP), next(iter(face))), (RIM, RIM))
    problems = audit_nine_slice(DRAWER9, out, (RIM, RIM, RIM, RIM))
    assert not problems, problems
    return out


def compose_drawer(face9: Image.Image, socket: Image.Image, size: tuple) -> Image.Image:
    """What the game draws for a drawer of size: the 9-slice face with the socket on it."""
    out = nine_slice(face9, (RIM, RIM, RIM, RIM), size)
    out.paste(socket, (SOCKET_BOX[0], (size[1] - socket.height) // 2))
    return out


def draw_rod(well: Image.Image) -> Image.Image:
    """The Aura Well rod with CUT columns taken out of the flat run between its two ends."""
    w, h = well.size
    assert w == WELL_ROD, f'the well rod is {w} wide, not {WELL_ROD}'
    out = Image.new('RGBA', (w - CUT, h))
    out.paste(well.crop((0, 0, w - 2 - CUT, h)), (0, 0))
    out.paste(well.crop((w - 2, 0, w, h)), (w - 2 - CUT, 0))
    return out


def check_rod(name: str, well: Image.Image, now: Image.Image) -> None:
    """The cut left a rod of the same make: the run it came out of was flat."""
    flat = {tuple(well.getpixel((x, y)) for y in range(well.height)) for x in range(2, well.width - 2)}
    assert len(flat) == 1, f'{name}: the rod is not flat in the middle'
    assert now.size == (well.width - CUT, well.height)
    assert now.getpixel((now.width - 1, 0)) == well.getpixel((well.width - 1, 0)), f'{name}: the end moved'


def build() -> None:
    """Draws the pieces into the mock folder, checking each against what it came from."""
    zone_drawer = load(ZONE_KIT / 'lacquer_drawer_ai.png')
    face9 = draw_drawer9(zone_drawer)
    socket = zone_drawer.crop(SOCKET_BOX)
    assert socket.size == (48, 48)
    again = compose_drawer(face9, socket, DRAWER)
    assert pixels(again) == pixels(zone_drawer), 'the 9-slice drawer is not the zone drawer at 392x72'
    face9.save(OUT / DRAWER9)
    socket.save(OUT / SOCKET_DRAWER)
    print(f'drew {DRAWER9} {face9.size}, {SOCKET_DRAWER} {socket.size}: at 392x72 they are the zone drawer, pixel for pixel')
    for part, name in zip(('empty', 'full', 'end'), ROD_NOW):
        well = load(ZONE_KIT / f'lacquer_rod_well_{part}_ai.png')
        if part == 'end':
            now = well.copy()
        else:
            now = draw_rod(well)
            check_rod(name, well, now)
        now.save(OUT / name)
        print(f'drew {name} {now.size}')


def import_all() -> None:
    """Bakes the drawer's 2 px shadow and copies the pieces into assets/ui/lacquer/."""
    offset, rgb = SHADOW_SMALL
    bake_shadow(OUT / DRAWER9, UI / DRAWER9, offset, rgb)
    for name in [SOCKET_DRAWER] + ROD_NOW:
        shutil.copy2(OUT / name, UI / name)
        print(f'copied {name} -> assets/ui/lacquer/')
    baked = load(UI / DRAWER9)
    problems = audit_nine_slice(DRAWER9, baked, (RIM, RIM, RIM + offset, RIM + offset))
    assert not problems, problems
    print(f'{DRAWER9} with its shadow: a clean 9-slice, margins (4, 4, 6, 6), {baked.size}')


if __name__ == '__main__':
    audit()
    build()
    import_all()
