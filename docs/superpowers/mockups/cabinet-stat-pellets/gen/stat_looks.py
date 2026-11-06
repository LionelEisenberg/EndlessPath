"""Lacquer and brass: the stat cells' level-up and capped looks, and the Control icon (2026-11-05).

Stats rework chunk #92, approved on the "Where stat XP lands" canvas. Three _ai files:

    assets/ui/lacquer/lacquer_stat_ring_flash_ai.png
        80x80: the stat ring with all 24 beads in brass, the frame a level-up flashes
        (300 ms on, 300 ms off, twice). Frame 24 of lacquer_stat_ring_strip_ai.png with
        the jade ramp swapped for the brass one.
    assets/ui/lacquer/lacquer_stat_ring_capped_strip_ai.png
        1920x80: 24 frames of 80x80 for a stat at the stage's cap. The beads are joined
        into one dark channel, and four brass glints with cream heads flow round it
        clockwise, a quarter turn apart, each a ramp step darker down its tail. One frame
        moves them 3.75 degrees, so a glint takes the 24 frames to reach where the next
        one started; StatCell steps the frames at CAPPED_FPS.
    assets/sprites/ui/attribute_icons/control_icon_ai.png
        64x64: Lionel's control_icon.png redrawn at 16 art px (4x4 file px each), 14 art px
        wide and centred, so at 32 px every pixel stands on the 2 px grid (LL-15).

Every pixel opaque and from the kit's palette (lacquer kit section 1 rules 4 and 6), no
randomness. Run: python stat_looks.py
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..', '..')) + os.sep
RING_STRIP = REPO + 'assets/ui/lacquer/lacquer_stat_ring_strip_ai.png'
OUT_FLASH = REPO + 'assets/ui/lacquer/lacquer_stat_ring_flash_ai.png'
OUT_CAPPED = REPO + 'assets/ui/lacquer/lacquer_stat_ring_capped_strip_ai.png'
OUT_CONTROL = REPO + 'assets/sprites/ui/attribute_icons/control_icon_ai.png'

FRAME = 80          # screen px a side
ART = FRAME // 2    # art px a side: one art px is 2 screen px
FULL_RING = 24      # the ring strip's frame with every bead lit
CAPPED_FRAMES = 24  # one per bead step round the ring


def hx(code):
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


CREAM = hx('F0E8D8')
BRASS = hx('D4A84A')
BRASS_SH = hx('A66834')
DEEP = hx('230F0F')
WARM_OL = hx('341E0E')
JADE_HI, JADE, JADE_DEEP = hx('AAECCE'), hx('5CC4A0'), hx('2F6B4A')

# The bead track: the lit beads' jade and the deep groove between them.
TRACK = {JADE_HI, JADE, JADE_DEEP, DEEP}


def art_grid(frame):
    """The frame's colour per art px."""
    return [[frame.getpixel((x * 2, y * 2)) for x in range(ART)] for y in range(ART)]


def to_screen(grid):
    img = Image.new('RGBA', (ART, ART), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, colour in enumerate(row):
            img.putpixel((x, y), colour)
    return img.resize((FRAME, FRAME), Image.NEAREST)


def flash_frame(full):
    swap = {JADE_HI: CREAM, JADE: BRASS, JADE_DEEP: BRASS_SH}
    return to_screen([[swap.get(c, c) for c in row] for row in full])


GLINTS = 4


def capped_frame(full, index):
    """The joined channel with its glints, `index` frames round from 12 o'clock."""
    head = index * 360.0 / GLINTS / CAPPED_FRAMES
    grid = []
    for y, row in enumerate(full):
        out = []
        for x, colour in enumerate(row):
            if colour not in TRACK:
                out.append(colour)
                continue
            # Clockwise angle from 12 o'clock, on screen (y grows down)
            angle = math.degrees(math.atan2(x + 0.5 - ART / 2, ART / 2 - (y + 0.5))) % 360.0
            lag = min((head + g * 360.0 / GLINTS - angle) % 360.0 for g in range(GLINTS))
            if lag < 8.0:
                out.append(CREAM)
            elif lag < 30.0:
                out.append(BRASS)
            elif lag < 52.0:
                out.append(BRASS_SH)
            else:
                out.append(WARM_OL)
        grid.append(out)
    return to_screen(grid)


# Lionel's control_icon.png at 16 art px, widened one column to 14 and centred.
# Roles: '.' clear, 'b' pink, 'a' violet, 'c' plum, 'd' deep plum (his own four colours).
CONTROL = [
    '.abbbac.........',
    '.bbbbbbbac......',
    '.bbbbbbbbba.....',
    '.abbbbbbbbba....',
    '..abbbbbbbbbc...',
    '....caabbbbbbc..',
    '.......caaabba..',
    '..........cabac.',
    '..daaacd...caac.',
    '.dac..dc...caac.',
    '.ca....c...caac.',
    '.ca..ccd...aaad.',
    '.ccc......caac..',
    '.dcccccccccccd..',
    '..dcccccccccd...',
    '...dddddddd.....',
]
CONTROL_COLOURS = {'b': hx('FEAFF0'), 'a': hx('B585F7'), 'c': hx('A05EAD'), 'd': hx('85408D')}


def control_icon():
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, line in enumerate(CONTROL):
        assert len(line) == 16, y
        for x, role in enumerate(line):
            if role != '.':
                img.putpixel((x, y), CONTROL_COLOURS[role])
    return img.resize((64, 64), Image.NEAREST)


def main():
    strip = Image.open(RING_STRIP).convert('RGBA')
    full = art_grid(strip.crop((FULL_RING * FRAME, 0, (FULL_RING + 1) * FRAME, FRAME)))
    flash_frame(full).save(OUT_FLASH)
    capped = Image.new('RGBA', (FRAME * CAPPED_FRAMES, FRAME), (0, 0, 0, 0))
    for index in range(CAPPED_FRAMES):
        capped.paste(capped_frame(full, index), (index * FRAME, 0))
    capped.save(OUT_CAPPED)
    control_icon().save(OUT_CONTROL)
    for path in (OUT_FLASH, OUT_CAPPED, OUT_CONTROL):
        print('wrote', path)


if __name__ == '__main__':
    main()
