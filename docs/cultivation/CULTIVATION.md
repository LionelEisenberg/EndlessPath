# Cultivation System

Last updated: 2026-10-24

## Overview

Cultivation tracks the player's power on two axes:

- **Core Density level**: an XP-driven level within the current stage. It stops at the stage's cap (`max_core_density_level`, 100), raises the Madra cap and awards path points every 10 levels.
- **Advancement Stage**: `FOUNDATION`, `COPPER`, `IRON`, `JADE` or `SILVER`.

`CultivationManager` (autoload) owns both, storing them in `SaveGameData`. Each stage's numbers come from an `AdvancementStageResource`.

Foundation and Copper have stage data. Foundation ends in the **Tribulation**: once Core Density reaches 100, a Spirit Valley action runs the Breath of the Core mini-game, and a pass calls `CultivationManager.advance_to_next_stage()`, which moves the player to Copper at level 0 on Copper's own curve. Copper is thin: it has stage data, and nothing is gated on it yet. The mini-game and where its code lives are in [breakthrough-tribulation.md](breakthrough-tribulation.md).

## Player Experience

1. A new save starts at **Foundation**, Core Density level 0, 0 XP, 25 Madra, with a Madra cap of 100.
2. Core Density XP comes only from scoring cycling zones (see [CYCLING.md](../cycling/CYCLING.md)). The starting Foundational Technique has no zones. The first XP-earning technique, Smooth Flow, comes from the `pure_core_awakening` path node. The player buys it with the path point awarded by the "First Steps Out" quest (`q_first_steps`).
3. XP fills the cabinet's XP beads and its `xp / need XP` figure (a scored cycling zone also sends XP pellets into the cabinet's Core orb, unless the core is full: see 8). Each level costs 2% more XP than the previous one, starting at 10 XP for level 1. One scored zone can grant several levels.
4. Each level raises the Madra cap by 5.
5. Every 10th level grants **1 path point** at Foundation, spent in the Path Tree. A stage pays each milestone once.
6. The quest "Harden Your Core" (`q_reach_core_density_10`) asks for level 10.
7. Stage and level are shown on the zone view's cultivator cabinet (`Foundation` / `Level N`, plus the Core orb that fills toward the stage's cap). The cabinet stays up beside the cycling board, so cycling has no readout of its own.
8. **At level 100 the core is full.** Core Density stops at the stage's cap and XP earned there is lost. The log writes "Your core is full. The Tribulation waits in Spirit Valley.", the cabinet's XP figure reads "Core full" with every bead lit, the Goals board's milestone reads "Face the Tribulation", and a scored cycling zone says "Core full" where it would say "+N XP" and sends no XP pellets. Madra still flows. The Tribulation's card appears in Spirit Valley with a NEW seal.
9. **The Tribulation** (about 38 s, [breakthrough-tribulation.md](breakthrough-tribulation.md)). A **pass** moves the player to Copper: stage COPPER, level 0, 0 XP, Madra cap 600 on Copper's curve (so it does not drop), the log line "You break through to Copper.", the card gone and the Goals milestone reading "Copper reached". Four cracks **fail** it: the core loses 5 levels (100 → 95), the path points stay, and the card shows "Core 95 / 100" until the player cycles back to 100. Regaining a lost level pays no second path point.
10. A save from before the cap that stands past it (the level was uncapped) loads at the cap with no XP. Path points it already earned stay.

## Architecture

```
CultivationManager (autoload #2)                 — singletons/cultivation_manager/cultivation_manager.gd
  advancement_stage_resources: Array[AdvancementStageResource]
      = [preload(foundation_advancement_stage.tres), preload(copper_advancement_stage.tres)]
  live_save_data → SaveGameData.core_density_xp / core_density_level / current_advancement_stage / core_density_milestones

AdvancementStageResource (Resource)              — scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd
AdvancementStageList (Resource, never loaded)    — advancement_stage_list.gd + resources/cycling/advancement_stages/advancement_stage_list.tres

Writers:  CyclingTechnique.try_score_zone() → add_core_density_xp()
          DevPanel "Add CD XP" → add_core_density_xp()
          TribulationView._end() → advance_to_next_stage() on a pass, lose_core_density_levels() on a failure
Readers:  ResourceManager.add_madra()           — Madra cap via get_max_madra()
          CultivatorPlate (zone view cabinet)   — stage name, level, XP beads, Madra cap, core orb up to the cap, "Core full"
          GoalsPanel                            — the Breakthrough milestone: level / cap, "Face the Tribulation", "<Stage> reached"
          CyclingTechnique, CyclingView         — is_core_full(): "Core full" in place of "+N XP", no XP pellets
          TribulationActionData                 — can_attempt() (full core, stage before the target) and is_passed()
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
| `CORE_FULL_LOG` | `"Your core is full. The Tribulation waits in Spirit Valley."` | Written to the player's log when the level-up that reaches the cap finds a next stage waiting |
| `CORE_FULL_TEXT` | `"Core full"` | The one copy of the short text. The cabinet's XP figure, `CycleResult.summary()` and the cycling floaters read it |

### AdvancementStageResource
| Field | Type | Class default | Read by code? |
|-------|------|---------------|---------------|
| `stage_name` | `String` | `""` | Yes (stage name getters) |
| `stage_id` | `CultivationManager.AdvancementStage` | `FOUNDATION` | Yes (stage lookup) |
| `core_density_base_xp_cost` | `float` | `10.0` | Yes |
| `core_xp_scaling_factor` | `float` | `1.0` | Yes |
| `max_core_density_level` | `int` | `100` | Yes (`get_core_density_cap()`). XP earned at it is lost |
| `unlocking_mechanics` | `Array[String]` | `[]` | No |
| `max_madra_base` | `float` | `0.0` | Yes |
| `max_madra_per_core_density_level` | `float` | `0.0` | Yes |
| `icon` | `Texture2D` | `null` | No |
| `next_stage` | `AdvancementStageResource` | `null` | Yes (`has_next_stage()`, `advance_to_next_stage()`) |

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
| `core_density_milestones` | `Dictionary[int, int]` | `{}`: stage → the highest milestone level already paid. A level pays its path points only above the stage's entry, so a level lost and regained pays nothing twice. A save without it is seeded on load |
| `madra` | `float` | `25.0`, owned by `ResourceManager`. `add_madra()` stops a gain at the stage's cap, and never lowers a pool that sits above it |

### CultivationManager API
| Method | Returns | Notes |
|--------|---------|-------|
| `add_core_density_xp(amount: float)` | `void` | See flow below |
| `lose_core_density_levels(count: int)` | `void` | `level = max(0, level − count)` and XP 0, then emits `core_density_level_updated` and `core_density_xp_updated`. Path points and the milestone ledger stay. The Tribulation's failure (5 levels) |
| `advance_to_next_stage()` | `bool` | The Tribulation's pass. `false`, changing and announcing nothing, when `has_next_stage()` is false. Otherwise it sets the stage to `next_stage.stage_id` with level 0 and XP 0, logs "You break through to Copper." (before the signals, so what the new stage unlocks logs after it), emits `core_density_level_updated`, `core_density_xp_updated` and `advancement_stage_changed`, and returns `true`. It does not check `is_core_full()` (the caller decides) and leaves the milestone ledger alone, so the new stage pays from its own level 10 |
| `get_core_density_cap()` | `int` | The current stage's `max_core_density_level`. `0` without save data or a stage resource |
| `is_core_full()` | `bool` | `cap > 0 and level >= cap` |
| `has_next_stage()` | `bool` | The current stage resource has a `next_stage` |
| `get_xp_for_next_level()` | `float` | `stage.get_xp_for_level(level + 1)`, i.e. `base × factor^level`. Returns `0.0` if there is no save or no stage resource |
| `get_core_density_xp()` / `get_core_density_level()` | `float` | `0.0` without save data |
| `get_current_advancement_stage()` | `AdvancementStage` | `FOUNDATION` without save data |
| `get_current_advancement_stage_name()` | `String` | `"Unknown"` if the stage has no resource |
| `get_advancement_stage_name(stage)` | `String` | `"Unknown"` if the stage has no resource |
| `get_max_madra()` | `float` | The Madra pool cap: the current stage's `get_max_madra(level)`. `0.0` without a stage resource. `ResourceManager`, `CyclingTechnique` (its cap check) and `CultivatorPlate` read it |
| `_pay_milestone(level: int)` | `void` | Private. Pays the stage's path points for a milestone level it has not paid yet, and records it (`cultivation_manager.gd:248-257`) |
| `_get_current_stage_resource()` / `_get_stage_resource(stage)` | `AdvancementStageResource` | Private; only the manager calls them now |

## Core Systems

### Core Density XP and Leveling
```
add_core_density_xp(amount)                                   # cultivation_manager.gd:88-149
  if is_core_full():                                          # lines 97-100
      core_density_xp = 0; core_density_xp_updated.emit(xp, level); return     # XP at the cap is lost
  core_density_xp += amount
  needed = get_xp_for_next_level()                            # base × factor^level; 0.0 if no stage resource
  while core_density_xp >= needed:
      if needed <= 0.0: Log.error("Cannot level …"); break    # lines 113-118: a free level, or a stage with no resource
      if core_density_level >= cap: break                     # lines 122-123: backstop for a cap of 0 or less
      core_density_level += 1
      core_density_xp -= needed
      if core_density_level >= cap: core_density_xp = 0       # lines 128-131: the XP left over is lost
      core_density_level_updated.emit(xp, level)
      _pay_milestone(int(level))                              # line 137: every 10 levels, once per stage
      if the level reached the cap:                           # lines 139-143
          core_filled.emit(stage)
          if has_next_stage(): LogManager.log_message(CORE_FULL_LOG)
          break
      needed = get_xp_for_next_level()
  core_density_xp_updated.emit(xp, level)
```
- Several level-ups from one award are handled by the `while` loop. Overflow XP carries into the next level, except at the cap.
- **The cap.** `get_core_density_cap()` is the stage's `max_core_density_level` (100 in Foundation and Copper). The level-up that reaches it drops the leftover XP, then announces itself: the level signal, the milestone, `core_filled` (once; nothing listens to it yet) and, only while a next stage waits, the log line. A Copper core fills without the log line, since there is no next stage to face. The cap is data: a stage can set another number.
- **Path points** come from `_pay_milestone()` (lines 248-257): `PATH_POINTS_PER_STAGE` for the current stage (Foundation 1, Copper 2, Iron 3, Jade 4, any other 1), when `level % 10 == 0`, `level > 0` and `level` is above the stage's entry in `core_density_milestones`. The entry is then set to `level`. Regaining a level a failed Tribulation took pays nothing, and Copper starts with its own empty entry.
- **The guard.** A stage with no resource, or a level that costs 0 XP, would spin the loop forever, because subtracting 0 never takes the XP below the cost. The loop logs `Cannot level - level N of stage X costs no XP …` with `Log.error` and stops instead.
- **On load**, `_update_resources()` (lines 62-83) first sets a level above the cap to the cap with no XP (`Log.info`: "Core Density 130 is past the stage's cap of 100. Loaded at the cap, with no XP"; no `core_filled`, no log line for the player). It then seeds a stage that has no ledger entry with `floor(level / 10) × 10`, so a save from before the ledger is not paid its milestones again. The clamp runs first, so a level-130 save is seeded at 100.
- Path-perk hooks `CORE_DENSITY_XP_MULT` and `MADRA_ON_LEVEL_UP` would plug into this function, but are not applied (see [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md)).

### Madra Cap
Two different maximums exist:

| Value | Formula (Foundation) | Enforced by | Shown in |
|-------|----------------------|-------------|----------|
| **Pool cap** (cultivation) | `get_max_madra(level)` = `100 + 5 × Core Density level` | `ResourceManager.add_madra()` stops a gain at the cap and never lowers a pool above it | The zone view's cultivator cabinet (`X / Y`) |
| **Adventure capacity** (character) | `CharacterAttributesData.get_max_madra()` = `FOUNDATION attribute × 10` (100 at the default 10) | `ResourceManager.get_adventure_madra_capacity()` / budget; combat `VitalsManager` | Adventure start |

Copper's pool cap is `600 + 10 × level`, so it starts at the 600 Foundation ends on and the breakthrough never drops it. A failed Tribulation lowers the level, and with it the cap, below a pool that was already full; `add_madra()` leaves that pool alone until it is spent.

The `MADRA_CAPACITY_BONUS` path perk is aggregated by `PathManager` but not added to either cap. See [RESOURCES.md](../infrastructure/RESOURCES.md) for the pool and adventure budget.

### Advancement Stage and Breakthrough
- `current_advancement_stage` is written by `SaveGameData.reset()` and by `advance_to_next_stage()` (`cultivation_manager.gd:167-183`), which only the Tribulation calls.
- `advancement_stage_changed` is emitted from `_update_resources()`, which runs in `_ready()` and on `PersistenceManager.save_data_reset` (it carries the unchanged stage), and from `advance_to_next_stage()` (the new one).
- Stage lookups go through `advancement_stage_resources`: Foundation and Copper. Any other stage resolves to `null`, which makes `get_xp_for_next_level()` return 0, the cap 0 and `get_max_madra()` 0.0. `add_core_density_xp()` then logs and stops rather than hang, and `ResourceManager.add_madra()` adds nothing but leaves the pool as it is.
- Foundation's `next_stage` is Copper (`foundation_advancement_stage.tres`). Copper has none, so `has_next_stage()` is false there: `advance_to_next_stage()` returns `false`, the Goals board reads "Copper reached", and a full Copper core writes no "waits in Spirit Valley" line.

**The Foundation → Copper breakthrough, as built:**
1. **The cap:** `max_core_density_level` (100) on the stage resource, XP earned at the cap discarded, and a save past it loaded at it (`cultivation_manager.gd:68-73`).
2. **The Copper stage:** `copper_advancement_stage.tres` (`stage_id` 1, base XP 20, scaling 1.02, Madra `600 + 10 × level`, cap 100, no `next_stage`), preloaded in `advancement_stage_resources` and listed in `advancement_stage_list.tres`. The numbers are placeholders until Copper is designed.
3. **The two calls:** `advance_to_next_stage()` for a pass and `lose_core_density_levels()` for a failure, both described under the API above.
4. **Milestones once per stage:** `core_density_milestones` and `_pay_milestone()`, so 100 → 95 → 100 pays the level-100 point once.
5. **The Tribulation itself:** a Spirit Valley `TribulationActionData`, its `TribulationData`, the judge `TribulationRun`, and the board and its state. Where each lives is in [breakthrough-tribulation.md](breakthrough-tribulation.md); the design is the [Tribulation spec](../superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md).
6. **Not built:** something for Copper to unlock. No `CULTIVATION_STAGE` unlock conditions exist, no path node requires a stage above Foundation, and Scripting and Elixir Making are not built.

## Signals

| Signal | Emitted | Listeners |
|--------|---------|-----------|
| `core_density_xp_updated(xp, level)` | End of every `add_core_density_xp()` (a full core emits only this one); `lose_core_density_levels()`; `advance_to_next_stage()`; `_update_resources()` | `CultivatorPlate` |
| `core_density_level_updated(xp, level)` | Each level gained; `lose_core_density_levels()`; `advance_to_next_stage()`; `_update_resources()` | `UnlockManager` (re-evaluates all conditions), `CultivatorPlate`, `GoalsPanel`, `TribulationPresenter` (the card's Core row and its ready state) |
| `advancement_stage_changed(new_stage)` | `_update_resources()`; `advance_to_next_stage()` | `UnlockManager`, `CultivatorPlate`, `GoalsPanel` ("Copper reached"), `ZonePanel` (a passed Tribulation's card leaves the list), `TribulationPresenter` |
| `core_filled(stage)` | The level-up that reaches the cap, once. Not the load clamp | None. The manager writes the log line itself |

## Integration Points

| System | Connection |
|--------|------------|
| Cycling | `CyclingTechnique.try_score_zone()` → `add_core_density_xp(zone XP)`. This is the only gameplay XP source |
| `ResourceManager` | `add_madra()` reads `get_max_madra()` for the pool cap |
| `PathManager` | Receives `add_points()` for each new milestone. `_is_stage_reached()` compares node `required_stage` with the current stage (tests use `_test_stage_override`) |
| `UnlockManager` / `UnlockConditionData` | Re-evaluates on `core_density_level_updated` and `advancement_stage_changed`. `CULTIVATION_STAGE` and `CULTIVATION_LEVEL` conditions query the manager. `core_density_full` (`CULTIVATION_LEVEL` ≥ 100) latches the Tribulation's card |
| `QuestManager` | `q_reach_core_density_10` step 1 completes when `q_reach_cd_10` unlocks |
| UI | The zone view's `CultivatorPlate` and `GoalsPanel` read `get_core_density_cap()` and `is_core_full()` |
| Tribulation | `TribulationActionData.can_attempt()` and `is_passed()` read the stage and `is_core_full()`; `ActionManager.select_action()` refuses a card the core is not ready for; `TribulationView._end()` applies the result through `advance_to_next_stage()` or `lose_core_density_levels()` (`tribulation_view.gd:442-460`). See [breakthrough-tribulation.md](breakthrough-tribulation.md) |
| `PersistenceManager` | Fields above persist in `user://save.tres` |
| `DevPanel` (Ctrl+Shift+D) | "Add CD XP" calls `add_core_density_xp(value)`. There is no stage control |

## Existing Content

### Advancement Stages
| Stage | Resource | `stage_name` | Base XP | Scaling | Core Density cap | Madra cap | `next_stage` | Path points per 10 levels |
|-------|----------|--------------|---------|---------|------------------|-----------|--------------|---------------------------|
| Foundation | `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres` | `Foundation` | 10.0 (class default) | 1.02 | 100 (class default) | 100 + 5 × level | Copper | 1 |
| Copper | `resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres` | `Copper` | 20.0 | 1.02 | 100 | 600 + 10 × level | `null` | 2 |
| Iron | none | — | — | — | — | — | — | 3 |
| Jade | none | — | — | — | — | — | — | 4 |
| Silver | none | — | — | — | — | — | — | 1 (fallback) |

`advancement_stage_list.tres` lists Foundation and Copper and is never loaded: only `CultivationManager.advancement_stage_resources` is read. Copper's numbers are placeholders until Copper is designed. Its XP curve is Foundation's doubled (about 6,245 XP to level 100 against 3,122), and its Madra cap starts at the 600 Foundation ends on.

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
| `resources/unlocks/core_density_full.tres` | `CULTIVATION_LEVEL` | `>= 100`. Gates the Tribulation's card; registered in `unlock_condition_list.tres`, so it latches and the card stays after a failure |
| `CULTIVATION_STAGE` conditions | — | None authored. The Tribulation hides its own card with `TribulationActionData.is_passed()` instead |
| Pure Madra path nodes | `required_stage` | All left at the default `FOUNDATION` |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/cultivation_manager/cultivation_manager.gd` | Core Density XP/levels and cap, stage, the breakthrough (`advance_to_next_stage()`, `lose_core_density_levels()`), path-point milestones |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | `AdvancementStageResource` (XP curve, Madra cap, Core Density cap, `next_stage`) |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage_list.gd` | `AdvancementStageList` (unused) |
| `resources/cycling/advancement_stages/` | Foundation and Copper stages and the unused list |
| `singletons/persistence_manager/save_game_data.gd` | Persisted cultivation fields, with the milestone ledger |
| `singletons/resource_manager/resource_manager.gd` | Applies the Madra cap |
| `scenes/zones/cultivator_plate/cultivator_plate.gd` | Stage, level, XP beads and Madra cap (zone view cabinet), "Core full" |
| `scenes/ui/goals_panel/goals_panel.gd` | Breakthrough milestone (level / cap, "Face the Tribulation", "<Stage> reached") |
| `scripts/tribulation/`, `scenes/tribulation/`, `resources/tribulation/` | The Tribulation: judge, board and data. See [breakthrough-tribulation.md](breakthrough-tribulation.md) |
| `tests/unit/test_cultivation_getters.gd` | 4 tests: `get_max_madra()` follows the level and caps `add_madra()`; Foundation's cap is 100 |
| `tests/unit/test_cultivation_manager.gd` | 55 tests: the real `add_core_density_xp()` level-up loop (carry-over, multi-level gains), the cap and the XP lost at it, `core_filled` once and the log line, the guard against a free level or a missing stage, `lose_core_density_levels()`, `advance_to_next_stage()` (stage, signals, Madra cap, log, refusal), its signals, path-point milestones per stage and once per stage (a regained level pays nothing, an old save is seeded, a save past the cap loads at it), stage names, and the XP curve |
| `tests/unit/test_foundation_tribulation_data.gd` | 16 tests on the shipped data: Foundation leads to Copper, Copper's values and registration, the Madra cap not dropping at the breakthrough, the Tribulation `.tres`, and the Spirit Valley action and its `core_density_full` condition |
| `tests/integration/test_tribulation_flow.gd` | 20 tests: the card revealed at 100, the refusal below it, a pass and a failure end to end, the idle action resuming, a stop or save reset mid-trial applying nothing, and a click on a card during the trial |

## Work Remaining

### Bugs

None known.

### Missing Functionality

- `[MEDIUM]` Cultivation path perks are not applied: `CORE_DENSITY_XP_MULT` (Dedicated Cultivation), `MADRA_ON_LEVEL_UP` (Breakthrough Surge) and `MADRA_CAPACITY_BONUS` (Expanded Core). `PathManager.get_effects()` has no gameplay reader.
- `[MEDIUM]` Copper unlocks nothing. No `CULTIVATION_STAGE` unlock conditions exist, no path node requires a stage above Foundation (the Path book's Copper chapter opens empty), and Scripting and Elixir Making are not built.
- `[MEDIUM]` Closing the game mid-trial applies nothing, so it is a way out of a failing run. The result is applied the moment the run ends, but nothing is written before then. Staking the penalty when the trial starts would close the gap, at the cost of punishing a crash.
- `[LOW]` A save that has reached Copper, opened in a build from before the Tribulation, still hits the endless level-up loop: the guard only protects builds that have it. Saves carry no version field ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#versioning)).
- `[LOW]` `unlocking_mechanics` and `icon` on `AdvancementStageResource` are exported but never read.

### Content

- `[HIGH]` Only Foundation and a placeholder Copper have stage data. Copper's numbers (base XP 20, scaling 1.02, Madra `600 + 10 × level`) stand in until Copper is designed. Iron, Jade and Silver have no `.tres`, so a later stage's Tribulation (a `TribulationData` with another `target_stage`) needs its stage first.
- `[MEDIUM]` The Tribulation's copy is placeholder (`foundation_tribulation.tres`), and no dialogue, quest or Dialogic timeline leads to it or follows it. Later stages' trials need their own `TribulationData`.
- `[MEDIUM]` The Core Density curve is not retuned. It sets when level 100 arrives and how heavy the 5-level penalty feels ([FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md#loop-economy)).

### UI

- `[LOW]` The stage appears only as text (the cabinet's painted stage name). There is no next-stage info and no stage badge or aura (the GDD calls for one).

### Tech Debt

- `[LOW]` The stage list is duplicated. The `@export advancement_stage_resources` preload on the autoload script cannot be edited in the inspector, and `AdvancementStageList` / `advancement_stage_list.tres` sits unused.
- `[LOW]` Coding standards:
  - the older public getters have no `##` doc comments;
  - `get_xp_for_next_level()` has untyped locals (`cur_level`, `res`).
- `[LOW]` `PATH_POINTS_PER_STAGE` has no `SILVER` entry.
- `[LOW]` `advance_to_next_stage()` logs before it emits so that the lines a new stage unlocks read after "You break through to …". No test pins that order.

## Related Docs

- [CYCLING.md](../cycling/CYCLING.md): the only Core Density XP source
- [breakthrough-tribulation.md](breakthrough-tribulation.md): the Tribulation, the Foundation → Copper breakthrough: how it plays and where its code lives
- [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md): path points and cultivation perks
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md): Foundation beats, including the Tribulation (Beat 9)
- [RESOURCES.md](../infrastructure/RESOURCES.md): Madra pool, adventure budget
- [UNLOCKS.md](../infrastructure/UNLOCKS.md): `CULTIVATION_STAGE` / `CULTIVATION_LEVEL` conditions
- [CHARACTER.md](../infrastructure/CHARACTER.md): Foundation attribute and adventure Madra capacity
- [PERSISTENCE.md](../infrastructure/PERSISTENCE.md): `SaveGameData`
