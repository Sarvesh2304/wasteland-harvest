"""Builds every environment PNG under art/env/ (see art/env/README.md for the inventory).

Usage:  python3 tools/art/env/build.py [section ...]
        sections: terrain fences trees debris decor props ruins   (default: all)
Also run by tools/art/build_all.py. Deterministic: fixed seeds everywhere, so re-running
produces byte-identical PNGs unless a generator changed.
"""
from __future__ import annotations

import importlib
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE.parent) not in sys.path:
    sys.path.insert(0, str(HERE.parent))           # tools/art (palette.py, env package)

SECTIONS = ["terrain", "fences", "trees", "debris", "decor", "props", "ruins"]


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS] or SECTIONS
    from env import lib, wang
    wang.verify()
    for name in wanted:
        t0 = time.time()
        mod = importlib.import_module(f"env.{name}")
        mod.build(lib.OUT)
        print(f"[env] {name:8s} done in {time.time() - t0:5.1f}s")


if __name__ == "__main__":
    main()
