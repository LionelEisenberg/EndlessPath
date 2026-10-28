"""Lacquer and brass: the pellet strip (2026-10-27).

One strip for LacquerPellet (scenes/common/lacquer/lacquer_pellet/): a row per ramp
(Madra, brass, cream, tan) and a column per frame of the pellet's life, every frame
10x10 art px saved at 2x (20x20 screen px) with the pellet centred:

    0 full       the pellet as the zone kit drew it (lacquer_madra_pellet_ai.png and
                 the cycling kit's lacquer_cyc_pellet_*_ai.png, which it replaces)
    1 small      4 art px: the second step of condensing
    2 seed       2 art px: the first step of condensing
    3 tail near  4 art px, a ramp step darker: the near half of the tail
    4 tail far   2 art px, darker still: the far half of the tail
    5 flash      the pellet lit to its two lightest tones as it lands
    6 burst      eight sparks round an empty centre
    7 scatter    the sparks farther out, dimmer

Lacquer kit section 1 rules 4 and 6: every pixel opaque, in the row's ramp or the
ink outline, no glow or soft edge. Frames are drawn by hand as role grids, no
randomness. Run: python pellet_strip.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..', '..')) + os.sep
OUT = REPO + 'assets/ui/lacquer/lacquer_pellet_strip_ai.png'

FRAME = 10  # art px a side
SCALE = 2   # one art px is 2 screen px


def hx(code):
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


INK = hx('150909')
CREAM = hx('F0E8D8')
BRASS = hx('D4A84A')
BRASS_SH = hx('A66834')
TAN = hx('A89070')
TAN_SH = hx('7A654C')
WARM_OL = hx('341E0E')

# The four ramps, light to deep: hi, pale, mid, deep. The rows of the strip, in the
# order of LacquerPellet.Ramp. Same ramps as the cycling kit's pellets (kit_cycling.py).
RAMPS = [
    (hx('E8F6FD'), hx('BBD5E7'), hx('849BE4'), hx('1C2F60')),  # Madra
    (CREAM, BRASS, BRASS_SH, WARM_OL),                         # brass: PERFECT
    (CREAM, CREAM, TAN, TAN_SH),                               # cream: GOOD
    (CREAM, TAN, TAN_SH, WARM_OL),                             # tan: OK
]

# Roles: '.' clear, 'a' ink, 'h' hi, 'p' pale, 'm' mid, 'd' deep.
FRAMES = [
    # 0 full
    [
        '..........',
        '..........',
        '....aa....',
        '...ahpa...',
        '..ahpmma..',
        '..apmmda..',
        '...amda...',
        '....aa....',
        '..........',
        '..........',
    ],
    # 1 small
    [
        '..........',
        '..........',
        '..........',
        '....aa....',
        '...ahpa...',
        '...apma...',
        '....aa....',
        '..........',
        '..........',
        '..........',
    ],
    # 2 seed
    [
        '..........',
        '..........',
        '..........',
        '..........',
        '....hp....',
        '....pm....',
        '..........',
        '..........',
        '..........',
        '..........',
    ],
    # 3 tail near
    [
        '..........',
        '..........',
        '..........',
        '....aa....',
        '...apma...',
        '...amda...',
        '....aa....',
        '..........',
        '..........',
        '..........',
    ],
    # 4 tail far
    [
        '..........',
        '..........',
        '..........',
        '..........',
        '....md....',
        '....dd....',
        '..........',
        '..........',
        '..........',
        '..........',
    ],
    # 5 flash
    [
        '..........',
        '..........',
        '....aa....',
        '...ahha...',
        '..ahhhpa..',
        '..ahhppa..',
        '...appa...',
        '....aa....',
        '..........',
        '..........',
    ],
    # 6 burst
    [
        '..........',
        '....hh....',
        '..p....p..',
        '..........',
        '.h......h.',
        '.h......h.',
        '..........',
        '..p....p..',
        '....hh....',
        '..........',
    ],
    # 7 scatter
    [
        '....mm....',
        '.d......d.',
        '..........',
        '..........',
        'm........m',
        'm........m',
        '..........',
        '..........',
        '.d......d.',
        '....mm....',
    ],
]


def main():
    strip = Image.new('RGBA', (FRAME * len(FRAMES), FRAME * len(RAMPS)), (0, 0, 0, 0))
    for row, (hi, pale, mid, deep) in enumerate(RAMPS):
        colours = {'a': INK, 'h': hi, 'p': pale, 'm': mid, 'd': deep}
        for column, grid in enumerate(FRAMES):
            assert len(grid) == FRAME and all(len(line) == FRAME for line in grid), column
            for y, line in enumerate(grid):
                for x, role in enumerate(line):
                    if role != '.':
                        strip.putpixel((column * FRAME + x, row * FRAME + y), colours[role])
    strip = strip.resize((strip.width * SCALE, strip.height * SCALE), Image.NEAREST)
    strip.save(OUT)
    print('wrote', OUT, strip.size)


if __name__ == '__main__':
    main()
