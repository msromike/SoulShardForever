"""Shot 5 composite: the stock minimap icon and the data bar broker, side by side.

Each capture at 1x in a thin border, vertically centred, on the minimap shot's own dark
backdrop. Run from anywhere: python make_composite.py
Reads 05_src_minimap_stock.png and 05_src_broker.png, writes 04_minimap_and_broker.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent

PAD = 24
GAP = 32
BORDER = 2
BORDER_RGB = (170, 140, 80)
TITLES = ("Stock Minimap", "EllesmereUI Broker")
TITLE_FONT = HERE.parents[2] / "EllesmereUI" / "media" / "fonts" / "FiraSans Medium.ttf"
TITLE_SIZE = 28
TITLE_RGB = (255, 209, 0)  # the game's gold
TITLE_GAP = 10             # title baseline to frame


def backdrop(im):
    """Average of the image's top-left corner."""
    return im.crop((0, 0, 6, 6)).resize((1, 1), Image.BOX).getpixel((0, 0))


def framed(out, im, x, y):
    ImageDraw.Draw(out).rectangle(
        (x, y, x + im.width + BORDER * 2 - 1, y + im.height + BORDER * 2 - 1), fill=BORDER_RGB)
    out.paste(im, (x + BORDER, y + BORDER))


def main():
    left = Image.open(HERE / "05_src_minimap_stock.png").convert("RGB")
    right = Image.open(HERE / "05_src_broker.png").convert("RGB")
    font = ImageFont.truetype(str(TITLE_FONT), TITLE_SIZE)
    title_h = font.getbbox("Ag")[3] + TITLE_GAP
    inner_h = max(left.height, right.height) + BORDER * 2
    width = PAD + left.width + GAP + right.width + BORDER * 4 + PAD
    height = PAD + title_h + inner_h + PAD
    out = Image.new("RGB", (width, height), backdrop(left))
    draw = ImageDraw.Draw(out)
    top = PAD + title_h
    x = PAD
    for im, title in zip((left, right), TITLES):
        y = top + (inner_h - im.height - BORDER * 2) // 2
        framed(out, im, x, y)
        w = draw.textlength(title, font=font)
        draw.text((x + (im.width + BORDER * 2 - w) / 2, y - title_h), title, font=font, fill=TITLE_RGB)
        x += im.width + BORDER * 2 + GAP
    out.save(HERE / "04_minimap_and_broker.png")
    print(out.size)


if __name__ == "__main__":
    main()
