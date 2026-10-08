"""Review images for the enemy sheets (not used by the game; Godot-ignored where possible).

  art/characters/enemies/_preview.png            every sheet at 3x on a dark ruins-grey ground,
                                                 the player's south idle frame beside each
  art/characters/enemies/_preview_anim/<id>.gif  walk S x2 -> attack S -> death (holds the corpse)
"""
from __future__ import annotations

from PIL import Image

import palette as P
from enemies import rig

BG = P.hex_to_rgba(P.CONCRETE_DARK)
BAND = P.hex_to_rgba("#3a3a35")


def _player(repo):
    return Image.open(repo / "art/characters/player/idle/south/0.png").convert("RGBA")


def contact_sheet(repo, ids, scale=3):
    player = _player(repo)
    gap = 8
    col_w = 24 + 4 + 96
    W = len(ids) * (col_w + gap) + gap
    H = 336 + 2 * gap
    im = Image.new("RGBA", (W, H), BG)
    for k, eid in enumerate(ids):
        x = gap + k * (col_w + gap)
        sheet = Image.open(repo / f"art/characters/enemies/{eid}.png").convert("RGBA")
        band = Image.new("RGBA", (96, 336), BAND)
        for r in range(0, 14, 2):
            band.paste(Image.new("RGBA", (96, 24), BG), (0, r * 24))
        im.alpha_composite(band, (x + 28, gap))
        im.alpha_composite(sheet, (x + 28, gap))
        for r in range(13):                       # the player beside every row, for scale
            im.alpha_composite(player, (x, gap + r * 24))
    return im.resize((W * scale, H * scale), Image.NEAREST)


def anim_gif(repo, eid, path, scale=3):
    sheet = Image.open(repo / f"art/characters/enemies/{eid}.png").convert("RGBA")
    seq = [(4, c, 140) for c in range(4)] * 2 + [(8, c, 170) for c in range(4)] + \
          [(13, c, 160) for c in range(3)] + [(13, 3, 900)]
    frames = []
    durs = []
    for (r, c, ms) in seq:
        fr = Image.new("RGBA", (24, 24), BG)
        fr.alpha_composite(sheet.crop((c * 24, r * 24, c * 24 + 24, r * 24 + 24)))
        frames.append(fr.resize((24 * scale, 24 * scale), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
        durs.append(ms)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durs, loop=0,
                   optimize=False, disposal=1)


def build(repo, enemies):
    ids = list(enemies)
    out = repo / "art/characters/enemies"
    contact_sheet(repo, ids).save(out / "_preview.png", optimize=False)
    anim = out / "_preview_anim"
    anim.mkdir(exist_ok=True)
    (anim / ".gdignore").write_text("")
    for eid in ids:
        anim_gif(repo, eid, anim / f"{eid}.gif")
