"""Generate every icon file in Assets from one description of the artwork.

Run from the repository root:

    python3 Scripts/make_icons.py

Needs cairosvg and Pillow (pip install cairosvg pillow).
"""

import io
import math
import struct
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Assets"
PNG_DIR = ASSETS / "png"

TILE = "#11161C"
BEZEL = "#5A6675"
SCREEN = "#1B232C"
SUN = "#FFD25E"
SUN_IN_SCREEN = "#C8902F"

# On a white page the bright sun drops to about 1.4 to 1, so light mode swaps
# in a deeper amber that holds 3 to 1. The bezel goes the other way in dark
# mode, where the tile gray would fade into a dark page.
SUN_ON_LIGHT = "#C47A0A"
BEZEL_ON_DARK = "#7A8592"

# Geometry on Apple's 1024 grid, where the rounded tile spans 100 to 924.
# The sun is centered on the top edge of the screen, so its upper half rises
# past the display. Brighter than the screen allows is the whole idea.
SUN_X, SUN_Y, SUN_R = 512, 482, 150
BEZEL_BOX = (196, 452, 632, 372, 40)
SCREEN_BOX = (226, 482, 572, 312, 18)
RAY_INNER, RAY_OUTER, RAY_WIDTH = 200, 300, 36

# Eight rays fanned across the upper half, symmetric about straight up (270
# degrees in SVG, where y grows downward). The ends stop 10 degrees short of
# horizontal so the outer rays clear the bezel corners.
RAY_ANGLES = [190 + i * (160 / 7) for i in range(8)]


def n(value):
    """Two decimals, trailing zeros dropped, so the SVG text stays short."""
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def svg(view_box, body, size, style=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}" '
            f'width="{size}" height="{size}">{style}{body}</svg>')


def rect(box, **attributes):
    x, y, w, h, r = box
    extra = "".join(f' {key.replace("_", "-")}="{value}"' for key, value in attributes.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"{extra}/>'


def rays_path():
    parts = []
    for angle in RAY_ANGLES:
        t = math.radians(angle)
        x0, y0 = SUN_X + RAY_INNER * math.cos(t), SUN_Y + RAY_INNER * math.sin(t)
        x1, y1 = SUN_X + RAY_OUTER * math.cos(t), SUN_Y + RAY_OUTER * math.sin(t)
        parts.append(f"M{n(x0)} {n(y0)}L{n(x1)} {n(y1)}")
    return "".join(parts)


def upper_half_disc():
    """The part of the sun above the bezel, as a closed path."""
    top = BEZEL_BOX[1]
    # Where the bezel top edge cuts the circle.
    half_chord = math.sqrt(SUN_R ** 2 - (SUN_Y - top) ** 2)
    return (f"M{n(SUN_X - half_chord)} {top}"
            f"A{SUN_R} {SUN_R} 0 0 1 {n(SUN_X + half_chord)} {top}Z")


def lower_half_disc():
    """The part of the sun inside the screen, as a closed path."""
    return (f"M{SUN_X - SUN_R} {SUN_Y}"
            f"A{SUN_R} {SUN_R} 0 0 0 {SUN_X + SUN_R} {SUN_Y}Z")


def artwork(sun, bezel, rays):
    """The mark without a tile. Each argument is a paint attribute, either a
    fixed fill or stroke, or a class for the transparent variant to restyle."""
    return (
        f'<path d="{rays_path()}" fill="none" {rays} stroke-width="{RAY_WIDTH}" stroke-linecap="round"/>'
        + rect(BEZEL_BOX).replace("/>", f" {bezel}/>")
        + rect(SCREEN_BOX, fill=SCREEN)
        + f'<path d="{lower_half_disc()}" fill="{SUN_IN_SCREEN}"/>'
        + f'<path d="{upper_half_disc()}" {sun}/>'
    )


def solid_artwork():
    return artwork(sun=f'fill="{SUN}"', bezel=f'fill="{BEZEL}"', rays=f'stroke="{SUN}"')


def app_icon():
    tile = f'<rect x="100" y="100" width="824" height="824" rx="184" fill="{TILE}"/>'
    return svg("0 0 1024 1024", tile + solid_artwork(), 1024)


def icon_transparent():
    # Classes rather than fills, so the media query can swap colors for the
    # page the icon lands on.
    style = ("<style>.s{fill:" + SUN_ON_LIGHT + "}.r{stroke:" + SUN_ON_LIGHT + "}.b{fill:" + BEZEL + "}"
             "@media (prefers-color-scheme:dark){.s{fill:" + SUN + "}.r{stroke:" + SUN + "}"
             ".b{fill:" + BEZEL_ON_DARK + "}}</style>")
    return svg("100 100 824 824", artwork(sun='class="s"', bezel='class="b"', rays='class="r"'), 824, style)


def icon_tile():
    # The README tile. A 48 unit grid with a radius of 7 matches the tile used
    # across the other projects. The artwork is scaled from the 824 unit tile.
    scale = 48 / 824
    body = (f'<rect width="48" height="48" rx="7" fill="{TILE}"/>'
            f'<g transform="scale({scale:.6f}) translate(-100 -100)">'
            + solid_artwork() + "</g>")
    return svg("0 0 48 48", body, 48)


def icon_mono():
    # One color throughout. The screen is cut out of the bezel, and the part
    # of the sun inside it is drawn at reduced opacity, so the rising half
    # still reads as the brighter one when everything takes a single tint.
    bx, by, bw, bh, br = BEZEL_BOX
    sx, sy, sw, sh, sr = SCREEN_BOX
    frame = (f"M{bx + br} {by}H{bx + bw - br}A{br} {br} 0 0 1 {bx + bw} {by + br}"
             f"V{by + bh - br}A{br} {br} 0 0 1 {bx + bw - br} {by + bh}"
             f"H{bx + br}A{br} {br} 0 0 1 {bx} {by + bh - br}V{by + br}A{br} {br} 0 0 1 {bx + br} {by}Z"
             f"M{sx + sr} {sy}H{sx + sw - sr}A{sr} {sr} 0 0 1 {sx + sw} {sy + sr}"
             f"V{sy + sh - sr}A{sr} {sr} 0 0 1 {sx + sw - sr} {sy + sh}"
             f"H{sx + sr}A{sr} {sr} 0 0 1 {sx} {sy + sh - sr}V{sy + sr}A{sr} {sr} 0 0 1 {sx + sr} {sy}Z")
    body = (
        f'<path d="{rays_path()}" fill="none" stroke="currentColor" '
        f'stroke-width="{RAY_WIDTH}" stroke-linecap="round"/>'
        f'<path d="{frame}" fill="currentColor" fill-rule="evenodd"/>'
        f'<path d="{lower_half_disc()}" fill="currentColor" fill-opacity="0.45"/>'
        f'<path d="{upper_half_disc()}" fill="currentColor"/>'
    )
    return svg("100 100 824 824", body, 824)


# The menu bar version, on the 18 point grid a status item uses. The app draws
# it in code (Sources/MenuBarIcon.swift) from these same numbers, and this
# SVG exists so the README and anyone editing the shape can see it. Keep the
# two in step. Fewer rays than the app icon, since eight would merge at this
# size, and a thinner bezel so the screen opening stays visible.
MENU = {"sun_x": 9, "sun_y": 9.5, "sun_r": 3.6, "ray_in": 5.0, "ray_out": 7.2, "ray_w": 1.3,
        "rays": (205, 237.5, 270, 302.5, 335), "bezel": (2.5, 9.5, 13, 6.5, 1.5), "bezel_w": 1.5}


def menu_bar_icon():
    m = MENU
    cx, cy, r = m["sun_x"], m["sun_y"], m["sun_r"]
    bx, by, bw, bh, br = m["bezel"]
    edge = m["bezel_w"] / 2
    rays = "".join(
        f"M{n(cx + m['ray_in'] * math.cos(math.radians(a)))} {n(cy + m['ray_in'] * math.sin(math.radians(a)))}"
        f"L{n(cx + m['ray_out'] * math.cos(math.radians(a)))} {n(cy + m['ray_out'] * math.sin(math.radians(a)))}"
        for a in m["rays"])
    # Clip paths stand in for the two halves of the sun: everything above
    # the outer edge of the bezel, and everything below its inner edge.
    body = (
        f'<clipPath id="above"><rect width="18" height="{n(by - edge)}"/></clipPath>'
        f'<clipPath id="inside"><rect y="{n(by + edge)}" width="18" height="18"/></clipPath>'
        f'<path d="{rays}" fill="none" stroke="#000" stroke-width="{m["ray_w"]}" stroke-linecap="round"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#000" clip-path="url(#above)"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#000" fill-opacity="0.45" clip-path="url(#inside)"/>'
        f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="{br}" fill="none" stroke="#000" '
        f'stroke-width="{m["bezel_w"]}"/>'
    )
    return svg("0 0 18 18", body, 18)


def strip_png(data):
    """Keep only the chunks that hold the image itself."""
    keep = {b"IHDR", b"PLTE", b"tRNS", b"IDAT", b"IEND"}
    out = [data[:8]]
    position = 8
    while position < len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        if kind in keep:
            out.append(data[position:position + 12 + length])
        position += 12 + length
    return b"".join(out)


def write_png(svg_text, size, path):
    raw = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size)
    buffer = io.BytesIO()
    Image.open(io.BytesIO(raw)).convert("RGBA").save(buffer, format="PNG", optimize=True)
    path.write_bytes(strip_png(buffer.getvalue()))


def main():
    PNG_DIR.mkdir(parents=True, exist_ok=True)
    sources = {
        "AppIcon.svg": app_icon(),
        "Icon-Transparent.svg": icon_transparent(),
        "Icon-Tile.svg": icon_tile(),
        "Icon-Mono.svg": icon_mono(),
        "MenuBarIcon.svg": menu_bar_icon(),
    }
    for name, text in sources.items():
        (ASSETS / name).write_text(text, encoding="utf-8")

    # build.sh copies these into the app's icon set, so 1024 has to be here
    # for the 512 at 2x slot.
    app_sizes = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
    tile_sizes = (16, 24, 32, 48)
    for size in app_sizes:
        write_png(sources["AppIcon.svg"], size, PNG_DIR / f"AppIcon-{size}.png")
    for size in tile_sizes:
        write_png(sources["Icon-Tile.svg"], size, PNG_DIR / f"Icon-Tile-{size}.png")

    print(f"Wrote {len(sources)} SVG files and {len(app_sizes) + len(tile_sizes)} PNG files "
          f"to {ASSETS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
