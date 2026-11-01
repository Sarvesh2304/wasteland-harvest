"""Builds the townsfolk and Town Works art (Milestone B).

Usage:  python3 tools/art/townsfolk/build.py [section ...]
        sections: characters buildings ui preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: no randomness anywhere (all
variation is hand-placed or hash-based), so re-running produces byte-identical PNGs unless a
generator changed. An output allowlist stops it from writing anything but its own files.

Writes
  art/characters/{brask,wren,doc_ama}/{idle,walk}/{south,north,east,west}/{0..3}.png  24x24
  art/characters/{brask,wren,doc_ama}/rotations/{south,north,east,west}.png  (= idle frame 0)
  art/buildings/town_clinic_ruined.png, town_clinic.png   64x56  footprint 4x3
  art/buildings/store_expanded.png                         48x48  footprint 3x2
  art/buildings/watchtower.png                             32x64  footprint 2x2
  art/buildings/greenhouse_{back,side,front}[_ruined].png  128x32 / 16x64 / 128x24
                                                           (footprint 8x6, see tf_buildings.py)
  art/buildings/doc_tent.png                               32x32  footprint 2x2
  art/ui/heart_full.png, heart_empty.png (7x6), quest_marker.png (9x12), gift_icon.png (8x8),
  art/ui/talk_icon.png (8x7)
  art/characters/townsfolk_preview.png, art/buildings/_works_preview.png   review images
Building sprites are exactly as wide as their footprint and bottom-anchored on it.
The <id>_frames.tres SpriteFrames are made by tools/build_player_frames.py, not here.
"""
from __future__ import annotations

import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
if str(ART_TOOLS) not in sys.path:
    sys.path.insert(0, str(ART_TOOLS))            # tools/art (palette.py, env, enemies, townsfolk)

REPO = ART_TOOLS.parents[1]
SECTIONS = ["characters", "buildings", "ui", "preview"]
CHARACTERS = {"brask": "tf_brask", "wren": "tf_wren", "doc_ama": "tf_doc_ama"}
DIRS = ["south", "north", "east", "west"]

BUILDINGS = ["town_clinic_ruined", "town_clinic", "store_expanded", "watchtower",
             "greenhouse_back", "greenhouse_side", "greenhouse_front",
             "greenhouse_back_ruined", "greenhouse_side_ruined", "greenhouse_front_ruined",
             "doc_tent"]
UI = ["heart_full", "heart_empty", "quest_marker", "gift_icon", "talk_icon"]


def _outputs():
    out = set()
    for cid in CHARACTERS:
        for d in DIRS:
            out.add(f"art/characters/{cid}/rotations/{d}.png")
            for act in ("idle", "walk"):
                for i in range(4):
                    out.add(f"art/characters/{cid}/{act}/{d}/{i}.png")
    out |= {f"art/buildings/{b}.png" for b in BUILDINGS}
    out |= {f"art/ui/{u}.png" for u in UI}
    out |= {"art/characters/townsfolk_preview.png", "art/buildings/_works_preview.png"}
    return out


OUTPUTS = _outputs()


def write(rel, canvas):
    """Save a Canvas (enemies.pix / env.lib) or a PIL image to a repo-relative allowlisted path."""
    if rel not in OUTPUTS:
        raise RuntimeError(f"townsfolk: refusing to write {rel} (not one of this kit's outputs)")
    path = REPO / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img = canvas.to_image() if hasattr(canvas, "to_image") else canvas
    img.save(path, optimize=False)
    return path


def build_characters():
    import importlib
    from townsfolk import tf_doll
    for cid, modname in CHARACTERS.items():
        look = importlib.import_module(f"townsfolk.{modname}").LOOK
        frames = look.frames()
        for (act, d, i), cv in frames.items():
            tf_doll.check_frame(cv, (cid, act, d, i))
            write(f"art/characters/{cid}/{act}/{d}/{i}.png", cv)
        for d in DIRS:
            write(f"art/characters/{cid}/rotations/{d}.png", frames[("idle", d, 0)])
        print(f"[townsfolk] {cid}: {len(frames)} frames + 4 rotations")


# name -> (width = footprint width, (min height, max height), translucent pixels allowed?)
BUILDING_SPECS = {
    "town_clinic_ruined": (64, (48, 60), True), "town_clinic": (64, (48, 60), True),
    "store_expanded": (48, (32, 48), True), "watchtower": (32, (64, 64), True),
    "greenhouse_back": (128, (32, 32), True), "greenhouse_side": (16, (64, 64), True),
    "greenhouse_front": (128, (24, 24), True), "greenhouse_back_ruined": (128, (32, 32), True),
    "greenhouse_side_ruined": (16, (64, 64), True), "greenhouse_front_ruined": (128, (24, 24), True),
    "doc_tent": (32, (16, 32), True),
}
UI_SPECS = {"heart_full": (7, 6), "heart_empty": (7, 6), "quest_marker": (9, 12),
            "gift_icon": (8, 8), "talk_icon": (8, 7)}


def verify_building(name, cv):
    """Hard checks on the contract the game places buildings by (see tf_buildings.py)."""
    w, (hmin, hmax), _ = BUILDING_SPECS[name]
    assert cv.w == w, f"{name}: width {cv.w} != footprint width {w}"
    assert hmin <= cv.h <= hmax, f"{name}: height {cv.h} outside {hmin}-{hmax}"
    a = cv.a
    assert (a[-2:, :, 3] > 0).any(), f"{name}: nothing on the bottom rows (must stand on the footprint)"
    assert not ((a[:, :, 3] == 255) & (a[:, :, :3].sum(axis=2) == 0)).any(), f"{name}: pure black"
    if name.startswith("greenhouse_front"):
        assert not a[:, 48:64, 3].any(), f"{name}: the doorway (x 48-63) must stay transparent"
    return True


def build_buildings():
    from townsfolk import tf_buildings
    for name, cv in tf_buildings.build().items():
        verify_building(name, cv)
        write(f"art/buildings/{name}.png", cv)
    print(f"[townsfolk] buildings: {len(BUILDINGS)} sprites")


def build_ui():
    from townsfolk import tf_ui
    for name, cv in tf_ui.build().items():
        assert (cv.w, cv.h) == UI_SPECS[name], (name, cv.w, cv.h)
        assert set(cv.a[:, :, 3].flatten()) <= {0, 255}, f"{name}: icons are fully opaque or clear"
        write(f"art/ui/{name}.png", cv)
    print(f"[townsfolk] ui: {len(UI)} icons")


def build_preview():
    from townsfolk import tf_preview
    write("art/characters/townsfolk_preview.png", tf_preview.characters(REPO))
    write("art/buildings/_works_preview.png", tf_preview.works(REPO))
    print("[townsfolk] previews done")


def main(argv=None):
    """argv: section filters. None (how tools/art/build_all.py calls it) = build all; the command
    line is only parsed when this file is run as a script."""
    argv = [] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS] or SECTIONS
    for name in wanted:
        t0 = time.time()
        {"characters": build_characters, "buildings": build_buildings, "ui": build_ui,
         "preview": build_preview}[name]()
        print(f"[townsfolk] {name:10s} done in {time.time() - t0:5.1f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
