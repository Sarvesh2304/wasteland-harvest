extends Node
## Global event bus (autoload "Events", 2026-10-07). Gameplay systems emit; presentation systems
## (HUD toasts, audio, achievements, quests, skills) listen — so a tree falling doesn't need to
## know a HUD exists. Keep payloads plain data.

## The player received items (pickup collected, harvest, purchase, reward...).
signal item_gained(item_id: String, count: int)
## Skill XP earned (skill ids: farming, foraging, scavenging, combat, crafting).
signal xp_gained(skill: String, amount: int)
## A skill reached a new level.
signal skill_leveled(skill: String, level: int)
## A short on-screen message (bottom-centre toast), e.g. "Your backpack is full."
signal message(text: String)
## A crop was harvested (crop_id, count) — quests/achievements/stats listen.
signal crop_harvested(crop_id: String, count: int)
## A world object was destroyed (kind) — quests/stats listen.
signal object_destroyed(kind: String)
## An item was shipped/sold for credits.
signal item_sold(item_id: String, count: int, credits: int)
## An enemy was killed (enemy kind).
signal enemy_killed(kind: String)
## Something was crafted (recipe id, count).
signal item_crafted(item_id: String, count: int)
## A quest changed state (quest id, new state).
signal quest_updated(quest_id: String, state: String)
