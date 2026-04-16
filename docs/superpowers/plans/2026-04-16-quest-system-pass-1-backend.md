# Quest System — Pass 1 (Backend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data-only half of the quest system — resource classes, `QuestManager` singleton, `StartQuestEffectData`, save integration, full GUT test coverage. No UI.

**Architecture:** Linear multi-step quests tracked by a new `QuestManager` autoload. Steps advance on `EventManager.event_triggered` (simple case) or when all `UnlockConditionData` evaluate true (complex case). Quests are started via a new `StartQuestEffectData` added to any action's `success_effects`. Progression persisted via new `QuestProgressionData` on `SaveGameData`.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0. Follows the `CyclingManager` singleton pattern for catalog + save integration and the `EventManager` pattern for event listening.

**Reference spec:** `docs/superpowers/specs/2026-04-16-quest-system-design.md`

**Test command (single file):**
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

**Test command (full suite):**
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

---

## File Structure

**New files:**
| File | Responsibility |
|---|---|
| `scripts/resource_definitions/quests/quest_step_data.gd` | One step in a quest. Completion event_id OR conditions list. |
| `scripts/resource_definitions/quests/quest_data.gd` | A quest: id, name, steps, completion_effects. |
| `scripts/resource_definitions/quests/quest_list.gd` | Catalog container: `Array[QuestData]`. |
| `resources/quests/quest_list.tres` | Empty catalog, populated later. |
| `singletons/persistence_manager/quest_progression_data.gd` | Save-side state: active_quests dict + completed ids. |
| `singletons/quest_manager/quest_manager.gd` | Singleton: start, advance, complete, load/save. |
| `scripts/resource_definitions/effects/start_quest_effect_data.gd` | EffectData subclass that calls `QuestManager.start_quest`. |
| `tests/unit/test_quest_manager.gd` | Unit tests for QuestManager. |
| `tests/unit/test_start_quest_effect_data.gd` | Unit tests for the effect. |

**Modified files:**
| File | Change |
|---|---|
| `scripts/resource_definitions/effects/effect_data.gd` | Add `START_QUEST` to `EffectType` enum. |
| `singletons/persistence_manager/save_game_data.gd` | Add `quest_progression` field + include in `reset()` + `_to_string()`. |
| `project.godot` | Register `QuestManager` autoload. |
| `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` | Remove `QUEST_GIVER` from `ActionType` enum. |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Remove `QUEST_GIVER` from comment at lines 13-15. |
| `docs/zones/ZONES.md` | Remove `QUEST_GIVER` rows (search `QUEST_GIVER`, remove both mentions). |

---

## Task 1: Define QuestStepData, QuestData, QuestList resources

Pure data resources with no behavior. Group them because none has a test.

**Files:**
- Create: `scripts/resource_definitions/quests/quest_step_data.gd`
- Create: `scripts/resource_definitions/quests/quest_data.gd`
- Create: `scripts/resource_definitions/quests/quest_list.gd`
- Create: `resources/quests/quest_list.tres`

- [ ] **Step 1: Create `quest_step_data.gd`**

```gdscript
class_name QuestStepData
extends Resource

## One step in a quest. A step advances when EITHER its completion_event_id fires
## OR all its completion_conditions evaluate true. Set exactly one of the two.
@export var step_id: String = ""
@export var description: String = ""
@export var completion_event_id: String = ""
@export var completion_conditions: Array[UnlockConditionData] = []


func _to_string() -> String:
	return "QuestStepData(step_id=%s, event=%s, conditions=%d)" % [
		step_id, completion_event_id, completion_conditions.size()
	]
```

- [ ] **Step 2: Create `quest_data.gd`**

```gdscript
class_name QuestData
extends Resource

## A linear multi-step quest. Started via StartQuestEffectData. Surfaced to the
## player by QuestManager. Steps complete in order; completion_effects fire when
## the last step advances.
@export var quest_id: String = ""
@export var quest_name: String = ""
@export var description: String = ""
@export var steps: Array[QuestStepData] = []
@export var completion_effects: Array[EffectData] = []


func _to_string() -> String:
	return "QuestData(quest_id=%s, steps=%d, completion_effects=%d)" % [
		quest_id, steps.size(), completion_effects.size()
	]
```

- [ ] **Step 3: Create `quest_list.gd`**

```gdscript
class_name QuestList
extends Resource

## Catalog container for all QuestData in the project. QuestManager preloads
## this at boot and indexes by quest_id.
@export var quests: Array[QuestData] = []
```

- [ ] **Step 4: Create the empty catalog resource**

Create an empty file at `resources/quests/quest_list.tres`:

```
[gd_resource type="Resource" script_class="QuestList" load_steps=2 format=3 uid="uid://will-regenerate"]

[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_list.gd" id="1"]

[resource]
script = ExtResource("1")
quests = Array[ExtResource("1")]([])
```

Note: the UID will be regenerated by Godot when it first imports the file. If Godot complains, let it regenerate.

- [ ] **Step 5: Verify the project parses**

Open the project once in the editor to let Godot generate UIDs and import the new resources:

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly with no parse errors. If errors mention `UnlockConditionData` or `EffectData` being unresolved at class-load time, that's fine — those are defined in existing files and Godot resolves them during editor import.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/quests/ resources/quests/
git commit -m "feat(quests): add QuestData, QuestStepData, QuestList resources"
```

---

## Task 2: Add QuestProgressionData and wire into SaveGameData

**Files:**
- Create: `singletons/persistence_manager/quest_progression_data.gd`
- Modify: `singletons/persistence_manager/save_game_data.gd`

- [ ] **Step 1: Create `quest_progression_data.gd`**

```gdscript
class_name QuestProgressionData
extends Resource

## Persisted per-save quest state.
## active_quests maps quest_id -> current step index (0-based).
## completed_quest_ids is an ordered list of completed quests.
@export var active_quests: Dictionary[String, int] = {}
@export var completed_quest_ids: Array[String] = []


func _to_string() -> String:
	return "QuestProgressionData(active=%s, completed=%s)" % [
		str(active_quests), str(completed_quest_ids)
	]
```

- [ ] **Step 2: Add to SaveGameData**

Open `singletons/persistence_manager/save_game_data.gd`. Find the section header block pattern (e.g., `# EVENT MANAGER`). Add a new section **after the EVENT MANAGER block** (around line 44):

```gdscript
#-----------------------------------------------------------------------------
# QUEST MANAGER
#-----------------------------------------------------------------------------

@export var quest_progression: QuestProgressionData = QuestProgressionData.new()
```

- [ ] **Step 3: Add to `reset()`**

In `SaveGameData.reset()`, add near the Event Manager block:

```gdscript
	# Quest Manager
	quest_progression = QuestProgressionData.new()
```

- [ ] **Step 4: Add to `_to_string()`**

In `SaveGameData._to_string()`, add `str(quest_progression)` to both the format string and the args array. Insert it next to `str(event_progression)` for locality:

In the format string, after `EventProgression: %s\n`, add:
```
  QuestProgression: %s\n
```

In the args array, after `str(event_progression),`, add:
```gdscript
				str(quest_progression),
```

- [ ] **Step 5: Verify the project still parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly. Log shouldn't mention save data errors.

- [ ] **Step 6: Commit**

```bash
git add singletons/persistence_manager/quest_progression_data.gd singletons/persistence_manager/save_game_data.gd
git commit -m "feat(quests): add QuestProgressionData to SaveGameData"
```

---

## Task 3: Scaffold QuestManager singleton and register autoload

Scaffold only — public API stubs + catalog load + save-data wiring. Behavior comes in later tasks.

**Files:**
- Create: `singletons/quest_manager/quest_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create `quest_manager.gd`**

```gdscript
extends Node

## Tracks active and completed quests. Advances quest steps based on
## EventManager.event_triggered or UnlockConditionData evaluation. Fires
## completion effects when the last step advances.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal quest_started(quest_id: String)
signal quest_step_advanced(quest_id: String, new_step_index: int)
signal quest_completed(quest_id: String)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _live_save_data: SaveGameData = null
var _quest_catalog: QuestList = preload("res://resources/quests/quest_list.tres")
var _quests_by_id: Dictionary = {}  # String -> QuestData

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("QuestManager: Could not get save_game_data from PersistenceManager on ready!")
	if EventManager:
		EventManager.event_triggered.connect(_on_event_triggered)
	else:
		Log.critical("QuestManager: EventManager not available on ready!")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Starts a quest by id. No-op if already active or completed.
func start_quest(quest_id: String) -> void:
	push_error("QuestManager.start_quest not yet implemented")

## Returns true if the quest is currently in the active list.
func has_active_quest(quest_id: String) -> bool:
	if not _live_save_data:
		return false
	return _live_save_data.quest_progression.active_quests.has(quest_id)

## Returns true if the quest is in the completed list.
func has_completed_quest(quest_id: String) -> bool:
	if not _live_save_data:
		return false
	return quest_id in _live_save_data.quest_progression.completed_quest_ids

## Returns ids of all currently active quests in insertion order.
func get_active_quest_ids() -> Array[String]:
	var result: Array[String] = []
	if not _live_save_data:
		return result
	for quest_id: String in _live_save_data.quest_progression.active_quests.keys():
		result.append(quest_id)
	return result

## Returns ids of all completed quests.
func get_completed_quest_ids() -> Array[String]:
	var result: Array[String] = []
	if not _live_save_data:
		return result
	for quest_id: String in _live_save_data.quest_progression.completed_quest_ids:
		result.append(quest_id)
	return result

## Returns the current step index for an active quest, or -1 if not active.
func get_current_step_index(quest_id: String) -> int:
	if not _live_save_data:
		return -1
	return _live_save_data.quest_progression.active_quests.get(quest_id, -1)

## Returns the QuestData for a quest_id, or null if unknown.
func get_quest_data(quest_id: String) -> QuestData:
	return _quests_by_id.get(quest_id, null)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _build_catalog_index() -> void:
	_quests_by_id.clear()
	for quest: QuestData in _quest_catalog.quests:
		if quest and not quest.quest_id.is_empty():
			_quests_by_id[quest.quest_id] = quest

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data

func _on_event_triggered(_event_id: String) -> void:
	# Implemented in Task 5.
	pass
```

- [ ] **Step 2: Register autoload in `project.godot`**

Open `project.godot`. Find the `[autoload]` section (starts around line 22). Add this line at the end of the autoload block (order matters — must come after `PersistenceManager` and `EventManager`):

```
QuestManager="*res://singletons/quest_manager/quest_manager.gd"
```

The autoload section should now end with `PathManager=` then `QuestManager=`.

- [ ] **Step 3: Verify project imports and autoloads resolve**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: no errors about `QuestManager`, no errors about missing `QuestList` or `QuestData` class names.

- [ ] **Step 4: Commit**

```bash
git add singletons/quest_manager/ project.godot
git commit -m "feat(quests): scaffold QuestManager singleton"
```

---

## Task 4: Implement start_quest (basic, no retroactive auto-complete)

TDD. Adds to active list + emits signal. Skips already-active / already-completed / unknown ids. Retroactive auto-complete comes in Task 7.

**Files:**
- Create: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_quest_manager.gd`:

```gdscript
extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _quest_a: QuestData
var _quest_b: QuestData
var _step_talk_eel: QuestStepData
var _step_visit_forest: QuestStepData

func _create_step(step_id: String, description: String, event_id: String = "") -> QuestStepData:
	var s := QuestStepData.new()
	s.step_id = step_id
	s.description = description
	s.completion_event_id = event_id
	return s

func _create_quest(quest_id: String, quest_name: String, steps: Array[QuestStepData]) -> QuestData:
	var q := QuestData.new()
	q.quest_id = quest_id
	q.quest_name = quest_name
	q.steps = steps
	return q

func before_each() -> void:
	_save_data = SaveGameData.new()
	_step_talk_eel = _create_step("talk_eel", "Talk to the Wisened Dirt Eel", "eel_dialogue_done")
	_step_visit_forest = _create_step("visit_forest", "Visit the Spring Forest", "spring_forest_visited")
	_quest_a = _create_quest("quest_a", "Quest A", [_step_talk_eel, _step_visit_forest] as Array[QuestStepData])
	_quest_b = _create_quest("quest_b", "Quest B", [_step_talk_eel] as Array[QuestStepData])
	QuestManager._live_save_data = _save_data
	QuestManager._quests_by_id = {
		"quest_a": _quest_a,
		"quest_b": _quest_b,
	}

func after_each() -> void:
	QuestManager._live_save_data = null
	QuestManager._quests_by_id = {}

# ----- start_quest: basic -----

func test_start_quest_adds_to_active_list() -> void:
	QuestManager.start_quest("quest_a")
	assert_true(QuestManager.has_active_quest("quest_a"), "quest_a should be active")

func test_start_quest_sets_step_index_zero() -> void:
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"newly started quest should be at step 0")

func test_start_quest_emits_signal() -> void:
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_emitted_with_parameters(QuestManager, "quest_started", ["quest_a"])

func test_start_quest_unknown_id_pushes_error() -> void:
	QuestManager.start_quest("nonexistent")
	assert_push_error("unknown quest_id")

func test_start_quest_already_active_is_noop() -> void:
	QuestManager.start_quest("quest_a")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_not_emitted(QuestManager, "quest_started")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"step index should remain 0 on re-start")

func test_start_quest_already_completed_is_noop() -> void:
	_save_data.quest_progression.completed_quest_ids.append("quest_a")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_not_emitted(QuestManager, "quest_started")
	assert_false(QuestManager.has_active_quest("quest_a"),
		"already-completed quest should not become active")
```

- [ ] **Step 2: Run tests to verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all tests fail with `QuestManager.start_quest not yet implemented` push_error.

- [ ] **Step 3: Implement start_quest (basic, no retroactive)**

Replace the `start_quest` stub in `quest_manager.gd`:

```gdscript
func start_quest(quest_id: String) -> void:
	if not _live_save_data:
		return
	if not _quests_by_id.has(quest_id):
		push_error("QuestManager: unknown quest_id '%s'" % quest_id)
		return
	if has_active_quest(quest_id):
		return
	if has_completed_quest(quest_id):
		return
	_live_save_data.quest_progression.active_quests[quest_id] = 0
	Log.info("QuestManager: Started quest '%s'" % quest_id)
	quest_started.emit(quest_id)
```

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 6 `start_quest` tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): implement start_quest with active/completed guards"
```

---

## Task 5: Advance step on event_triggered

TDD. When `EventManager.event_triggered(event_id)` fires, any active quest whose current step has `completion_event_id == event_id` advances.

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append to `tests/unit/test_quest_manager.gd`:

```gdscript
# ----- step advancement: event-based -----

func test_step_advances_on_matching_event() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"quest_a should advance to step 1 after eel_dialogue_done")

func test_step_does_not_advance_on_unmatched_event() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager._on_event_triggered("unrelated_event")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"quest_a should still be at step 0")

func test_step_advance_emits_signal() -> void:
	QuestManager.start_quest("quest_a")
	watch_signals(QuestManager)
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_signal_emitted_with_parameters(QuestManager, "quest_step_advanced", ["quest_a", 1])

func test_multiple_active_quests_share_event_advance() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager.start_quest("quest_b")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"quest_a advances to step 1")
	# quest_b only has one step matching eel_dialogue_done — it completes;
	# "completes" behavior is tested in Task 7 — for now just assert it's no
	# longer at step 0 OR has been removed from active.
	assert_true(
		not QuestManager.has_active_quest("quest_b") or
			QuestManager.get_current_step_index("quest_b") != 0,
		"quest_b should have left step 0"
	)
```

- [ ] **Step 2: Run tests to verify failures**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: the 4 new tests fail (step index stays at 0).

- [ ] **Step 3: Implement `_on_event_triggered` and a helper**

Replace the `_on_event_triggered` stub and add a helper in `quest_manager.gd`:

```gdscript
func _on_event_triggered(event_id: String) -> void:
	# Iterate over a copy since advancement may complete a quest and mutate active_quests.
	var active_ids: Array[String] = get_active_quest_ids()
	for quest_id: String in active_ids:
		_try_advance_step(quest_id, event_id)

## Advances the current step of `quest_id` if its completion criteria are met.
## `triggering_event_id` is the event that just fired (empty for non-event triggers).
func _try_advance_step(quest_id: String, triggering_event_id: String) -> void:
	var quest: QuestData = _quests_by_id.get(quest_id)
	if quest == null:
		return
	var step_index: int = _live_save_data.quest_progression.active_quests.get(quest_id, -1)
	if step_index < 0 or step_index >= quest.steps.size():
		return
	var step: QuestStepData = quest.steps[step_index]
	if not _is_step_satisfied(step, triggering_event_id):
		return
	_advance_step(quest_id)

## Returns true if the step's completion criterion is met right now.
## For event-based steps, `triggering_event_id` must match. For condition-based
## steps, evaluates all conditions against current state.
func _is_step_satisfied(step: QuestStepData, triggering_event_id: String) -> bool:
	if not step.completion_event_id.is_empty():
		return step.completion_event_id == triggering_event_id
	# Conditions path — implemented in Task 6.
	return false

## Moves the quest forward one step. If it was on the last step, the quest
## completes (implemented in Task 8). Emits quest_step_advanced otherwise.
func _advance_step(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	var new_index: int = _live_save_data.quest_progression.active_quests[quest_id] + 1
	if new_index >= quest.steps.size():
		# Completion logic added in Task 8 — for now, remove from active to
		# satisfy Task 5's multi-quest test.
		_live_save_data.quest_progression.active_quests.erase(quest_id)
		return
	_live_save_data.quest_progression.active_quests[quest_id] = new_index
	Log.info("QuestManager: Quest '%s' advanced to step %d" % [quest_id, new_index])
	quest_step_advanced.emit(quest_id, new_index)
```

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all tests so far pass (10 tests across Tasks 4-5).

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): advance quest step on matching event"
```

---

## Task 6: Advance step on condition-based criteria

TDD. When the current step has no `completion_event_id` but has `completion_conditions`, all conditions must evaluate true on any `event_triggered` fire.

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append to `tests/unit/test_quest_manager.gd`:

```gdscript
# ----- step advancement: condition-based -----

func _create_condition_event(event_id: String) -> UnlockConditionData:
	var c := UnlockConditionData.new()
	c.condition_id = "cond_" + event_id
	c.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	c.target_value = event_id
	return c

func test_condition_step_advances_when_all_conditions_true() -> void:
	var cond_step := QuestStepData.new()
	cond_step.step_id = "cond_step"
	cond_step.description = "Do two things"
	cond_step.completion_conditions = [
		_create_condition_event("event_x"),
		_create_condition_event("event_y"),
	] as Array[UnlockConditionData]
	var cond_quest := _create_quest("cond_quest", "Cond Quest",
		[cond_step] as Array[QuestStepData])
	QuestManager._quests_by_id["cond_quest"] = cond_quest

	QuestManager.start_quest("cond_quest")
	EventManager.trigger_event("event_x")  # one of two satisfied
	assert_true(QuestManager.has_active_quest("cond_quest"),
		"quest should still be active (only 1/2 conditions met)")

	EventManager.trigger_event("event_y")  # both now satisfied
	# After event_y, _on_event_triggered re-evaluates, both conditions pass,
	# step advances (quest has 1 step total, so it completes and is removed).
	assert_false(QuestManager.has_active_quest("cond_quest"),
		"quest should no longer be active after all conditions met")

func test_condition_step_does_not_advance_while_partial() -> void:
	var cond_step := QuestStepData.new()
	cond_step.step_id = "cond_step"
	cond_step.completion_conditions = [
		_create_condition_event("event_x"),
		_create_condition_event("event_never"),
	] as Array[UnlockConditionData]
	var cond_quest := _create_quest("cond_quest", "Cond Quest",
		[cond_step] as Array[QuestStepData])
	QuestManager._quests_by_id["cond_quest"] = cond_quest

	QuestManager.start_quest("cond_quest")
	EventManager.trigger_event("event_x")
	assert_true(QuestManager.has_active_quest("cond_quest"),
		"quest should remain active since event_never never fired")
	assert_eq(QuestManager.get_current_step_index("cond_quest"), 0,
		"step should still be 0")
```

Note: these tests use the real `EventManager` (an autoload). `EventManager.trigger_event` persists to `PersistenceManager.save_game_data.event_progression`. Because `before_each` sets `QuestManager._live_save_data = _save_data` but does NOT reset `EventManager.live_save_data`, events fired in one test persist across tests. This is fine as long as each test uses **unique event ids** (`event_x`, `event_y`, `event_never`), but if a test is flaky, check for collisions.

- [ ] **Step 2: Run tests to verify failures**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: the 2 new tests fail because `_is_step_satisfied` returns `false` for the conditions path.

- [ ] **Step 3: Implement conditions evaluation**

Replace the conditions stub line in `_is_step_satisfied`:

```gdscript
func _is_step_satisfied(step: QuestStepData, triggering_event_id: String) -> bool:
	if not step.completion_event_id.is_empty():
		return step.completion_event_id == triggering_event_id
	if step.completion_conditions.is_empty():
		# No criteria at all — auto-advance (load-time validation logs an error).
		return true
	for cond: UnlockConditionData in step.completion_conditions:
		if not cond.evaluate():
			return false
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): advance step on UnlockConditionData evaluation"
```

---

## Task 7: Retroactive auto-complete on start_quest

TDD. When `start_quest` is called, walk forward through the quest's steps evaluating each against current state. Advance past any already-satisfied step. Stop at the first unsatisfied step (or the quest completes outright).

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append to `tests/unit/test_quest_manager.gd`:

```gdscript
# ----- retroactive auto-complete on start -----

func test_start_skips_past_already_satisfied_event_step() -> void:
	# Pre-fire the first step's event before starting the quest.
	EventManager.trigger_event("eel_dialogue_done")
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"start should skip past the pre-satisfied step")

func test_start_stops_at_first_unsatisfied_step() -> void:
	# quest_a has two steps: eel_dialogue_done, spring_forest_visited.
	# Only the first event has fired.
	EventManager.trigger_event("eel_dialogue_done")
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"should stop at step 1 (unfired spring_forest_visited)")
	assert_true(QuestManager.has_active_quest("quest_a"),
		"quest_a should still be active")

func test_start_completes_instantly_if_all_satisfied() -> void:
	EventManager.trigger_event("eel_dialogue_done")
	EventManager.trigger_event("spring_forest_visited")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_false(QuestManager.has_active_quest("quest_a"),
		"fully-satisfied quest should not remain active")
	# quest_started still fires (the quest WAS started, just instantly finished).
	assert_signal_emitted(QuestManager, "quest_started")
```

- [ ] **Step 2: Run tests to verify failures**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: 3 new tests fail (quest stays at step 0 after start).

- [ ] **Step 3: Add retroactive pass to `start_quest`**

Replace `start_quest` with:

```gdscript
func start_quest(quest_id: String) -> void:
	if not _live_save_data:
		return
	if not _quests_by_id.has(quest_id):
		push_error("QuestManager: unknown quest_id '%s'" % quest_id)
		return
	if has_active_quest(quest_id):
		return
	if has_completed_quest(quest_id):
		return
	_live_save_data.quest_progression.active_quests[quest_id] = 0
	Log.info("QuestManager: Started quest '%s'" % quest_id)
	quest_started.emit(quest_id)
	_retroactive_advance(quest_id)

## Walks a freshly-started quest forward through any already-satisfied steps.
## For event-based steps, checks `EventManager.has_event_triggered`. For
## condition-based steps, re-evaluates conditions. Stops at first unsatisfied
## step or when the quest completes.
func _retroactive_advance(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	while _live_save_data.quest_progression.active_quests.has(quest_id):
		var step_index: int = _live_save_data.quest_progression.active_quests[quest_id]
		if step_index >= quest.steps.size():
			break
		var step: QuestStepData = quest.steps[step_index]
		if not _is_step_retroactively_satisfied(step):
			break
		_advance_step(quest_id)

## Returns true if the step should be treated as already done at start time.
func _is_step_retroactively_satisfied(step: QuestStepData) -> bool:
	if not step.completion_event_id.is_empty():
		return EventManager != null and EventManager.has_event_triggered(step.completion_event_id)
	if step.completion_conditions.is_empty():
		return true
	for cond: UnlockConditionData in step.completion_conditions:
		if not cond.evaluate():
			return false
	return true
```

Note the split: `_is_step_satisfied` vs. `_is_step_retroactively_satisfied` exists because the runtime path needs the triggering event id, while the retroactive path consults `EventManager.has_event_triggered`.

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 15 tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): retroactive auto-complete on start_quest"
```

---

## Task 8: Quest completion — fire completion_effects and move to completed list

TDD. When the last step advances, `completion_effects` fire, the quest is removed from `active_quests`, appended to `completed_quest_ids`, and `quest_completed` emits.

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append to `tests/unit/test_quest_manager.gd`:

```gdscript
# ----- quest completion -----

## A simple effect that records when it was processed — lets us assert
## completion_effects fire in order.
class TestRecordingEffect extends EffectData:
	var processed: bool = false
	func process() -> void:
		processed = true
	func _to_string() -> String:
		return "TestRecordingEffect(processed=%s)" % processed

func test_final_step_advance_completes_quest() -> void:
	QuestManager.start_quest("quest_b")  # single step
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_false(QuestManager.has_active_quest("quest_b"),
		"quest_b should be removed from active after final step")
	assert_true(QuestManager.has_completed_quest("quest_b"),
		"quest_b should be in completed list")

func test_completion_fires_completion_effects() -> void:
	var effect := TestRecordingEffect.new()
	_quest_b.completion_effects = [effect] as Array[EffectData]
	QuestManager.start_quest("quest_b")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_true(effect.processed, "completion effect should have been processed")

func test_completion_emits_signal() -> void:
	QuestManager.start_quest("quest_b")
	watch_signals(QuestManager)
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_signal_emitted_with_parameters(QuestManager, "quest_completed", ["quest_b"])

func test_completion_preserves_insertion_order_in_completed_list() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager.start_quest("quest_b")
	# Complete quest_b first (it only has 1 step).
	QuestManager._on_event_triggered("eel_dialogue_done")
	# eel_dialogue_done also advanced quest_a to step 1. Complete quest_a by
	# firing spring_forest_visited.
	QuestManager._on_event_triggered("spring_forest_visited")
	var completed: Array[String] = QuestManager.get_completed_quest_ids()
	assert_eq(completed.size(), 2)
	assert_eq(completed[0], "quest_b", "quest_b completed first")
	assert_eq(completed[1], "quest_a", "quest_a completed second")
```

- [ ] **Step 2: Run tests to verify failures**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: 4 new tests fail. Quest is erased from active (from Task 5's placeholder) but no completion signal, no effects fired, no completed list entry.

- [ ] **Step 3: Implement completion in `_advance_step`**

Replace `_advance_step` with:

```gdscript
func _advance_step(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	var new_index: int = _live_save_data.quest_progression.active_quests[quest_id] + 1
	if new_index >= quest.steps.size():
		_complete_quest(quest_id)
		return
	_live_save_data.quest_progression.active_quests[quest_id] = new_index
	Log.info("QuestManager: Quest '%s' advanced to step %d" % [quest_id, new_index])
	quest_step_advanced.emit(quest_id, new_index)

func _complete_quest(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	_live_save_data.quest_progression.active_quests.erase(quest_id)
	_live_save_data.quest_progression.completed_quest_ids.append(quest_id)
	Log.info("QuestManager: Quest '%s' completed" % quest_id)
	for effect: EffectData in quest.completion_effects:
		if effect:
			effect.process()
	quest_completed.emit(quest_id)
```

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 19 tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): fire completion effects and track completed quests"
```

---

## Task 9: Edge cases — zero-step quest and unknown-quest guard on active list

TDD. Zero-step quest should complete instantly on start. Also cover: `start_quest` with an empty-id quest does not crash; quest whose `QuestData` was removed from catalog (loaded save references a deleted quest) is dropped on `_ready()`.

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append to `tests/unit/test_quest_manager.gd`:

```gdscript
# ----- edge cases -----

func test_zero_step_quest_completes_instantly_on_start() -> void:
	var empty_quest := _create_quest("empty_quest", "Empty Quest", [] as Array[QuestStepData])
	QuestManager._quests_by_id["empty_quest"] = empty_quest
	QuestManager.start_quest("empty_quest")
	assert_false(QuestManager.has_active_quest("empty_quest"),
		"zero-step quest should not remain active")
	assert_true(QuestManager.has_completed_quest("empty_quest"),
		"zero-step quest should be in completed list")

func test_zero_step_quest_fires_completion_effects() -> void:
	var effect := TestRecordingEffect.new()
	var empty_quest := _create_quest("empty_quest", "Empty Quest", [] as Array[QuestStepData])
	empty_quest.completion_effects = [effect] as Array[EffectData]
	QuestManager._quests_by_id["empty_quest"] = empty_quest
	QuestManager.start_quest("empty_quest")
	assert_true(effect.processed, "zero-step quest should still fire completion effects")

func test_load_drops_active_quest_with_deleted_data() -> void:
	# Simulate a save that references a quest no longer in the catalog.
	_save_data.quest_progression.active_quests["ghost_quest"] = 0
	QuestManager._prune_unknown_active_quests()
	assert_false(_save_data.quest_progression.active_quests.has("ghost_quest"),
		"unknown active quests should be pruned")
```

- [ ] **Step 2: Run tests to verify failures**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: zero-step tests fail because `start_quest` sets `active_quests[quest_id] = 0` and doesn't check for the empty-steps case; `_prune_unknown_active_quests` doesn't exist.

- [ ] **Step 3: Handle zero-step quests in `start_quest`**

Insert after the `quest_started.emit(quest_id)` line in `start_quest`:

```gdscript
	# Zero-step quests complete immediately. Retroactive advance would also
	# catch this, but handle it explicitly for clarity.
	if quest.steps.is_empty():
		_complete_quest(quest_id)
		return
	_retroactive_advance(quest_id)
```

To reference `quest`, declare it at the top of the function. Final `start_quest`:

```gdscript
func start_quest(quest_id: String) -> void:
	if not _live_save_data:
		return
	if not _quests_by_id.has(quest_id):
		push_error("QuestManager: unknown quest_id '%s'" % quest_id)
		return
	if has_active_quest(quest_id):
		return
	if has_completed_quest(quest_id):
		return
	var quest: QuestData = _quests_by_id[quest_id]
	_live_save_data.quest_progression.active_quests[quest_id] = 0
	Log.info("QuestManager: Started quest '%s'" % quest_id)
	quest_started.emit(quest_id)
	if quest.steps.is_empty():
		_complete_quest(quest_id)
		return
	_retroactive_advance(quest_id)
```

- [ ] **Step 4: Add `_prune_unknown_active_quests` and call on ready**

Add this function near the bottom of the script:

```gdscript
## Removes any active quests whose QuestData is no longer in the catalog.
## Called on _ready and on save_data_reset to keep state consistent with the
## current resource definitions.
func _prune_unknown_active_quests() -> void:
	if not _live_save_data:
		return
	var to_remove: Array[String] = []
	for quest_id: String in _live_save_data.quest_progression.active_quests.keys():
		if not _quests_by_id.has(quest_id):
			Log.warn("QuestManager: dropping active quest '%s' (no QuestData in catalog)" % quest_id)
			to_remove.append(quest_id)
	for quest_id: String in to_remove:
		_live_save_data.quest_progression.active_quests.erase(quest_id)
```

Update `_ready()` to call it after save data is wired:

```gdscript
func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("QuestManager: Could not get save_game_data from PersistenceManager on ready!")
	if EventManager:
		EventManager.event_triggered.connect(_on_event_triggered)
	else:
		Log.critical("QuestManager: EventManager not available on ready!")
	_prune_unknown_active_quests()
```

Update `_on_save_data_reset()`:

```gdscript
func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
	_prune_unknown_active_quests()
```

- [ ] **Step 5: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 22 tests pass.

- [ ] **Step 6: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): handle zero-step quests and prune unknown save entries"
```

---

## Task 10: Load-time validation for malformed steps

TDD. A step with BOTH `completion_event_id` and `completion_conditions` set, or NEITHER set, is a data authoring error. Log an error at catalog-load time. Runtime already handles both cases gracefully (prefers event / auto-advances), per the spec.

**Files:**
- Modify: `tests/unit/test_quest_manager.gd`
- Modify: `singletons/quest_manager/quest_manager.gd`

- [ ] **Step 1: Add tests**

Append:

```gdscript
# ----- load-time validation -----

func test_step_with_both_event_and_conditions_pushes_error() -> void:
	var bad_step := QuestStepData.new()
	bad_step.step_id = "bad"
	bad_step.completion_event_id = "some_event"
	bad_step.completion_conditions = [_create_condition_event("other")] as Array[UnlockConditionData]
	var bad_quest := _create_quest("bad_quest", "Bad Quest", [bad_step] as Array[QuestStepData])
	QuestManager._quest_catalog = QuestList.new()
	QuestManager._quest_catalog.quests = [bad_quest] as Array[QuestData]
	QuestManager._build_catalog_index()
	QuestManager._validate_catalog()
	assert_push_error("has both completion_event_id and completion_conditions")

func test_step_with_neither_event_nor_conditions_pushes_error() -> void:
	var bad_step := QuestStepData.new()
	bad_step.step_id = "bad"
	# Neither completion_event_id nor completion_conditions set.
	var bad_quest := _create_quest("bad_quest2", "Bad Quest 2", [bad_step] as Array[QuestStepData])
	QuestManager._quest_catalog = QuestList.new()
	QuestManager._quest_catalog.quests = [bad_quest] as Array[QuestData]
	QuestManager._build_catalog_index()
	QuestManager._validate_catalog()
	assert_push_error("has no completion criteria")
```

- [ ] **Step 2: Run tests to verify failures**

Expected: `_validate_catalog` method not defined.

- [ ] **Step 3: Implement `_validate_catalog`**

Add:

```gdscript
## Validates the catalog for authoring errors. Called from _ready(). Does not
## modify state; only logs errors so the developer sees them in the console.
func _validate_catalog() -> void:
	for quest: QuestData in _quest_catalog.quests:
		if quest == null or quest.quest_id.is_empty():
			continue
		for i: int in quest.steps.size():
			var step: QuestStepData = quest.steps[i]
			if step == null:
				push_error("QuestManager: quest '%s' step %d is null" % [quest.quest_id, i])
				continue
			var has_event: bool = not step.completion_event_id.is_empty()
			var has_conditions: bool = not step.completion_conditions.is_empty()
			if has_event and has_conditions:
				push_error("QuestManager: quest '%s' step '%s' has both completion_event_id and completion_conditions — event will take precedence" % [quest.quest_id, step.step_id])
			elif not has_event and not has_conditions:
				push_error("QuestManager: quest '%s' step '%s' has no completion criteria — will auto-advance" % [quest.quest_id, step.step_id])
```

Call it from `_ready()` after `_build_catalog_index()`:

```gdscript
	_build_catalog_index()
	_validate_catalog()
```

- [ ] **Step 4: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: all 24 tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_quest_manager.gd singletons/quest_manager/quest_manager.gd
git commit -m "feat(quests): validate catalog at load for malformed steps"
```

---

## Task 11: StartQuestEffectData and EffectType enum entry

TDD. A new `EffectData` subclass. Its `process()` calls `QuestManager.start_quest(quest_id)`.

**Files:**
- Modify: `scripts/resource_definitions/effects/effect_data.gd`
- Create: `scripts/resource_definitions/effects/start_quest_effect_data.gd`
- Create: `tests/unit/test_start_quest_effect_data.gd`

- [ ] **Step 1: Add `START_QUEST` to the enum**

Open `scripts/resource_definitions/effects/effect_data.gd`. Change the enum:

```gdscript
enum EffectType {
	NONE,
	TRIGGER_EVENT,
	AWARD_RESOURCE,
	AWARD_ITEM,
	AWARD_LOOT_TABLE,
	START_QUEST,
}
```

Add trailing so no existing enum int shifts.

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_start_quest_effect_data.gd`:

```gdscript
extends GutTest

var _save_data: SaveGameData
var _test_quest: QuestData

func before_each() -> void:
	_save_data = SaveGameData.new()
	var step := QuestStepData.new()
	step.step_id = "s1"
	step.completion_event_id = "test_event"
	_test_quest = QuestData.new()
	_test_quest.quest_id = "test_quest"
	_test_quest.quest_name = "Test Quest"
	_test_quest.steps = [step] as Array[QuestStepData]
	QuestManager._live_save_data = _save_data
	QuestManager._quests_by_id = {"test_quest": _test_quest}

func after_each() -> void:
	QuestManager._live_save_data = null
	QuestManager._quests_by_id = {}

func test_process_starts_the_quest() -> void:
	var effect := StartQuestEffectData.new()
	effect.quest_id = "test_quest"
	effect.process()
	assert_true(QuestManager.has_active_quest("test_quest"),
		"process() should call QuestManager.start_quest and add to active list")

func test_process_with_empty_quest_id_pushes_error() -> void:
	var effect := StartQuestEffectData.new()
	effect.quest_id = ""
	effect.process()
	assert_push_error("empty quest_id")
```

- [ ] **Step 3: Run tests to verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_start_quest_effect_data.gd -gexit
```

Expected: fails with `StartQuestEffectData` class not found.

- [ ] **Step 4: Create `start_quest_effect_data.gd`**

```gdscript
class_name StartQuestEffectData
extends EffectData

@export var quest_id: String = ""


func _to_string() -> String:
	return "StartQuestEffectData { quest_id: %s }" % quest_id


func process() -> void:
	if quest_id.is_empty():
		push_error("StartQuestEffectData: empty quest_id")
		return
	if QuestManager == null:
		Log.error("StartQuestEffectData: QuestManager not available")
		return
	Log.info("StartQuestEffectData: Starting quest '%s'" % quest_id)
	QuestManager.start_quest(quest_id)
```

- [ ] **Step 5: Run tests to verify they pass**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_start_quest_effect_data.gd -gexit
```

Expected: both tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/effects/effect_data.gd scripts/resource_definitions/effects/start_quest_effect_data.gd tests/unit/test_start_quest_effect_data.gd
git commit -m "feat(quests): add StartQuestEffectData and START_QUEST effect type"
```

---

## Task 12: Save/load round-trip integration test

TDD. Verify `QuestProgressionData` survives serialization through `ResourceSaver.save` + `ResourceLoader.load`. This is an integration test for the persistence layer, not a QuestManager behavior test.

**Files:**
- Create: `tests/unit/test_quest_progression_persistence.gd`

- [ ] **Step 1: Write the tests**

```gdscript
extends GutTest

const TMP_PATH: String = "user://test_quest_progression.tres"

func after_each() -> void:
	if ResourceLoader.exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

func test_active_quests_round_trip() -> void:
	var data := SaveGameData.new()
	data.quest_progression.active_quests["quest_a"] = 2
	data.quest_progression.active_quests["quest_b"] = 0
	ResourceSaver.save(data, TMP_PATH)

	var loaded: SaveGameData = ResourceLoader.load(TMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.quest_progression.active_quests.get("quest_a", -1), 2)
	assert_eq(loaded.quest_progression.active_quests.get("quest_b", -1), 0)

func test_completed_quests_round_trip() -> void:
	var data := SaveGameData.new()
	data.quest_progression.completed_quest_ids = ["quest_x", "quest_y"]
	ResourceSaver.save(data, TMP_PATH)

	var loaded: SaveGameData = ResourceLoader.load(TMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.quest_progression.completed_quest_ids.size(), 2)
	assert_eq(loaded.quest_progression.completed_quest_ids[0], "quest_x")
	assert_eq(loaded.quest_progression.completed_quest_ids[1], "quest_y")

func test_reset_clears_quest_progression() -> void:
	var data := SaveGameData.new()
	data.quest_progression.active_quests["quest_a"] = 5
	data.quest_progression.completed_quest_ids = ["quest_x"]
	data.reset()
	assert_eq(data.quest_progression.active_quests.size(), 0,
		"reset should empty active_quests")
	assert_eq(data.quest_progression.completed_quest_ids.size(), 0,
		"reset should empty completed_quest_ids")
```

- [ ] **Step 2: Run tests**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_progression_persistence.gd -gexit
```

Expected: all 3 tests pass (no production code change needed — tasks 1 and 2 already wired this up).

If the round-trip fails because typed `Dictionary[String, int]` doesn't serialize cleanly in Godot 4.6, fall back to `Dictionary` (untyped) in `QuestProgressionData` and reapply the type in a new commit. Document the change inline in the file.

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_quest_progression_persistence.gd
git commit -m "test(quests): verify QuestProgressionData save/load round-trip"
```

---

## Task 13: Remove QUEST_GIVER from ZoneActionData.ActionType and clean references

Not TDD — this is a pure cleanup. Verify no `.tres` file uses `action_type = 7` (the QUEST_GIVER int value) before proceeding.

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd`
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd`
- Modify: `docs/zones/ZONES.md`

- [ ] **Step 1: Verify no `.tres` references action_type = 7**

Run a grep:

```
grep -r "action_type = 7" resources/
```

Expected: no matches. If any appear, investigate and either remap or delete before continuing. (Spec already verified none at design time, but re-verify after any new resources added.)

- [ ] **Step 2: Remove `QUEST_GIVER` from the enum**

In `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd`, change:

```gdscript
enum ActionType {
	FORAGE,
	ADVENTURE,
	NPC_DIALOGUE,
	MERCHANT,
	TRAIN_STATS,
	CYCLING,
	ZONE_EVENT,  # Story/scripted events
	QUEST_GIVER
}
```

to:

```gdscript
enum ActionType {
	FORAGE,
	ADVENTURE,
	NPC_DIALOGUE,
	MERCHANT,
	TRAIN_STATS,
	CYCLING,
	ZONE_EVENT,  # Story/scripted events
}
```

- [ ] **Step 3: Update the comment in `zone_action_button.gd` (lines 13-15)**

Change:

```gdscript
## Maps active ActionTypes to their category color. Unmapped types (MERCHANT,
## TRAIN_STATS, ZONE_EVENT, QUEST_GIVER) fall back to DEFAULT_CATEGORY_COLOR
## since they have no zone action buttons yet.
```

to:

```gdscript
## Maps active ActionTypes to their category color. Unmapped types (MERCHANT,
## TRAIN_STATS, ZONE_EVENT) fall back to DEFAULT_CATEGORY_COLOR since they have
## no zone action buttons yet.
```

- [ ] **Step 4: Update `docs/zones/ZONES.md`**

Open the file and remove the two `QUEST_GIVER` references:
- Row in the action-type handler table (around line 157): `| `QUEST_GIVER` | No | No handler |`
- Bullet in the Missing Functionality section (around line 277): remove `QUEST_GIVER` from the list of types with no handler. The bullet currently reads:
  ```
  - `[MEDIUM]` MERCHANT, TRAIN_STATS, ZONE_EVENT, QUEST_GIVER action types have no handler in ActionManager — selecting these actions does nothing
  ```
  Change to:
  ```
  - `[MEDIUM]` MERCHANT, TRAIN_STATS, ZONE_EVENT action types have no handler in ActionManager — selecting these actions does nothing
  ```

- [ ] **Step 5: Verify project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: no errors. If anything references `ZoneActionData.ActionType.QUEST_GIVER` (grep to double-check), it will now fail.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd scenes/zones/zone_action_button/zone_action_button.gd docs/zones/ZONES.md
git commit -m "chore(zones): remove unused QUEST_GIVER action type"
```

---

## Task 14: Run full test suite and final verification

- [ ] **Step 1: Run the full suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all pre-existing tests still pass, plus:
- `test_quest_manager.gd`: 24 tests pass
- `test_start_quest_effect_data.gd`: 2 tests pass
- `test_quest_progression_persistence.gd`: 3 tests pass

Total new tests: 29.

If any pre-existing test regresses, the most likely cause is the `SaveGameData._to_string()` edit in Task 2 — verify format string and arg array match in length.

- [ ] **Step 2: Manually verify autoload registration**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Check the log for `QuestManager` errors. Expected: none.

- [ ] **Step 3: Final commit — if needed**

If the full-suite run uncovers any issue and fixes are needed, commit them as:
```bash
git commit -m "fix(quests): <specific issue>"
```

Otherwise, Pass 1 is complete.

---

## Pass 1 summary

On completion:
- 7 new production files (3 resource classes, 1 catalog, 1 progression data, 1 manager, 1 effect data)
- 1 new catalog `.tres` (empty, populated in later content work)
- 3 new test files with 29 tests
- 6 modified files (effect enum, save data, project.godot, zone action enum + two cleanup refs)
- `QuestManager` fully functional headless — start quest, advance step on event or conditions, retroactive auto-complete, fire completion effects, track completed list, save/load
- Ready for Pass 2 (UI: `QuestWindow`, `QuestToast`, badge)
