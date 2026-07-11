# Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)

**Status:** a durable design reference, not a task list. Requested by Sarvesh 2026-07-12 as the
guiding structural reference for future farm/town/ranch/environment work in this project.

**Scope and IP note, read first:** this document captures Pelican Town's and Marnie's Ranch's
*functional/structural ideas* — what kinds of spaces exist, how they relate spatially, what
role each plays in the daily loop — not their specific art, character designs, or exact layouts.
Game-design concepts like "a plaza with a general store and a gathering spot" aren't
copyrightable; Stardew's specific pixel art, building silhouettes, and character designs are.
Every asset built from this reference should be **original art in Wasteland Harvest's own
established post-apocalyptic palette** (`GDD.md` §9), not a visual clone. No literal screenshots
of Stardew Valley were used to produce this document — Claude has no game-client access, and
using copyrighted commercial screenshots as direct generation templates would be a real risk for
a project with genuine commercial release plans (see this repo's own `CLAUDE.md`, "Platform &
Release"). This was compiled from public wiki/guide text describing the game's structure.

## Pelican Town — structural takeaways

- **One central plaza**, not a street grid: a town square with a fountain/gathering-point at its
  heart, ringed by the town's key institutions. Hosts seasonal festivals. Wasteland Harvest's
  own town-core plaza (`MAPS.md` §2) already follows this same idea — packed-dirt square,
  bulletin board, a fire pit/lamp at the center instead of a fountain.
- **Two "anchor" institutions flank the plaza**: a general store (commerce) and a
  civic/authority building (the Mayor's Manor). WH already mirrors this exactly: Marta's store
  and Mayor Harlan's fortified house flank the plaza from opposite sides.
- **A water feature with bridges** splits part of the town, doubling as a scenic/quiet corner.
  WH's dock (`MAPS.md` §2, "The water edge") already serves this role.
- **NPC homes scattered around the plaza's edges**, not clustered in one row — gives the town a
  lived-in, organic feel rather than a barracks-like arrangement. WH's settler-shack ring is the
  analogous idea, currently more uniform (a loose arc) than Pelican Town's scattered placement —
  worth loosening up visually as the town grows past Phase 4's placeholder count.
- **Distinct edge-zones connect outward in different directions**: forest (SW), mountain (N),
  beach (S), bus stop/farm (NW) — each a different "flavor" of adjacent space, not just more
  town. WH's equivalent outward connections are the farm (already adjacent) and the ruined city
  (Phase 9) — the ranch/sanctuary below adds a third.
- **Population/building density** is much higher than WH's current town (~12 buildings, ~30
  NPCs vs. WH's mayor's house + store + 3-4 shacks + 3 NPCs) — this is a *scale* gap, already
  addressed by WH's own roadmap (Phase 8 settler recruitment, Phase 12 "6-10 settler homes,
  Clinic, Watchtower, market stalls"), not a structural one.

## Marnie's Ranch — structural takeaways

- **A separate small compound**, not inside the town's fence — reached via its own short path,
  distinct from both the farm and the town proper. This is the key structural fact that shaped
  the decision below: Wasteland Harvest's ranch/sanctuary (`MAPS.md` §3) is likewise its own
  small map area outside the town-core's perimeter fence, not a building slotted into the plaza.
- **A ranch-keeper NPC runs it as a shop**: sells starting livestock and animal supplies, has
  set hours, lives on-site (with a family member or two as flavor/social content). The compound
  itself reads visually as fenced pastures with the keeper's own animals wandering — the ranch
  feels "alive" even before the player owns a single animal of their own.
- **The mechanical split that matters most**: Marnie's Ranch is where you *buy* animals; your
  own barn/coop (built on your own farm) is where you *house* them. The ranch itself is a
  shop-and-atmosphere location, not the player's livestock storage. This is the model
  `ROADMAP.md` Phase 8 now follows (see the reconciliation below) — a rancher NPC + ranch
  compound to buy from, separate from the player-buildable Barn/Coop that actually holds stock.

## What this unblocks

- `MAPS.md` §3 (new) sketches the Ranch/Sanctuary compound's lore/layout, following this
  reference's "separate compound south of the farm" structural fact.
- `GDD.md` §11 gets a new scope-addition flag: the "Animals & pets" system was already designed
  there but had no assigned building type, NPC, or map location until now.
- `ROADMAP.md` Phase 8 gets new checklist items: the ranch compound itself, a rancher NPC, and
  splitting the generic "Storage Barn" building-library entry into distinct Barn/Coop livestock
  buildings (mirroring the Barn/Coop split above), alongside the existing resource-storage
  building.

This document is meant to be **the standing reference point** for future farm/town/environment
work per Sarvesh's request — later sessions building out the town, the ranch, or new adjacent
areas should check here first rather than re-deriving Stardew's structural ideas from scratch.
