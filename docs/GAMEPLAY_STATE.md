# Gameplay State

Last updated: 2026-04-15

This document tracks the current player experience — what a player can actually do, what content exists, and what blocks the next stage of progression. For per-system details, see the [system documentation index](CODEBASE_STATE.md#system-documentation-index).

---

## Current Player Experience

A new player can currently:

1. **Start on the Zone Map** — see Spirit Valley tile, click it; the zone view features parallax backgrounds, floating panels, card-style action panels (PR #14), atmospheric mist/motes, hover selector ring, glowing paths between zones, and lock overlays on gated tiles (PR #23)
2. **Talk to the Wisened Dirt Eel** — triggers a Dialogic dialogue, awards a Dagger, unlocks more content
3. **Cycle** — open the cycling mini-game, follow the Madra Ball, click inflection points for XP; the cycling UI features shader effects, particle feedback, and a tabbed info panel (PRs #12/#13)
4. **Forage** — toggle passive foraging, earn Spirit Fern and Dewdrop Tear materials over time
5. **Open Inventory** — view equipment grid, equip the Dagger, see materials from foraging
6. **Start an Adventure** — enter a procedurally generated hex map with fog-of-war (shader fog + smoke veil overlays), per-type encounter icons, atmospheric mist/motes, and a tiled-texture path preview that commits on click and fades behind the player as they walk; move tile-by-tile spending stamina; adventures cost Madra (50% threshold required, with particle drain animation) (PRs #16/#23)
7. **Fight enemies** — encounter the test enemy in combat, use 4 abilities; equipped gear stats now flow through to combat (PR #9)
8. **Defeat the boss** — complete the adventure, earn gold; end card shows stats and loot (PR #19)
9. **Open Path Tree** — press P to view the Pure Madra skill tree; earn Path Points every 10 Core Density levels; purchase nodes for cycling/combat/progression perks; pannable/zoomable tree with animated shaders (PR #20)
10. **Manage Abilities** — press A to open the abilities view; drag-and-drop abilities into a 4-slot loadout; filter by type, sort by cost/name; hoverable stat pills show damage breakdowns; path tree purchases unlock new abilities (PR #22)
11. **Repeat** — cycle for more Madra, forage for materials, adventure for gold, spend Path Points on perks

Navigation is handled by a **Toolbar** with buttons for Inventory, Abilities, Character, and Path views (PRs #10/#14/#20). A **draggable log window** provides in-game feedback (PR #15). The entire UI uses a unified warm parchment theme (PR #11).

The core loop now includes a meaningful progression sink: cycle for XP → earn Path Points → spend on perks that improve cycling, combat, and adventuring. However, the loop is still Foundation-only with one zone, one adventure, and one enemy.

---

## Content Inventory

### Zones
| Zone | Actions | Unlock |
|------|---------|--------|
| Spirit Valley | Basic Room Cycling, Wisened Dirt Eel Dialogue, Mountain Top Cycling, Spring Forest Foraging, Test Adventure | Always |
| Test Zone | None | After NPC dialogue |

### Items
| Item | Type | Source |
|------|------|--------|
| Dagger | Weapon (MAIN_HAND, `attribute_bonuses = { STRENGTH: 3, AGILITY: 1 }`) | NPC dialogue reward |
| Sword | Weapon (MAIN_HAND, `attribute_bonuses = { STRENGTH: 6, AGILITY: 2 }`) | — |
| Spirit Fern | Material | Foraging |
| Dewdrop Tear | Material | Foraging |

### Abilities (Player)
| Ability | Source | Madra Type | Cost | Cooldown | Cast | Scaling | Damage Type |
|---------|--------|-----------|------|----------|------|---------|-------------|
| Basic Strike | INNATE | NONE | 10 stam | 4.0s | 0s | STR 0.2, BODY 0.2, AGI 0.2 | Physical |
| Empty Palm | PATH | PURE | 12 madra, 3 stam | 3.0s | 0s | AGI 0.3, SPI 1.0 | Physical |
| Enforce | INNATE | NONE | 10 madra | 30.0s | 0s | STR x1.5, SPI x1.5 for 8s | Buff |
| Power Font | INNATE | PURE | 20 madra | 15.0s | 3.0s | SPI 1.5, FND 0.5 | Madra |

Abilities are managed by `AbilityManager` (PR #22): INNATE abilities start unlocked, PATH abilities are unlocked via path tree purchases (UNLOCK_ABILITY effect). Players equip up to 4 abilities in a loadout via the AbilitiesView (press A).

### Enemies
| Enemy | Abilities | Gold |
|-------|-----------|------|
| Test Enemy | test_cast_ability | 10 |

### Adventure Encounters
| Encounter | Type | Notes |
|-----------|------|-------|
| Test Combat | Combat | 1 enemy, basic gold reward |
| Boss Combat | Combat (Boss) | Furthest tile, completes adventure |
| Treasure | Treasure | Rolls weapon loot table |
| Rest | Rest | — |
| Trap | Trap | No unique handling |

### Unlock Conditions
| Condition | Type | Trigger |
|-----------|------|---------|
| initial_spirit_valley_dialogue_1 | EVENT_TRIGGERED | NPC dialogue completion |
| test_attribute_requirement_unlock_data | ATTRIBUTE_VALUE | BODY >= 20 |

### Path Progression
| Path | Tier | Nodes | Status |
|------|------|-------|--------|
| Pure Madra | Tier 1 (Foundation) | 14 nodes (1 keystone, 2 major, 7 minor, 4 repeatable) | Implemented (PR #20) |
| Blackflame | — | — | Theme data only, no tree |
| Earth | — | — | Theme data only, no tree |

### Cultivation Stages
| Stage | Data Exists | Status |
|-------|-------------|--------|
| Foundation | Yes | Active — only stage with an AdvancementStageResource |
| Copper | No | Planned — unlocks Scripting, Elixir Making |
| Iron | No | Planned — unlocks Soulsmithing |
| Jade | No | Planned |
| Silver | No | Planned |

---

## Progression Blockers

These are the biggest gaps preventing a playable loop beyond Foundation:

1. **No breakthrough mechanic** — players can level Core Density to 100 but never advance stages. Design doc exists at [breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md)
2. **No Copper stage data** — even with breakthrough, there's nowhere to go. No AdvancementStageResource for Copper
3. ~~**Equipment doesn't affect combat** — the Dagger's `attack_power: 10` is cosmetic. `_get_attribute_bonuses()` returns 0~~ (Done - PR #9)
4. ~~**Madra pools disconnected** — cycling Madra (ResourceManager) and combat Madra (VitalsManager) are separate systems with no link. Design for unification in [RESOURCES.md](infrastructure/RESOURCES.md)~~ (Done - PR #16)
5. **Only 1 enemy** — combat has no variety
6. ~~**Abilities are hardcoded** — `get_equipped_abilities()` returns 4 fixed `.tres` files, no unlock or equip system~~ (Done - PR #22: AbilityManager singleton with unlock/equip/4-slot loadout, AbilitiesView UI with drag-drop, filter/sort, stat tooltips)
7. **No save persistence** — `reset_save_data = true` wipes progress every launch
8. ~~**No character stats screen** — player has no way to see their attributes, equipped gear, or abilities in one place~~ (Partially done - PR #22: AbilitiesView shows ability loadout and stat breakdowns; full character sheet still needed)

---

## Recommended Next Steps (Gameplay Priority)

### Foundation Stage (make the current loop solid)
1. ~~Fix persistence — flip `reset_save_data = false`, fix `reset_state()` naming mismatch~~ *(PR #3 fixed naming; `reset_save_data` still defaults to true)*
2. ~~Wire equipment stats to combat — make the Dagger matter~~ (Done - PR #9)
3. ~~Unify Madra pools — create the cycle→adventure resource loop~~ (Done - PR #16)
4. Add ability tooltips and cost feedback in combat — make the system learnable
5. Add more enemies and encounters — combat variety
6. ~~Remove debug artifacts (+100 STR)~~ *(PR #3 fixed +100 STR; debug buttons and enable_ai flag still present)*

### Copper Stage (unlock the next progression tier)
7. Implement breakthrough — Tribulation mini-game via adventure encounter
8. Create Copper AdvancementStageResource — new XP scaling, madra cap
9. ~~Build ability unlock/equip system — let players discover and choose abilities~~ (Done - PR #22)
10. Add character stats screen — let players see their full growth (abilities covered by PR #22, need equipment/attributes view)
11. Add more zones with unique content

### Future (post-Copper)
12. Build Scripting system (Copper unlock)
13. Build Elixir Making system (Copper unlock)
14. Build Soulsmithing system (Iron unlock)
15. New player onboarding — no guidance on first load pointing player to the NPC dialogue, which gates most content
