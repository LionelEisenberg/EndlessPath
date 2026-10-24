# Gameplay State

This document tracks the player experience on `main`: what a player can actually do, what content exists, and what blocks the next stage of progression. For the one-page summary and roadmap see [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md). For per-system detail see the [documentation index](README.md).

---

## Current Player Experience

All content is in the **Foundation** stage, in one zone (**Spirit Valley**). A new save plays like this. The authoritative beat-by-beat walkthrough with every id is [FOUNDATION_PLAYTHROUGH.md](progression/FOUNDATION_PLAYTHROUGH.md).

1. **Start.** The zone view opens on Spirit Valley:
   - Resources: 25 Madra (cap `100 + 5 × Core Density level`), Core Density 0, 0 Path Points.
   - Loadout: Basic Strike and Enforce equipped; the Foundational Technique equipped for cycling.
   - The only action card is *Talk to the [INTERVENER]*. The zoom-2 map shows only Spirit Valley, framed in fog. The Goals board shows only the Breakthrough milestone (`0 / 100`).
2. **NPC dialogue 1** (Dialogic). It unlocks Wilderness Cycling (and the empty Test Zone, which stays hidden on the map), and starts quest **Awaken Your Core** (`q_fill_core`), which the Goals board shows with a Madra figure (`25 / 100` on a new save).
3. **Cycle.** Click the Madra Ball and keep the cursor in it as it travels its path to earn Madra. The Foundational Technique has no cycling zones, so it earns **no Core Density XP**. Reaching 100 Madra completes step 1.
4. **NPC dialogue 2.** It completes the quest, unlocks **Spring Forest Foraging** and **The Shallow Woods** adventure, and starts **First Steps Out** (`q_first_steps`). When the dialogue ends, foraging starts on its own ("Resumed Spring Forest Foraging").
5. **Forage** (idle). Every 5 s the player gains Spirit Fern (2–6) and Dewdrop Tear (1–5), shown in the Now strip and floated over the map. Foraging costs nothing, can't be toggled off, and the materials have no use yet. From now on an idle action always runs: it pauses for cycling, adventures, dialogue and the shop, and resumes when they end (and on load).
6. **Adventure.** Starting a run needs Madra ≥ 50% of the adventure capacity (`FOUNDATION × 10`, so 50 of 100 on a new save). The whole budget drains into the run.
   - The map is a procedurally generated hex map with fog of war, drawn like the zone map; the wheel zooms it from 1 to 2. Each step costs 5 Stamina, and Stamina regenerates 1/s. A click with too little Stamina logs "Too tired to walk" and shakes the Stamina row.
   - The timer is 300 s, on the chest's clock. The chest names the tile you stand on and what each of its choices does (its own tooltip, when it has one), says when an encounter holds you, and keeps a Run ledger (fights, gold, tiles, loot). A long name or line wraps and the chest grows. Fights are real-time, with Q/W/E/R for abilities on the technique dock.
   - The run ends on a boss win, a death, or a timeout. A scroll end card shows stats and loot.
7. **Win any fight**, then **NPC dialogue 3**. This completes the quest, awards **+1 Path Point**, and starts **Harden Your Core** (`q_reach_core_density_10`).
8. **Path tree** (P). The dock's Path button shows a count seal while points are unspent. Buying *Pure Core Awakening* unlocks Empty Palm and the Smooth Flow technique.
   - The player must equip them by hand: Abilities view (A) and the technique drawers in the zone chest while cycling. A new technique lights NEW on the Wilderness Cycling card and on its drawer.
   - Smooth Flow has cycling zones, so cycling now earns Core Density XP. The only hint is a line of dialogue.
9. **Aura Well** (one per map). Choosing *Mark down the location* unlocks **Aura Well** training: an idle action giving +1.5 Madra/s and +1 Spirit per level.
10. **Reach Core Density 10** (+1 Path Point), then **NPC dialogue 4**. This completes the quest and awards the **Refugee Camp Map**.
11. **Refugee Camp** encounter. It appears in later runs while the player holds the map. Visiting it reveals the **Traveling Merchant**, whose shop sells six gear pieces (once each per save) and Crude Scales for gold.
12. **Fill the core.** Core Density stops at 100 and the XP beyond it is lost. The log says "Your core is full. The Tribulation waits in Spirit Valley.", the cabinet reads "Core full", cycling shows "Core full" instead of "+N XP", the Goals board reads "Face the Tribulation", and **The Tribulation** appears under Cultivate with a NEW seal. Below 100 its card shows "Core 95 / 100" and refuses a click.
13. **Face the Tribulation.** A click at 100 opens a board in the map gap (the log, the Goals board and the dock hide). About 38 s of breathing: press Space or click as the bright sphere crosses the brass ring, and hold through the last breath. 4 cracks fail it. A pass moves the player to **Copper** (level 0, a placeholder curve, "Copper reached" on the Goals board, the card gone); a failure costs 5 Core Density levels (100 → 95), keeps the path points, and leaves the card for another try once the core is full again.
14. **End of content.** No quest is active and no further beats exist. Cycling, adventures, foraging, training, the Merchant and the path tree remain as repeatable loops. Copper unlocks nothing: no zone, quest, path node or system is gated on it.

Other views, all opened from the zone view via keyboard or the dock:

| View | Key | Details |
|---|---|---|
| Inventory | I | 4 tabs: Equipment (2 pages, filter, trash), Consumables (+ 4-slot hotbar), Materials, Journal. See [INVENTORY.md](inventory/INVENTORY.md) |
| Abilities | A | 4-slot loadout with drag-drop and right-click quick equip, a filter, and a details card with the damage breakdown. See [ABILITIES.md](abilities/ABILITIES.md) |
| Character | C | 8 total attributes with tooltips. See [CHARACTER.md](infrastructure/CHARACTER.md) |
| Path | P | Pure Madra skill tree. See [PATH_PROGRESSION.md](progression/PATH_PROGRESSION.md) |

A five-line log board (L opens the full log), the Goals board (the current quest step and the Breakthrough milestone) and quest toasts give feedback. The zone view is described in [ZONES.md](zones/ZONES.md). Progress auto-saves every 5 s to `user://save.tres` ([PERSISTENCE.md](infrastructure/PERSISTENCE.md)).

---

## Content Inventory

### Zones and Actions
| Zone | Actions | Unlock |
|---|---|---|
| Spirit Valley (`SpiritValley`) | 10 actions, listed below | Always |
| Test Zone (`TestZone`) | None (placeholder, no description). Hidden on the map at (-1, 0), west of Spirit Valley; the dev panel can show it | Event `celestial_intervener_dialogue_1` |

| Action (`action_id`) | Type | Unlock | What it does |
|---|---|---|---|
| `celestial_intervener_dialogue_1` | NPC dialogue (once) | — | Starts `q_fill_core` |
| `wilderness_cycling_action` | Cycling | `celestial_intervener_dialogue_1` | Opens the cycling board in the map gap; the chest lists the techniques |
| `celestial_intervener_dialogue_2` | NPC dialogue (once) | Madra ≥ 100 | Completes `q_fill_core`, starts `q_first_steps` |
| `sprint_forest_foraging_action` (sic) | Forage | `q_fill_core_completed` | Spirit Fern + Dewdrop Tear every 5 s |
| `shallow_woods_adventure_action` | Adventure | `q_fill_core_completed` | The Shallow Woods, 300 s limit |
| `celestial_intervener_dialogue_3` | NPC dialogue (once) | `q_first_steps_enemy_defeated` | Completes `q_first_steps`, starts `q_reach_core_density_10` |
| `aura_well_training` | Training | `aura_well_discovered` | 1 s ticks: +1.5 Madra; +1 Spirit per level (60/300/600/1200 ticks, then ×2) |
| `celestial_intervener_dialogue_4` | NPC dialogue (once) | Core Density ≥ 10 | Completes `q_reach_core_density_10` |
| `spirit_valley_merchant` | Merchant | `merchant_discovered` | Opens the shop: 6 gear pieces (once per save) and Crude Scales for gold |
| `spirit_valley_tribulation` | Tribulation | `core_density_full` (Core Density ≥ 100) | "Core 95 / 100" and a refusal until the core is full, then the Breath of the Core: a pass reaches Copper, a failure costs 5 levels |

Details: [ZONES.md](zones/ZONES.md).

### Quests
| Quest | Name | Steps | Reward |
|---|---|---|---|
| `q_fill_core` | Awaken Your Core | Reach 100 Madra → talk to the Intervener | Unlocks Foraging + The Shallow Woods |
| `q_first_steps` | First Steps Out | Win a combat → talk to the Intervener | +1 Path Point |
| `q_reach_core_density_10` | Harden Your Core | Reach Core Density 10 → talk to the Intervener | Refugee Camp Map |

All dialogue is one Dialogic timeline (`celestial_intervener_introduction_1`, labels `dialogue_1`–`dialogue_4`) spoken by the Celestial Intervener. Details: [QUESTS.md](progression/QUESTS.md), [DIALOGUE.md](infrastructure/DIALOGUE.md).

### Items
| Item | Type | Stats / effect | Obtainable on `main`? |
|---|---|---|---|
| Makeshift Dagger (`makeshift_dagger`) | Equipment, MAIN_HAND | STR +3, AGI +2 | Yes, Merchant (60 gold, once) |
| Iron Shortsword (`iron_shortsword`) | Equipment, MAIN_HAND | STR +5, AGI +2 | Yes, Merchant (150 gold, once) |
| Cultivator's Cowl (`cultivators_cowl`) | Equipment, HEAD | WIL +3, SPI +1 | Yes, Merchant (40 gold, once) |
| Reinforced Robes (`reinforced_robes`) | Equipment, ARMOR | BODY +4, RES +2 | Yes, Merchant (180 gold, once) |
| Scripted Bark (`scripted_bark`) | Equipment, OFF_HAND | BODY +2 | Yes, Merchant (75 gold, once) |
| Leeching Ring (`leeching_ring`) | Equipment, ACCESSORY | FND +2, CTRL +2 | Yes, Merchant (120 gold, once) |
| Dreadbeast Tooth Necklace (`dreadbeast_tooth_necklace`) | Equipment, ACCESSORY | STR +2, AGI +2 | Yes, 25% drop from the Ravenous Dreadbeast elite |
| Spirit Fern (`SpiritFern`) | Material | — | Yes, foraging |
| Dewdrop Tear (`DewdropTear`) | Material | — | Yes, foraging |
| Crude Scale (`crude_scale`) | Consumable | +20 Madra, 10 s cooldown (unenforced) | Yes, Merchant (10 gold, unlimited) |
| Barely Coalesced Scale (`barely_coalesced_scale`) | Consumable | Same values as Crude Scale, no icon | No |
| Refugee Camp Map (`refugee_camp_map`) | Quest item | Gates the Refugee Camp encounter | Yes, quest reward |

Consumables can be put on the hotbar, but nothing on `main` uses them. In-combat use is on the unmerged branch `feat/infallible-chaum-58f8ad`. Details: [INVENTORY.md](inventory/INVENTORY.md), [ITEMS.md](inventory/ITEMS.md).

### Abilities
| Ability | Source | Cost | Cooldown / cast | Effect |
|---|---|---|---|---|
| Basic Strike (`basic_strike`) | Innate, equipped at start | 3 Stamina | 2 s / 0.5 s | Physical, 10 + STR×1.0 + AGI×0.5 |
| Enforce (`enforce`) | Innate, equipped at start | 10 Madra | 15 s / 1 s | Next damaging ability ×1.5 (5 s, consumed) |
| Empty Palm (`empty_palm`) | Path node `pure_core_awakening` | 8 Madra | 3 s / instant | Spirit, 15 + SPI×1.0 + AGI×0.3, interrupts the target's cast |
| Power Font (`power_font`) | Path node `power_font` | 30 Madra | 25 s / 3 s | Spirit, 30 + SPI×1.5 + FND×0.5, strips all target buffs |

There are also 3 enemy abilities: `madra_lash`, `famishing_bite` and `coalesce`. Full values: [ABILITIES_MATRIX.md](abilities/ABILITIES_MATRIX.md).

### Enemies and Encounters (The Shallow Woods)
| Encounter | Type | Per map | Enemy / effect | Gold |
|---|---|---|---|---|
| `manifested_spirit_encounter` | Boss (win = victory) | 1 | `amorphous_spirit` (the regular enemy) | 15 |
| `amorphous_spirit_encounter` | Combat | 4 | `amorphous_spirit`: 100 HP, Madra Lash | 15 |
| `starving_dreadbeast_encounter` | Combat | 3 | `starving_dreadbeast`: 85 HP, Famishing Bite (self-stacking Hunger) | 20 |
| `coalescing_spirit_encounter` | Elite | 2 | `coalescing_spirit`: 200 HP, Madra Lash + Coalesce (self-heal) | 0 |
| `ravenous_dreadbeast_encounter` | Elite | 2 | `ravenous_dreadbeast`: STR 15, Famishing Bite | 20, plus 25% necklace |
| `aura_well_encounter` | Rest site | 1 | Rest (+HP/Madra), or mark the location (unlocks Aura Well training) | — |
| `refugee_camp_encounter` | Rest site | 0–1 | Only while holding the map and before discovery; reveals the Merchant | — |

`test_rest_encounter`, `test_trap_encounter` and `test_treasure_encounter` exist but no adventure uses them. Enemies have no sprite art. Details: [ADVENTURING.md](adventuring/ADVENTURING.md), [COMBAT.md](combat/COMBAT.md).

### Cycling Techniques
| Technique | Cycle | Madra per cycle | Cycling zones (max XP per cycle) | Unlock |
|---|---|---|---|---|
| Foundational Technique (`foundation_technique`) | 8 s | 50 | 0 (0 XP) | Default |
| Smooth Flow Technique (`smooth_flow`) | 15 s | 200 | 4 (125) | Path node `pure_core_awakening` |
| Torrential Flow (`torrential_flow`) | 8 s | 250 | 1 (30) | Path node `torrential_flow` |

Details: [CYCLING.md](cycling/CYCLING.md).

### Path Progression
| Path | Nodes | Working in play | Status |
|---|---|---|---|
| Pure Madra (`pure_madra`) | 14: 2 keystone, 4 major, 5 minor, 3 repeatable; 22 points to max | 3 unlock nodes (Pure Core Awakening, Power Font, Torrential Flow) | Auto-selected; Tier 1 only |
| Blackflame, Earth | — | — | Theme data only, no tree |

Points come from every 10th Core Density level, once per stage (+1 in Foundation, +2 in Copper), and the First Steps Out quest (+1). Details: [PATH_PROGRESSION.md](progression/PATH_PROGRESSION.md).

### Cultivation Stages
| Stage | Data | Status |
|---|---|---|
| Foundation | `foundation_advancement_stage.tres`: 10 XP base, ×1.02 per level, Core Density cap 100, Madra cap 100 + 5/level | Active; ends at Core Density 100, where the Tribulation waits |
| Copper | `copper_advancement_stage.tres`: 20 XP base, ×1.02 per level, Core Density cap 100, Madra cap 600 + 10/level | Reached by passing the Tribulation. Placeholder numbers; nothing is gated on it yet |
| Iron, Jade, Silver | Enum values only | Unreachable: no stage resources |

Details: [CULTIVATION.md](cultivation/CULTIVATION.md).

### Events and Unlock Conditions
- **Events (8):** `celestial_intervener_dialogue_1`–`_4`, `q_fill_core_completed`, `q_first_steps_enemy_defeated`, `aura_well_discovered`, `merchant_discovered`.
- **Registered unlock conditions (9):**
  - `celestial_intervener_dialogue_1`
  - `q_fill_core_madra_full` (`RESOURCE_AMOUNT` Madra ≥ 100)
  - `q_fill_core_completed`
  - `q_first_steps_enemy_defeated`
  - `q_reach_cd_10` (`CULTIVATION_LEVEL` ≥ 10)
  - `aura_well_discovered`
  - `merchant_discovered`
  - `core_density_full` (`CULTIVATION_LEVEL` ≥ 100)
  - `test_attribute_requirement_unlock_data` (unused)
- **Inline conditions (2):** an `ITEM_OWNED` check on the Refugee Camp Map, and a duplicate of `merchant_discovered`.

Details: [EVENTS.md](infrastructure/EVENTS.md), [UNLOCKS.md](infrastructure/UNLOCKS.md).

---

## Built but Not Wired

These systems look finished to the player but have no effect:

| What the player sees | Reality | Doc |
|---|---|---|
| 11 path nodes (19 of 22 points) sold as perks | 7 numeric perks are aggregated but nothing reads them; 4 nodes have no effects at all | [PATH_PROGRESSION.md](progression/PATH_PROGRESSION.md) |
| Gear with BODY / FOUNDATION | Player max HP/Stamina/Madra only refresh when a *base* attribute changes, not when gear is equipped | [CHARACTER.md](infrastructure/CHARACTER.md) |
| CONTROL and WILLPOWER on gear | CONTROL does nothing. WILLPOWER only counts toward MIXED-damage defense, and no ability deals MIXED damage | [COMBAT.md](combat/COMBAT.md) |
| Consumable hotbar | Nothing on `main` consumes from it | [INVENTORY.md](inventory/INVENTORY.md) |
| Foraging "Madra cost" field, cycling action modifiers | Exported but never read | [ZONES.md](zones/ZONES.md), [CYCLING.md](cycling/CYCLING.md) |
| Clearing The Shallow Woods | Fires no event, so nothing can gate on it | [ADVENTURING.md](adventuring/ADVENTURING.md) |

---

## Progression Blockers

Ranked by how much they stop the game from growing:

1. **Copper is empty.** The Tribulation ([breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md)) breaks through to a thin Copper stage, and nothing is gated on it: no zone, quest, path node, Scripting or Elixir Making. Foundation has an ending now; what follows it does not exist.
2. **No content after Beat 4 but the Tribulation.** There is no quest, NPC or event after the Merchant. Beat 5 (elite gear drop) is a stub, and Beats 6 and 10 (third keystone, the Zone 2 onramp) are design-only ([FOUNDATION_PLAYTHROUGH.md](progression/FOUNDATION_PLAYTHROUGH.md)).
3. **The gold sink runs dry.** Once the six gear pieces are bought (625 gold), gold only buys Crude Scales.
4. **No real boss.** The Shallow Woods boss fights the regular Amorphous Spirit, and clearing a run records nothing.
5. **Inert perks.** Most of the path tree, and every stat-multiplier hook, does nothing.
6. **Onboarding.** Unlocks are nearly silent (a static NEW seal on new cards; unspent Path Points show only on the dock), the Foundational Technique earns no XP with no clear prompt to switch, and dialogue still has placeholder text (`[INTERVENER]`).

## Recommended Next Steps

The prioritized roadmap (make Foundation complete → break through to Copper → GDD MVP through Iron) lives in [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md#necessary-work). Each system doc's **Work Remaining** section holds the detailed, tagged backlog.
