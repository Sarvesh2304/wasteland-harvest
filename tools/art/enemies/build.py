"""Builds the Milestone C combat art: enemy sheets, combat FX and the two combat HUD icons.

Usage:  python3 tools/art/enemies/build.py [section ...]
        sections: enemies fx hud preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: fixed seeds everywhere, so
re-running produces byte-identical PNGs unless a generator changed.

Writes
  art/characters/enemies/<id>.png     96x336 sheets (see enemies/rig.py for the row layout)
  art/characters/enemies/_preview.png contact sheet (3x, ruins-grey ground, player for scale)
  art/characters/enemies/_preview_anim/<id>.gif  walk S -> attack S -> death review loops
  art/fx/*.png                        combat FX (fx.py)
  art/ui/hp_icon.png, art/ui/rad_icon.png
"""
from __future__ import annotations

import importlib
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
if str(ART_TOOLS) not in sys.path:
    sys.path.insert(0, str(ART_TOOLS))          # tools/art (palette.py, the enemies package)

REPO = ART_TOOLS.parents[1]
ENEMY_DIR = REPO / "art" / "characters" / "enemies"
# enemy id -> generator module (enemies.<module>)
ENEMIES = {
    "shambler": "shambler",
    "runner": "runner",
    "raider": "raider",
    "bloater": "bloater",
    "rad_hound": "hound",
}
SECTIONS = ["enemies", "fx", "hud", "preview"]


def verify_sheet(eid, sheet):
    """Hard checks on the sheet contract the game slices by."""
    from enemies import rig
    assert (sheet.w, sheet.h) == (96, 336), (eid, sheet.w, sheet.h)
    a = sheet.a
    assert not ((a[:, :, 3] == 255) & (a[:, :, :3].sum(axis=2) == 0)).any(), f"{eid}: pure black"
    for r in range(13):
        n = 2 if r < 4 else 4
        for c in range(4):
            fr = rig.frame_slice(sheet, r, c)
            if r < 4 and c >= n:
                assert not fr[:, :, 3].any(), f"{eid}: idle row {r} col {c} must be empty"
                continue
            ys = (fr[:, :, 3] > 0).any(axis=1).nonzero()[0]
            assert len(ys), f"{eid}: empty frame r{r} c{c}"
            assert ys.max() <= rig.FEET_ROW, f"{eid}: r{r} c{c} below the feet row ({ys.max()})"
    return True


def build_enemies(names=None):
    ENEMY_DIR.mkdir(parents=True, exist_ok=True)
    sheets = {}
    for eid, modname in ENEMIES.items():
        if names and eid not in names:
            continue
        t0 = time.time()
        mod = importlib.import_module(f"enemies.{modname}")
        sheet = mod.sheet()
        verify_sheet(eid, sheet)
        sheet.save(ENEMY_DIR / f"{eid}.png")
        sheets[eid] = sheet
        print(f"[enemies] {eid:10s} {sheet.w}x{sheet.h} in {time.time() - t0:4.1f}s")
    return sheets


def main(argv=None):
    """argv: section / enemy-id filters. None (how tools/art/build_all.py calls it) = build all;
    the command line is only parsed when this file is run as a script."""
    argv = [] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS] or SECTIONS
    only = [a for a in argv if a in ENEMIES] or None
    if "enemies" in wanted:
        build_enemies(only)
    if "fx" in wanted:
        from enemies import fx
        fx.build(REPO)
        print("[enemies] fx done")
    if "hud" in wanted:
        from enemies import hud
        hud.build(REPO)
        print("[enemies] hud icons done")
    if "preview" in wanted:
        from enemies import preview
        preview.build(REPO, ENEMIES)
        print("[enemies] previews done")


if __name__ == "__main__":
    main(sys.argv[1:])
