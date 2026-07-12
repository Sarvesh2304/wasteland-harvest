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
