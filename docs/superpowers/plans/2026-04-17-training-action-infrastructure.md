# Training Action Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `TRAIN_STATS` zone-action infrastructure from [docs/superpowers/specs/2026-04-17-training-action-infrastructure-design.md](../specs/2026-04-17-training-action-infrastructure-design.md) and ship the Spirit Well as the first concrete training instance.

**Architecture:** New `TrainingActionData` resource subclasses `ZoneActionData`; new `AwardAttributeEffectData` extends `EffectData`. Per-action tick progress lives on existing `ZoneProgressionData.training_tick_progress` dictionary — no new singleton. `ActionManager` routes `TRAIN_STATS` to a new tick handler that reads/increments via `ZoneManager` helpers, fires `effects_per_tick` every tick, and fires `effects_on_level` once per level crossed.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0 for tests.

**Bottom-up build order:** enum → effect class → data class → persistence → manager helpers → action routing → content → integration test. Each task is a TDD cycle ending in a commit.

**Running tests (reused in every task):**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit
```
For all unit + integration tests:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
If class names don't resolve, pre-import once:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

---

## File Structure

**New files:**
- `scripts/resource_definitions/effects/award_attribute_effect_data.gd` — attribute-grant effect
- `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd` — training action resource class
- `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres` — Spirit Well content
- `tests/unit/test_training_action_data.gd` — cost curve + level pure-function tests
- `tests/unit/test_award_attribute_effect_data.gd` — effect processing test
- `tests/unit/test_zone_progression_data.gd` — field defaults + ZoneManager helper tests
- `tests/integration/test_training_flow.gd` — end-to-end tick → level-up → persistence

**Modified files:**
- `scripts/resource_definitions/effects/effect_data.gd` — add `AWARD_ATTRIBUTE` enum value
- `singletons/persistence_manager/zone_progression_data.gd` — add `training_tick_progress` field
- `singletons/zone_manager/zone_manager.gd` — add `get_training_ticks` / `increment_training_ticks`
- `singletons/action_manager/action_manager.gd` — add signals, routing branch, tick handler
- `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` — append Spirit Well action to `all_actions`

---

### Task 1: Add `AWARD_ATTRIBUTE` enum value

**Files:**
- Modify: `scripts/resource_definitions/effects/effect_data.gd`

- [ ] **Step 1: Edit the `EffectType` enum.**

In `scripts/resource_definitions/effects/effect_data.gd`, update the enum to add `AWARD_ATTRIBUTE`:

```gdscript
enum EffectType {
	NONE,
	TRIGGER_EVENT,
	AWARD_RESOURCE,
	AWARD_ITEM,
	AWARD_LOOT_TABLE,
	START_QUEST,
	AWARD_ATTRIBUTE,
}
```

- [ ] **Step 2: Verify no other files reference the enum by numeric value.**

```bash
grep -rn "EffectType\." --include="*.gd"
```

Expected: all references use the name (e.g., `EffectType.AWARD_RESOURCE`), none by integer. The only numeric use would be in `.tres` files (`effect_type = 2`), which are fine — added enum is appended last, existing values keep their indices.

- [ ] **Step 3: Commit.**

```bash
git add scripts/resource_definitions/effects/effect_data.gd
git commit -m "feat(effects): add AWARD_ATTRIBUTE enum value"
```

---

### Task 2: Create `AwardAttributeEffectData`

**Files:**
- Create: `scripts/resource_definitions/effects/award_attribute_effect_data.gd`
- Create: `tests/unit/test_award_attribute_effect_data.gd`

- [ ] **Step 1: Write the failing test first.**

Create `tests/unit/test_award_attribute_effect_data.gd`:

```gdscript
extends GutTest

var _save_data: SaveGameData
var _original_live_save: SaveGameData

func before_each() -> void:
	_original_live_save = CharacterManager.live_save_data
	_save_data = SaveGameData.new()
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	CharacterManager.live_save_data = _save_data

func after_each() -> void:
	CharacterManager.live_save_data = _original_live_save

func test_process_adds_amount_to_spirit() -> void:
	var effect := AwardAttributeEffectData.new()
	effect.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	effect.amount = 1.0
	effect.process()
	assert_eq(
		_save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT),
		11.0,
		"Spirit should go from 10.0 -> 11.0 after +1.0 award"
	)

func test_process_adds_fractional_amount_to_body() -> void:
	var effect := AwardAttributeEffectData.new()
	effect.attribute_type = CharacterAttributesData.AttributeType.BODY
	effect.amount = 2.5
	effect.process()
	assert_eq(
		_save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY),
		12.5
	)

func test_process_sets_effect_type() -> void:
	var effect := AwardAttributeEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_ATTRIBUTE)
```

- [ ] **Step 2: Run the test to verify it fails.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_award_attribute_effect_data.gd -gexit
```

Expected: parse error / class `AwardAttributeEffectData` not found.

- [ ] **Step 3: Create the class.**

Create `scripts/resource_definitions/effects/award_attribute_effect_data.gd`:

```gdscript
class_name AwardAttributeEffectData
extends EffectData

@export var attribute_type: CharacterAttributesData.AttributeType
@export var amount: float = 1.0

func _init() -> void:
	effect_type = EffectType.AWARD_ATTRIBUTE

func process() -> void:
	if CharacterManager == null:
		Log.error("AwardAttributeEffectData: CharacterManager is not found!")
		return
	Log.info("AwardAttributeEffectData: Awarding %s +%.1f" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		amount,
	])
	CharacterManager.add_base_attribute(attribute_type, amount)

func _to_string() -> String:
	return "AwardAttributeEffectData(%s +%.1f)" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		amount,
	]
```

- [ ] **Step 4: Run the test to verify it passes.**

Same command as Step 2. Expected: all three tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add scripts/resource_definitions/effects/award_attribute_effect_data.gd tests/unit/test_award_attribute_effect_data.gd
git commit -m "feat(effects): add AwardAttributeEffectData"
```

---

### Task 3: Create `TrainingActionData` with pure-function API

**Files:**
- Create: `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd`
- Create: `tests/unit/test_training_action_data.gd`

- [ ] **Step 1: Write the failing tests.**

Create `tests/unit/test_training_action_data.gd`:

```gdscript
extends GutTest

func _make_data(ticks_per_level: Array[int] = [60, 300, 600, 1200], tail: float = 2.0) -> TrainingActionData:
	var data := TrainingActionData.new()
	data.ticks_per_level = ticks_per_level
	data.tail_growth_multiplier = tail
	return data

#-----------------------------------------------------------------------------
# get_ticks_required_for_level — incremental cost per level
#-----------------------------------------------------------------------------

func test_ticks_required_level_0_is_zero() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(0), 0)

func test_ticks_required_level_1_reads_array_first_entry() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(1), 60)

func test_ticks_required_level_4_reads_array_last_entry() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(4), 1200)

func test_ticks_required_beyond_array_applies_tail_multiplier() -> void:
	# Array size 4, tail 2.0 → level 5 = 1200*2.0 = 2400
	assert_eq(_make_data().get_ticks_required_for_level(5), 2400)

func test_ticks_required_two_levels_beyond_array() -> void:
	# level 6 = 1200*2^2 = 4800
	assert_eq(_make_data().get_ticks_required_for_level(6), 4800)

func test_ticks_required_tail_multiplier_1_is_linear() -> void:
	# With multiplier 1.0, level N beyond array equals the last array value.
	var data := _make_data([10, 20], 1.0)
	assert_eq(data.get_ticks_required_for_level(3), 20)
	assert_eq(data.get_ticks_required_for_level(10), 20)

#-----------------------------------------------------------------------------
# get_current_level — cumulative tick count -> current level
#-----------------------------------------------------------------------------

func test_current_level_zero_ticks_is_zero() -> void:
	assert_eq(_make_data().get_current_level(0), 0)

func test_current_level_just_before_first_threshold() -> void:
	assert_eq(_make_data().get_current_level(59), 0)

func test_current_level_exactly_first_threshold() -> void:
	assert_eq(_make_data().get_current_level(60), 1)

func test_current_level_mid_second_tier() -> void:
	assert_eq(_make_data().get_current_level(359), 1)

func test_current_level_exactly_second_threshold() -> void:
	# level 2 requires cumulative 60 + 300 = 360
	assert_eq(_make_data().get_current_level(360), 2)

func test_current_level_beyond_array_uses_tail() -> void:
	# cumulative to level 4 = 60+300+600+1200 = 2160; level 5 adds 2400 -> 4560
	assert_eq(_make_data().get_current_level(4559), 4)
	assert_eq(_make_data().get_current_level(4560), 5)

#-----------------------------------------------------------------------------
# get_progress_within_level — fraction toward next level
#-----------------------------------------------------------------------------

func test_progress_at_tier_start_is_zero() -> void:
	assert_almost_eq(_make_data().get_progress_within_level(0), 0.0, 0.001)

func test_progress_mid_first_tier() -> void:
	# 30 ticks of 60 required for level 1 -> 0.5
	assert_almost_eq(_make_data().get_progress_within_level(30), 0.5, 0.001)

func test_progress_just_before_threshold() -> void:
	# 59/60 -> ~0.983
	assert_almost_eq(_make_data().get_progress_within_level(59), 59.0 / 60.0, 0.001)

func test_progress_at_threshold_resets_to_zero() -> void:
	# 60 ticks = exactly level 1; 0 ticks into level 2
	assert_almost_eq(_make_data().get_progress_within_level(60), 0.0, 0.001)

func test_progress_mid_second_tier() -> void:
	# Cumulative 60 + 150 = 210; level 2 needs 300 -> 150/300 = 0.5
	assert_almost_eq(_make_data().get_progress_within_level(210), 0.5, 0.001)

#-----------------------------------------------------------------------------
# action_type is set in _init
#-----------------------------------------------------------------------------

func test_action_type_defaults_to_train_stats() -> void:
	var data := TrainingActionData.new()
	assert_eq(data.action_type, ZoneActionData.ActionType.TRAIN_STATS)
```

- [ ] **Step 2: Run tests to verify they fail.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_training_action_data.gd -gexit
```

Expected: parse error / `TrainingActionData` not found.

- [ ] **Step 3: Implement the class.**

Create `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd`:

```gdscript
class_name TrainingActionData
extends ZoneActionData

## Per-tick timer interval in seconds while this action is selected.
@export var tick_interval_seconds: float = 1.0

## Hand-tuned incremental tick cost for levels 1..N (1-indexed).
## ticks_per_level[0] is the cost for level 1; ticks_per_level[1] is the cost to go from level 1 to 2, etc.
@export var ticks_per_level: Array[int] = [60, 300, 600, 1200]

## For levels beyond ticks_per_level.size(), each subsequent level costs
## the previous level's cost multiplied by this factor.
@export var tail_growth_multiplier: float = 2.0

## Effects fired every tick while active (e.g., madra trickle).
@export var effects_per_tick: Array[EffectData] = []

## Effects fired once each time a new level is crossed (e.g., attribute grant).
@export var effects_on_level: Array[EffectData] = []

func _init() -> void:
	action_type = ZoneActionData.ActionType.TRAIN_STATS

## Incremental tick cost to go from level-1 to `level`. Level 0 = 0. Levels beyond
## ticks_per_level.size() apply tail_growth_multiplier to the last array value.
func get_ticks_required_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if ticks_per_level.is_empty():
		return 0
	var array_size: int = ticks_per_level.size()
	if level <= array_size:
		return ticks_per_level[level - 1]
	var last: float = float(ticks_per_level[array_size - 1])
	var extra_levels: int = level - array_size
	return int(round(last * pow(tail_growth_multiplier, extra_levels)))

## Highest completed level given cumulative accumulated ticks.
func get_current_level(accumulated_ticks: int) -> int:
	if accumulated_ticks <= 0:
		return 0
	var level: int = 0
	var cumulative: int = 0
	while true:
		var next_cost: int = get_ticks_required_for_level(level + 1)
		if next_cost <= 0:
			return level
		if cumulative + next_cost > accumulated_ticks:
			return level
		cumulative += next_cost
		level += 1

## 0.0-1.0 progress toward the next level. 0.0 at tier boundary, ~1.0 just before next boundary.
func get_progress_within_level(accumulated_ticks: int) -> float:
	var current_level: int = get_current_level(accumulated_ticks)
	var cumulative_to_current: int = 0
	for i in range(1, current_level + 1):
		cumulative_to_current += get_ticks_required_for_level(i)
	var next_cost: int = get_ticks_required_for_level(current_level + 1)
	if next_cost <= 0:
		return 0.0
	var progress_ticks: int = accumulated_ticks - cumulative_to_current
	return clamp(float(progress_ticks) / float(next_cost), 0.0, 1.0)
```

- [ ] **Step 4: Run tests to verify they pass.**

Same command as Step 2. Expected: all tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd tests/unit/test_training_action_data.gd
git commit -m "feat(zones): add TrainingActionData with cost-curve API"
```

---

### Task 4: Add `training_tick_progress` field to `ZoneProgressionData`

**Files:**
- Modify: `singletons/persistence_manager/zone_progression_data.gd`
- Create: `tests/unit/test_zone_progression_data.gd`

- [ ] **Step 1: Write the failing test.**

Create `tests/unit/test_zone_progression_data.gd`:

```gdscript
extends GutTest

func test_training_tick_progress_defaults_to_empty_dict() -> void:
	var zp := ZoneProgressionData.new()
	assert_true(zp.training_tick_progress.is_empty(), "training_tick_progress should default to empty")

func test_training_tick_progress_accepts_string_int_pairs() -> void:
	var zp := ZoneProgressionData.new()
	zp.training_tick_progress["spirit_well_training"] = 42
	assert_eq(zp.training_tick_progress["spirit_well_training"], 42)

func test_training_tick_progress_persists_via_resource_save_load(params = null) -> void:
	var zp := ZoneProgressionData.new()
	zp.zone_id = "SpiritValley"
	zp.training_tick_progress["spirit_well_training"] = 7
	zp.training_tick_progress["other_training"] = 99

	var tmp_path: String = "user://__test_zone_progression.tres"
	ResourceSaver.save(zp, tmp_path)
	var loaded: ZoneProgressionData = ResourceLoader.load(tmp_path, "ZoneProgressionData", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.training_tick_progress["spirit_well_training"], 7)
	assert_eq(loaded.training_tick_progress["other_training"], 99)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
```

- [ ] **Step 2: Run test to verify it fails.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_zone_progression_data.gd -gexit
```

Expected: fails on `training_tick_progress` not found.

- [ ] **Step 3: Add the field.**

In `singletons/persistence_manager/zone_progression_data.gd`, add the field below the existing exports:

```gdscript
class_name ZoneProgressionData
extends Resource

@export var zone_id: String = ""

## Dict ZoneActionData.action_id -> num_completions
@export var action_completion_count : Dictionary[String, int] = {}
@export var forage_active: bool = false
@export var forage_start_time: float = 0.0

## Accumulated ticks per training action_id in this zone.
@export var training_tick_progress: Dictionary[String, int] = {}

func _to_string() -> String:
	return "ZoneProgressionData(ZoneId: %s\n, ActionCompletionCount: %s\n, ForageActive: %s\n, ForageStartTime: %s\n, TrainingTickProgress: %s\n)" % [zone_id, str(action_completion_count), forage_active, forage_start_time, str(training_tick_progress)]
```

- [ ] **Step 4: Run test to verify it passes.**

Same command as Step 2. Expected: all three tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add singletons/persistence_manager/zone_progression_data.gd tests/unit/test_zone_progression_data.gd
git commit -m "feat(zones): add training_tick_progress to ZoneProgressionData"
```

---

### Task 5: Add `get_training_ticks` / `increment_training_ticks` to `ZoneManager`

**Files:**
- Modify: `singletons/zone_manager/zone_manager.gd`
- Modify: `tests/unit/test_zone_progression_data.gd` (add helper tests)

- [ ] **Step 1: Write failing tests in the existing file.**

Append to `tests/unit/test_zone_progression_data.gd`:

```gdscript
#-----------------------------------------------------------------------------
# ZoneManager.get_training_ticks / increment_training_ticks
#-----------------------------------------------------------------------------

var _original_live_save: SaveGameData
var _save_data: SaveGameData

func before_each() -> void:
	_original_live_save = ZoneManager.live_save_data
	_save_data = SaveGameData.new()
	ZoneManager.live_save_data = _save_data

func after_each() -> void:
	ZoneManager.live_save_data = _original_live_save

func test_get_training_ticks_returns_zero_for_unseen_action() -> void:
	assert_eq(ZoneManager.get_training_ticks("unknown_action", "SpiritValley"), 0)

func test_increment_training_ticks_initializes_from_zero() -> void:
	var total := ZoneManager.increment_training_ticks("spirit_well_training", "SpiritValley")
	assert_eq(total, 1)
	assert_eq(ZoneManager.get_training_ticks("spirit_well_training", "SpiritValley"), 1)

func test_increment_training_ticks_accumulates_across_calls() -> void:
	ZoneManager.increment_training_ticks("spirit_well_training", "SpiritValley")
	ZoneManager.increment_training_ticks("spirit_well_training", "SpiritValley")
	var total := ZoneManager.increment_training_ticks("spirit_well_training", "SpiritValley", 3)
	assert_eq(total, 5)

func test_increment_training_ticks_independent_per_action() -> void:
	ZoneManager.increment_training_ticks("a", "SpiritValley", 2)
	ZoneManager.increment_training_ticks("b", "SpiritValley", 7)
	assert_eq(ZoneManager.get_training_ticks("a", "SpiritValley"), 2)
	assert_eq(ZoneManager.get_training_ticks("b", "SpiritValley"), 7)
```

- [ ] **Step 2: Run to verify failure.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_zone_progression_data.gd -gexit
```

Expected: `get_training_ticks` / `increment_training_ticks` not found on ZoneManager.

- [ ] **Step 3: Add the helpers to ZoneManager.**

In `singletons/zone_manager/zone_manager.gd`, under the `ZONE PROGRESS HANDLING` section (after `increment_zone_progression_for_action`), append:

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

- [ ] **Step 4: Run tests to verify they pass.**

Same command as Step 2. Expected: all tests (old and new) PASS.

- [ ] **Step 5: Commit.**

```bash
git add singletons/zone_manager/zone_manager.gd tests/unit/test_zone_progression_data.gd
git commit -m "feat(zones): ZoneManager training tick getter/incrementer"
```

---

### Task 6: Add `ActionManager` routing and tick handler

**Files:**
- Modify: `singletons/action_manager/action_manager.gd`

This task has no unit test (timer coupling makes it integration territory). The integration coverage lands in Task 8. Commit after Godot parses the file cleanly — verified by running the existing test suite.

- [ ] **Step 1: Add the new signals.**

In `singletons/action_manager/action_manager.gd`, under the SIGNALS section (around line 24, after `stop_adventure`), append:

```gdscript
## training signals
signal start_training(action_data: TrainingActionData)
signal stop_training()
signal training_tick_processed(action_data: TrainingActionData, new_tick_count: int)
signal training_level_gained(action_data: TrainingActionData, new_level: int)
```

- [ ] **Step 2: Add the routing branch in `_execute_action`.**

In the `match action_data.action_type:` block inside `_execute_action` (around line 72-94), add a new branch before the wildcard `_` case:

```gdscript
ZoneActionData.ActionType.TRAIN_STATS:
	if action_data is TrainingActionData:
		_execute_train_action(action_data as TrainingActionData)
	else:
		Log.error("ActionManager: Training action data is not a TrainingActionData: %s" % action_data.action_name)
```

- [ ] **Step 3: Add the stop-routing branch in `_stop_executing_current_action`.**

In the `match current_action.action_type:` block inside `_stop_executing_current_action` (around line 101-111), add before the wildcard `_`:

```gdscript
ZoneActionData.ActionType.TRAIN_STATS:
	_stop_train_action(successful)
```

- [ ] **Step 4: Add the execution handlers.**

At the end of the ACTION EXECUTION HANDLERS section (after `_execute_dialogue_action`), append:

```gdscript
## Handle training action - start periodic tick timer.
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
```

- [ ] **Step 5: Add the stop handler.**

At the end of the ACTION STOP EXECUTION HANDLERS section (after `_stop_dialogue_action`), append:

```gdscript
## Handle training action - stop and persist remaining progress.
func _stop_train_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping training action")
	stop_training.emit()
	_reset_action_timer()
	_process_completion_effects(successful)
```

- [ ] **Step 6: Verify the file parses and existing tests still pass.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```

Expected: all existing unit tests pass; no parse errors from ActionManager.

- [ ] **Step 7: Commit.**

```bash
git add singletons/action_manager/action_manager.gd
git commit -m "feat(actions): route TRAIN_STATS to tick handler"
```

---

### Task 7: Create Spirit Well `.tres` and wire into zone

**Files:**
- Create: `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres`
- Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`

This task uses the Godot editor (inspector-driven resource creation is how the other `.tres` files were authored). Reference the raw `.tres` text below to double-check the result.

- [ ] **Step 1: Open the project in Godot editor.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" project.godot
```

- [ ] **Step 2: Create the `AwardAttributeEffectData` resource for Spirit grant.**

In FileSystem, navigate to `res://resources/zones/spirit_valley_zone/zone_actions/`. Right-click → New Resource → `AwardAttributeEffectData`. Save as `spirit_well_spirit_award_effect.tres`. In Inspector set:
- `attribute_type` = `SPIRIT` (enum index 3)
- `amount` = `1.0`

- [ ] **Step 3: Create the `AwardResourceEffectData` for madra trickle.**

Same directory → New Resource → `AwardResourceEffectData`. Save as `spirit_well_madra_trickle_effect.tres`. In Inspector set:
- `resource_type` = `MADRA` (enum index 0)
- `amount` = `1.5`

- [ ] **Step 4: Create the `TrainingActionData` resource.**

Same directory → New Resource → `TrainingActionData`. Save as `spirit_well_training_action.tres`. In Inspector set:
- `action_id` = `spirit_well_training`
- `action_name` = `Spirit Well`
- `action_type` = `TRAIN_STATS` (auto-set by `_init`, but confirm = 4)
- `description` = `Sit at the Spirit Well. Let the valley's aura steep into your bones.`
- `max_completions` = `0` (unlimited)
- `tick_interval_seconds` = `1.0`
- `ticks_per_level` = `[60, 300, 600, 1200]`
- `tail_growth_multiplier` = `2.0`
- `effects_per_tick` = `[spirit_well_madra_trickle_effect.tres]`
- `effects_on_level` = `[spirit_well_spirit_award_effect.tres]`
- `unlock_conditions` = `[]` (Beat 3a unlock gating is a later pass; ship unlocked for dev testing)

- [ ] **Step 5: Add Spirit Well to the Spirit Valley zone.**

Open `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`. In the `all_actions` array, append `spirit_well_training_action.tres`. Save.

- [ ] **Step 6: Verify the `.tres` loads by running the project briefly.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Enter Zone view. Confirm a `Spirit Well` action card appears alongside the existing actions (no category section exists for `TRAIN_STATS` yet — the card will land under the default "ACTIONS" section with the fallback grey dot color until UI polish). Close the game.

Resulting `spirit_well_training_action.tres` should resemble (exact UIDs differ):

```
[gd_resource type="Resource" script_class="TrainingActionData" load_steps=5 format=3 uid="uid://<auto>"]

[ext_resource type="Script" uid="uid://<training_action_data_uid>" path="res://scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd" id="1_train"]
[ext_resource type="Resource" uid="uid://<madra_trickle_uid>" path="res://resources/zones/spirit_valley_zone/zone_actions/spirit_well_madra_trickle_effect.tres" id="2_trickle"]
[ext_resource type="Resource" uid="uid://<spirit_award_uid>" path="res://resources/zones/spirit_valley_zone/zone_actions/spirit_well_spirit_award_effect.tres" id="3_award"]

[resource]
script = ExtResource("1_train")
action_id = "spirit_well_training"
action_name = "Spirit Well"
action_type = 4
description = "Sit at the Spirit Well. Let the valley's aura steep into your bones."
max_completions = 0
tick_interval_seconds = 1.0
ticks_per_level = Array[int]([60, 300, 600, 1200])
tail_growth_multiplier = 2.0
effects_per_tick = Array[Resource]([ExtResource("2_trickle")])
effects_on_level = Array[Resource]([ExtResource("3_award")])
```

- [ ] **Step 7: Commit.**

```bash
git add resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres \
        resources/zones/spirit_valley_zone/zone_actions/spirit_well_madra_trickle_effect.tres \
        resources/zones/spirit_valley_zone/zone_actions/spirit_well_spirit_award_effect.tres \
        resources/zones/spirit_valley_zone/spirit_valley_zone.tres
git commit -m "feat(content): add Spirit Well training action to Spirit Valley"
```

---

### Task 8: Integration test — end-to-end training flow

**Files:**
- Create: `tests/integration/test_training_flow.gd`

- [ ] **Step 1: Write the integration test.**

Create `tests/integration/test_training_flow.gd`:

```gdscript
extends GutTest

## Integration test: TRAIN_STATS action drives ZoneProgressionData ticks,
## fires effects_per_tick every tick, and effects_on_level once per level crossed.
## Progress persists across stop/restart.

var _save_data: SaveGameData
var _training_data: TrainingActionData
var _spirit_award_effect: AwardAttributeEffectData
var _madra_trickle_effect: AwardResourceEffectData

var _original_character_live: SaveGameData
var _original_zone_live: SaveGameData
var _original_resource_live: SaveGameData

var _tick_signal_count: int = 0
var _level_signal_levels: Array[int] = []

func before_each() -> void:
	# Fresh save data, seed Spirit Valley as current zone
	_save_data = SaveGameData.new()
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_save_data.madra = 0.0
	_save_data.current_selected_zone_id = "SpiritValley"

	_original_character_live = CharacterManager.live_save_data
	_original_zone_live = ZoneManager.live_save_data
	_original_resource_live = ResourceManager.live_save_data

	CharacterManager.live_save_data = _save_data
	ZoneManager.live_save_data = _save_data
	ResourceManager.live_save_data = _save_data

	# Build a test training action with fast ticks and small thresholds
	_spirit_award_effect = AwardAttributeEffectData.new()
	_spirit_award_effect.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	_spirit_award_effect.amount = 1.0

	_madra_trickle_effect = AwardResourceEffectData.new()
	_madra_trickle_effect.resource_type = ResourceManager.ResourceType.MADRA
	_madra_trickle_effect.amount = 1.0

	_training_data = TrainingActionData.new()
	_training_data.action_id = "test_training"
	_training_data.action_name = "Test Training"
	_training_data.tick_interval_seconds = 0.05
	_training_data.ticks_per_level = [3, 3] as Array[int]
	_training_data.tail_growth_multiplier = 2.0
	_training_data.effects_per_tick = [_madra_trickle_effect] as Array[EffectData]
	_training_data.effects_on_level = [_spirit_award_effect] as Array[EffectData]

	_tick_signal_count = 0
	_level_signal_levels = []
	ActionManager.training_tick_processed.connect(_on_tick)
	ActionManager.training_level_gained.connect(_on_level)

func after_each() -> void:
	if ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	ActionManager.training_tick_processed.disconnect(_on_tick)
	ActionManager.training_level_gained.disconnect(_on_level)
	CharacterManager.live_save_data = _original_character_live
	ZoneManager.live_save_data = _original_zone_live
	ResourceManager.live_save_data = _original_resource_live

func _on_tick(_data: TrainingActionData, _count: int) -> void:
	_tick_signal_count += 1

func _on_level(_data: TrainingActionData, level: int) -> void:
	_level_signal_levels.append(level)

func _get_spirit() -> float:
	return _save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)

func test_training_ticks_fire_effects_and_level_up() -> void:
	ActionManager.select_action(_training_data)

	# 4 ticks at 0.05s each = 0.20s; wait 0.25s to allow buffer
	await get_tree().create_timer(0.25).timeout

	# Expect 4 tick signals, madra +4, level 1 crossed once at tick 3
	assert_eq(_tick_signal_count, 4, "tick signal should have fired 4 times")
	assert_eq(_save_data.madra, 4.0, "madra trickle should have accumulated +4")
	assert_eq(_level_signal_levels, [1] as Array[int], "level 1 should have been gained once")
	assert_eq(_get_spirit(), 11.0, "Spirit should be 10 + 1 = 11 after one level-up")

	ActionManager.stop_action()

	# Persistence: ticks survived stop
	assert_eq(ZoneManager.get_training_ticks("test_training", "SpiritValley"), 4,
		"accumulated_ticks should persist after stop")

	# Restart: 2 more ticks -> cumulative 6 -> level 2 crossed
	ActionManager.select_action(_training_data)
	await get_tree().create_timer(0.15).timeout

	assert_gt(_tick_signal_count, 4, "tick signal should have fired more times after restart")
	assert_true(_level_signal_levels.has(2), "level 2 should have been gained after tick 6")
	assert_eq(_get_spirit(), 12.0, "Spirit should be 12 after two level-ups")

	ActionManager.stop_action()
```

- [ ] **Step 2: Run the integration test.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_training_flow.gd -gexit
```

Expected: PASS. If the tick count is off by one (timer timing jitter), increase the `0.25s` wait to `0.30s`; the assertion is on the count, not the time.

- [ ] **Step 3: Run the full suite to verify no regressions.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass (pre-existing + new).

- [ ] **Step 4: Commit.**

```bash
git add tests/integration/test_training_flow.gd
git commit -m "test(training): integration test for end-to-end tick and level flow"
```

---

## Self-Review

**Spec coverage check:**
- ✅ `TrainingActionData` (Task 3) — all fields and pure-function API
- ✅ `AwardAttributeEffectData` + `AWARD_ATTRIBUTE` enum (Tasks 1, 2)
- ✅ `training_tick_progress` on `ZoneProgressionData` (Task 4)
- ✅ `get_training_ticks` / `increment_training_ticks` on `ZoneManager` (Task 5)
- ✅ `ActionManager` signals + routing + tick handler (Task 6)
- ✅ Spirit Well `.tres` content and zone wiring (Task 7)
- ✅ Unit tests for cost curve, effect processing, persistence, helpers (Tasks 2-5)
- ✅ Integration test with effects, persistence across switch (Task 8)

**Placeholder scan:** All steps have literal code or exact commands. The only intentional placeholders are Godot-generated UIDs in the `.tres` reference block (Task 7 Step 6), which are explicitly noted as auto-assigned.

**Type consistency:**
- `TrainingActionData.get_current_level(accumulated_ticks: int) -> int` — used with same signature in Task 6 handler and Task 3 tests
- `ZoneManager.increment_training_ticks(action_id, zone_id, amount = 1) -> int` — used consistently in Tasks 5, 6, 8
- `CharacterAttributesData.AttributeType.SPIRIT` (enum member) — consistent across Tasks 2, 7, 8
- `ResourceManager.ResourceType.MADRA` — consistent across Task 7 and 8
- Signal parameters match between `ActionManager` declaration (Task 6) and test connections (Task 8)

No issues found.

---

## Post-Implementation Handoff

Once all tasks land:

1. **Manual smoke test:** start the game, navigate to Zone view, select Spirit Well. Confirm madra ticks up at ~1.5/sec; after ~60s, Spirit attribute increments by 1 (verify via character view or `LogManager` output).
2. **Follow-up specs:** (1) adventure-tile-visit unlock condition to gate Spirit Well visibility per Beat 3a; (2) per-level progress fill UI variant for the action card; (3) tuning pass on the `1.5 madra/tick` rate once cycling output is measured.
