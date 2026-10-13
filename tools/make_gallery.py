#!/usr/bin/env python3
"""Build images/gallery/*.png, the Wago listing's gallery: one 1280x720 card
per in-game screenshot in images/screenshots, in the Goblin look (Look.lua's
palette): the window colour, a gold top edge, a Cinzel title and a caption on
the left, the screenshot framed on the right.

Add a screenshot to images/screenshots and a line to CARDS, then
run from anywhere: python tools/make_gallery.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "images" / "screenshots"
OUT = ROOT / "images" / "gallery"
TITLE_FONT = ROOT / "tools" / "fonts" / "Cinzel.ttf"
BODY_FONT = Path(r"C:\Windows\Fonts\segoeui.ttf")

W, H = 1280, 720
TEXT_W = 420  # the left column
PAD = 56
GAP = 48        # between the text and the screenshot
MAX_SCALE = 2   # a small bar shot is enlarged at most this much, so it stays sharp

# Look.COLOUR
WINDOW = (0x16, 0x17, 0x1A)
INSET = (0x0F, 0x10, 0x12)
LINE = (0x33, 0x36, 0x3C)
GOLD = (0xD6, 0xAA, 0x4E)
TEXT = (0xEC, 0xE6, 0xD8)
DIM = (0x9A, 0x94, 0x88)

# (output name, screenshot, title, caption), in gallery order.
CARDS = [
    ("1-window", "window.png", "One window",
     "Nine flyouts. Drag an icon onto your action bar to place its button, and choose which way "
     "each bar opens."),
    ("2-food-and-drink", "meals.png", "Food & Drink",
     "Everything you can eat, then everything you can drink, best first, with stack counts."),
    ("3-professions", "professions.png", "Professions",
     "Every profession with a crafting window, in Blizzard's tab order. Hover for your skill."),
    ("4-your-icons", "icon_selection.png", "Your icons",
     "Right-click a button's icon in the window to pick any other in Blizzard's macro window."),
]


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=font) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def card(shot, title, caption):
    im = Image.new("RGB", (W, H), WINDOW)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, W - 1, 3), fill=GOLD)  # the gold top edge
    d.rectangle((0, 0, W - 1, H - 1), outline=LINE)

    # The title at 46 px, smaller if it would not fit the column.
    size = 46
    while True:
        title_font = ImageFont.truetype(str(TITLE_FONT), size)
        title_font.set_variation_by_axes([700])
        if d.textlength(title, font=title_font) <= TEXT_W - PAD or size <= 24:
            break
        size -= 2
    body_font = ImageFont.truetype(str(BODY_FONT), 24)
    small_font = ImageFont.truetype(str(BODY_FONT), 18)
    y = 250
    d.text((PAD, y), title, font=title_font, fill=GOLD)
    y += 72
    for line in wrap(d, caption, body_font, TEXT_W - PAD):
        d.text((PAD, y), line, font=body_font, fill=TEXT)
        y += 34
    d.text((PAD, H - PAD - 18), "Goblin Flyout  ·  Time is money, friend.", font=small_font, fill=DIM)

    # The screenshot, as large as fits the right side, in an inset well.
    left = TEXT_W + GAP
    area_w, area_h = W - left - PAD, H - 2 * PAD
    src = Image.open(SHOTS / shot).convert("RGB")
    scale = min(area_w / src.width, area_h / src.height, MAX_SCALE)
    size = (round(src.width * scale), round(src.height * scale))
    src = src.resize(size, Image.LANCZOS)
    x = left + (area_w - size[0]) // 2
    top = PAD + (area_h - size[1]) // 2
    d.rectangle((x - 9, top - 9, x + size[0] + 8, top + size[1] + 8), fill=INSET, outline=LINE)
    im.paste(src, (x, top))
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shot, title, caption in CARDS:
        path = OUT / (name + ".png")
        card(shot, title, caption).save(path)
        print("Wrote", path)


if __name__ == "__main__":
    main()
