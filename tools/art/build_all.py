"""Regenerates every code-generated art asset (see docs/ART_STYLE.md).

Usage: python3 tools/art/build_all.py [env|items ...]

Each sub-pipeline lives in its own package (tools/art/<name>/build.py exposing main()). They are
deterministic, so re-running produces byte-identical PNGs unless a generator changed.
"""
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
PIPELINES = ["env", "items", "ruins_city", "enemies", "townsfolk", "living"]


def _run(name: str) -> None:
    build = ROOT / name / "build.py"
    if not build.exists():
        print(f"[art] skip {name}: {build} missing")
        return
    sys.path.insert(0, str(ROOT))
    sys.path.insert(0, str(build.parent))
    spec = importlib.util.spec_from_file_location(f"art_{name}_build", build)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    print(f"[art] building {name} ...")
    module.main()


if __name__ == "__main__":
    for pipeline in (sys.argv[1:] or PIPELINES):
        _run(pipeline)
