"""Fishing art pipeline (docs/FISHING.md section 9).

Entry point: tools/art/fishing/build.py (main()). Draws the 13 fish icons and the three fish
dishes with the items pipeline's own kit (tools/art/items/ia_lib.py), plus the bobber and the
water splash effects.

Modules carry an `fi_` prefix and are imported package-qualified (`fishing.fi_fish`, ...) so they
never collide with same-named helper modules of the other art pipelines that share the process
when tools/art/build_all.py runs them all.
"""
