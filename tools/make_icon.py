#!/usr/bin/env python3
"""Build GoblinFlyout/Media/icon.tga (256x256 RGBA, round): the minimap
button and the AddOns-list icon.

GoblinQuest's icon recipe (D:\\goblinquest\\tools\\make_icon.py), with Goblin
Flyout's letters and disc: a shaded disc with a gold rim and "GF" in Cinzel
(tools/fonts, SIL Open Font License), gold with a dark outline and a drop
shadow. Everything is drawn at 4x and shrunk for smooth edges. Coordinates
are in a 100-unit square.
Run from anywhere: python tools/make_icon.py [preview_dir]
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "tools" / "fonts" / "Cinzel.ttf"
DEST = ROOT / "GoblinFlyout" / "Media" / "icon.tga"
SIZE = 256
BIG = SIZE * 4
S = BIG / 100  # pixels per unit

LETTERS = "GF"
# The disc, lit centre to dark edge. GoblinQuest is forest; Goblin Flyout is
# oxblood (picked by the owner 2026-10-12 from these four).
DISCS = {
    "forest": ((42, 110, 34), (11, 42, 9)),
    "teal": ((24, 104, 112), (5, 34, 40)),
    "oxblood": ((128, 34, 30), (44, 8, 8)),
    "iron": ((88, 96, 108), (24, 27, 32)),
}
DISC = "oxblood"
RIM, INNER_RING, OUTLINE = (217, 165, 32), (5, 20, 4), (30, 18, 2)
# Top-to-bottom gold of the letters: (position 0..1, colour).
GOLD = [(0.0, (255, 240, 160)), (0.35, (242, 195, 58)), (0.7, (200, 138, 18)), (1.0, (138, 90, 6))]


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gold_at(t):
    for (t0, c0), (t1, c1) in zip(GOLD, GOLD[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / (t1 - t0))
    return GOLD[-1][1]


def circle(draw, cx, cy, r, **kwargs):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), **kwargs)


def disc(centre, edge) -> Image.Image:
    # Radial shade: light a little up and left of centre, dark at the rim.
    shade = Image.new("RGB", (BIG, BIG), edge)
    d = ImageDraw.Draw(shade)
    fx, fy, reach = 45 * S, 38 * S, 65 * S
    steps = 200
    for i in range(steps):
        t = i / (steps - 1)  # 0 = outermost ring, 1 = centre
        circle(d, fx, fy, reach * (1 - t), fill=mix(edge, centre, t))
    im = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    mask = Image.new("L", (BIG, BIG), 0)
    circle(ImageDraw.Draw(mask), 50 * S, 50 * S, 48 * S, fill=255)
    im.paste(shade, (0, 0), mask)
    d = ImageDraw.Draw(im)
    circle(d, 50 * S, 50 * S, 48 * S, outline=RIM, width=round(3.5 * S))
    circle(d, 50 * S, 50 * S, 42.5 * S, outline=INNER_RING, width=round(2 * S))
    return im


# Every pixel of the outlined letters stays this far inside the inner ring (radius 42.5).
FIT_RADIUS = 40 * S


def letters_mask(font, outline=0, shift=(0, 0)) -> Image.Image:
    """White letters on black, drawn from a baseline at (0, 60) plus shift."""
    mask = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(mask)
    spacing = -2 * S
    x, y = shift[0], 60 * S + shift[1]
    for ch in LETTERS:
        d.text((x, y), ch, font=font, fill=255, anchor="ls", stroke_width=outline, stroke_fill=255)
        x += d.textlength(ch, font=font) + spacing
    return mask


def centred(font, outline):
    """The shift that centres the capitals on the disc: across by the whole
    word, up and down by the first letter."""
    probe = (BIG // 8, 0)
    left, _, right, _ = letters_mask(font, outline, probe).getbbox()
    first = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(first).text((0, 60 * S), LETTERS[0], font=font, fill=255, anchor="ls")
    _, top, _, bottom = first.getbbox()
    return (probe[0] + 50 * S - (left + right) / 2, 50 * S - (top + bottom) / 2)


def fits(mask) -> bool:
    outside = Image.new("L", (BIG, BIG), 255)
    circle(ImageDraw.Draw(outside), 50 * S, 50 * S, FIT_RADIUS, fill=0)
    return ImageChops.multiply(mask, outside).getbbox() is None


def fitted_font(outline):
    """Cinzel's heaviest weight at the largest size whose outlined letters fit."""
    size = round(56 * S)
    while True:
        font = ImageFont.truetype(str(FONT), size)
        font.set_variation_by_axes([900])
        if fits(letters_mask(font, outline, centred(font, outline))):
            return font
        size -= 4


def letters(im: Image.Image) -> Image.Image:
    outline = round(1.2 * S)
    font = fitted_font(outline)
    shift = centred(font, outline)
    fill = letters_mask(font, shift=shift)
    edge = letters_mask(font, outline, shift)

    # Shadow: the outlined letters, dropped and blurred, under everything.
    shadow = ImageChops.offset(edge, 0, round(1.6 * S)).filter(ImageFilter.GaussianBlur(1.2 * S))
    shadow = shadow.point(lambda a: round(a * 0.85))
    im.paste((0, 0, 0), (0, 0), ImageChops.multiply(shadow, im.getchannel("A")))

    im.paste(OUTLINE, (0, 0), edge)

    top, bottom = fill.getbbox()[1], fill.getbbox()[3]
    gradient = Image.new("RGB", (BIG, BIG))
    gd = ImageDraw.Draw(gradient)
    for y in range(top, bottom + 1):
        gd.line([(0, y), (BIG, y)], fill=gold_at((y - top) / max(1, bottom - top)))
    im.paste(gradient, (0, 0), fill)
    return im


def icon(name=DISC, size=SIZE) -> Image.Image:
    centre, edge = DISCS[name]
    return letters(disc(centre, edge)).resize((size, size), Image.LANCZOS)


THUMBNAIL = ROOT / "images" / "thumbnail.png"  # the Wago listing's thumbnail
THUMBNAIL_SIZE = 512


def main():
    big = letters(disc(*DISCS[DISC]))
    image = big.resize((SIZE, SIZE), Image.LANCZOS)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    image.save(DEST)
    print("Wrote", DEST)
    THUMBNAIL.parent.mkdir(parents=True, exist_ok=True)
    big.resize((THUMBNAIL_SIZE, THUMBNAIL_SIZE), Image.LANCZOS).save(THUMBNAIL)
    print("Wrote", THUMBNAIL)
    if len(sys.argv) > 1:  # previews for a human: full size and the minimap size, blown up
        out = Path(sys.argv[1])
        out.mkdir(parents=True, exist_ok=True)
        bg = Image.new("RGBA", image.size, (30, 30, 30, 255))
        Image.alpha_composite(bg, image).save(out / "icon-256.png")
        small = Image.alpha_composite(bg.resize((20, 20)), image.resize((20, 20), Image.LANCZOS))
        small.resize((160, 160), Image.NEAREST).save(out / "icon-20-x8.png")
        print("Previews in", out)


if __name__ == "__main__":
    main()
