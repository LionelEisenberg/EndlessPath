"""The holed coin from lacquer_work/v2/coin.py (it replaced gen2's coin pile in the swatch)."""
import math
import lq_base as g

def coin(name):
    D = 16
    img = g.new(D, D)
    c = 7.5
    for y in range(D):
        for x in range(D):
            r = math.hypot(x - c, y - c)
            if r > 7.3:
                continue
            ang = math.atan2(y - c, x - c)
            light = math.cos(ang + math.pi * 0.75)
            if r > 6.3:
                col = g.WARM_OL
            elif r > 5.3:
                col = g.GOLD_Y
                if light > 0.45:
                    col = g.CREAM
                elif light < -0.35:
                    col = g.GOLD_C
            else:
                col = g.GOLD_Y
                if light < -0.6 and r > 4.3:
                    col = g.GOLD_C
            img.putpixel((x, y), col)
    # square hole with a dark lip
    for y in range(5, 11):
        for x in range(5, 11):
            if 6 <= x <= 9 and 6 <= y <= 9:
                img.putpixel((x, y), g.CLEAR)
            else:
                img.putpixel((x, y), g.WARM_OL)
    # lit lower-right lip of the hole (light falls into it from the top-left)
    for i in range(6, 10):
        img.putpixel((i, 10), g.GOLD_C if i < 9 else g.GOLD_C)
        img.putpixel((10, i), g.GOLD_C)
    img.putpixel((10, 10), g.WARM_OL)
    g.save(img, name)

coin('ic_coin')
