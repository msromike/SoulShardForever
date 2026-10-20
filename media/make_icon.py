# Soul Shards Forever (SSF): draws the 400x400 CurseForge logo.
#
# The logo today is media/ssf_new.png (2026-10-20): python make_icon.py ssf_new.png --table 0.34
# The defaults draw the 2026-09-27 logo (ssf.png, facets meeting in a point) exactly.
#
# A faceted soul shard in the Soul Shard icon's purples, corner to corner on near-black,
# in a flat gold frame, with "SSF" across the bottom. Recovered from the session that made
# the 2026-09-27 logo (commit ad9a697), so a tweak is a setting here, not a redraw by hand.
#
#   python make_icon.py OUT.png [--table K] [--flat]
#
# TABLE (--table): 0 draws the shard's facets meeting in a point, as the 2026-09-27 logo
# does. Above 0 the face gets a flat table facet, like a cut jewel: the outline scaled by K
# around the old meeting point, with a facet from each table edge out to the outline.
# FLAT (--flat, with a table): the table's bottom corner, the one aimed at the tip, is cut
# off by one more facet: a short one hanging under the cut, between the two lower facets,
# which still meet along their old line down to the tip. The table stays the same size
# less that corner (CUT: how far up its two bottom edges the cut sits, from the corner;
# DROP: how far the short facet reaches toward the tip, as a share of the way).

import argparse
from PIL import Image, ImageDraw, ImageFont

S, INSET, BORDER = 400, 24, 10
GOLD, FRAME_DARK, BACK = (212, 160, 40, 255), (20, 14, 6, 255), (14, 6, 22, 255)
HI, LIGHT, MID, DARK, DEEP = (240, 190, 255), (205, 120, 245), (165, 75, 220), (115, 40, 170), (80, 22, 125)
TABLE_FILL = (225, 165, 252)   # the table faces the viewer: lighter than every facet but HI
CUT_FILL = (185, 95, 232)      # the facet under the table's cut corner: between MID and LIGHT
CUT = 0.45                     # where the cut meets the table's bottom edges, from its corner
DROP = 0.12                    # how far the short facet reaches toward the tip
EDGE = (60, 10, 90)


def frame(c):
    d = ImageDraw.Draw(c)
    d.rounded_rectangle((INSET-BORDER-2, INSET-BORDER-2, S-INSET+BORDER+1, S-INSET+BORDER+1), radius=14, fill=FRAME_DARK)
    d.rounded_rectangle((INSET-BORDER, INSET-BORDER, S-INSET+BORDER-1, S-INSET+BORDER-1), radius=12, fill=GOLD)
    d.rounded_rectangle((INSET-2, INSET-2, S-INSET+1, S-INSET+1), radius=6, fill=FRAME_DARK)
    d.rectangle((INSET, INSET, S-INSET-1, S-INSET-1), fill=BACK)


def shard(table, flat=False):
    """the shard upright on its own layer, then turned 45 degrees to run corner to corner"""
    inner = S - 2*INSET
    L = int(inner * 1.41 * 0.90)
    layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    g = ImageDraw.Draw(layer)
    cx, cy = L//2, L//2
    half = L//2 - 6
    top, bot = (cx, cy-half), (cx, cy+half)
    w = int(half * 0.72)
    girdle = -int(half*0.30)                  # the widest line: short crown, long tail
    l, r = (cx-w, cy+girdle), (cx+w, cy+girdle)
    ul, ur = (cx-int(w*0.58), cy-int(half*0.68)), (cx+int(w*0.58), cy-int(half*0.68))
    mid = (cx, cy+girdle)                     # where the facets meet (TABLE 0)
    outline = [l, ul, top, ur, r, bot]
    # each facet: the outline edge it runs from, and its color
    facets = [((ul, top), DEEP), ((top, ur), DARK), ((l, ul), DARK),
              ((ur, r), MID), ((bot, l), LIGHT), ((r, bot), HI)]

    def inward(p):                            # an outline point pulled toward mid by TABLE
        return (mid[0] + table*(p[0]-mid[0]), mid[1] + table*(p[1]-mid[1]))

    if flat and table > 0:
        tb = inward(bot)                      # the table's corner aimed at the tip, cut off
        c1 = (tb[0] + CUT*(inward(l)[0]-tb[0]), tb[1] + CUT*(inward(l)[1]-tb[1]))
        c2 = (tb[0] + CUT*(inward(r)[0]-tb[0]), tb[1] + CUT*(inward(r)[1]-tb[1]))
        for (a, b), color in facets[:4]:      # the crown facets, as before
            g.polygon([a, b, inward(b), inward(a)], fill=color)
        # the short facet's lower point: a little way from the old corner toward the tip,
        # where the two lower facets' shared line now starts
        pt = (tb[0] + DROP*(bot[0]-tb[0]), tb[1] + DROP*(bot[1]-tb[1]))
        g.polygon([l, bot, pt, c1, inward(l)], fill=LIGHT)
        g.polygon([bot, r, inward(r), c2, pt], fill=HI)
        g.polygon([c1, c2, pt], fill=CUT_FILL)   # the new short facet under the cut
        g.polygon([inward(p) for p in [l, ul, top, ur, r]] + [c2, c1], fill=TABLE_FILL, outline=EDGE, width=3)
        g.polygon(outline, outline=EDGE, width=4)
        for p in [l, ul, top, ur, r]:
            g.line([p, inward(p)], fill=EDGE, width=3)
        g.line([c1, pt], fill=EDGE, width=3)
        g.line([c2, pt], fill=EDGE, width=3)
        g.line([pt, bot], fill=EDGE, width=3)
    else:
        for (a, b), color in facets:
            g.polygon([a, b, inward(b), inward(a)], fill=color)
        if table > 0:
            g.polygon([inward(p) for p in outline], fill=TABLE_FILL, outline=EDGE, width=3)
        g.polygon(outline, outline=EDGE, width=4)
        for p in outline:
            g.line([p, inward(p)], fill=EDGE, width=3)

    layer = layer.rotate(45, resample=Image.BICUBIC, expand=True)
    lw, lh = layer.size
    full = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    full.paste(layer, (S//2 - lw//2, S//2 - lh//2), layer)
    clip = Image.new("L", (S, S), 0)
    ImageDraw.Draw(clip).rectangle((INSET, INSET, S-INSET-1, S-INSET-1), fill=255)
    full.putalpha(Image.composite(full.getchannel("A"), Image.new("L", (S, S), 0), clip))
    return full


def label(c):
    """SSF in white with a black outline, letter-spaced, low in the frame"""
    d = ImageDraw.Draw(c)
    font = None
    for f in [r"C:\Windows\Fonts\impact.ttf", r"C:\Windows\Fonts\arialbd.ttf"]:
        try:
            font = ImageFont.truetype(f, 140)
            break
        except OSError:
            pass
    gap = 14
    letters = ["S", "S", "F"]
    boxes = [d.textbbox((0, 0), ch, font=font) for ch in letters]
    widths = [b[2]-b[0] for b in boxes]
    total = sum(widths) + gap * (len(letters) - 1)
    bb = d.textbbox((0, 0), "SSF", font=font)
    y = S - INSET - 22 - (bb[3]-bb[1]) - bb[1]   # text bottom 22px above the frame's inner edge
    x = (S - total)//2
    for ch, b, wch in zip(letters, boxes, widths):
        ox = x - b[0]
        for dx in range(-6, 7):
            for dy in range(-6, 7):
                if dx*dx+dy*dy <= 36:
                    d.text((ox+dx, y+dy), ch, font=font, fill=(0, 0, 0, 255))
        d.text((ox, y), ch, font=font, fill=(255, 255, 255, 255))
        x += wch + gap


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--table", type=float, default=0.0, help="table facet size, 0 = facets meet in a point")
    ap.add_argument("--flat", action="store_true", help="flat table bottom, no corner toward the tip")
    args = ap.parse_args()
    c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    frame(c)
    c.alpha_composite(shard(args.table, args.flat))
    label(c)
    c.save(args.out)


if __name__ == "__main__":
    main()
