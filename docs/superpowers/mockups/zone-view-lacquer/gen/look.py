"""Quick look: tile some kit files onto one image (optionally zoomed) for review."""
import sys
from PIL import Image, ImageDraw

A = ("C:/Users/lione/AppData/Local/Temp/claude/C--worktrees-EndlessPath-endless-path-js-vs-godot-fe1f72/"
     "c2134538-305c-43cf-9f63-9a433ef4bec2/scratchpad/lacquer_full/")


def look(names, out, zoom=1, maxw=1800, bg=(9, 14, 14, 255)):
    ims = []
    for n in names:
        p = n if ('/' in n or ':' in n) else A + 'assets/' + n
        im = Image.open(p).convert('RGBA')
        if zoom != 1:
            im = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
        ims.append((n, im))
    x = y = 8
    rowh = 0
    pos = []
    for n, im in ims:
        if x + im.width > maxw and x > 8:
            x = 8
            y += rowh + 22
            rowh = 0
        pos.append((x, y))
        x += im.width + 12
        rowh = max(rowh, im.height)
    H = y + rowh + 24
    sheet = Image.new('RGBA', (maxw, H), bg)
    d = ImageDraw.Draw(sheet)
    for (n, im), (px, py) in zip(ims, pos):
        sheet.paste(im, (px, py), im)
        d.text((px, py + im.height + 2), n.replace('lacquer_', '').replace('_ai.png', '')[-28:], fill=(168, 144, 112, 255))
    sheet.save(A + 'tmp/' + out)


if __name__ == '__main__':
    z = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    look(sys.argv[3:], sys.argv[1], zoom=z)
