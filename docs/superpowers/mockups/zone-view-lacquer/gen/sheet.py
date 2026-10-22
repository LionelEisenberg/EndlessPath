"""Contact sheet of the kit: every texture at display size (big ones scaled, marked), labelled."""
from PIL import Image, ImageDraw, ImageFont

import lq_base as B

A = B.OUT
W = 2000
BG = (9, 14, 14, 255)
LABEL = (168, 144, 112, 255)
HEAD = (212, 168, 74, 255)
FONT = ImageFont.truetype(B.REPO + 'assets/fonts/BMEULJIROTTF.ttf', 14)
HFONT = ImageFont.truetype(B.REPO + 'assets/fonts/YatraOne-Regular.ttf', 26)


def load(n):
    p = A + (n if n.endswith('.png') else 'lacquer_' + n + '_ai.png')
    return Image.open(p).convert('RGBA')


def nine(n, w, h, sl):
    s = load(n)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    W_, H_ = s.size
    parts = [((0, 0, sl, sl), (0, 0, sl, sl)), ((W_ - sl, 0, W_, sl), (w - sl, 0, sl, sl)),
             ((0, H_ - sl, sl, H_), (0, h - sl, sl, sl)), ((W_ - sl, H_ - sl, W_, H_), (w - sl, h - sl, sl, sl)),
             ((sl, 0, W_ - sl, sl), (sl, 0, w - 2 * sl, sl)), ((sl, H_ - sl, W_ - sl, H_), (sl, h - sl, w - 2 * sl, sl)),
             ((0, sl, sl, H_ - sl), (0, sl, sl, h - 2 * sl)), ((W_ - sl, sl, W_, H_ - sl), (w - sl, sl, sl, h - 2 * sl))]
    for src, (x, y, ww, hh) in parts:
        p = s.crop(src).resize((ww, hh), Image.NEAREST)
        out.paste(p, (x, y), p)
    return out


class Sheet:
    def __init__(self):
        self.items = []

    def section(self, title):
        self.items.append(('head', title))

    def add(self, name, im=None, label=None, scale=1, under=None):
        if im is None:
            im = load(name)
        disp = im.size
        if scale != 1:
            im = im.resize((int(im.width * scale), int(im.height * scale)), Image.NEAREST if scale >= 1 else Image.BOX)
        if under:
            base = Image.new('RGBA', im.size, under)
            base.paste(im, (0, 0), im)
            im = base
        lab = label or name.replace('.png', '')
        lab += '  %dx%d' % disp + ('  (shown x%s)' % scale if scale != 1 else '')
        self.items.append(('img', lab, im))

    def render(self, out):
        x = y = 16
        rowh = 0
        placed = []
        for it in self.items:
            if it[0] == 'head':
                if x > 16:
                    y += rowh + 34
                x, rowh = 16, 0
                placed.append(('head', it[1], 16, y))
                y += 40
                continue
            _, lab, im = it
            lw = FONT.getlength(lab)
            w = max(im.width, int(lw))
            if x + w > W - 16 and x > 16:
                x = 16
                y += rowh + 34
                rowh = 0
            placed.append(('img', lab, im, x, y))
            x += w + 24
            rowh = max(rowh, im.height)
        H = y + rowh + 50
        sheet = Image.new('RGBA', (W, H), BG)
        d = ImageDraw.Draw(sheet)
        for p in placed:
            if p[0] == 'head':
                d.text((p[2], p[3]), p[1], font=HFONT, fill=HEAD)
                continue
            _, lab, im, px, py = p
            sheet.paste(im, (px, py), im)
            d.text((px, py + im.height + 4), lab, font=FONT, fill=LABEL)
        sheet.convert('RGB').save(out)
        return sheet.size


def strip_frames(name, fw, frames, scale=1):
    s = load(name)
    out = Image.new('RGBA', (len(frames) * (fw + 8), s.height), (0, 0, 0, 0))
    for i, k in enumerate(frames):
        f = s.crop((k * fw, 0, k * fw + fw, s.height))
        out.paste(f, (i * (fw + 8), 0), f)
    return out


def main():
    S = Sheet()
    S.section('Panels (display size)')
    for n in ('cult', 'goals', 'log1', 'log2', 'log5', 'lore', 'now_tray', 'dock', 'token'):
        S.add(n, scale=3 if n == 'token' else 1)
    top, mid, bot = load('chest_top'), load('chest_mid'), load('chest_bot')
    ch = Image.new('RGBA', (440, 560), (0, 0, 0, 0))
    ch.paste(top, (0, 0))
    for y in range(128, 512, 128):
        ch.paste(mid, (0, y))
    ch.paste(bot, (0, 512))
    S.add('chest', im=ch, label='chest_top + chest_mid (repeat-y) + chest_bot at 560 tall')
    S.section('Drawers, marks, buttons')
    for n in ('drawer', 'drawer_run', 'drawer_tall', 'drawer_tall_ready'):
        S.add(n)
    S.add('frame_brass', im=nine('frame_brass', 392, 64, 8), label='frame_brass as border-image 8 / 8px on 392x64')
    S.add('frame_hover', im=nine('frame_hover', 392, 64, 4), label='frame_hover as border-image 4 / 4px on 392x64')
    for n in ('tag', 'tag_enter', 'tag_wide', 'seal_new_s', 'seal_locked', 'seal_count', 'now_plate', 'about',
              'about_open', 'showme', 'close', 'close_hover', 'chev', 'btn', 'btn_ring', 'btn_hover'):
        S.add(n)
    S.section('Progress: orbs, beads, rods, rings')
    S.add('orb_madra_strip', im=strip_frames('orb_madra_strip', 80, [0, 4, 6, 8, 16, 24, 32]),
          label='orb_madra_strip frames 0 4 6 8 16 24 32 of 0..32')
    S.add('orb_core_strip', im=strip_frames('orb_core_strip', 80, [0, 1, 5, 8, 12, 16]),
          label='orb_core_strip frames 0 1 5 8 12 16 (row 0)')
    core = load('orb_core_strip').crop((5 * 80, 0, 6 * 80, 320))
    S.add('orb_core_phase', im=core, label='core frame 5, phase rows 0-3')
    bx = load('beads_xp_strip')
    S.add('beads', im=bx.crop((0, 17 * 12, bx.width, 18 * 12)), label='beads_xp_strip row 17 of 0..18')
    S.add('beads0', im=bx.crop((0, 0, bx.width, 12)), label='beads_xp_strip row 0')
    for r in ('rod_well', 'rod_goal', 'rod_adv'):
        S.add(r + '_empty')
        S.add(r + '_full')
        S.add(r + '_end', scale=4)
    S.add('ring_strip', im=strip_frames('ring_strip', 56, [0, 3, 5, 8, 12]), label='ring_strip frames 0 3 5 8 12 of 0..12')
    S.add('map_ring_strip', im=strip_frames('map_ring_strip', 64, [0, 3, 5, 8, 12]), label='map_ring_strip frames 0 3 5 8 12')
    S.section('Rail, lips, grooves, bullets')
    tr = Image.new('RGBA', (12, 120))
    t = load('rail_track')
    for yy in range(0, 120, t.height):
        tr.paste(t, (0, yy), t)
    S.add('rail_track', im=tr, label='rail_track tiled')
    th = load('rail_thumb')
    thumb = Image.new('RGBA', (12, 80))
    thumb.paste(th.crop((0, 0, 12, 4)), (0, 0))
    thumb.paste(th.crop((0, 4, 12, 8)).resize((12, 72), Image.NEAREST), (0, 4))
    thumb.paste(th.crop((0, 8, 12, 12)), (0, 76))
    S.add('rail_thumb', im=thumb, label='rail_thumb at 80 tall')
    for n in ('rail_up_on', 'rail_up_off', 'rail_down_on', 'rail_down_off'):
        S.add(n, scale=3)
    S.add('lip_top', under=(70, 32, 32, 255))
    S.add('lip_bottom', under=(70, 32, 32, 255))
    S.add('line')
    g = Image.new('RGBA', (200, 6))
    gt = load('groove')
    for xx in range(0, 194, 4):
        g.paste(gt, (xx, 0), gt)
    ge = load('groove_end')
    g.paste(ge, (194, 0), ge)
    S.add('groove', im=g, label='groove tiled + groove_end', under=(44, 20, 20, 255))
    for n in ('bullet_brass', 'bullet_cream', 'bullet_madra', 'bullet_tan', 'bullet_dim'):
        S.add(n, scale=3, under=(44, 20, 20, 255))
    S.section('Icons (16 px art at 32, 8 px minis at 16), glyphs, dots')
    for n in ('ic_core', 'ic_abilities'):
        S.add(n, scale=2)
    for n in ('character_icon.png', 'star_icon.png', 'gold_icon.png', 'combat_icon.png'):
        S.add(n, im=load(n).resize((32, 32), Image.NEAREST), label=n[:-4] + ' (user, 16 art px at 32)', scale=2)
    for n in ('cycle', 'forage', 'well', 'merchant', 'story', 'dewdrop', 'fern'):
        S.add('ic_%s_ai.png' % n, im=load('ic_%s_ai.png' % n).resize((32, 32), Image.NEAREST), label='ic_%s_ai (16 at 32)' % n, scale=2)
    S.add('inventory_icon.png', im=load('inventory_icon.png').resize((32, 32), Image.NEAREST), label='inventory_icon (user, 16 at 32)', scale=2)
    for n in ('mini_madra', 'mini_dewdrop', 'mini_forage', 'mini_fern', 'mini_well', 'mini_swords', 'mini_lock'):
        S.add(n, scale=3)
    S.add('glyph_twinkle_strip', scale=3)
    for n in ('glyph_lock', 'glyph_unknown', 'route_dot', 'route_dot_lit', 'char_shadow'):
        S.add(n, scale=2 if 'dot' in n or 'shadow' in n else 1)
    S.add('thumb')
    S.add('thumb_basic')
    S.section('Map pieces (zoom 2)')
    river = load('Hex_Forest_06_River.png').resize((328, 380), Image.NEAREST)
    cur = load('hex_current')
    comp = Image.new('RGBA', (328, 380), BG)
    comp.paste(river, (0, 0), river)
    comp.paste(cur, (0, 0), cur)
    S.add('hex_current', im=comp, label='hex_current over Hex_Forest_06_River')
    basic = load('Hex_Forest_00_Basic.png').resize((328, 380), Image.NEAREST)
    comp = Image.new('RGBA', (328, 380), BG)
    comp.paste(basic, (0, 0), basic)
    op = load('hex_open')
    comp.paste(op, (0, 0), op)
    S.add('hex_open', im=comp, label='hex_open over Hex_Forest_00_Basic')
    for n in ('tile_locked', 'tile_locked_hover', 'tile_uncharted', 'tile_uncharted_hover'):
        S.add(n, under=BG)
    comp = Image.new('RGBA', (328, 380), BG)
    comp.paste(basic, (0, 0), basic)
    hv = load('hex_hover')
    comp.paste(hv, (0, 0), hv)
    S.add('hex_hover', im=comp, label='hex_hover over Hex_Forest_00_Basic')
    for tile, rim in (('tile_locked_hover', 'hex_hover_in'), ('tile_locked', 'hex_pinned_in')):
        comp = Image.new('RGBA', (328, 380), BG)
        t = load(tile)
        r = load(rim)
        comp.paste(t, (0, 0), t)
        comp.paste(r, (0, 0), r)
        S.add(rim, im=comp, label=rim + ' over ' + tile)
    for n in ('plate_current', 'plate_current_hover', 'plate_open', 'plate_open_hover', 'plate_locked',
              'plate_locked_hover', 'plate_uncharted', 'plate_uncharted_hover'):
        S.add(n)
    for n in ('pop_locked', 'pop_locked_preview', 'pop_uncharted', 'pop_uncharted_preview'):
        S.add(n)
    S.section('Fog (atlases at x0.5, full-screen composites at x0.25)')
    for t in (1, 2, 3):
        S.add('fog_t%d_atlas' % t, scale=0.5)
    for st in ('base', 'open', 'locked', 'both'):
        S.add('fog_%s' % st, scale=0.25)
    size = S.render(B.SCRATCH + 'lacquer_full/kit_sheet.png')
    print('sheet', size)


if __name__ == '__main__':
    main()
