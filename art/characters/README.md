# Character Art — PixelLab Provenance

## `player/` — Phase 2 player character

One representative player character proving the movement/animation pipeline (ROADMAP Phase 2).
This is deliberately NOT the full preset-portraits-plus-cosmetic-sliders character-creation
system from `GDD.md` §3 — that's later birth-sequence/UI work — and it's placeholder-tier art
until Phase 6's "Art pass 1" (which explicitly re-does the player character).

Generated via `mcp__pixellab__create_character` (standard mode, 1 generation):

- **Character id `6ee1466d-dd09-4732-9e99-ad57c9efbfab`** ("Player - Wastelander Farmer v2"),
  16px character on a 24x24 canvas, 4 directions, `low top-down` view, basic shading, single
  color outline, low detail. Judgment call on view: tiles are `high top-down` but the character
  uses `low top-down` (classic 3/4 RPG look) — this is Stardew's actual mix (flat floors,
  forced-perspective characters), per CLAUDE.md's projection note.
- Description: young adult wasteland settler farmer in the settlement anchor palette
  (`GDD.md` §9 — dusty amber jacket `#c9974b`, faded green undershirt `#8a9a56`, worn wood
  brown trousers `#6e5033`).
- A first attempt (id `54624216-c898-4a40-80d4-1a482bd11dbe`, "Player - Wastelander Farmer")
  painted frontal shirt details on the north/back view and was superseded by v2; v2's back
  view still shows a sliver of neck/ear skin under the hair — acceptable at 16px, fix in
  Phase 6's art pass. v1 is left on the PixelLab account (not deleted) in case the
  orchestrating session prefers its outfit detail.

### Files

- `player/rotations/{south,north,east,west}.png` — base directional stills (24x24 each).
- `player/walk/{dir}/{0-3}.png` — walk cycle, template `walking-4-frames` (1 gen/direction).
- `player/idle/{dir}/{n}.png` — idle, template `breathing-idle` (1 gen/direction).
- `player/tool/{dir}/{n}.png` — tool-use stub swing, v3 custom animation from an
  action description (1 gen/direction). Phase 3 attaches real tool effects to it.
- `player/player_frames.tres` — the Godot `SpriteFrames` consumed by
  `scenes/player.tscn`'s AnimatedSprite2D: animations `idle_*`, `walk_*`, `tool_*` per
  direction; `tool_*` are non-looping (scripts/player.gd waits on `animation_finished`
  to unlock movement).
