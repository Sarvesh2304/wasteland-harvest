"""Environment art pipeline (terrain, fences, trees, debris, decor, props, ruins).

Entry point: tools/art/env/build.py (main()), also driven by tools/art/build_all.py.
Modules are imported package-qualified (`env.lib`, `env.terrain`, ...) so they never collide
with same-named helper modules of the other art pipelines that share the process.
"""
