# Cultivation & Progression System

## Overview

The cultivation system drives stage-based progression in Endless Path. Players advance through two axes: **Core Density Level** (continuous XP-based leveling within a stage) and **Advancement Stage** (discrete cultivation stages: Foundation, Copper, Iron, Jade, Silver). Reaching Core Density 100 and completing a Tribulation mini-game advances the player to the next stage, unlocking new game systems.

## Progression Model

### Axis 1: Core Density Level
- A continuous float level representing how filled the player's core is
- XP added via `CultivationManager.add_core_density_xp(amount)` (from Cycling zone clicks)
- XP formula: `core_density_base_xp_cost * pow(core_xp_scaling_factor, level - 1)`
- Foundation stage: base=10, scaling=1.02 — level 1 costs 10 XP, level 50 costs ~26.8 XP
- Multi-level-up supported per single XP award via a `while` loop
- Level affects Madra cap: `max_madra = max_madra_base + max_madra_per_core_density_level * level`
- Foundation: `100 + 5 * level` — level 0 = 100 max, level 20 = 200 max

### Axis 2: Advancement Stage
| Stage | Enum Value | Resource Exists | Unlocks |
|-------|------------|-----------------|---------|
| Foundation | `FOUNDATION` | Yes | Cycling, Zones, Adventuring, Combat |
| Copper | `COPPER` | No | Scripting, Elixir Making (planned) |
| Iron | `IRON` | No | Soulsmithing (planned) |
| Jade | `JADE` | No | Advanced systems (planned) |
| Silver | `SILVER` | No | End-game (planned) |

Only Foundation has an `AdvancementStageResource` with actual data. `attempt_breakthrough()` is a stub.

### AdvancementStageResource
| Field | Type | Description |
|-------|------|-------------|
| `stage_name` | `String` | Display name |
| `stage_id` | `AdvancementStage` | Enum reference |
| `core_density_base_xp_cost` | `float` | Base XP per level (10.0) |
| `core_xp_scaling_factor` | `float` | Exponential scaling (1.02) |
| `max_madra_base` | `float` | Madra cap at level 0 (100.0) |
| `max_madra_per_core_density_level` | `float` | Cap increase per level (5.0) |
| `next_stage` | `AdvancementStageResource` | Linked list to next (currently null) |
| `unlocking_mechanics` | `Array[String]` | Defined but unused |
| `icon` | `Texture2D` | Defined but unused |

## Integration Map

```
Cycling → CultivationManager.add_core_density_xp()
              → core_density_level_updated → UnlockManager re-evaluates
              → max_madra recalculated via ResourceManager
              → every 10 levels → PathManager.add_points(1) (PR #20)

Core Density 100 + Adventure Breakthrough Site → Tribulation mini-game
              → Success → advancement_stage_changed → UnlockManager re-evaluates
              → Core Density resets to 0 for new stage
```

## Key Files

| File | Purpose |
|------|---------|
| `singletons/cultivation_manager/cultivation_manager.gd` | Core Density + stage progression |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | Stage data |

## Existing Content

### Advancement Stages
Only Foundation exists as a `.tres` resource. `advancement_stage_list.tres` exists but is never loaded by any manager.

## Work Remaining

### Bugs

- `[HIGH]` `advancement_stage_changed` signal emitted only on save reset, not on actual stage advancement — downstream listeners (UnlockManager) won't react to breakthrough success

### Missing Functionality

- `[HIGH]` `attempt_breakthrough()` is a stub — no breakthrough mechanic exists. Full design doc at [breakthrough-tribulation.md](breakthrough-tribulation.md). Tribulation triggers from adventure mode, reuses cycling components
- `[HIGH]` Copper `AdvancementStageResource` needed — new XP scaling, madra cap, `next_stage` linkage from Foundation. Required for breakthrough to have a destination
- `[MEDIUM]` `unlocking_mechanics` and `icon` fields on AdvancementStageResource are defined but never consumed — need to wire these or remove them
- `[LOW]` `advancement_stage_list.tres` exists but is never loaded by any manager — dead resource or needs to be wired into CultivationManager

### Content

- `[HIGH]` Only Foundation stage has data — no Copper/Iron/Jade/Silver `.tres` resources exist
- `[MEDIUM]` No stage-specific unlock definitions — which GameSystems unlock at each stage needs to be authored as UnlockConditionData entries

### UI

- `[MEDIUM]` No UI indicator when Core Density reaches 100 and breakthrough is available — player needs a hint to seek a breakthrough site in adventure mode

### Tech Debt

- `[LOW]` `_get_current_stage_resource()` is private (underscore prefix) but called by ResourceManager and CyclingResourcePanel — should be a public API

### Related Docs

- **Resources (Madra, Gold):** [infrastructure/RESOURCES.md](../infrastructure/RESOURCES.md)
- **Unlock System:** [infrastructure/UNLOCKS.md](../infrastructure/UNLOCKS.md)
- **Character State:** [infrastructure/CHARACTER.md](../infrastructure/CHARACTER.md)
- **Events:** [infrastructure/EVENTS.md](../infrastructure/EVENTS.md)
- **Persistence:** [infrastructure/PERSISTENCE.md](../infrastructure/PERSISTENCE.md)
