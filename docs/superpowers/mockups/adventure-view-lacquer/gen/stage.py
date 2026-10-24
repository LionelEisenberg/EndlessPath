"""Adventure view mock: the combat stage and two PLACEHOLDER fighters (style guide S1, S3).

The stage is the map's own world, close up: tree trunks in the kit's three fog tiers (far to
near), round a clearing in the colours of the user's forest tiles. Static, opaque, 2x grid, no
gradient (bands and hand-placed shapes only). The fighters are placeholders for question A-Q8:
the player in the palette of the user's map character, the Amorphous Spirit in a violet ramp
that is not in the kit (the kit has no enemy colours).
"""
from PIL import ImageDraw

from adv_base import Image, save_as, put, hx, GROUND, FOG_T1, FOG_T2, FOG_T3

W, H = 960, 540
HORIZON = 372
# the user's forest tile colours (Hex_Forest_00_Basic.png)
G_BASE, G_LIGHT, G_SHADE, G_DARK, G_INK = hx('789C87'), hx('7FA68F'), hx('4B6054'), hx('161D19'), hx('000000')


def trunk(d, x, w, top, bottom, fill, line=None, lean=0):
    pts = [(x, top), (x + w, top), (x + w + lean, bottom), (x + lean, bottom)]
    d.polygon(pts, fill=fill)
    if line:
        for k in range(1, 3):
            lx = x + w * k // 3
            d.line([(lx, top + 6 * k), (lx + lean, bottom - 10 * k)], fill=line)


def canopy(d, cx, cy, rx, ry, fill):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill)


def stage():
    img = Image.new('RGBA', (W, H), GROUND)
    d = ImageDraw.Draw(img)
    # far: tier 3 silhouettes
    for x, w in ((30, 12), (118, 10), (205, 14), (300, 10), (392, 12), (470, 9), (548, 13), (640, 10), (735, 14), (820, 11), (905, 12)):
        trunk(d, x, w, 0, HORIZON, FOG_T3)
    for cx in range(0, W + 60, 70):
        canopy(d, cx, 18 + (cx * 7) % 22, 58, 34, FOG_T3)
    # mid: tier 2, etched bark
    for x, w, lean in ((70, 20, -2), (250, 24, 2), (430, 18, 0), (600, 22, -2), (780, 26, 2), (875, 18, 0)):
        trunk(d, x, w, 0, HORIZON + 4, FOG_T2[1], FOG_T2[0], lean)
    for cx in range(-20, W + 60, 96):
        canopy(d, cx, 6 + (cx * 5) % 18, 66, 30, FOG_T2[1])
    # a shrub line along the horizon (tier 1), so the clearing has an edge
    for cx in range(-10, W + 40, 34):
        ry = 10 + (cx * 13) % 9
        canopy(d, cx, HORIZON - 4, 22 + (cx * 7) % 10, ry, FOG_T1[1])
        canopy(d, cx - 4, HORIZON - 8, 14 + (cx * 3) % 8, ry - 5, FOG_T1[2])
    for x in (84, 262, 444, 612, 792, 887):
        for k, (y0, y1) in enumerate(((40, 120), (150, 230), (250, 330))):
            d.line([(x + 3 + k * 4, y0), (x + 3 + k * 4, y1)], fill=FOG_T2[0])
        d.line([(x - 10, 96), (x + 2, 110)], fill=FOG_T2[1])
        d.line([(x - 12, 96), (x - 18, 90)], fill=FOG_T2[1])
    for x, y1 in ((160, 120), (350, 96), (520, 140), (700, 110), (860, 130)):
        d.line([(x, 30), (x, y1)], fill=FOG_T1[2])
        d.line([(x + 1, 30), (x + 1, y1 - 20)], fill=FOG_T1[3])
    # ground: the clearing, in stepped bands
    d.rectangle([0, HORIZON, W, H], fill=G_BASE)
    d.rectangle([0, HORIZON, W, HORIZON + 5], fill=G_SHADE)
    d.rectangle([0, HORIZON + 6, W, HORIZON + 7], fill=G_DARK)
    for x in range(0, W, 2):
        if (x // 2) % 2 == 0:
            put(img, x, HORIZON + 8, G_SHADE)
    # light patches and grass dashes, placed by hand like the tile's
    for (x, y, w) in ((140, 420, 60), (380, 470, 90), (660, 430, 70), (820, 500, 80), (40, 500, 50), (520, 515, 60)):
        d.rectangle([x, y, x + w, y + 1], fill=G_LIGHT)
    for (x, y) in ((90, 400), (230, 452), (318, 410), (470, 438), (560, 404), (690, 470), (760, 412), (880, 446),
                   (150, 500), (420, 506), (610, 520), (930, 520), (36, 440), (300, 490), (840, 470)):
        put(img, x, y, G_INK)
        put(img, x + 1, y - 1, G_INK)
        put(img, x + 2, y - 1, G_INK)
        put(img, x + 3, y, G_INK)
        put(img, x + 5, y, G_INK)
        put(img, x + 6, y - 1, G_INK)
    # near: tier 1 trunks framing the clearing, roots on the ground
    base, shade, light, line = FOG_T1[2], FOG_T1[1], FOG_T1[3], FOG_T1[0]
    for x, w, lean in ((-10, 62, 4), (906, 64, -4)):
        trunk(d, x, w, 0, HORIZON + 24, base, line, lean)
        d.line([(x + 6, 0), (x + 6 + lean, HORIZON + 20)], fill=light)
        d.line([(x + w - 4, 0), (x + w - 4 + lean, HORIZON + 20)], fill=shade)
        d.polygon([(x + lean - 14, HORIZON + 26), (x + lean + w + 14, HORIZON + 26), (x + lean + w, HORIZON + 14), (x + lean, HORIZON + 14)], fill=shade)
    # foreground bushes at the bottom corners (tier 1, darkest first)
    for cx, cy, rx, ry in ((40, 548, 120, 46), (930, 552, 130, 50), (150, 560, 70, 30), (820, 566, 80, 34)):
        canopy(d, cx, cy, rx, ry, FOG_T1[1])
        canopy(d, cx - 8, cy - 6, rx - 16, ry - 12, base)
        d.line([(cx - rx + 30, cy - ry + 14), (cx + rx - 40, cy - ry + 10)], fill=light)
    save_as(img, 'adv_stage_forest_ai.png')


def outline(img, col):
    """1 px outline outside the silhouette (4-neighbourhood)."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < w and 0 <= Y < h and px[X, Y][3] != 0:
                    out[x, y] = col
                    break


def cultivator():
    """The player, facing right, in the map character's palette (main_character_spritesheet)."""
    NAVY, WHITE, LAV, PUR, PUR_D = hx('1C2F60'), hx('FCFCFC'), hx('C4C7EE'), hx('978BDE'), hx('635D96')
    BR, BR_S = hx('D4A84A'), hx('A66834')
    w, h = 60, 99
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # robe: a flared skirt, shaded on the far (right, lower) side
    d.polygon([(16, 45), (40, 45), (50, 87), (8, 87)], fill=WHITE)
    d.polygon([(33, 45), (40, 45), (50, 87), (38, 87)], fill=LAV)
    d.line([(28, 60), (26, 87)], fill=LAV)
    d.rectangle([8, 84, 50, 87], fill=PUR)
    # sash
    d.rectangle([15, 56, 42, 58], fill=BR)
    d.line([(15, 58), (42, 58)], fill=BR_S)
    d.polygon([(18, 58), (22, 58), (20, 70), (15, 69)], fill=BR_S)
    # feet
    d.rectangle([12, 88, 21, 92], fill=NAVY)
    d.rectangle([33, 88, 44, 92], fill=NAVY)
    # front arm, fist out toward the enemy
    d.polygon([(36, 46), (44, 46), (54, 52), (51, 57), (38, 52)], fill=WHITE)
    d.line([(39, 52), (51, 57)], fill=LAV)
    d.rectangle([51, 50, 56, 56], fill=LAV)
    d.line([(51, 56), (56, 56)], fill=PUR)
    # head: the white hood, the face on the right
    d.ellipse([9, 3, 48, 45], fill=WHITE)
    d.pieslice([9, 3, 48, 45], 300, 60, fill=WHITE)
    d.ellipse([22, 15, 46, 42], fill=LAV)
    d.ellipse([9, 3, 33, 33], fill=WHITE)
    d.line([(24, 39), (42, 39)], fill=PUR)
    d.line([(44, 27), (44, 38)], fill=PUR)
    # hood shading (far side) and a highlight (near the light, top left)
    d.arc([9, 3, 48, 45], 20, 120, fill=PUR)
    d.line([(15, 9), (24, 4)], fill=LAV)
    # eye and brow
    d.rectangle([38, 22, 39, 27], fill=NAVY)
    d.line([(36, 20), (40, 20)], fill=PUR_D)
    outline(img, NAVY)
    save_as(img, 'adv_cultivator_ai.png')


def spirit():
    """The Amorphous Spirit: a violet blob with a lashing tendril (placeholder palette)."""
    V_HI, V_LIGHT, V_MID, V_DARK, V_DEEP, V_OL = (hx('F1ECFA'), hx('CBBDE8'), hx('9A84C9'), hx('5E4A8C'),
                                                hx('3A2C60'), hx('1B1433'))
    CREAM, INKY = hx('F0E8D8'), hx('150909')
    w, h = 108, 84
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # body: overlapping lobes, darker toward the lower right
    d.ellipse([21, 18, 99, 78], fill=V_DARK)
    d.ellipse([18, 12, 90, 72], fill=V_MID)
    d.ellipse([24, 15, 75, 54], fill=V_LIGHT)
    d.ellipse([30, 18, 51, 33], fill=V_HI)
    d.ellipse([60, 3, 93, 36], fill=V_MID)
    d.ellipse([66, 6, 84, 21], fill=V_LIGHT)
    # drips along the bottom, stepped
    for x, ln in ((33, 9), (45, 4), (66, 10), (81, 6), (90, 3)):
        d.rectangle([x, 69, x + 4, 69 + ln], fill=V_DARK)
        d.rectangle([x + 2, 69 + ln, x + 3, 70 + ln], fill=V_DEEP)
    # the lashing tendril, reaching left toward the player
    d.polygon([(24, 45), (3, 36), (0, 40), (18, 54)], fill=V_MID)
    d.line([(3, 38), (21, 46)], fill=V_LIGHT)
    d.rectangle([0, 36, 3, 40], fill=V_DARK)
    # eyes: pale, with ink pupils looking left
    for ex in (36, 54):
        d.rectangle([ex, 30, ex + 8, 39], fill=CREAM)
        d.rectangle([ex, 33, ex + 3, 38], fill=INKY)
    d.line([(39, 46), (54, 46)], fill=V_DEEP)
    d.line([(54, 46), (57, 45)], fill=V_DEEP)
    outline(img, V_OL)
    save_as(img, 'adv_spirit_ai.png')


def shadows():
    for name, w in (('adv_shadow_player_ai.png', 30), ('adv_shadow_spirit_ai.png', 50)):
        img = Image.new('RGBA', (w, 6), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([0, 0, w - 1, 5], fill=G_SHADE)
        d.ellipse([3, 1, w - 4, 4], fill=G_DARK)
        save_as(img, name)


def run():
    # Round 2: the stage and the fighters are drawn in Aseprite now (aseprite/adv_stage_bamboo_ai,
    # adv_fighter_player_ai, adv_fighter_spirit_ai), so only the ground shadows come from here.
    shadows()


if __name__ == '__main__':
    run()
    print('ok')
