# Training Zone Action Infrastructure

**Date:** 2026-04-17
**Status:** Approved
**Drives:** Beat 3a of [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md#beat-3a--spirit-well-discovery) — the Spirit Well zone action and the "Basic Training" system.

## Overview

Introduce a new `TRAIN_STATS` zone-action type: a tick-based, long-horizon action where the player commits time at a training site to earn **attribute points** on an **exponential cost curve**, plus a **passive madra trickle** while active. First concrete instance is the Spirit Well (grants Spirit + madra). Infrastructure is designed to carry future training sites (Body, Foundation, etc.) without further plumbing changes.

Progress persists per-action across action-switches and save/load — the 20-minute 4th-tier commitment must survive cycling/adventuring breaks.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Progress model | Tick-based (mirrors Forage) | Reuses `ActionManager.action_timer` plumbing; every tick is a unit of progress + a trickle opportunity. |
| Cost curve representation | Hybrid: hand-tuned array + tail growth multiplier | Spec hand-picks 1m/5m/10m/20m; later levels auto-scale. Tuning stays in the array without restructuring. |
| Reward dispatch | `Array[EffectData]` at two hooks (`effects_per_tick`, `effects_on_level`) | Reuses existing effect system; attribute grant becomes a standalone reusable effect. |
| Persistence shape | `training_tick_progress: Dictionary[String, int]` on `ZoneProgressionData` | Per-action, per-zone state already has a home. No new top-level save field. |
| State ownership | No new singleton | `ActionManager` routes + runs the timer (same as Forage); reads/writes via `ZoneManager` helpers. `CharacterManager` receives attribute grants via effect. |
| Attribute award mechanism | New `AwardAttributeEffectData` | Reusable beyond training — path perks, quest rewards can grant attributes too. |

## Scope

**In scope:**
- `TrainingActionData` resource class.
- `AwardAttributeEffectData` effect class + new `AWARD_ATTRIBUTE` enum value on `EffectData.EffectType`.
- `ZoneProgressionData.training_tick_progress` field + `ZoneManager` getter/incrementer.
- `ActionManager` routing branch for `TRAIN_STATS` with tick handler.
- One concrete `.tres`: the Spirit Well training action.
- GUT unit and integration tests.

**Out of scope (separate passes):**
- UI polish on the action card: how the progress fill visualizes per-level progress, level-up flash, floating text.
- The adventure-tile-visit unlock condition that gates Spirit Well visibility (Beat 3a trigger).
- Additional training actions beyond Spirit Well.
- Content decision for what resource the trickle grants — structurally supported via `effects_per_tick`, but the trickle's specific effects are a separate tuning question.

## New Resource Class: `TrainingActionData`

**File:** `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd`

Extends `ZoneActionData`. Sets `action_type = ZoneActionData.ActionType.TRAIN_STATS` in `_init`.

### Exported fields

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `tick_interval_seconds` | `float` | `1.0` | How often the tick handler fires while the action is selected. |
| `ticks_per_level` | `Array[int]` | `[60, 300, 600, 1200]` | Hand-tuned **incremental** (not cumulative) tick cost for levels 1..N (1-indexed). Cumulative ticks to reach level N = sum of `ticks_per_level[0..N-1]`. |
| `tail_growth_multiplier` | `float` | `2.0` | For levels beyond the array, each subsequent level costs the previous level × this factor. |
| `effects_per_tick` | `Array[EffectData]` | `[]` | Effects fired every tick (trickle rewards). |
| `effects_on_level` | `Array[EffectData]` | `[]` | Effects fired once per level crossed (includes the attribute grant). |

### Public API (pure functions)

| Method | Return | Description |
|--------|--------|-------------|
| `get_ticks_required_for_level(level: int)` | `int` | **Incremental** tick cost for the given level (i.e., cost to go from level-1 to level). For `level ≤ ticks_per_level.size()` returns the array value; beyond that, applies `tail_growth_multiplier` to the last array value for each additional level (e.g., level 5 = `ticks_per_level[-1] * tail_growth_multiplier^1`). `level` is 1-indexed; level 0 returns 0. |
| `get_current_level(accumulated_ticks: int)` | `int` | Highest level whose cumulative tick cost is ≤ `accumulated_ticks`. Returns 0 when no levels earned. |
| `get_progress_within_level(accumulated_ticks: int)` | `float` | `(accumulated_ticks - ticks_at_start_of_current_tier) / ticks_needed_for_next_level`, clamped 0.0–1.0. Used by UI for progress fill. |

These are pure functions on `TrainingActionData` — no external state, fully unit-testable.

## New Resource Class: `AwardAttributeEffectData`

**File:** `scripts/resource_definitions/effects/award_attribute_effect_data.gd`

Extends `EffectData`. Adds `AWARD_ATTRIBUTE` to `EffectData.EffectType` enum.

```gdscript
class_name AwardAttributeEffectData
extends EffectData

@export var attribute_type: CharacterAttributesData.AttributeType
@export var amount: float = 1.0

func _init() -> void:
    effect_type = EffectType.AWARD_ATTRIBUTE

func process() -> void:
    CharacterManager.add_base_attribute(attribute_type, amount)

func _to_string() -> String:
    return "AwardAttributeEffectData(%s +%.1f)" % [
        CharacterAttributesData.AttributeType.keys()[attribute_type],
        amount,
    ]
```

Reusable anywhere — path node perks, quest completion rewards, dialogue outcomes.

## Persistence Changes

### `ZoneProgressionData` — new field

**File:** `singletons/persistence_manager/zone_progression_data.gd`

```gdscript
## Accumulated ticks per training action_id in this zone.
@export var training_tick_progress: Dictionary[String, int] = {}
```

No migration needed — missing keys default to 0 on read; existing saves load cleanly (Godot resource serialization tolerates absent exported fields).

### `SaveGameData` — no direct change

Training state rides inside the existing `zone_progression_data: Dictionary[String, ZoneProgressionData]`. `reset()` already clears `zone_progression_data = {}`, which transitively resets training progress.

### `ZoneManager` — new helpers

**File:** `singletons/zone_manager/zone_manager.gd`

```gdscript
## Returns accumulated training ticks for the given action in the given zone (0 if unseen).
func get_training_ticks(action_id: String, zone_id: String = get_current_zone().zone_id) -> int:
    return get_zone_progression(zone_id).training_tick_progress.get(action_id, 0)

## Adds `amount` ticks to the action's training progress and returns the new total.
func increment_training_ticks(action_id: String, zone_id: String = get_current_zone().zone_id, amount: int = 1) -> int:
    var zp: ZoneProgressionData = get_zone_progression(zone_id)
    var new_total: int = zp.training_tick_progress.get(action_id, 0) + amount
    zp.training_tick_progress[action_id] = new_total
    return new_total
```

## `ActionManager` Changes

**File:** `singletons/action_manager/action_manager.gd`

### New signals

```gdscript
signal start_training(action_data: TrainingActionData)
signal stop_training()
signal training_tick_processed(action_data: TrainingActionData, new_tick_count: int)
signal training_level_gained(action_data: TrainingActionData, new_level: int)
```

### Routing

Add a branch in `_execute_action`:

```gdscript
ZoneActionData.ActionType.TRAIN_STATS:
    if action_data is TrainingActionData:
        _execute_train_action(action_data as TrainingActionData)
    else:
        Log.error("ActionManager: Training action data is not a TrainingActionData: %s" % action_data.action_name)
```

And in `_stop_executing_current_action`:

```gdscript
ZoneActionData.ActionType.TRAIN_STATS:
    _stop_train_action(successful)
```

### Tick handler

```gdscript
func _execute_train_action(action_data: TrainingActionData) -> void:
    Log.info("ActionManager: Executing training action: %s" % action_data.action_name)
    start_training.emit(action_data)

    action_timer.name = "TrainingTimer"
    action_timer.timeout.connect(_on_train_timer_finished.bind(action_data))
    action_timer.wait_time = action_data.tick_interval_seconds
    action_timer.autostart = true
    action_timer.start()

func _on_train_timer_finished(action_data: TrainingActionData) -> void:
    var prev_ticks: int = ZoneManager.get_training_ticks(action_data.action_id)
    var prev_level: int = action_data.get_current_level(prev_ticks)

    var new_ticks: int = ZoneManager.increment_training_ticks(action_data.action_id)
    var new_level: int = action_data.get_current_level(new_ticks)

    for effect in action_data.effects_per_tick:
        effect.process()

    training_tick_processed.emit(action_data, new_ticks)

    for level in range(prev_level + 1, new_level + 1):
        for effect in action_data.effects_on_level:
            effect.process()
        training_level_gained.emit(action_data, level)

func _stop_train_action(successful: bool) -> void:
    Log.info("ActionManager: Stopping training action")
    stop_training.emit()
    _reset_action_timer()
    _process_completion_effects(successful)
```

The `range(prev_level + 1, new_level + 1)` loop handles the edge case where a single tick crosses multiple levels (rare with 1s ticks but safe under future tuning or external increments).

`_stop_executing_current_action`'s existing call to `ZoneManager.increment_zone_progression_for_action(current_action.action_id)` continues to fire for training, bumping `action_completion_count` by 1 per stop — consistent with other action types.

## Content: Spirit Well `.tres`

**File:** `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres`

| Field | Value |
|-------|-------|
| `action_id` | `spirit_well_training` |
| `action_name` | `Spirit Well` |
| `action_type` | `TRAIN_STATS` |
| `description` | (flavor TBD — reflect atmosphere, not mechanics) |
| `tick_interval_seconds` | `1.0` |
| `ticks_per_level` | `[60, 300, 600, 1200]` |
| `tail_growth_multiplier` | `2.0` |
| `effects_on_level` | `[AwardAttributeEffectData(SPIRIT, 1.0)]` |
| `effects_per_tick` | `[AwardResourceEffectData(MADRA, 1.5)]` — starting value, playtest-tunable |

The Spirit Well `.tres` is added to the Spirit Valley zone's action list. Unlock gating (Beat 3a trigger — player reaches the Spirit Well adventure tile) is deferred to a separate pass; initial implementation ships it unlocked for developer testing.

## Testing

### Unit: `tests/unit/test_training_action_data.gd`

- `get_ticks_required_for_level(N)` — returns array values for N within array size (1→60, 2→300, 3→600, 4→1200); applies tail formula beyond (5→2400 with default 2.0 multiplier, 6→4800).
- `get_current_level(ticks)` — 0 ticks → 0; 59 → 0; 60 → 1; 359 → 1; 360 → 2; high ticks beyond array → correct with tail formula.
- `get_progress_within_level(ticks)` — 0.0 at tier start, ~0.99 just before threshold, 0.0 exactly at threshold (because a new level just started).
- Edge cases: empty `ticks_per_level` array → all levels use tail formula seeded from a sentinel (`base_ticks = 60` documented default); `tail_growth_multiplier = 1.0` → linear post-array growth.

### Unit: `tests/unit/test_award_attribute_effect_data.gd`

- `process()` with `attribute_type = SPIRIT, amount = 1.0` → `CharacterManager.get_base_attribute(SPIRIT)` increments by 1.0.
- `process()` with `amount = 2.5` → increments by 2.5.

### Unit: `tests/unit/test_zone_progression_data.gd` (extend if exists; else create)

- `training_tick_progress` defaults to empty dict.
- `ZoneManager.get_training_ticks(unknown_action)` → 0, no crash.
- `ZoneManager.increment_training_ticks(id, amount=3)` → 3; again amount=2 → 5.
- Save/load round-trip preserves `training_tick_progress` values across multiple zones.

### Integration: `tests/integration/test_training_flow.gd`

Seed a test `TrainingActionData` with `tick_interval_seconds = 0.05`, `ticks_per_level = [3, 3]` (level 1 at cumulative tick 3; level 2 at cumulative tick 6), `effects_on_level = [AwardAttributeEffectData(SPIRIT, 1.0)]`, `effects_per_tick = [AwardResourceEffectData(GOLD, 1.0)]`.

1. `ActionManager.select_action(training_data)`.
2. Wait 4 ticks via `await`. Assert: `training_tick_processed` fired 4×, `training_level_gained` fired 1× (level 1 at cumulative tick 3), gold +4, Spirit +1.
3. `ActionManager.stop_action()`.
4. `ZoneManager.get_training_ticks("test_training")` → 4 (persistence across stop).
5. `ActionManager.select_action(training_data)` again.
6. Wait 2 more ticks (cumulative 6). Assert: `training_level_gained` fires for level 2, Spirit +1 (total +2), gold +2 (total +6).

## File Manifest

**New files:**
- `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd`
- `scripts/resource_definitions/effects/award_attribute_effect_data.gd`
- `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres`
- `tests/unit/test_training_action_data.gd`
- `tests/unit/test_award_attribute_effect_data.gd`
- `tests/integration/test_training_flow.gd`

**Modified files:**
- `scripts/resource_definitions/effects/effect_data.gd` — add `AWARD_ATTRIBUTE` enum value.
- `singletons/persistence_manager/zone_progression_data.gd` — add `training_tick_progress` field.
- `singletons/zone_manager/zone_manager.gd` — add `get_training_ticks` / `increment_training_ticks`.
- `singletons/action_manager/action_manager.gd` — add signals, routing branch, tick handler.
- `tests/unit/test_zone_progression_data.gd` — extend if present.
- `resources/zones/spirit_valley_zone/spirit_valley_zone_data.tres` — add Spirit Well action to the zone's action list.

## Open Questions (tracked for later passes)

- **Madra trickle rate** — starting value is 1.5 madra/tick (90 madra/min at default 1s tick). Needs playtest against cycling output to ensure Spirit Well supplements rather than replaces cycling. Tuning lives in the `.tres`, not the infrastructure.
- **Unlock trigger** — Beat 3a wants Spirit Well to appear only after the player reaches its adventure tile. Requires a new `UnlockConditionData` subtype (adventure-tile-visited). Separate spec.
- **UI progress fill** — the current action card's fill shader resets every forage tick. Training needs a per-level fill. Requires a mode switch or a new card variant. Separate spec.
