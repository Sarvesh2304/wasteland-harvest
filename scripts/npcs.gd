extends Node2D
## Phase 5 Stage 1 NPC spawner: instantiates the active layout's npcs() roster as real npc.gd
## nodes — the same data-driven "read a list off the active layout, spawn one node per entry"
## shape scripts/structures.gd uses for buildings() (see that file's class doc), generalized
## from a StaticBody2D-per-building to a CharacterBody2D-per-NPC.
##
## Expected in the scene tree as a child of TestMap (see scenes/test_map.tscn), sibling to Farm/
## Structures, so get_parent() is the TestMap node whose `layout` this reads npcs() from — same
## _enter_tree()-before-children's-_ready() ordering guarantee those siblings document.
##
## No save/load: NPC positions are cosmetic wander noise with no gameplay meaning yet (see
## npc.gd's class doc) — a reload simply respawns every NPC at its authored home cell, same as a
## fresh game.

const Npc := preload("res://scripts/npc.gd")

var _test_map: Node2D
var _npcs: Array[Node] = []


func _ready() -> void:
	_test_map = get_parent()
	for entry in _test_map.layout.npcs():
		_spawn_npc(entry)


func _spawn_npc(entry: Dictionary) -> void:
	var home: Vector2i = entry["home"]
	var npc := Npc.new()
	npc.setup(String(entry["id"]), home, int(entry.get("wander_radius", 2)), _test_map)
	# `position`, not global_position: this node lives under its zone's TestMap, whose zone
	# offset (the zone split's sibling-layout trick) must carry through — cell_to_world_center
	# returns zone-LOCAL pixels.
	npc.position = _test_map.cell_to_world_center(home)
	add_child(npc)
	_npcs.append(npc)


## All spawned NPC nodes (tests/runtime_smoke inspect these directly).
func npcs() -> Array[Node]:
	return _npcs


## The NPC (if any) occupying `cell` — player.gd's use_tool() dispatch calls this exactly the
## way it calls structures.is_chest_at()/is_bed_at(), just returning the node itself (rather than
## a bool) since the dialogue trigger needs to know WHICH npc, not just that one is there.
func npc_at(cell: Vector2i) -> Node:
	for npc in _npcs:
		if npc.occupies_cell(cell):
			return npc
	return null
