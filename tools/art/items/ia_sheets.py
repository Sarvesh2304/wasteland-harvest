"""Contact sheets for reviewing the item icons, world sprites and crop chains (written to
art/items/_preview/ and art/crops/_preview/, which carry a .gdignore so Godot skips them)."""
from __future__ import annotations

import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LIGHT_BG = (0xFF, 0xED, 0xB1, 255)
DARK_BG = (0x28, 0x1A, 0x0B, 255)
SOIL = (0x89, 0x5A, 0x2E, 255)
GRASS = (0x95, 0xAC, 0x49, 255)


def _font(size=10):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # very old Pillow
        return ImageFont.load_default()


def _text_color(bg):
    return (40, 26, 11, 255) if sum(bg[:3]) > 380 else (255, 237, 177, 255)


def icon_sheet(groups, path, bg, scale=4, cols=12):
    """groups: list of (title, [(label, img16), ...])."""
    font = _font(10)
    head = _font(12)
    cell_w, cell_h = 16 * scale + 36, 16 * scale + 18
    rows_total = sum((len(items) + cols - 1) // cols for _, items in groups)
    W = cols * cell_w + 16
    H = rows_total * cell_h + len(groups) * 22 + 16
    im = Image.new("RGBA", (W, H), bg)
    d = ImageDraw.Draw(im)
    tc = _text_color(bg)
    y = 8
    for title, items in groups:
        d.text((8, y), f"{title} ({len(items)})", fill=tc, font=head)
        y += 20
        for i, (label, img) in enumerate(items):
            r, c = divmod(i, cols)
            x0 = 8 + c * cell_w
            y0 = y + r * cell_h
            big = Image.fromarray(np.asarray(img, np.uint8), "RGBA").resize((16 * scale, 16 * scale), Image.NEAREST)
            im.alpha_composite(big, (x0 + (cell_w - 16 * scale) // 2, y0))
            txt = label if len(label) <= 17 else label[:16] + "."
            tw = d.textlength(txt, font=font)
            d.text((x0 + (cell_w - tw) / 2, y0 + 16 * scale + 2), txt, fill=tc, font=font)
        y += ((len(items) + cols - 1) // cols) * cell_h + 2
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def world_sheet(items, path, scale=4):
    """items: list of (label, strip_img). Each frame drawn on a grass tile row with a tile grid."""
    font = _font(10)
    pad = 10
    max_w = max(img.shape[1] for _, img in items)
    cell_w = max_w * scale + 2 * pad
    cell_h = 32 * scale + 22
    cols = 4
    rows = (len(items) + cols - 1) // cols
    im = Image.new("RGBA", (cols * cell_w + 8, rows * cell_h + 8), (70, 70, 70, 255))
    d = ImageDraw.Draw(im)
    for i, (label, img) in enumerate(items):
        r, c = divmod(i, cols)
        x0, y0 = 4 + c * cell_w, 4 + r * cell_h
        d.rectangle([x0 + 2, y0 + 2, x0 + cell_w - 3, y0 + 32 * scale + 2], fill=GRASS)
        h, w = img.shape[:2]
        # tile grid under the sprite footprint
        for fx in range(0, w, 16):
            gx = x0 + pad + fx * scale
            d.rectangle([gx, y0 + 2 + (32 - 16) * scale, gx + 16 * scale - 1, y0 + 1 + 32 * scale],
                        outline=(120, 140, 60, 255))
        big = Image.fromarray(img, "RGBA").resize((w * scale, h * scale), Image.NEAREST)
        im.alpha_composite(big, (x0 + pad, y0 + 2 + (32 - h) * scale))
        d.text((x0 + pad, y0 + 32 * scale + 5), f"{label}  ({w // 16} fr, 16x{h})", fill=(255, 237, 177, 255),
               font=font)
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def crop_sheet(rows, path, scale=4):
    """rows: list of (crop_id, [stage imgs...], dead_img). Two columns of crop chains, each chain
    drawn over a strip of tilled soil (the bottom 16 px of the sprites)."""
    font = _font(11)
    max_n = max(len(st) + 1 for _, st, _ in rows)
    lab_w = 0
    cell = 16 * scale + 6
    chain_w = max_n * cell + 12
    chain_h = 32 * scale + 26
    half = (len(rows) + 1) // 2
    im = Image.new("RGBA", (2 * chain_w + 24, half * chain_h + 8), (70, 70, 70, 255))
    d = ImageDraw.Draw(im)
    for i, (cid, stages, dead) in enumerate(rows):
        col, r = divmod(i, half)
        x0 = 8 + col * (chain_w + 8)
        y0 = 4 + r * chain_h
        d.rectangle([x0, y0, x0 + chain_w - 8, y0 + 32 * scale + 4], fill=GRASS)
        d.rectangle([x0, y0 + 4 + 16 * scale, x0 + chain_w - 8, y0 + 32 * scale + 4], fill=SOIL)
        for j, img in enumerate(list(stages) + [dead]):
            big = Image.fromarray(img, "RGBA").resize((16 * scale, 32 * scale), Image.NEAREST)
            im.alpha_composite(big, (x0 + 4 + j * cell, y0 + 4))
        n = len(stages)
        d.text((x0 + 2, y0 + 32 * scale + 8), f"{cid}: stage_0..{n - 1} + dead", fill=(255, 237, 177, 255),
               font=font)
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def mock_scene(icons, crop_rows, player_png, path, scale=3):
    """A 1x mock (upscaled for viewing): a hotbar of icons on a dark plaque and a little field of
    mature crops on tilled soil next to the player for scale."""
    W, H = 320, 120
    im = Image.new("RGBA", (W, H), GRASS)
    d = ImageDraw.Draw(im)
    # tilled field: 2 rows of 8 tiles
    for ty in range(2):
        for tx in range(8):
            x, y = 8 + tx * 16, 40 + ty * 32
            d.rectangle([x, y + 16, x + 15, y + 31], fill=SOIL)
            d.rectangle([x, y + 16, x + 15, y + 16], fill=(0xA5, 0x70, 0x3A, 255))
    flat = []
    for cid, stages, dead in crop_rows:
        flat.append(stages[-1])
        flat.append(stages[len(stages) // 2])
    for i, img in enumerate(flat[:16]):
        tx, ty = i % 8, i // 8
        im.alpha_composite(Image.fromarray(img, "RGBA"), (8 + tx * 16, 40 + ty * 32))
    if player_png and pathlib.Path(player_png).exists():
        p = Image.open(player_png).convert("RGBA")
        im.alpha_composite(p, (140, 40 + 32 - p.height + 4))
    # hotbar
    d.rectangle([150, 4, 150 + 12 * 18 + 4, 26], fill=(0x3d, 0x26, 0x12, 255))
    for i, ic in enumerate(icons[:12]):
        x = 152 + i * 18
        d.rectangle([x, 6, x + 17, 23], fill=(0x7b, 0x50, 0x25, 255))
        im.alpha_composite(Image.fromarray(ic, "RGBA"), (x + 1, 7))
    # second strip of icons on light paper
    d.rectangle([150, 30, 150 + 12 * 18 + 4, 52], fill=LIGHT_BG)
    for i, ic in enumerate(icons[12:24]):
        im.alpha_composite(Image.fromarray(ic, "RGBA"), (152 + i * 18 + 1, 33))
    big = im.resize((W * scale, H * scale), Image.NEAREST)
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    big.save(path)
