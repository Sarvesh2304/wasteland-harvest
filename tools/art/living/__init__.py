"""A living settlement art pipeline (Milestone D, docs/LIVING_SETTLEMENT.md section 7).

Entry point: tools/art/living/build.py (main()). Draws the open market stall (with Tully's
pack-goat), the player's trading post, the mayor's house with its radio antenna, the festival
dressing (booth, bunting, food table, lanterns, seed packet), the race goat strip, the Northgate
vault door and two item icons. Tully himself is drawn by tools/art/townsfolk/tf_tully.py.

Modules carry an `lv_` prefix and are imported package-qualified (`living.lv_common`, ...) so they
never collide with same-named helper modules of the other art pipelines that share the process
when tools/art/build_all.py runs them all.
"""
