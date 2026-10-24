# Cultivation System

Last updated: 2026-10-23

## Overview

Cultivation tracks the player's power on two axes:

- **Core Density level**: an XP-driven level within the current stage. It raises the Madra cap and awards path points every 10 levels.
- **Advancement Stage**: `FOUNDATION`, `COPPER`, `IRON`, `JADE` or `SILVER`.

`CultivationManager` (autoload) owns both, storing them in `SaveGameData`. Each stage's numbers come from an `AdvancementStageResource`.

Only the Foundation stage is playable. Only Foundation has stage data, and there is no way to change stage: `CultivationManager.attempt_breakthrough()` is an empty stub with no callers. The designed breakthrough (a Spirit Valley action at Core Density 100 that runs the Breath of the Core mini-game, then Copper) is summarised in [breakthrough-tribulation.md](breakthrough-tribulation.md) and is not implemented.

## Player Experience

1. A new save starts at **Foundation**, Core Density level 0, 0 XP, 25 Madra, with a Madra cap of 100.
2. Core Density XP comes only from scoring cycling zones (see [CYCLING.md](../cycling/CYCLING.md)). The starting Foundational Technique has no zones. The first XP-earning technique, Smooth Flow, comes from the `pure_core_awakening` path node. The player buys it with the path point awarded by the "First Steps Out" quest (`q_first_steps`).
3. XP fills the cabinet's XP beads and its `xp / need XP` figure (a scored cycling zone also sends XP pellets into the cabinet's Core orb). Each level costs 2% more XP than the previous one, starting at 10 XP for level 1. One scored zone can grant several levels.
4. Each level raises the Madra cap by 5.
5. Every 10th level grants **1 path point** at Foundation, spent in the Path Tree.
6. The quest "Harden Your Core" (`q_reach_core_density_10`) asks for level 10.
7. Stage and level are shown on the zone view's cultivator cabinet (`Foundation` / `Level N`, plus the Core orb that is full at level 100). The cabinet stays up beside the cycling board, so cycling has no readout of its own.
8. **At level 100 nothing happens.** There is no hint, no breakthrough and no cap. The Core orb reads full, levels keep going (each more expensive), path points keep coming every 10 levels, and the Madra cap keeps growing.

## Architecture

```
CultivationManager (autoload #2)                 — singletons/cultivation_manager/cultivation_manager.gd
  advancement_stage_resources: Array[AdvancementStageResource]
      = [preload(foundation_advancement_stage.tres)]
  live_save_data → SaveGameData.core_density_xp / core_density_level / current_advancement_stage

AdvancementStageResource (Resource)              — scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd
AdvancementStageList (Resource, never loaded)    — advancement_stage_list.gd + resources/cycling/advancement_stages/advancement_stage_list.tres

Writers:  CyclingTechnique.try_score_zone() → add_core_density_xp()
          DevPanel "Add CD XP" → add_core_density_xp()
Readers:  ResourceManager.add_madra()           — Madra cap via get_max_madra()
          CultivatorPlate (zone view cabinet)   — stage name, level, XP beads, Madra cap, core orb up to BREAKTHROUGH_LEVEL
          GoalsPanel                            — the Breakthrough milestone, level / BREAKTHROUGH_LEVEL
          UnlockConditionData.evaluate()        — CULTIVATION_STAGE / CULTIVATION_LEVEL
          PathManager._is_stage_reached()       — node required_stage gate
          SaveGameData._to_string()             — get_advancement_stage_name()
```

## Data Model

### AdvancementStage enum (`CultivationManager.AdvancementStage`)
`FOUNDATION` = 0, `COPPER` = 1, `IRON` = 2, `JADE` = 3, `SILVER` = 4.

### Constants
| Constant | Value | Use |
|----------|-------|-----|
| `PATH_POINTS_PER_STAGE` | `{FOUNDATION: 1, COPPER: 2, IRON: 3, JADE: 4}` | Path points per milestone. `SILVER` has no entry and falls back to 1 |
| `PATH_POINT_LEVEL_INTERVAL` | `10` | Milestone every N levels |

### AdvancementStageResource
| Field | Type | Class default | Read by code? |
|-------|------|---------------|---------------|
| `stage_name` | `String` | `""` | Yes (stage name getters) |
| `stage_id` | `CultivationManager.AdvancementStage` | `FOUNDATION` | Yes (stage lookup) |
| `core_density_base_xp_cost` | `float` | `10.0` | Yes |
| `core_xp_scaling_factor` | `float` | `1.0` | Yes |
| `unlocking_mechanics` | `Array[String]` | `[]` | No |
| `max_madra_base` | `float` | `0.0` | Yes |
| `max_madra_per_core_density_level` | `float` | `0.0` | Yes |
| `icon` | `Texture2D` | `null` | No |
| `next_stage` | `AdvancementStageResource` | `null` | No |

| Method | Formula |
|--------|---------|
| `get_xp_for_level(level: int) -> float` | `core_density_base_xp_cost × core_xp_scaling_factor^(level − 1)` (XP to reach `level` from `level − 1`) |
| `get_max_madra(level: int) -> float` | `max_madra_base + max_madra_per_core_density_level × level` |

### SaveGameData (cultivation fields)
| Field | Type | Default |
|-------|------|---------|
| `core_density_xp` | `float` | `0.0`: XP into the current level |
| `core_density_level` | `float` | `0.0`: whole levels stored as a float |
| `current_advancement_stage` | `CultivationManager.AdvancementStage` | `FOUNDATION` |
| `madra` | `float` | `25.0`, owned by `ResourceManager` and capped by the stage |

### CultivationManager API
| Method | Returns | Notes |
|--------|---------|-------|
| `add_core_density_xp(amount: float)` | untyped (void) | See flow below |
| `attempt_breakthrough()` | untyped | Body is `return`. No callers |
| `get_xp_for_next_level()` | `float` | `stage.get_xp_for_level(level + 1)`, i.e. `base × factor^level`. Returns `0.0` if there is no save or no stage resource |
| `get_core_density_xp()` / `get_core_density_level()` | `float` | `0.0` without save data |
| `get_current_advancement_stage()` | `AdvancementStage` | `FOUNDATION` without save data |
| `get_current_advancement_stage_name()` | `String` | `"Unknown"` if the stage has no resource |
| `get_advancement_stage_name(stage)` | `String` | `"Unknown"` if the stage has no resource |
| `get_max_madra()` | `float` | The Madra pool cap: the current stage's `get_max_madra(level)`. `0.0` without a stage resource. `ResourceManager`, `CyclingTechnique` (its cap check) and `CultivatorPlate` read it |
| `BREAKTHROUGH_LEVEL` (const) | `int` | 100. The Goals board's milestone and the cabinet's core orb read it; nothing enforces it |
| `_get_current_stage_resource()` / `_get_stage_resource(stage)` | `AdvancementStageResource` | Private; only the manager calls them now |

## Core Systems

### Core Density XP and Leveling
```
add_core_density_xp(amount)                                   # cultivation_manager.gd:69-99
  core_density_xp += amount
  needed = get_xp_for_next_level()                            # base × factor^level; 0.0 if no stage resource
  while core_density_xp >= needed:
      core_density_level += 1
      core_density_xp -= needed
      core_density_level_updated.emit(xp, level)
      if int(level) % PATH_POINT_LEVEL_INTERVAL == 0 and int(level) > 0:      # every 10 levels (lines 89-93)
          PathManager.add_points(PATH_POINTS_PER_STAGE.get(current_advancement_stage, 1))
          # Foundation 1, Copper 2, Iron 3, Jade 4; Silver and anything else fall back to 1
      needed = get_xp_for_next_level()
  core_density_xp_updated.emit(xp, level)
```
- Several level-ups from one award are handled by the `while` loop. Overflow XP carries into the next level.
- Path points per milestone depend on the current stage, not a flat 1. Only Foundation is reachable, so in practice every 10th level gives 1 point.
- **There is no level cap.** Neither `add_core_density_xp()` nor `AdvancementStageResource` has a maximum. The only "100" in the code is display: `CultivationManager.BREAKTHROUGH_LEVEL`, read by the cabinet's core orb and the Goals board's milestone (both capped there), sets when the orb and the milestone read full.
- Path-perk hooks `CORE_DENSITY_XP_MULT` and `MADRA_ON_LEVEL_UP` would plug into this function, but are not applied (see [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md)).

### Madra Cap
Two different maximums exist:

| Value | Formula (Foundation) | Enforced by | Shown in |
|-------|----------------------|-------------|----------|
| **Pool cap** (cultivation) | `get_max_madra(level)` = `100 + 5 × Core Density level` | `ResourceManager.add_madra()` clamps to `[0, cap]` | The zone view's cultivator cabinet (`X / Y`) |
| **Adventure capacity** (character) | `CharacterAttributesData.get_max_madra()` = `FOUNDATION attribute × 10` (100 at the default 10) | `ResourceManager.get_adventure_madra_capacity()` / budget; combat `VitalsManager` | Adventure start |

The `MADRA_CAPACITY_BONUS` path perk is aggregated by `PathManager` but not added to either cap. See [RESOURCES.md](../infrastructure/RESOURCES.md) for the pool and adventure budget.

### Advancement Stage and Breakthrough
- `current_advancement_stage` is written only by `SaveGameData.reset()`.
- `attempt_breakthrough()` is a stub with no callers.
- `advancement_stage_changed` is emitted only from `_update_resources()`, which runs in `_ready()` and on `PersistenceManager.save_data_reset`. It always carries the unchanged stage.
- Stage lookups go through `advancement_stage_resources`. Only Foundation is listed, so any other stage resolves to `null`. A `null` stage makes `get_xp_for_next_level()` return 0 and makes `ResourceManager.add_madra()` clamp Madra to 0 (see Bugs).

**What a Foundation → Copper breakthrough still needs:**
1. A Copper `AdvancementStageResource` `.tres` (`stage_id = COPPER`, XP curve, Madra cap) added to `advancement_stage_resources`. This has to land before any code can change the stage.
2. The level cap, decided on 2026-10-23: `max_core_density_level` (100) on the stage resource, with XP earned at the cap discarded.
3. An `advance_to_next_stage()` (replacing `attempt_breakthrough()`) that sets the stage, resets level and XP, and emits `advancement_stage_changed` plus the Core Density signals, and a `lose_core_density_levels()` for the failure penalty.
4. The Tribulation itself: a Spirit Valley `TribulationActionData`, `TribulationData`, `TribulationRun`, and a Tribulation view and state. None exist. See the [Tribulation spec](../superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md).
5. Path-point milestones paid once per stage. Today they re-pay, so 100 → 95 → 100 would pay the level-100 point twice.
6. Something for Copper to unlock. No `CULTIVATION_STAGE` unlock conditions exist, no path node requires a stage above Foundation, and Scripting and Elixir Making are not built.

## Signals

| Signal | Emitted | Listeners |
|--------|---------|-----------|
| `core_density_xp_updated(xp, level)` | End of every `add_core_density_xp()`; `_update_resources()` | `CultivatorPlate` |
| `core_density_level_updated(xp, level)` | Each level gained; `_update_resources()` | `UnlockManager` (re-evaluates all conditions), `CultivatorPlate`, `GoalsPanel` |
| `advancement_stage_changed(new_stage)` | `_update_resources()` only | `UnlockManager`, `CultivatorPlate` |

## Integration Points

| System | Connection |
|--------|------------|
| Cycling | `CyclingTechnique.try_score_zone()` → `add_core_density_xp(zone XP)`. This is the only gameplay XP source |
| `ResourceManager` | `add_madra()` reads `get_max_madra()` for the pool cap |
| `PathManager` | Receives `add_points()` every 10 levels. `_is_stage_reached()` compares node `required_stage` with the current stage (tests use `_test_stage_override`) |
| `UnlockManager` / `UnlockConditionData` | Re-evaluates on `core_density_level_updated` and `advancement_stage_changed`. `CULTIVATION_STAGE` and `CULTIVATION_LEVEL` conditions query the manager |
| `QuestManager` | `q_reach_core_density_10` step 1 completes when `q_reach_cd_10` unlocks |
| UI | The zone view's `CultivatorPlate` and `GoalsPanel` read `BREAKTHROUGH_LEVEL` |
| `PersistenceManager` | Fields above persist in `user://save.tres` |
| `DevPanel` (Ctrl+Shift+D) | "Add CD XP" calls `add_core_density_xp(value)`. There is no stage control |

## Existing Content

### Advancement Stages
| Stage | Resource | `stage_name` | Base XP | Scaling | Madra cap | `next_stage` | Path points per 10 levels |
|-------|----------|--------------|---------|---------|-----------|--------------|---------------------------|
| Foundation | `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres` | `Foundation` | 10.0 (class default) | 1.02 | 100 + 5 × level | `null` | 1 |
| Copper | none | — | — | — | — | — | 2 |
| Iron | none | — | — | — | — | — | 3 |
| Jade | none | — | — | — | — | — | 4 |
| Silver | none | — | — | — | — | — | 1 (fallback) |

`advancement_stage_list.tres` lists only Foundation and is never loaded.

### Foundation Curve
| Level reached | XP for that level | Cumulative XP | Madra cap | Path points so far |
|---------------|-------------------|---------------|-----------|--------------------|
| 1 | 10.0 | 10.0 | 105 | 0 |
| 10 | 11.95 | 109.5 | 150 | 1 |
| 20 | 14.57 | 243.0 | 200 | 2 |
| 30 | 17.76 | 405.7 | 250 | 3 |
| 50 | 26.39 | 845.8 | 350 | 5 |
| 100 | 71.03 | 3,122.3 | 600 | 10 |

Pacing derived from the authored values, counting cycle time only:

- **Smooth Flow** (125 / 70 / 25 XP per cycle for all PERFECT / all GOOD / all OK, 15 s cycles):
  - level 10 takes 1–5 cycles;
  - level 100 takes 25 cycles (about 6 min) to 125 cycles (about 31 min).
- **Torrential Flow** (30 / 25 / 20 XP per 8 s cycle): level 100 takes 105–157 cycles (14–21 min).

### Content That Reads Cultivation State
| Resource | Kind | Check |
|----------|------|-------|
| `resources/unlocks/q_reach_cd_10.tres` | `CULTIVATION_LEVEL` | `>= 10`. Step 1 of `q_reach_core_density_10` "Harden Your Core", whose completion awards the Refugee Camp Map |
| `CULTIVATION_STAGE` conditions | — | None authored |
| Pure Madra path nodes | `required_stage` | All left at the default `FOUNDATION` |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/cultivation_manager/cultivation_manager.gd` | Core Density XP/levels, stage, path-point milestones |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | `AdvancementStageResource` (XP curve, Madra cap) |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage_list.gd` | `AdvancementStageList` (unused) |
| `resources/cycling/advancement_stages/` | Foundation stage and the unused list |
| `singletons/persistence_manager/save_game_data.gd` | Persisted cultivation fields |
| `singletons/resource_manager/resource_manager.gd` | Applies the Madra cap |
| `scenes/zones/cultivator_plate/cultivator_plate.gd` | Stage, level, XP beads and Madra cap (zone view cabinet) |
| `scenes/ui/goals_panel/goals_panel.gd` | Breakthrough milestone (Core Density toward 100) |
| `tests/unit/test_cultivation_getters.gd` | 4 tests: `get_max_madra()` follows the level; `BREAKTHROUGH_LEVEL` is 100 |
| `tests/unit/test_cultivation_manager.gd` | 28 tests: the real `add_core_density_xp()` level-up loop (carry-over, multi-level gains), its signals, path-point milestones per stage, stage names, and the XP curve |

## Work Remaining

### Bugs

- `[HIGH]` Infinite loop as soon as the stage moves past Foundation. This blocks Copper. `get_xp_for_next_level()` (`cultivation_manager.gd:106-111`) returns `0.0` when `_get_current_stage_resource()` is `null`, which happens for any stage missing from `advancement_stage_resources` (today, everything except `FOUNDATION`). The `while core_density_xp >= xp_needed_for_next_level` loop (line 83) then never exits, because XP never drops below 0 when 0 is subtracted. The game freezes on the first Core Density XP award: `core_density_level_updated` fires on every pass, and path points are added every 10th pass. With the same missing resource, `ResourceManager.add_madra()` clamps Madra to 0 (cap = 0). It is unreachable only because nothing changes the stage yet. Fix before or with the breakthrough: add the Copper resource and make the loop bail out when `needed <= 0`.

### Missing Functionality

- `[HIGH]` No breakthrough. `attempt_breakthrough()` is an empty stub and nothing changes `current_advancement_stage`. See "What a Foundation → Copper breakthrough still needs" and [breakthrough-tribulation.md](breakthrough-tribulation.md).
- `[HIGH]` No Copper stage resource. `advancement_stage_resources` only preloads Foundation, and Foundation's `next_stage` is `null`.
- `[MEDIUM]` No Core Density cap or overflow rule at 100. `AdvancementStageResource` has no `max_core_density_level`, and 100 is only the display constant `CultivationManager.BREAKTHROUGH_LEVEL`. Path points keep accruing past 100.
- `[MEDIUM]` Cultivation path perks are not applied: `CORE_DENSITY_XP_MULT` (Dedicated Cultivation), `MADRA_ON_LEVEL_UP` (Breakthrough Surge) and `MADRA_CAPACITY_BONUS` (Expanded Core). `PathManager.get_effects()` has no gameplay reader.
- `[MEDIUM]` No stage-gated content. No `CULTIVATION_STAGE` unlock conditions exist and no path node requires a stage above Foundation.
- `[LOW]` `unlocking_mechanics`, `icon` and `next_stage` on `AdvancementStageResource` are exported but never read.

### Content

- `[HIGH]` Only Foundation has stage data. Copper, Iron, Jade and Silver have no `.tres`.
- `[MEDIUM]` No breakthrough content: no Tribulation curve or data, no breakthrough encounter, no pre/post Dialogic timelines. Beats 7–9 in [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md) are planned.

### UI

- `[MEDIUM]` Nothing tells the player what to do at Core Density 100. The Goals board's Breakthrough milestone ("Raise Core Density to 100") fills and stops at `100 / 100`, and nothing follows.
- `[LOW]` The stage appears only as text (the cabinet's painted stage name). There is no next-stage info and no stage badge or aura (the GDD calls for one).

### Tech Debt

- `[LOW]` The stage list is duplicated. The `@export advancement_stage_resources` preload on the autoload script cannot be edited in the inspector, and `AdvancementStageList` / `advancement_stage_list.tres` sits unused.
- `[LOW]` Coding standards:
  - `add_core_density_xp()` and `attempt_breakthrough()` have no return types;
  - the public getters have no `##` doc comments;
  - several locals are untyped (`xp_needed_for_next_level`, `cur_level`, `res`).
- `[LOW]` `PATH_POINTS_PER_STAGE` has no `SILVER` entry.

## Related Docs

- [CYCLING.md](../cycling/CYCLING.md): the only Core Density XP source
- [breakthrough-tribulation.md](breakthrough-tribulation.md): breakthrough and Tribulation design (not implemented)
- [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md): path points and cultivation perks
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md): Foundation beats, including the planned breakthrough
- [RESOURCES.md](../infrastructure/RESOURCES.md): Madra pool, adventure budget
- [UNLOCKS.md](../infrastructure/UNLOCKS.md): `CULTIVATION_STAGE` / `CULTIVATION_LEVEL` conditions
- [CHARACTER.md](../infrastructure/CHARACTER.md): Foundation attribute and adventure Madra capacity
- [PERSISTENCE.md](../infrastructure/PERSISTENCE.md): `SaveGameData`
