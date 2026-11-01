"""Townsfolk and Town Works art pipeline (Milestone B: the social half and the Town Works).

Entry point: tools/art/townsfolk/build.py (main()). Draws the three code-generated townsfolk
(Brask, Wren, Doc Ama) as per-frame PNGs in the same layout as the PixelLab NPCs, the Town Works
buildings (clinic before/after, expanded store, watchtower, greenhouse wall pieces), Doc Ama's
field tent and the social UI icons (hearts, quest marker, gift and talk icons).

Modules carry a `tf_` prefix and are imported package-qualified (`townsfolk.tf_doll`, ...) so they
never collide with same-named helper modules of the other art pipelines that share the process
when tools/art/build_all.py runs them all.
"""
