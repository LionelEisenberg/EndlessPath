"""Composes the full 1920x1080 zone view from the kit, following kit.md's rects, so the
kit can be checked as a whole. This is a review render, not a deliverable layout engine.

usage: python preview.py <out.png> key=value ...
  state=well|forage|fresh  list=5|9  demo=0|1  locked=0|1  popover=none|advancement|uncharted
  hover=none|advancement|uncharted|open  lore=0|1  zone=valley|test  scroll=0|1  flash=none|well|woods
"""
import sys

from PIL import Image, ImageDraw, ImageFont

import geom
import lq_base as B

A = B.OUT
FONT = B.REPO + 'assets/fonts/BMEULJIROTTF.ttf'
YATRA = B.REPO + 'assets/fonts/YatraOne-Regular.ttf'

CREAM, TAN, BRASS, INK = '#F0E8D8', '#A89070', '#D4A84A', '#150909'
MADRA = '#BBD5E7'
DIM = '#94806A'
SH4, SH2 = (5, 7, 7, 255), (21, 9, 9, 255)


def img(name):
    if name.endswith('.png'):
        return Image.open(A + name).convert('RGBA')
    return Image.open(A + 'lacquer_' + name + '_ai.png').convert('RGBA')


class Frame:
    def __init__(self, bg):
        self.im = Image.open(A + 'lacquer_fog_%s_ai.png' % bg).convert('RGBA')
        self.d = ImageDraw.Draw(self.im)
        self.fonts = {}

    def font(self, size, yatra=False):
        k = (size, yatra)
        if k not in self.fonts:
            self.fonts[k] = ImageFont.truetype(YATRA if yatra else FONT, size)
        return self.fonts[k]

    def put(self, name, x, y, shadow=0, crop=None, im=None):
        s = im if im is not None else img(name)
        if crop:
            s = s.crop(crop)
        if shadow:
            a = s.split()[3]
            sil = Image.new('RGBA', s.size, SH4 if shadow == 4 else SH2)
            self.im.paste(sil, (x + shadow, y + shadow), a)
        self.im.paste(s, (x, y), s)

    def frame9(self, name, x, y, w, h, sl):
        """border-image with stretch: corners kept, edges stretched, centre empty."""
        s = img(name)
        W, H = s.size
        parts = [
            ((0, 0, sl, sl), (x, y, sl, sl)), ((W - sl, 0, W, sl), (x + w - sl, y, sl, sl)),
            ((0, H - sl, sl, H), (x, y + h - sl, sl, sl)), ((W - sl, H - sl, W, H), (x + w - sl, y + h - sl, sl, sl)),
            ((sl, 0, W - sl, sl), (x + sl, y, w - 2 * sl, sl)), ((sl, H - sl, W - sl, H), (x + sl, y + h - sl, w - 2 * sl, sl)),
            ((0, sl, sl, H - sl), (x, y + sl, sl, h - 2 * sl)), ((W - sl, sl, W, H - sl), (x + w - sl, y + sl, sl, h - 2 * sl)),
        ]
        for src, (dx, dy, dw, dh) in parts:
            p = s.crop(src).resize((max(1, dw), max(1, dh)), Image.NEAREST)
            self.im.paste(p, (dx, dy), p)

    def tile_x(self, name, x, y, w):
        s = img(name)
        for xx in range(x, x + w, s.width):
            p = s.crop((0, 0, min(s.width, x + w - xx), s.height))
            self.im.paste(p, (xx, y), p)

    def tile_y(self, name, x, y, h):
        s = img(name)
        for yy in range(y, y + h, s.height):
            p = s.crop((0, 0, s.width, min(s.height, y + h - yy)))
            self.im.paste(p, (x, yy), p)

    def text(self, s, x, y, size, color, lh=None, align='left', yatra=False, shadow=None, outline=None, width=None):
        f = self.font(size, yatra)
        lh = lh or round(size * 1.2)
        tw = f.getlength(s)
        if align == 'right':
            x = x - tw
        elif align == 'center':
            x = x + (width - tw) / 2
        asc, desc = f.getmetrics()
        ty = y + (lh - (asc + desc)) / 2
        if outline:
            for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (2, 2)):
                self.d.text((x + dx, ty + dy), s, font=f, fill=outline)
        if shadow:
            self.d.text((x + shadow[0], ty + shadow[1]), s, font=f, fill=shadow[2])
        self.d.text((x, ty), s, font=f, fill=color)
        if not yatra and '.' in s:
            import re
            yf = self.font(size, True)
            ya, yd = yf.getmetrics()
            for m in re.finditer(r'(?<=\d)\.(?=\d)', s):
                px = x + f.getlength(s[:m.start()])
                dw = f.getlength('.')
                bg = self.im.getpixel((int(px + dw / 2), int(y + lh - 3)))
                self.d.rectangle((px, ty + asc - size * 0.3, px + dw - 1, ty + asc + 1), fill=bg)
                yw = yf.getlength('.')
                self.d.text((px + (dw - yw) / 2, y + (lh - (ya + yd)) / 2 + (asc - ya) * 0 - 1), '.', font=yf, fill=color)
        return tw

    def rod(self, name, x, y, frac):
        e = img(name + '_empty')
        f = img(name + '_full')
        self.put(None, x, y, im=e)
        nat = e.width // 2
        k = round(frac * (nat - 2))
        if k > 0:
            fill = f.crop((0, 0, 2 + 2 * k, f.height))
            self.put(None, x, y, im=fill)
            if k > 1:
                self.put(name + '_end', x + 2 * k, y)


def build(opts):
    st = opts.get('state', 'well')
    nine = opts.get('list', '5') == '9'
    demo = opts.get('demo', '0') == '1'
    locked = opts.get('locked', '0') == '1'
    pop = opts.get('popover', 'none') if locked else 'none'
    hov = opts.get('hover', 'none')
    lore = opts.get('lore', '0') == '1'
    zone = opts.get('zone', 'valley')
    scrolled = opts.get('scroll', '0') == '1'
    flash = opts.get('flash', 'none')
    global MADRA_NOW
    MADRA_NOW = int(opts.get('madra', '46'))
    fresh = st == 'fresh'
    cur = None if fresh or zone == 'test' else st
    bg = {(False, False): 'base', (True, False): 'open', (False, True): 'locked', (True, True): 'both'}[(demo, locked)]
    F = Frame(bg)

    # ------------------------------------------------------------------ map
    def tl(z):
        return geom.tile_tl(*geom.ZONES[z])

    if locked:
        F.put('tile_uncharted_hover' if hov == 'uncharted' else 'tile_uncharted', *tl('uncharted'))
        F.put('tile_locked_hover' if hov == 'advancement' else 'tile_locked', *tl('advancement'))
    F.put('Hex_Forest_06_River.png', *tl('valley'), im=img('Hex_Forest_06_River.png').resize((328, 380), Image.NEAREST))
    if demo:
        F.put(None, *tl('test'), im=img('Hex_Forest_00_Basic.png').resize((328, 380), Image.NEAREST))
        F.put('hex_open', *tl('valley' if zone == 'test' else 'test'))
    F.put('hex_current', *tl(zone))
    # routes
    if locked:
        for (x, y) in ROUTE_NORTH:
            F.put('route_dot', x, y)
    if demo:
        lit = hov == 'open' and zone == 'valley'
        for (x, y) in ROUTE_WEST:
            F.put('route_dot_lit' if lit else 'route_dot', x, y)
    # character, map ring, floater
    cx = 992 if zone == 'valley' else 664
    F.put('char_shadow', cx + 2, 762)
    sheet = Image.open(A + 'main_character_spritesheet.png').convert('RGBA').resize((256, 576), Image.NEAREST)
    F.put(None, cx, 720, im=sheet.crop((128, 96, 160, 144)))
    if cur:
        ring = img('map_ring_strip')
        frame = 5 if cur == 'well' else 8
        F.put(None, cx + 44, 712, im=ring.crop((frame * 60, 0, frame * 60 + 60, 60)))
        ic = img('ic_well_ai.png' if cur == 'well' else 'ic_forage_ai.png').resize((32, 32), Image.NEAREST)
        F.put(None, cx + 58, 726, im=ic)
        if cur == 'well':
            F.text('+1.5 Madra', cx + 16 - 50, 686, 16, MADRA, lh=20, align='center', width=100, outline=INK)
        else:
            F.text('+3 Dewdrop Tear  +4 Spirit Fern', cx + 16 - 140, 686, 16, CREAM, lh=20, align='center', width=280, outline=INK)
    if locked:
        F.put('glyph_unknown', 946, 92)
        F.put('glyph_lock', 1102, 356)
    # plates
    vx = 836 if True else 0
    pv = 'plate_current' if zone == 'valley' else 'plate_open'
    if hov == 'valley':
        pv += '_hover'
    F.put(pv, 836, 800, shadow=2)
    F.text('Spirit Valley', 836, 806, 16, BRASS if zone == 'valley' else CREAM, lh=18, align='center', width=248)
    if zone == 'valley' and cur:
        line = 'Aura Well · +1.5 Madra / s' if cur == 'well' else 'Foraging · a haul every 5 s'
        f = F.font(14)
        tw = f.getlength(line) + 22
        x0 = 836 + (248 - tw) / 2
        F.put('mini_well' if cur == 'well' else 'mini_forage', int(x0) // 2 * 2, 828)
        F.text(line, x0 + 22, 826, 14, CREAM, lh=18)
    elif zone == 'test':
        F.text('Open · 5 activities', 836, 826, 14, TAN, lh=18, align='center', width=248)
    if demo:
        pt = 'plate_current' if zone == 'test' else ('plate_open_hover' if hov == 'open' else 'plate_open')
        F.put(pt, 508, 800, shadow=2)
        F.text('Test Zone', 508, 806, 16, BRASS if zone == 'test' else CREAM, lh=18, align='center', width=248)
        if zone != 'test':
            if hov == 'open':
                F.text('Click to travel', 508, 826, 14, BRASS, lh=18, align='center', width=248)
            else:
                F.text('Open · nothing to do yet', 508, 826, 14, TAN, lh=18, align='center', width=248)
    if locked:
        F.put('plate_locked_hover' if hov == 'advancement' else 'plate_locked', 1000, 428, shadow=2)
        if pop == 'advancement':
            F.frame9('frame_brass', 1000, 428, 248, 52, 8)
        F.text('Advancement Zone', 1000, 434, 16, CREAM, lh=18, align='center', width=248)
        f = F.font(14)
        tw = f.getlength('Tribulation Guardian') + 22
        x0 = 1000 + (248 - tw) / 2
        F.put('mini_swords', int(x0) // 2 * 2, 456)
        F.text('Tribulation Guardian', x0 + 22, 454, 14, CREAM, lh=18)
        F.put('plate_uncharted_hover' if hov == 'uncharted' else 'plate_uncharted', 836, 150, shadow=2)
        if pop == 'uncharted':
            F.frame9('frame_brass', 836, 150, 248, 52, 8)
        F.text('Uncharted', 836, 156, 16, CREAM if hov == 'uncharted' else TAN, lh=18, align='center', width=248)
        F.text('After the Tribulation', 836, 176, 14, TAN, lh=18, align='center', width=248)
    # brackets
    spots = {'advancement': geom.ZONES['advancement'], 'uncharted': geom.ZONES['uncharted'], 'open': geom.ZONES['test']}
    if hov in spots and hov != pop and (hov != 'open' or (demo and zone == 'valley')) and (hov == 'open' or locked):
        x, y = geom.centre(*spots[hov])
        F.put('bracket_hover', x - 184, y - 210)
    if pop in spots:
        x, y = geom.centre(*spots[pop])
        F.put('bracket_pinned', x - 184, y - 210)
    # popovers
    if locked and (pop == 'advancement' or (hov == 'advancement' and pop == 'none')):
        pinned = pop == 'advancement'
        h = 172 if pinned else 132
        y = 417 - h // 2
        X = 684                      # card 264 wide + 8 px notch on the right, tip at x 956
        F.put('pop_locked' if pinned else 'pop_locked_preview', X, y, shadow=4)
        F.put('seal_locked', X + 16, y + 14)
        F.put('mini_lock', X + 24, y + 17)
        F.text('LOCKED', X + 42, y + 14, 13, CREAM, lh=22)
        if pinned:
            F.put('close', X + 264 - 16 - 28, y + 12)
        F.text('Advancement Zone', X + 16, y + 46, 18, CREAM, lh=22)
        F.text('Defeat the Tribulation Guardian', X + 16, y + 74, 15, CREAM, lh=20)
        F.text('in The Shallow Woods', X + 16, y + 94, 15, CREAM, lh=20)
        if pinned:
            F.put('showme', X + 16, y + 124, shadow=2)
            w = F.font(14).getlength('Show me')
            F.text('Show me', X + 16 + (104 - w - 16) / 2, y + 124, 14, CREAM, lh=32)
            F.put('chev', int(X + 16 + (104 - w - 16) / 2 + w + 6) // 2 * 2, y + 134)
    if locked and (pop == 'uncharted' or (hov == 'uncharted' and pop == 'none')):
        pinned = pop == 'uncharted'
        y = 132 - 56
        X = 1128                     # 8 px notch on the left, tip at x 1128
        F.put('pop_uncharted' if pinned else 'pop_uncharted_preview', X, y, shadow=4)
        F.put('tag_wide', X + 24, y + 14)
        F.text('UNKNOWN', X + 24, y + 14, 13, TAN, lh=22, align='center', width=88)
        if pinned:
            F.put('close', X + 8 + 264 - 16 - 28, y + 12)
        F.text('Uncharted', X + 24, y + 46, 18, CREAM, lh=22)
        F.text('Revealed after the Tribulation.', X + 24, y + 74, 15, CREAM, lh=20)

    # ------------------------------------------------------------------ left column
    F.put('cult', 24, 24, shadow=4)
    madra, cap = (25, 100) if fresh else (46, 260)
    strip = img('orb_madra_strip')
    k = round(madra / cap * 32)
    F.put(None, 42, 40, im=strip.crop((k * 80, 0, k * 80 + 80, 80)))
    F.text('Madra', 138, 46, 15, TAN, lh=18)
    w = F.text(str(madra) + ' ', 138, 68, 30, CREAM, lh=36)
    F.text('/ %d' % cap, 138 + w, 68, 30, TAN, lh=36)
    if cur == 'well':
        F.text('+1.5 / s', 446, 80, 17, TAN, lh=20, align='right')
    core = img('orb_core_strip')
    lvl = 0 if fresh else 32
    k = round(lvl / 100 * 16)
    F.put(None, 42, 132, im=core.crop((k * 80, 0, k * 80 + 80, 80)))
    F.text('Core Density', 138, 134, 15, TAN, lh=18)
    F.text('Foundation', 138, 154, 21, CREAM, lh=28, yatra=True, shadow=(2, 2, INK))
    F.text('Level %d' % lvl, 446, 160, 17, CREAM, lh=20, align='right')
    xp, need = (3, 10) if fresh else (17, 18)
    beads = img('beads_xp_strip')
    lit = round(xp / need * 18)
    F.put(None, 138, 192, im=beads.crop((0, lit * 12, beads.width, lit * 12 + 12)))
    F.text('%d / %d XP' % (xp, need), 446, 189, 15, TAN, lh=18, align='right')
    F.put('line', 40, 222)
    F.put('ic_coin', 50, 232)
    w = F.text('%d ' % (0 if fresh else 120), 92, 234, 22, CREAM, lh=28)
    F.text('gold', 92 + w, 238, 17, TAN, lh=22)

    F.put('goals', 24, 272, shadow=4)
    F.text('Goals', 42, 302, 22, BRASS, lh=28, yatra=True, shadow=(2, 2, INK))
    F.put('ic_story_ai.png', 44, 340, im=img('ic_story_ai.png').resize((32, 32), Image.NEAREST))
    F.text('Awaken Your Core' if fresh else 'First Elite', 88, 338, 17, CREAM, lh=20)
    if fresh:
        F.text('%d / 100' % madra, 446, 338, 15, TAN, lh=20, align='right')
    F.text('Fill your Madra by cycling' if fresh else 'Defeat an elite in The Shallow Woods', 88, 360, 15, TAN, lh=18)
    F.put('line', 40, 392)
    F.put('ic_core', 44, 410)
    F.text('Breakthrough', 88, 408, 17, CREAM, lh=20)
    F.text('Raise Core Density to 100', 88, 430, 15, TAN, lh=18)
    F.rod('rod_goal', 88, 460, lvl / 100)
    F.text('%d / 100' % lvl, 446, 456, 15, TAN, lh=18, align='right')

    F.put('log', 24, 852, shadow=4)
    F.text('Log', 42, 866, 22, BRASS, lh=28, yatra=True, shadow=(2, 2, INK))
    F.text('Full log · L', 446, 872, 15, TAN, lh=18, align='right')
    if fresh:
        feed = [('Spoke with the Intervener', 'brass'), ('Learned Wilderness Cycling', 'tan')]
    elif zone == 'test':
        feed = [('Returned from The Shallow Woods · +34 gold', 'brass'), ('Resumed the Aura Well', 'tan'),
                ('Aura Well reached level 2 · +1 Spirit', 'madra'), ('Travelled to Test Zone', 'tan')]
    else:
        feed = [('Found 3 Dewdrop Tear, 4 Spirit Fern', 'cream'), ('Aura Well reached level 2 · +1 Spirit', 'madra'),
                ('Returned from The Shallow Woods · +34 gold', 'brass'),
                ('Resumed ' + ('foraging' if cur == 'forage' else 'the Aura Well'), 'tan'),
                ('Started ' + ('foraging' if cur == 'forage' else 'the Aura Well'), 'tan')]
    tone = {'brass': BRASS, 'cream': CREAM, 'madra': MADRA, 'tan': TAN}
    n = len(feed)
    for i, (t, tn) in enumerate(feed):
        age = n - 1 - i
        col = tone[tn] if age <= 1 else (TAN if age == 2 else DIM)
        bul = tn if age <= 1 else ('tan' if age == 2 else 'dim')
        y = 1014 - age * 26
        F.put('bullet_' + bul, 44, y + 4)
        F.text(t, 62, y, 15, col, lh=18)

    # ------------------------------------------------------------------ dock
    F.put('dock', 722, 976, shadow=4)
    for i, (label, key, icon) in enumerate((('Inventory', 'I', 'inventory_icon.png'), ('Abilities', 'A', 'ic_abilities'),
                                            ('Character', 'C', 'ic_character'), ('Path', 'P', 'ic_star'))):
        x = 732 + i * 116
        F.put('btn_ring' if key == 'P' else 'btn', x, 984, shadow=2)
        ic = img(icon) if icon != 'inventory_icon.png' else img(icon).resize((32, 32), Image.NEAREST)
        F.put(None, x + 38, 990, im=ic)
        F.text(label, x, 1024, 14, CREAM, lh=18, align='center', width=108)
        F.text(key, x + 108 - 12, 988, 14, TAN, lh=18, align='right')
    F.put('seal_count', 1074, 978)
    F.text('1', 1074, 981, 15, CREAM, lh=18, align='center', width=24)

    # ------------------------------------------------------------------ zone chest
    F.put('chest', 1456, 24, shadow=4)
    F.put('thumb' if zone == 'valley' else 'thumb_basic', 1472, 38)
    F.text('Spirit Valley' if zone == 'valley' else 'Test Zone', 1530, 40, 30, BRASS, lh=44, yatra=True, shadow=(2, 2, INK))
    if zone == 'valley':
        F.put('about_open' if lore else 'about', 1792, 46, shadow=0 if lore else 2)
        F.text('About', 1792, 46 + (2 if lore else 0), 15, CREAM, lh=36, align='center', width=88)
    if cur:
        F.put('now_tray', 1472, 106)
        F.put('now_plate', 1484, 96, shadow=2)
        F.text('Now', 1484, 96, 14, INK, lh=22, align='center', width=60)
        ring = img('ring_strip')
        fr = 5 if cur == 'well' else 8
        F.put(None, 1486, 122, im=ring.crop((fr * 56, 0, fr * 56 + 56, 56)))
        F.put(None, 1498, 134, im=img('ic_well_ai.png' if cur == 'well' else 'ic_forage_ai.png').resize((32, 32), Image.NEAREST))
        if cur == 'well':
            F.text('Aura Well', 1556, 118, 18, CREAM, lh=22)
            w = F.font(16).getlength('+1.5 Madra / s')
            F.put('mini_madra', int(1864 - w - 22) // 2 * 2, 122)
            F.text('+1.5 Madra / s', 1864, 118, 16, CREAM, lh=22, align='right')
            F.text('Lv 1 → 2 · +1 Spirit', 1556, 144, 15, TAN, lh=18)
            F.text('214 / 300', 1864, 144, 15, TAN, lh=18, align='right')
            F.rod('rod_well', 1556, 170, 214 / 300)
        else:
            F.text('Spring Forest Foraging', 1556, 124, 18, CREAM, lh=22)
            F.put('mini_dewdrop', 1556, 156)
            F.text('1–5', 1578, 154, 15, TAN, lh=20)
            F.put('mini_fern', 1616, 156)
            F.text('2–6', 1638, 154, 15, TAN, lh=20)
            F.text('haul in 3 s', 1864, 154, 15, CREAM, lh=20, align='right')
        if flash == 'strip':
            F.frame9('frame_brass', 1472, 106, 408, 88, 8)
    hy = 206 if cur else 104
    ly = 232 if cur else 132
    lh = 808 if cur else 908
    groups = build_groups(fresh, nine, zone)
    count = sum(len(g[1]) for g in groups)
    w1 = F.text('Activities', 1472, hy - 2, 20, BRASS, lh=24, yatra=True, shadow=(2, 2, INK))
    cnt = '%d here' % count
    w2 = F.font(15).getlength(cnt)
    F.text(cnt, 1880, hy, 15, TAN, lh=20, align='right')
    gx0, gx1 = 1472 + int(w1) + 12, 1880 - int(w2) - 12
    gx0 += gx0 % 2
    F.tile_x('groove', gx0, hy + 8, gx1 - gx0 - 6)
    F.put('groove_end', gx0 + (gx1 - gx0 - 6), hy + 8)

    # list content into its own layer, clipped to the viewport
    content = []
    y = 0
    for gi, (gname, cards) in enumerate(groups):
        if gi:
            y += 14
        content.append(('label', gname, y))
        y += 24
        for ci, card in enumerate(cards):
            if ci:
                y += 8
            content.append(('card', card, y))
            y += 96 if card['tall'] else 72
    total = y
    off = max(0, total - lh) if scrolled else 0
    layer = Image.new('RGBA', (1920, 1080), (0, 0, 0, 0))
    saved_im, saved_d = F.im, F.d
    F.im, F.d = layer, ImageDraw.Draw(layer)
    if not groups:
        F.text('Nothing to do here yet.', 1472, ly + 8, 15, TAN, lh=18)
    for kind, obj, yy in content:
        Y = ly + yy - off
        if kind == 'label':
            w = F.text(obj, 1472, Y, 15, TAN, lh=18)
            g0 = 1472 + int(w) + 10
            g0 += g0 % 2
            F.tile_x('groove', g0, Y + 7, 1864 - g0 - 6)
            F.put('groove_end', 1864 - 6, Y + 7)
        else:
            draw_card(F, obj, 1472, Y, cur, flash)
    F.im, F.d = saved_im, saved_d
    clip = layer.crop((1472, ly, 1880, ly + lh))
    F.im.paste(clip, (1472, ly), clip)
    # rail
    if total > lh:
        F.put('rail_up_on' if off > 0 else 'rail_up_off', 1868, ly)
        F.put('rail_down_on' if off < total - lh else 'rail_down_off', 1868, ly + lh - 14)
        F.tile_y('rail_track', 1868, ly + 14, lh - 28)
        th = max(32, round((lh - 28) * lh / total / 2) * 2)
        ty = ly + 14 + round((lh - 28 - th) * (off / (total - lh)) / 2) * 2
        th_img = img('rail_thumb')
        F.put(None, 1868, ty, im=th_img.crop((0, 0, 12, 4)))
        mid = th_img.crop((0, 4, 12, 8)).resize((12, th - 8), Image.NEAREST)
        F.put(None, 1868, ty + 4, im=mid)
        F.put(None, 1868, ty + th - 4, im=th_img.crop((0, 8, 12, 12)))
        if off > 0:
            F.put('lip_top', 1472, ly)
        if off < total - lh:
            F.put('lip_bottom', 1472, ly + lh - 10)
    if lore and zone == 'valley':
        F.put('lore', 1472, hy, shadow=4)
        paras = ["Deep at the heart of the world lies Spirit Valley, a sanctuary revered as the cradle of power. This lush basin overflows with vital aura, drawing young sacred artists to its peaks to meditate on the roots of their paths.",
                 "In this place of beginnings, aspiring masters temper their spirits, learning the fundamental techniques that will one day grant them the strength to shake the heavens."]
        yy = hy + 18
        f = F.font(16)
        for p in paras:
            words, line = p.split(), ''
            for wd in words:
                t = (line + ' ' + wd).strip()
                if f.getlength(t) > 364:
                    F.text(line, 1494, yy, 16, CREAM, lh=22)
                    yy += 22
                    line = wd
                else:
                    line = t
            F.text(line, 1494, yy, 16, CREAM, lh=22)
            yy += 32
    return F.im


def build_groups(fresh, nine, zone):
    def c(id_, title, icon, tag, sub=None, tall=False, new=False, idle=False, kind=None):
        return dict(id=id_, title=title, icon=icon, tag=tag, sub=sub, tall=tall, new=new, idle=idle, kind=kind)
    cyc = c('cycling', 'Wilderness Cycling', 'ic_cycle_ai.png', 'ACTIVE',
            ('Foundational Technique' if fresh else 'Smooth Flow') + ' · Madra and Core Density XP')
    if zone == 'test':
        return []
    if fresh:
        return [('Cultivate', [cyc])]
    well = c('well', 'Aura Well', 'ic_well_ai.png', 'IDLE', '+1.5 Madra / s · each level +1 Spirit', idle=True)
    forage = c('forage', 'Spring Forest Foraging', 'ic_forage_ai.png', 'IDLE', None, idle=True, kind='forage')
    woods = c('woods', 'The Shallow Woods', 'ic_swords', 'ACTIVE', None, tall=True, kind='woods')
    merch = c('merchant', 'Traveling Merchant', 'ic_merchant_ai.png', 'SHOP', '7 wares · you have 120 gold', new=True)
    g = []
    if nine:
        g.append(('Talk', [c('talk1', 'The Intervener', 'ic_story_ai.png', 'STORY', 'Your next story step', new=True),
                           c('talk2', 'A wandering cultivator', 'ic_story_ai.png', 'STORY', 'Placeholder')]))
    g.append(('Cultivate', [cyc, well]))
    g.append(('Gather', [forage] + ([c('gather2', 'Riverbank Gathering', 'ic_forage_ai.png', 'IDLE', 'Placeholder', idle=True)] if nine else [])))
    g.append(('Venture', [woods] + ([c('venture2', 'The Deep Thicket', 'ic_swords', 'ACTIVE', 'Placeholder')] if nine else [])))
    g.append(('Visit', [merch]))
    return g


def draw_card(F, card, x, y, cur, flash):
    running = card['idle'] and card['id'] == cur
    tall = card['tall']
    madra = MADRA_NOW
    ready = card['kind'] == 'woods' and madra >= 60
    if running:
        F.put('drawer_run', x - 2, y - 2, shadow=4)
        x, y = x - 2, y - 2
    elif tall:
        F.put('drawer_tall_ready' if ready else 'drawer_tall', x, y, shadow=2)
    else:
        F.put('drawer', x, y, shadow=2)
    if flash == card['id']:
        F.frame9('frame_brass', x, y, 392, 96 if tall else 72, 8)
    ic = card['icon']
    icon = img(ic)
    if icon.width == 16:
        icon = icon.resize((32, 32), Image.NEAREST)
    F.put(None, x + 16, y + 20, im=icon)
    ty = y + 26 if ready else y + 14
    tw = F.text(card['title'], x + 64, ty, 17, CREAM, lh=20)
    if card['new']:
        F.put('seal_new_s', x + 64 + int(tw) // 2 * 2 + 10, ty - 1)
        F.text('NEW', x + 64 + int(tw) // 2 * 2 + 10, ty - 1, 13, CREAM, lh=22, align='center', width=44)
    tag = 'RUNNING' if running else card['tag']
    F.put('tag_enter' if (ready and tag == 'ACTIVE') else 'tag', x + 392 - 12 - 76, ty - 1)
    F.text('ENTER' if (ready and tag == 'ACTIVE') else tag, x + 392 - 12 - 76, ty - 1, 13,
           INK if ready else (CREAM if running else TAN), lh=22, align='center', width=76)
    if card['sub']:
        sub = card['sub']
        f = F.font(15)
        if f.getlength(sub) > 316:
            while f.getlength(sub + '…') > 316:
                sub = sub[:-1]
            sub = sub.rstrip() + '…'
        F.text(sub, x + 64, y + 38, 15, TAN, lh=18)
    if card['kind'] == 'forage':
        F.put('mini_dewdrop', x + 64, y + 40)
        F.text('1–5', x + 86, y + 38, 15, TAN, lh=18)
        F.put('mini_fern', x + 120, y + 40)
        F.text('2–6 · every 5 s · free', x + 142, y + 38, 15, TAN, lh=18)
    if card['kind'] == 'woods' and ready:
        F.text('Ready · carries up to 120 Madra · 5 min run', x + 64, y + 54, 15, BRASS, lh=18)
    if card['kind'] == 'woods' and not ready:
        F.put('mini_madra', x + 64, y + 41)
        F.text('Needs 60 Madra · you have %d' % madra, x + 86, y + 38, 15, TAN, lh=20)
        if ready:
            return
        F.rod('rod_adv', x + 64, y + 70, madra / 60)
        hint = 'ready in ~10 s' if cur == 'well' else 'train or cycle to fill'
        F.text(hint, x + 380, y + 66, 15, CREAM if cur == 'well' else TAN, lh=18, align='right')


# the dotted routes, every 24 px, snapped to the 2 px grid (top-left of each 8x8 dot)
def dots(points, step=24, skip_r=0):
    out = []
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        import math
        L = math.hypot(bx - ax, by - ay)
        n = int(L // step)
        for i in range(1, n + 1):
            t = i * step / L
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            out.append((int(round((x - 4) / 2)) * 2, int(round((y - 4) / 2)) * 2))
    return out


MADRA_NOW = 46
V = geom.centre(0, 0)
ROUTE_NORTH = [p for p in dots([V, geom.centre(0, -1), geom.centre(0, -2)])]
ROUTE_WEST = dots([V, geom.centre(-1, 0)])

if __name__ == '__main__':
    out = sys.argv[1]
    opts = dict(a.split('=') for a in sys.argv[2:])
    build(opts).convert('RGB').save(B.SCRATCH + 'lacquer_full/tmp/' + out)
