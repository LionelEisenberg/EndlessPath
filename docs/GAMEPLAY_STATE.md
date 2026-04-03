# Gameplay State

Last updated: 2026-04-03

This document tracks where each game mechanic currently stands — what the player can actually do, what content exists, and what is missing relative to the GDD vision.

---

## Current Player Experience

A new player can currently:

1. **Start on the Zone Map** — see Spirit Valley tile, click it
2. **Talk to the Wisened Dirt Eel** — triggers a Dialogic dialogue, awards a Dagger, unlocks more content
3. **Cycle** — open the cycling mini-game, follow the Madra Ball, click inflection points
4. **Forage** — toggle passive foraging, earn Spirit Fern and Dewdrop Tear materials over time
5. **Open Inventory** — view equipment grid, equip the Dagger, see materials from foraging
6. **Start an Adventure** — enter a procedurally generated hex map, move tile-by-tile
7. **Fight enemies** — encounter the test enemy in combat, use 4 abilities
8. **Defeat the boss** — complete the adventure, earn gold
9. **Repeat** — cycle for more Madra, forage for materials, adventure for gold

The experience loop exists but is thin: one zone, one adventure, one enemy, one dialogue, and Foundation is the only stage.

---

## System-by-System Status

### Cycling

| What works | What doesn't |
|------------|-------------|
| Mouse tracking generates Madra proportional to accuracy | CyclingActionData modifiers (madra_multiplier, xp_multiplier) are ignored |
| Zone clicks award Core Density XP with PERFECT/GOOD/OK tiers | Auto-cycle toggle has no visual distinction on/off |
| Technique selection persists across sessions | Both techniques share the same path (no variety) |
| Resource panel shows Madra, Core Density, stage info | Next stage shows "(MAX)" even though Foundation isn't max |
| Floating text feedback on zone clicks | Zone radius hardcoded (timing_window_ratio unused) |

**Content:** 2 techniques (functionally identical), 3 zones, Foundation stage only.

**GDD gap:** Cycling Techniques should vary paths and rewards. No technique unlocking system exists.

---

### Combat

| What works | What doesn't |
|------------|-------------|
| Real-time ability casting with cooldowns | No AP regeneration in combat (GDD feature) |
| Cast bar for abilities with cast_time > 0 | Only OFFENSIVE ability type — no DEFENSIVE/HEALING |
| Buff/debuff system with attribute modifiers | ALL_ALLIES target type unimplemented |
| DoT damage with stacking | Always uses enemy_pool[0] — no random/multiple enemies |
| 8-attribute damage scaling with defense reduction | Equipment stats don't affect combat |
| Resource bars with ghost trail and floating text | CONTROL and AGILITY have no special runtime effects |
| Simple enemy AI (first-available ability) | Player sprite hardcoded |

**Content:** 6 abilities (4 player, 2 test), 1 enemy.

**GDD gap:** The GDD describes 3 starter skills (Flowing Strike, Stand Your Ground, Empty Palm) — only Empty Palm exists. The "Cycle" tap skill (0-cost AP regen) is not implemented. An Iron Body skill tree is planned but absent.

---

### Adventuring

| What works | What doesn't |
|------------|-------------|
| Procedural hex map generation with MST connectivity | No stamina UI feedback when blocked |
| Fog-of-war tile reveal with pulsing beacons | Movement cost is constant (no terrain/stat variation) |
| Combat, dialogue, and generic encounter choices | No experience or difficulty modifiers |
| 5-minute timer (test adventure) | No cooldown or daily limit enforcement |
| Boss at furthest tile completes the adventure | Debug buttons still in scene |
| Stamina cost per movement step | Only 1 adventure config exists |
| Gold rewards from combat with multiplier chain | TRAP encounter type has no unique handling |

**Content:** 1 adventure (test_adventure_data), 1 combat encounter, 1 boss encounter.

**GDD gap:** Node types should include Treasure Chest and Madra Well — neither exists. Adventure is currently available from Foundation, but the GDD places it at Iron stage.

---

### Inventory

| What works | What doesn't |
|------------|-------------|
| 50-slot equipment grid | Equipment stats don't affect gameplay (attack_power, defense are display-only) |
| 8 gear slots with type validation | Trash slot exists but doesn't work |
| Drag & drop between grid and gear | No consumable item usage |
| Materials tab with quantities | No quest item support |
| Book open/close animation with page turning | Loot system is built but has no authored loot tables |
| Award items from foraging and encounters | Inventory grid count hardcoded in two places |

**Content:** 2 materials (Spirit Fern, Dewdrop Tear), 1 weapon (Dagger). No loot tables.

**GDD gap:** The inventory should support crafting materials from multiple tiers, Knowledge items (Manuals, Recipes, Schematics), and a much larger gear variety.

---

### Zones & Map

| What works | What doesn't |
|------------|-------------|
| Hex tilemap with locked/unlocked rendering | MERCHANT, TRAIN_STATS, ZONE_EVENT, QUEST_GIVER actions unimplemented |
| Zone selection with character walk animation | Offline forage progress not resumed on load |
| Action display grouped by type | Foraging madra cost not deducted |
| Condition-based unlock chain (dialogue → event → unlock) | Only 2 zones exist (1 functional) |
| Forage timer with loot table rolling | |
| One-time action completion tracking | |

**Content:** Spirit Valley (5 actions), Test Zone (0 actions, exists only as an unlock target).

**GDD gap:** The GDD describes a 3D hex-grid planet view, zone bosses gating progression, and merchants. The current map is a flat 2D tilemap with 2 tiles.

---

### Cultivation & Progression

| What works | What doesn't |
|------------|-------------|
| Core Density XP leveling with exponential scaling | Breakthrough mechanic is a stub |
| Madra cap increases with level | Only Foundation stage has data |
| Unlock condition system (5 of 10 types work) | No Copper/Iron/Jade/Silver stage resources |
| Event-triggered content unlocks | Equipment doesn't grant stat bonuses |
| Gold tracking | GameSystem enum doesn't gate UI visibility |

**Content:** Foundation stage, 2 unlock conditions.

**GDD gap:** The entire progression spine above Foundation is missing. Breakthrough/Tribulation is the key advancement mechanic and has no implementation. The unlock system lacks ITEM_OWNED, ZONE_UNLOCKED, ADVENTURE_COMPLETED, and GAME_SYSTEM_UNLOCKED condition types.

---

### Planned Systems (No Code)

| System | GDD Stage | Status | Dependencies |
|--------|-----------|--------|-------------|
| **Scripting** | Copper | Not started | Consumable item support, calligraphy input system |
| **Elixir Making** | Copper | Not started | Multi-station UI, consumable items, higher-tier ingredients |
| **Soulsmithing** | Iron | Not started | Tetris-like puzzle UI, schematic system, equipment stat wiring |

---

## Content Inventory

### Zones
| Zone | Actions | Unlock |
|------|---------|--------|
| Spirit Valley | Cycling, NPC Dialogue, Mountain Cycling, Foraging, Adventure | Always |
| Test Zone | None | After NPC dialogue |

### Items
| Item | Type | Source |
|------|------|--------|
| Dagger | Weapon (10 atk) | NPC dialogue reward |
| Spirit Fern | Material | Foraging |
| Dewdrop Tear | Material | Foraging |

### Abilities
| Ability | Cost | Cooldown | Notes |
|---------|------|----------|-------|
| Basic Strike | 5 stam | 2.0s | STR+AGI scaling |
| Empty Palm | 30 stam | 8.0s | High damage, STR scaling |
| Enforce | 10 madra | 8.0s | Self-buff: STR/SPIRIT x1.5 |
| Power Font | 10 madra | 5.0s | 3s cast, SPIRIT scaling |

### Enemies
| Enemy | Abilities | Gold |
|-------|-----------|------|
| Test Enemy | test_cast_ability | 10 |

### Unlock Conditions
| Condition | Type | Trigger |
|-----------|------|---------|
| initial_spirit_valley_dialogue_1 | EVENT_TRIGGERED | NPC dialogue completion |
| test_attribute_requirement_unlock_data | ATTRIBUTE_VALUE | BODY >= 20 |

---

## Progression Blockers

These are the biggest gaps preventing a playable loop beyond Foundation:

1. **No breakthrough mechanic** — players can level Core Density infinitely but never advance stages
2. **No Copper/Iron stage data** — even with breakthrough, there's nowhere to go
3. **Equipment doesn't affect combat** — the Dagger is cosmetic
4. **Only 1 enemy** — combat has no variety
5. **Abilities are hardcoded** — no way to unlock or change abilities
6. **No save persistence** — `reset_save_data = true` wipes progress every launch

---

## Recommended Next Steps (Gameplay Priority)

1. **Implement breakthrough** — Core Density 100% → Tribulation challenge → Copper stage
2. **Create Copper stage resource** — new madra cap, XP scaling, unlock Scripting/Elixir Making
3. **Wire equipment stats** — make the Dagger actually grant attack power
4. **Add more enemies** — diverse CombatantData with different abilities and strategies
5. **Add more zones** — each with unique foraging resources and adventure maps
6. **Enable save persistence** — flip `reset_save_data = false`
7. **Build the Scripting system** — first Copper-stage content
8. **Expand adventure content** — more encounter types, loot tables, adventure configurations
