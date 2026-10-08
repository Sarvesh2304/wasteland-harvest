"""Ruined-city art pipeline (Milestone C): ruin walls, building masses, landmarks, props and the
ruins base ground. Entry point: tools/art/ruins_city/build.py (main()).

Modules are imported package-qualified (`ruins_city.rc_walls`, ...) and carry an `rc_` prefix so
they never collide with same-named helper modules of the other art pipelines that share the
process (tools/art/build_all.py puts every pipeline folder on sys.path).
"""
