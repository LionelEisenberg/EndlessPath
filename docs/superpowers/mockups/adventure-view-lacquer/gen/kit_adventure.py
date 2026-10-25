"""Adventure view mock: the new UI pieces (vitals, technique dock, trays, plates, cooldown ring).

Run build_all.py. Native sizes below; every file is saved at 2x (screen px in comments).
Only the decided design is built (grill rounds 1 and 2, 2026-10-22): the columns layout, the
radial cooldown sweep, and round 1's paper scroll kept as the reference for the deferred end card.
"""
from adv_base import (B, Image, OUT, ZONE_KIT, ASSETS as ASSETS_DIR, CLEAR, INK, DEEP, LAC, GRAIN,
                      GRAIN2, RAISED, RIM_S, RIM, BRASS, BRASS_SH, CREAM, TAN, TAN_SH, JADE_HI, JADE,
                      JADE_SH, SOCKET, H_HI, H_PALE, H_MID, H_DEEP, S_HI, S_PALE, S_MID, S_DEEP,
                      MADRA_RAMP, HEALTH_RAMP, new, put, save, save_as, side_of, streak, gloss, tray,
                      brass_plate, tablet, seal, caps, board_base, recess, rod_pair, recolour, rows)


# ----------------------------------------------------------------------------
# Vitals: the health orb (the Madra orb strip, recoloured one for one) and the rods
# ----------------------------------------------------------------------------
def health_orb_strip():
    madra = Image.open(ZONE_KIT + 'lacquer_orb_madra_strip_ai.png').convert('RGBA')
    health = recolour(madra, dict(zip(MADRA_RAMP, HEALTH_RAMP)))
    save_as(health, 'lacquer_orb_health_strip_ai.png', s=1)     # 33 frames of 80x80


def rods():
    rod_pair('rod_stamina', 120, S_HI, S_PALE, S_MID)        # 240: vitals cabinet
    rod_pair('rod_health', 130, H_HI, H_PALE, H_MID)         # 260: opponent chest
    rod_pair('rod_cast', 120, JADE_HI, JADE, JADE_SH)        # 240: player cast tray
    rod_pair('rod_intent', 128, JADE_HI, JADE, JADE_SH)      # 256: the opponent's cast


# ----------------------------------------------------------------------------
# Sockets and caps
# ----------------------------------------------------------------------------
def bezel_socket(name, n, bezel=True):
    """A carved socket. bezel=True rings it with a raised lacquer lip (technique slots)."""
    img = new(n, n)
    for y in range(n):
        for x in range(n):
            d, s = side_of(x, y, n, n)
            if bezel:
                if d == 0:
                    c = INK
                elif d == 1:
                    c = RIM if s == 'lit' else DEEP
                elif d == 2:
                    c = RAISED
                elif d == 3:
                    c = INK if s == 'lit' else RIM_S
                else:
                    c = SOCKET
            else:
                if d == 0:
                    c = INK if s == 'lit' else RIM
                elif d == 1:
                    c = INK if s == 'lit' else DEEP
                else:
                    c = SOCKET
            img.putpixel((x, y), c)
    for p in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        put(img, p[0], p[1], CLEAR)
    save(img, name)


def sockets():
    bezel_socket('slot', 40)                 # 80: technique slot, 64 icon at +8
    bezel_socket('socket_loot', 36, False)   # 72: loot, 64 icon at +4 (deferred end card)
    bezel_socket('socket_buff', 20, False)   # 40: buff or loot in the Run ledger, 32 icon at +4
    bezel_socket('socket_glyph', 24, False)  # 48: the Here tray's glyph, 32 at +8
    tablet('keycap', 11, 11)                 # 22: Q W E R


# ----------------------------------------------------------------------------
# Mini icons, 8 art px (16 screen), for cost lines and the timer
# ----------------------------------------------------------------------------
def minis():
    heart = new(8, 8)
    rows(heart, 0, 0, [
        ".II.II..",
        "IhpIpmI.",
        "IpmmmmI.",
        "ImmmmdI.",
        ".ImmmdI.",
        "..ImdI..",
        "...II...",
    ], {'I': INK, 'h': H_HI, 'p': H_PALE, 'm': H_MID, 'd': H_DEEP})
    save(heart, 'mini_health')
    bolt = new(8, 8)
    rows(bolt, 0, 0, [
        "....III.",
        "...IhpI.",
        "..IpmI..",
        ".IpmmmI.",
        "..IImdI.",
        "...IdI..",
        "..IdI...",
        "..II....",
    ], {'I': INK, 'h': S_HI, 'p': S_PALE, 'm': S_MID, 'd': S_DEEP})
    save(bolt, 'mini_stamina')
    glass = new(8, 8)
    rows(glass, 0, 0, [
        "TTTTTTT.",
        ".IcccI..",
        "..IcI...",
        "...I....",
        "..I.I...",
        ".I.c.I..",
        ".IcccI..",
        "TTTTTTT.",
    ], {'I': INK, 'c': CREAM, 'T': TAN})
    save(glass, 'mini_hourglass')


# ----------------------------------------------------------------------------
# Plates, trays and seals
# ----------------------------------------------------------------------------
def plates():
    brass_plate('plate_casting', 44, 11)     # 88x22 legend: Casting
    recess('timer', 44, 18)                  # 88x36 timer readout in the chest header
    seal('timer_low', 44, 18, [(6, 0), (7, 0), (43, 7), (43, 8), (30, 17), (31, 17), (0, 11)],
         [(7, 1), (42, 8), (1, 11), (31, 16)])
    seal('seal_defeat', 70, 22, [(9, 0), (10, 0), (11, 0), (69, 6), (69, 7), (44, 21), (45, 21), (0, 13), (1, 0), (68, 21)],
         [(10, 1), (68, 7), (1, 13), (45, 20), (3, 20), (4, 20)])
    tray('cast_tray', 238, 22)               # 476x44: player cast
    tablet('btn_wide', 76, 22)               # 152x44 text button (Return)
    hov = new(76, 22)
    for y in range(22):
        for x in range(76):
            d, s = side_of(x, y, 76, 22)
            hov.putpixel((x, y), INK if d == 0 else ((RIM if s == 'lit' else DEEP) if d == 1 else RAISED))
    for p in ((0, 0), (75, 0), (0, 21), (75, 21)):
        put(hov, p[0], p[1], CLEAR)
    caps(hov, arm=6, th=2)
    save(hov, 'btn_wide_hover')


# ----------------------------------------------------------------------------
# Boards
# ----------------------------------------------------------------------------
def technique_dock():
    b = board_base(238, 68)
    streak(b, 16, 60, 60, ((22, 1), (41, -1)))
    streak(b, 160, 8, 50, ((18, 1),), GRAIN2)
    streak(b, 200, 40, 24, ())
    gloss(b, 4, [(58, 96, RAISED), (100, 102, RAISED)])
    gloss(b, 4, [(66, 72, RIM_S)])
    save(b, 'tdock')                         # 476x136


def boards():
    save(board_base(12, 12), 'board9')       # 24x24 9-slice, margin 8 (technique tooltips)


# ----------------------------------------------------------------------------
# Consumables on the technique dock (spec 2026-10-25-combat-consumables-lacquer-design.md):
# the dock grows by 64 px for a row of four sockets over the techniques. Not in the mock's page,
# which still draws the 476x136 dock.
# ----------------------------------------------------------------------------
def technique_dock_consumables():
    # The sockets are the kit's 48 px glyph sockets and the count seal the zone kit's (made
    # stretchable in kit_ui.py): only the taller board is new.
    b = board_base(238, 100)
    streak(b, 52, 5, 22, ((9, 1),))          # top band, between the first two sockets
    streak(b, 118, 36, 52, ((14, -1), (37, 1)), GRAIN2)   # between the two rows
    streak(b, 16, 92, 60, ((22, 1), (41, -1)))
    streak(b, 226, 60, 9, ())
    gloss(b, 4, [(132, 168, RAISED), (172, 174, RAISED)])
    gloss(b, 4, [(140, 146, RIM_S)])
    save(b, 'tdock_consumables')             # 476x200


# ----------------------------------------------------------------------------
# End card: round 1's paper scroll, kept as the reference for when the end card is taken up
# (the user took the end card out of this rework, 2026-10-22)
# ----------------------------------------------------------------------------
def scroll():
    w, h = 380, 22
    roll = new(w, h)
    bands = [INK, RIM, RAISED, RAISED, LAC, LAC, LAC, LAC, LAC, LAC, LAC, LAC, LAC, LAC, LAC, DEEP, DEEP, DEEP, DEEP, DEEP, INK, CLEAR]
    for x in range(14, w - 14):
        for y in range(1, h - 2):
            put(roll, x, y, bands[y])
    streak(roll, 40, 9, 60, ((20, 1),), GRAIN2)
    streak(roll, 220, 12, 70, ((30, -1),), GRAIN)
    gloss(roll, 3, [(60, 150, RIM_S), (156, 160, RIM_S)])
    for x0 in (14, w - 22):                  # brass caps on the roller's ends, knobs beyond
        for x in range(x0, x0 + 8):
            for y in range(0, h - 1):
                d = min(y, h - 2 - y)
                c = INK if d == 0 or x in (x0, x0 + 7) else (CREAM if y < 4 else (BRASS_SH if y > h - 7 else BRASS))
                put(roll, x, y, c)
    for x0, x1 in ((2, 14), (w - 14, w - 2)):
        for x in range(x0, x1):
            for y in range(6, h - 7):
                c = INK if y in (6, h - 8) or x in (x0, x1 - 1) else (CREAM if y == 7 else (BRASS_SH if y == h - 9 else BRASS))
                put(roll, x, y, c)
    save(roll, 'scroll_roll')                # 760x44
    pw = 340
    paper = new(pw, 64)
    for y in range(64):
        for x in range(pw):
            if x in (0, pw - 1):
                c = INK
            elif x in (1, pw - 2):
                c = TAN
            elif x in (2, pw - 3):
                c = hx_paper_edge()
            else:
                c = CREAM
            paper.putpixel((x, y), c)
    save(paper, 'scroll_paper')              # 680x128, tiles down
    shade = new(pw, 4)
    for y in range(4):
        for x in range(pw):
            if x in (0, pw - 1):
                c = INK
            elif y == 0:
                c = TAN_SH
            elif y == 1:
                c = TAN if x % 2 == 0 else CREAM
            elif y == 2:
                c = TAN if x % 4 == 1 else CREAM
            else:
                c = CREAM
            if x in (1, pw - 2) and c == CREAM:
                c = TAN
            shade.putpixel((x, y), c)
    save(shade, 'scroll_shade')              # 680x8: the roller's shadow on the paper (2-step dither)


def backdrop_and_icons():
    """The opaque 2-step dither backdrop tile (style guide F5) and a 16 art px hourglass."""
    tile = new(2, 2)
    put(tile, 0, 0, hx_shadow())
    put(tile, 1, 1, hx_shadow())
    save(tile, 'dither_backdrop')            # 4x4: every other 2 px cell is #050707
    glass = new(16, 16)
    rows(glass, 0, 0, [
        ".IIIIIIIIIIIII..",
        ".IBBBBBBBBBBBI..",
        ".IIIIIIIIIIIII..",
        "..IcccccccccI...",
        "..IcCCCCCCCcI...",
        "...IcCCCCCcI....",
        "....IcCCCcI.....",
        ".....IcCcI......",
        ".....IcIcI......",
        "....Ic.C..cI....",
        "...Ic..C...cI...",
        "..Ic..CCC...cI..",
        "..IcCCCCCCCCcI..",
        ".IIIIIIIIIIIIII.",
        ".IBBBBBBBBBBBBI.",
        ".IIIIIIIIIIIIII.",
    ], {'I': INK, 'B': TAN, 'c': TAN_SH, 'C': CREAM})
    save(glass, 'ic_hourglass')              # 32x32


# ----------------------------------------------------------------------------
# Technique cooldown (the user's pick in round 2: a radial sweep that shadows the button, with
# the seconds left in its centre)
# ----------------------------------------------------------------------------
SWEEP_STEPS = 24


def cooldown_sweep():
    """While a technique recharges, the part of its icon still to recharge is shown in shadow: the
    kit's locked (desaturated, dark) veil, never an alpha overlay. The shadow sweeps away clockwise
    from 12 o'clock in 24 whole steps, worked out per 2 px cell so its edge stays on the grid.

    Frame k (0 to 24) has k steps recharged: frame 0 is all shadow, frame 24 the plain icon.
    In the game this is one canvas_item shader on the icon with a single progress uniform.
    """
    import math
    from map_render import spent
    for name in ('basic_strike', 'empty_palm', 'enforce', 'power_font'):
        icon = Image.open(ASSETS_DIR + 'sprites/abilities/%s.png' % name).convert('RGBA')
        dark = spent(icon)
        strip = new(64 * (SWEEP_STEPS + 1), 64)
        for k in range(SWEEP_STEPS + 1):
            frame = icon.copy()
            for cy in range(32):
                for cx in range(32):
                    angle = math.atan2(cx * 2 + 1 - 32, -(cy * 2 + 1 - 32)) % (2 * math.pi)
                    if angle >= k * 2 * math.pi / SWEEP_STEPS:
                        for dy in (0, 1):
                            for dx in (0, 1):
                                frame.putpixel((cx * 2 + dx, cy * 2 + dy), dark.getpixel((cx * 2 + dx, cy * 2 + dy)))
            strip.paste(frame, (k * 64, 0))
        save_as(strip, 'adv_ability_%s_cd_strip_ai.png' % name, s=1)    # 25 frames of 64x64


def hx_shadow():
    return (0x05, 0x07, 0x07, 255)


def hx_paper_edge():
    return (0xE0, 0xD2, 0xB8, 255)              # one step under cream, only on the scroll's paper


def run():
    health_orb_strip()
    rods()
    sockets()
    minis()
    plates()
    technique_dock()
    boards()
    technique_dock_consumables()
    scroll()
    backdrop_and_icons()
    cooldown_sweep()


if __name__ == '__main__':
    run()
    print(len(B.SAVED), 'pieces')
