# Prop Art — PixelLab Provenance

## `ranch_cow.png`, `ranch_goat.png` — Phase 8 Ranch/Sanctuary decorative livestock

The Ranch/Sanctuary compound's cosmetic pen animals (`scripts/props.gd`, `ROADMAP.md` Phase 8,
`GDD.md` §8/§11 "Animals & pets") — static, non-collidable `Sprite2D`s the keeper's compound
scatters across its pens so the ranch reads as alive and working before the player has bought
anything. Deliberately **not** a live animal-entity system (no wandering, no state, no
save/load) — pure scenery, spawned fresh from the active layout's `decor_props()` list on every
map build. `scripts/props.gd`'s `_prop_texture()` loads the real PNG when present, falling back
to a flat-color `ImageTexture` fill otherwise (`PROP_COLORS`: `ranch_cow` `#c9b89a` dusty hide,
`ranch_goat` `#8a9a7a` mutant grey-green) — same fallback pattern as
`structures.gd`'s `_building_texture()` and `farm.gd`'s `_crop_texture()`.

Generated via `mcp__pixellab__create_map_object`, basic mode (no `background_image`), 32x32,
**`low top-down` view** — a deliberate departure from this directory's sibling `art/buildings/`
convention (`high top-down`): per `scripts/props.gd`'s own comment, animals use the *characters'*
projection ("so the animals read as recognizable critters rather than top-down blobs"), not the
buildings' flat front-elevation one. Sprites are centered on their 16x16 cell and allowed to
overhang it (the CLAUDE.md sprite-beyond-tile convention), reading as an animal standing in the
pasture rather than confined to a single tile.

| Kind | Object id | Canvas -> shipped | Identity hex anchored |
|---|---|---|---|
| `ranch_cow` | `d929877b-8449-4cc3-9d66-f46e5822ebdb` | 32x32 as-is | `#c9b89a` dusty hide |
| `ranch_goat` | `739c1160-4297-4733-8467-940ad9a124b9` | 32x32 as-is | `#8a9a7a` mutant grey-green |

Both object ids confirmed by downloading each from the PixelLab account and matching its SHA-256
hash byte-for-byte against the shipped PNG — no rejected/duplicate attempt exists for either kind
on the account (unlike some of the `art/buildings/` ranch kinds), so there was no ambiguity to
resolve, only confirmation. Same 8-hour map-object auto-delete caveat as `art/buildings/README.md`
applies — these ids are historical provenance only, the shipped PNGs are the only copies.

## `wrecked_car.png`, `weed_tuft.png` — Path zone dressing (zone split, Stage 1)

The new Farm↔Town Path corridor's props (`scripts/map_layouts/path_layout_*.gd`'s
`decor_props()`, spawned by `scripts/props.gd` exactly like the ranch animals — static,
non-collidable, no save/load):

- **`wrecked_car`** — the corridor's landmark: a rusted pre-war sedan being reclaimed by weeds,
  abandoned on the dead paved road. Deliberately reuses the image Forest Edge's lore blurb
  already established ("a rusted car half-eaten" by green), not new IP-risky art — the zone's
  "the world before" statement, per the zone-transition plan's design brief (conceptual
  Stardew bus-stop reference only, original art, per `docs/STARDEW_REFERENCE.md`).
- **`weed_tuft`** — a weed clump sprouting through cracked pavement, scattered along the ruined
  road's cracks (and one at the sealed checkpoint's foot). Its baked-in pavement base is
  intentional: every authored placement cell is a road/plank ('p') cell.

Generated via `mcp__pixellab__create_map_object`, basic mode, **`low top-down` view** (the
props/characters projection, per this README's ranch-animals note), `basic shading`,
`lineless`; car `medium detail` 48x32 (a car is a wide landmark — allowed to overhang its cell
per the CLAUDE.md sprite-beyond-tile convention), weeds `low detail` 32x32.

| Kind | Object id | Canvas -> shipped | SHA-256 of shipped PNG |
|---|---|---|---|
| `wrecked_car` | `372232af-8e8f-4f5a-8ab4-2702c839c3f6` | 48x32 as-is | `292d66b2928a0e19b6bab8e1aa8f4ec61ec726684f9afb135423c712a3d583c9` |
| `weed_tuft` | `d0c28407-e7bb-4e53-8e1c-26468ea2113a` | 32x32 as-is | `062907e8444ab87d7432aa71db38761af2fc7649255adfc45a47e95be05389cb` |

One generation attempt each, downloaded directly from the returned job — no rejected/duplicate
attempts on the account for either kind. Same 8-hour map-object auto-delete caveat as above:
the ids are historical provenance only, the shipped PNGs are the only copies. Flat-color
fallbacks in `props.gd`'s `PROP_COLORS` (`wrecked_car` `#9d9180` scavenged metal, `weed_tuft`
`#95ac49` faded field green).
