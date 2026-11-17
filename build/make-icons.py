#!/usr/bin/env python3
"""Generate simple icons for the chdman / unecm AppImages."""
from PIL import Image, ImageDraw, ImageFont

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def base_bg(size=256, radius=48):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # dark navy rounded square
    d.rounded_rectangle([8, 8, size - 8, size - 8], radius=radius,
                        fill=(24, 32, 56, 255), outline=(90, 110, 160, 255), width=4)
    return img, d


def disc(d, cx, cy, r):
    # optical-disc motif: outer ring + inner hole + gloss arc
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(38, 50, 84, 255),
              outline=(120, 200, 255, 255), width=6)
    d.arc([cx - r + 14, cy - r + 14, cx + r - 14, cy + r - 14],
          start=200, end=320, fill=(190, 230, 255, 255), width=4)
    hr = r * 0.22
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(24, 32, 56, 255),
              outline=(120, 200, 255, 255), width=4)


def make_chdman(path):
    img, d = base_bg()
    disc(d, 128, 96, 52)
    f = ImageFont.truetype(FONT_BOLD, 54)
    tb = d.textbbox((0, 0), "CHD", font=f)
    d.text(((256 - (tb[2] - tb[0])) / 2 - tb[0], 172), "CHD", font=f,
           fill=(120, 200, 255, 255))
    img.save(path)


def make_unecm(path):
    img, d = base_bg()
    disc(d, 128, 92, 46)
    # downward "extract" arrow
    ax = 128
    d.polygon([(ax - 22, 146), (ax + 22, 146), (ax + 22, 176), (ax + 38, 176),
               (ax, 214), (ax - 38, 176), (ax - 22, 176)],
              fill=(120, 255, 170, 255))
    img.save(path)


if __name__ == "__main__":
    import sys
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    make_chdman(f"{outdir}/chdman.png")
    make_unecm(f"{outdir}/unecm.png")
    print("icons written")
