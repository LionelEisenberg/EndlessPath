# Gameplay State

Last updated: 2026-04-07

This document tracks the current player experience — what a player can actually do, what content exists, and what blocks the next stage of progression. For per-system details, see the [system documentation index](CODEBASE_STATE.md#system-documentation-index).

---

## Current Player Experience

A new player can currently:

1. **Start on the Zone Map** — see Spirit Valley tile, click it; the zone view features parallax backgrounds, floating panels, and card-style action panels (PR #14)
2. **Talk to the Wisened Dirt Eel** — triggers a Dialogic dialogue, awards a Dagger, unlocks more content
3. **Cycle** — open the cycling mini-game, follow the Madra Ball, click inflection points for XP; the cycling UI features shader effects, particle feedback, and a tabbed info panel (PRs #12/#13)
4. **Forage** — toggle passive foraging, earn Spirit Fern and Dewdrop Tear materials over time
5. **Open Inventory** — view equipment grid, equip the Dagger, see materials from foraging
6. **Start an Adventure** — enter a procedurally generated hex map, move tile-by-tile spending stamina; adventures now cost Madra (50% threshold required, with particle drain animation) (PR #16)
7. **Fight enemies** — encounter the test enemy in combat, use 4 abilities; equipped gear stats now flow through to combat (PR #9)
8. **Defeat the boss** — complete the adventure, earn gold
9. **Repeat** — cycle for more Madra, forage for materials, adventure for gold

Navigation is handled by a **Toolbar** with buttons for Inventory, Abilities, Character, and Path views (PRs #10/#14). A **draggable log window** provides in-game feedback (PR #15). The entire UI uses a unified warm parchment theme (PR #11).

The core loop exists but is thin: one zone, one adventure, one enemy, one dialogue, and Foundation is the only cultivation stage. There is no way to advance beyond Foundation.

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
| Ability | Cost | Cooldown | Cast | Scaling | Damage Type |
|---------|------|----------|------|---------|-------------|
| Basic Strike | 10 stam | 4.0s | 0s | STR 0.2, BODY 0.2, AGI 0.2 | Physical |
| Empty Palm | 12 madra, 3 stam | 3.0s | 0s | AGI 0.3, SPI 1.0 | Physical |
| Enforce | 10 madra | 30.0s | 0s | STR x1.5, SPI x1.5 for 8s | Buff |
| Power Font | 20 madra | 15.0s | 3.0s | SPI 1.5, FND 0.5 | Madra |

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
6. **Abilities are hardcoded** — `get_equipped_abilities()` returns 4 fixed `.tres` files, no unlock or equip system
7. **No save persistence** — `reset_save_data = true` wipes progress every launch
8. **No character stats screen** — player has no way to see their attributes, equipped gear, or abilities in one place

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
9. Build ability unlock/equip system — let players discover and choose abilities
10. Add character stats screen — let players see their growth
11. Add more zones with unique content

### Future (post-Copper)
12. Build Scripting system (Copper unlock)
13. Build Elixir Making system (Copper unlock)
14. Build Soulsmithing system (Iron unlock)
15. New player onboarding — no guidance on first load pointing player to the NPC dialogue, which gates most content
