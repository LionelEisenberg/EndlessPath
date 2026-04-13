# Cycling Technique Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a CyclingManager singleton that makes path progression technique unlocks functional end-to-end — from path node purchase to cycling view display.

**Architecture:** New CyclingManager singleton owns all cycling technique state (unlocked list + equipped technique), persisted via SaveGameData string IDs. PathManager calls CyclingManager.unlock_technique() on node purchase. CyclingView queries CyclingManager instead of a static list.

**Tech Stack:** Godot 4.6, GDScript, GUT 9.6.0 for tests

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd` | Modify | Add `id: String` field |
| `resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres` | Modify | Add `id = "foundation_technique"` |
| `resources/cycling/cycling_techniques/test_foundation_cycling_technique/test_foundation_cycling_technique.tres` | Modify | Add `id = "test_foundation_technique"` |
| `resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres` | Modify | Add `id = "smooth_flow"` |
| `singletons/persistence_manager/save_game_data.gd` | Modify | Add `unlocked_cycling_technique_ids`, rename `current_cycling_technique_name` to `equipped_cycling_technique_id` |
| `singletons/cycling_manager/cycling_manager.gd` | Create | CyclingManager singleton |
| `tests/unit/test_cycling_manager.gd` | Create | Unit tests for CyclingManager |
| `project.godot` | Modify | Register CyclingManager autoload |
| `singletons/path_manager/path_manager.gd` | Modify | Call CyclingManager.unlock_technique() in purchase_node |
| `scenes/cycling/cycling_view/cycling_view.gd` | Modify | Query CyclingManager instead of static list |
| `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd` | Modify | Accept Array[CyclingTechniqueData] instead of CyclingTechniqueList |

---

### Task 1: Add `id` field to CyclingTechniqueData and update technique resources

**Files:**
- Modify: `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`
- Modify: `resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres`
- Modify: `resources/cycling/cycling_techniques/test_foundation_cycling_technique/test_foundation_cycling_technique.tres`
- Modify: `resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres`

- [ ] **Step 1: Add `id` field to CyclingTechniqueData**

In `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`, add the `id` field as the first export, before `technique_name`:

```gdscript
class_name CyclingTechniqueData
extends Resource

@export var id: String = ""
@export var technique_name: String = "Basic Cycling"
@export var path_curve: Curve2D  # The path shape
@export var cycle_duration: float = 10.0 # Seconds for one complete cycle (Replaced cycle_speed)
@export var base_madra_per_cycle: float = 25.0  # Base madra awarded per cycle (scaled by mouse tracking accuracy)

# --- This is the key change ---
# Now it exports an Array OF CyclingZoneData resources.
# This makes it editable in the Inspector!
@export var cycling_zones: Array[CyclingZoneData] = []
```

- [ ] **Step 2: Add `id` to foundation_cycling_technique.tres**

In `resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres`, add `id = "foundation_technique"` to the `[resource]` section, before `technique_name`:

```
[resource]
script = ExtResource("6_anl3h")
id = "foundation_technique"
technique_name = "Foundation Technique"
```

- [ ] **Step 3: Add `id` to test_foundation_cycling_technique.tres**

In `resources/cycling/cycling_techniques/test_foundation_cycling_technique/test_foundation_cycling_technique.tres`, add `id = "test_foundation_technique"` to the `[resource]` section, before `technique_name`:

```
[resource]
script = ExtResource("6_anl3h")
id = "test_foundation_technique"
technique_name = "Test Foundation Technique"
```

- [ ] **Step 4: Add `id` to smooth_flow.tres**

In `resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres`, add `id = "smooth_flow"` to the `[resource]` section, before `technique_name`:

```
[resource]
script = ExtResource("7_cbmp4")
id = "smooth_flow"
technique_name = "Smooth Flow Technique"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd \
  resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres \
  resources/cycling/cycling_techniques/test_foundation_cycling_technique/test_foundation_cycling_technique.tres \
  resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres
git commit -m "feat(cycling): add id field to CyclingTechniqueData and populate technique resources"
```

---

### Task 2: Update SaveGameData

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd`

- [ ] **Step 1: Add `unlocked_cycling_technique_ids` field and rename equipped field**

In `singletons/persistence_manager/save_game_data.gd`, replace the `CURRENT STATE` section:

```gdscript
#-----------------------------------------------------------------------------
# CYCLING MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_cycling_technique_ids: Array[String] = ["foundation_technique"]
@export var equipped_cycling_technique_id: String = "foundation_technique"
```

This replaces the old `current_cycling_technique_name` field. The section header changes from `CURRENT STATE` to `CYCLING MANAGER` to match the manager ownership pattern.

- [ ] **Step 2: Update `_to_string()` method**

In the `_to_string()` method, replace the `CurrentCyclingTechnique` format line. Change:

```gdscript
			current_cycling_technique_name,
```

to:

```gdscript
			str(unlocked_cycling_technique_ids),
			equipped_cycling_technique_id,
```

And update the format string to replace `CurrentCyclingTechnique: %s` with `UnlockedCyclingTechniques: %s\n  EquippedCyclingTechniqueId: %s`.

- [ ] **Step 3: Update `reset()` method**

In the `reset()` method, replace:

```gdscript
	# Current State
	current_cycling_technique_name = "Foundation Technique"
```

with:

```gdscript
	# Cycling Manager
	unlocked_cycling_technique_ids = ["foundation_technique"]
	equipped_cycling_technique_id = "foundation_technique"
```

- [ ] **Step 4: Commit**

```bash
git add singletons/persistence_manager/save_game_data.gd
git commit -m "feat(cycling): add unlocked_cycling_technique_ids and rename equipped field in SaveGameData"
```

---

### Task 3: Create CyclingManager singleton with tests (TDD)

**Files:**
- Create: `singletons/cycling_manager/cycling_manager.gd`
- Create: `tests/unit/test_cycling_manager.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Create minimal CyclingManager stub**

Create `singletons/cycling_manager/cycling_manager.gd` with just enough to register:

```gdscript
extends Node

## Manages cycling technique state — which techniques are unlocked and equipped.
## Authoritative owner of all cycling technique data.
```

- [ ] **Step 2: Register CyclingManager autoload in project.godot**

In `project.godot`, in the `[autoload]` section, add CyclingManager after `LogManager` and before `PathManager` (PathManager will call CyclingManager, so CyclingManager must init first):

```
LogManager="*res://singletons/log_manager/log_manager.gd"
CyclingManager="*res://singletons/cycling_manager/cycling_manager.gd"
PathManager="*res://singletons/path_manager/path_manager.gd"
```

- [ ] **Step 3: Write failing tests**

Create `tests/unit/test_cycling_manager.gd`:

```gdscript
extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _technique_a: CyclingTechniqueData
var _technique_b: CyclingTechniqueData
var _foundation: CyclingTechniqueData

func _create_test_technique(technique_id: String, technique_name: String) -> CyclingTechniqueData:
	var t := CyclingTechniqueData.new()
	t.id = technique_id
	t.technique_name = technique_name
	return t

func before_each() -> void:
	_save_data = SaveGameData.new()
	_foundation = _create_test_technique("foundation_technique", "Foundation Technique")
	_technique_a = _create_test_technique("tech_a", "Technique A")
	_technique_b = _create_test_technique("tech_b", "Technique B")
	CyclingManager._live_save_data = _save_data
	CyclingManager._techniques_by_id = {
		"foundation_technique": _foundation,
		"tech_a": _technique_a,
		"tech_b": _technique_b,
	}

# ----- Default state -----

func test_default_save_has_foundation_unlocked() -> void:
	assert_true(CyclingManager.is_technique_unlocked("foundation_technique"),
		"foundation_technique should be unlocked by default")

func test_default_equipped_is_foundation() -> void:
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	assert_not_null(equipped, "should have an equipped technique by default")
	assert_eq(equipped.id, "foundation_technique", "default equipped should be foundation")

# ----- get_unlocked_techniques -----

func test_get_unlocked_techniques_returns_matching_resources() -> void:
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked technique by default")
	assert_eq(unlocked[0].id, "foundation_technique", "should be foundation")

func test_get_unlocked_techniques_skips_unknown_ids() -> void:
	_save_data.unlocked_cycling_technique_ids.append("nonexistent_technique")
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 1, "should skip IDs not in catalog")

# ----- unlock_technique -----

func test_unlock_technique_adds_to_list() -> void:
	CyclingManager.unlock_technique("tech_a")
	assert_true(CyclingManager.is_technique_unlocked("tech_a"), "tech_a should be unlocked")
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 2, "should now have 2 unlocked techniques")

func test_unlock_technique_is_idempotent() -> void:
	CyclingManager.unlock_technique("tech_a")
	CyclingManager.unlock_technique("tech_a")
	var count: int = _save_data.unlocked_cycling_technique_ids.count("tech_a")
	assert_eq(count, 1, "should not duplicate technique in save data")

func test_unlock_technique_emits_signal() -> void:
	watch_signals(CyclingManager)
	CyclingManager.unlock_technique("tech_a")
	assert_signal_emitted_with_parameters(CyclingManager, "technique_unlocked", [_technique_a])

func test_unlock_technique_unknown_id_pushes_error() -> void:
	CyclingManager.unlock_technique("nonexistent")
	assert_push_error("unknown technique_id")

func test_unlock_already_unlocked_does_not_emit_signal() -> void:
	watch_signals(CyclingManager)
	CyclingManager.unlock_technique("foundation_technique")
	assert_signal_not_emitted(CyclingManager, "technique_unlocked")

# ----- equip_technique -----

func test_equip_technique_changes_equipped() -> void:
	CyclingManager.equip_technique("tech_a")
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	assert_eq(equipped.id, "tech_a", "equipped should be tech_a")

func test_equip_technique_updates_save_data() -> void:
	CyclingManager.equip_technique("tech_a")
	assert_eq(_save_data.equipped_cycling_technique_id, "tech_a",
		"save data should store the equipped technique id")

func test_equip_technique_emits_signal() -> void:
	watch_signals(CyclingManager)
	CyclingManager.equip_technique("tech_a")
	assert_signal_emitted_with_parameters(CyclingManager, "equipped_technique_changed", [_technique_a])

func test_equip_technique_unknown_id_pushes_error() -> void:
	CyclingManager.equip_technique("nonexistent")
	assert_push_error("unknown technique_id")

# ----- is_technique_unlocked -----

func test_is_technique_unlocked_true_for_unlocked() -> void:
	assert_true(CyclingManager.is_technique_unlocked("foundation_technique"))

func test_is_technique_unlocked_false_for_locked() -> void:
	assert_false(CyclingManager.is_technique_unlocked("tech_a"))
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_cycling_manager.gd -gexit`

Expected: FAIL — CyclingManager has no methods yet.

- [ ] **Step 5: Implement CyclingManager**

Replace `singletons/cycling_manager/cycling_manager.gd` with the full implementation:

```gdscript
extends Node

## Manages cycling technique state — which techniques are unlocked and equipped.
## Authoritative owner of all cycling technique data.

signal technique_unlocked(technique: CyclingTechniqueData)
signal equipped_technique_changed(technique: CyclingTechniqueData)

var _live_save_data: SaveGameData = null
var _technique_catalog: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var _techniques_by_id: Dictionary = {}  # String -> CyclingTechniqueData

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)

# ----- Public API -----

## Returns full resource data for all unlocked technique IDs.
func get_unlocked_techniques() -> Array[CyclingTechniqueData]:
	var result: Array[CyclingTechniqueData] = []
	if not _live_save_data:
		return result
	for technique_id: String in _live_save_data.unlocked_cycling_technique_ids:
		if _techniques_by_id.has(technique_id):
			result.append(_techniques_by_id[technique_id])
	return result

## Returns the currently equipped technique, or null if none.
func get_equipped_technique() -> CyclingTechniqueData:
	if not _live_save_data:
		return null
	return _techniques_by_id.get(_live_save_data.equipped_cycling_technique_id, null)

## Unlocks a cycling technique by ID. Idempotent — skips if already unlocked.
func unlock_technique(technique_id: String) -> void:
	if not _live_save_data:
		return
	if technique_id in _live_save_data.unlocked_cycling_technique_ids:
		return
	if not _techniques_by_id.has(technique_id):
		push_error("CyclingManager: unknown technique_id '%s'" % technique_id)
		return
	_live_save_data.unlocked_cycling_technique_ids.append(technique_id)
	technique_unlocked.emit(_techniques_by_id[technique_id])

## Sets the equipped technique by ID.
func equip_technique(technique_id: String) -> void:
	if not _live_save_data:
		return
	if not _techniques_by_id.has(technique_id):
		push_error("CyclingManager: unknown technique_id '%s'" % technique_id)
		return
	_live_save_data.equipped_cycling_technique_id = technique_id
	equipped_technique_changed.emit(_techniques_by_id[technique_id])

## Returns true if the technique is currently unlocked.
func is_technique_unlocked(technique_id: String) -> bool:
	if not _live_save_data:
		return false
	return technique_id in _live_save_data.unlocked_cycling_technique_ids

# ----- Private -----

func _build_catalog_index() -> void:
	_techniques_by_id.clear()
	for technique: CyclingTechniqueData in _technique_catalog.cycling_techniques:
		if technique and not technique.id.is_empty():
			_techniques_by_id[technique.id] = technique

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_cycling_manager.gd -gexit`

Expected: All 15 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add singletons/cycling_manager/cycling_manager.gd \
  tests/unit/test_cycling_manager.gd \
  project.godot
git commit -m "feat(cycling): create CyclingManager singleton with tests"
```

---

### Task 4: Wire PathManager to call CyclingManager on node purchase

**Files:**
- Modify: `singletons/path_manager/path_manager.gd`

- [ ] **Step 1: Add CyclingManager call in purchase_node**

In `singletons/path_manager/path_manager.gd`, modify the `purchase_node` method. After the `_recalculate_effects()` call (line 101), add a loop that calls CyclingManager for any cycling technique effects on the purchased node. The full method becomes:

```gdscript
## Attempts to purchase a node. Returns true on success.
func purchase_node(node_id: String) -> bool:
	if not can_purchase_node(node_id):
		return false
	var node: PathNodeData = _current_tree.get_node_by_id(node_id)
	_live_save_data.path_points -= node.point_cost
	var new_level: int = get_node_purchase_count(node_id) + 1
	_live_save_data.path_node_purchases[node_id] = new_level
	_recalculate_effects()
	points_changed.emit(_live_save_data.path_points)
	node_purchased.emit(node_id, new_level)
	# Apply cycling technique unlocks
	if CyclingManager:
		for effect: PathNodeEffectData in node.effects:
			if effect.effect_type == PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
				CyclingManager.unlock_technique(effect.string_value)
	return true
```

The key addition is the `if CyclingManager:` block after the existing signals. This iterates the purchased node's effects and calls `CyclingManager.unlock_technique()` for any `UNLOCK_CYCLING_TECHNIQUE` effects. The `if CyclingManager:` guard handles test environments where CyclingManager may not be loaded.

- [ ] **Step 2: Run existing PathManager tests to verify nothing broke**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_path_manager.gd -gexit`

Expected: All 21 existing PathManager tests PASS.

- [ ] **Step 3: Commit**

```bash
git add singletons/path_manager/path_manager.gd
git commit -m "feat(cycling): wire PathManager to call CyclingManager.unlock_technique on node purchase"
```

---

### Task 5: Refactor CyclingView to use CyclingManager

**Files:**
- Modify: `scenes/cycling/cycling_view/cycling_view.gd`
- Modify: `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd`

- [ ] **Step 1: Update CyclingTabPanel.setup to accept Array[CyclingTechniqueData]**

In `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd`, change the `setup` method signature and the internal storage. Replace the `STATE` section and `setup`/`_populate_technique_list` methods:

Change the state variable from:

```gdscript
var _technique_list: CyclingTechniqueList = null
```

to:

```gdscript
var _techniques: Array[CyclingTechniqueData] = []
```

Change the `setup` method from:

```gdscript
## Initialize with technique list data.
func setup(technique_list: CyclingTechniqueList) -> void:
	_technique_list = technique_list
	_populate_technique_list()
```

to:

```gdscript
## Initialize with unlocked technique data.
func setup(techniques: Array[CyclingTechniqueData]) -> void:
	_techniques = techniques
	_populate_technique_list()
```

Change `_populate_technique_list` from iterating `_technique_list.cycling_techniques` to iterating `_techniques`:

```gdscript
func _populate_technique_list() -> void:
	if _techniques.is_empty():
		return

	_list_dirty = false

	for child in _technique_list_container.get_children():
		child.queue_free()

	for technique_data: CyclingTechniqueData in _techniques:
		var slot: Control = _technique_slot_scene.instantiate()
		_technique_list_container.add_child(slot)
		slot.setup(technique_data)
		slot.set_equipped(_current_technique_data == technique_data)
		slot.slot_selected.connect(_on_technique_slot_selected)
```

Change the tab_changed handler's null check from `_technique_list == null` to `_techniques.is_empty()`:

```gdscript
func _on_tab_changed(tab_index: int) -> void:
	if tab_index == 1 and _list_dirty:
		_populate_technique_list()
```

- [ ] **Step 2: Refactor CyclingView to use CyclingManager**

In `scenes/cycling/cycling_view/cycling_view.gd`, replace the static technique list loading and save/load with CyclingManager queries.

Remove these state variables:

```gdscript
var technique_list: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var foundation_technique: CyclingTechniqueData = technique_list.cycling_techniques[0]
```

In `_ready()`, replace the tab panel setup and saved technique loading. Change:

```gdscript
	# Tab panel technique change
	cycling_tab_panel.technique_change_request.connect(_on_technique_change_request)
	cycling_tab_panel.setup(technique_list)
```

to:

```gdscript
	# Tab panel technique change
	cycling_tab_panel.technique_change_request.connect(_on_technique_change_request)
	_refresh_technique_list()

	# Listen for new technique unlocks
	CyclingManager.technique_unlocked.connect(_on_technique_unlocked)
```

Replace the `_load_saved_technique` call at the end of `_ready()`:

```gdscript
	# Load saved technique
	_load_saved_technique()
```

with:

```gdscript
	# Load equipped technique from CyclingManager
	_load_equipped_technique()
```

Replace the `set_current_technique` method:

```gdscript
## Sets the current technique.
func set_current_technique(technique_data: CyclingTechniqueData) -> void:
	current_cycling_technique_data = technique_data
	current_technique_changed.emit(technique_data)
	CyclingManager.equip_technique(technique_data.id)
```

Replace `_on_technique_change_request` — no change needed to this method, it already calls `set_current_technique`.

Replace `_load_saved_technique` with:

```gdscript
func _load_equipped_technique() -> void:
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	if equipped:
		current_cycling_technique_data = equipped
		current_technique_changed.emit(equipped)
	else:
		# Fallback: equip first unlocked technique
		var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
		if not unlocked.is_empty():
			set_current_technique(unlocked[0])
```

Remove the `_save_current_technique` method entirely — CyclingManager handles persistence via `equip_technique`.

Add the new private methods:

```gdscript
func _refresh_technique_list() -> void:
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	cycling_tab_panel.setup(unlocked)

func _on_technique_unlocked(_technique: CyclingTechniqueData) -> void:
	_refresh_technique_list()
```

- [ ] **Step 3: Commit**

```bash
git add scenes/cycling/cycling_view/cycling_view.gd \
  scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd
git commit -m "feat(cycling): refactor CyclingView and CyclingTabPanel to use CyclingManager"
```

---

### Task 6: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass, including:
- All 15 CyclingManager tests
- All 21 PathManager tests
- Any other existing tests

- [ ] **Step 2: Fix any failures**

If tests fail, read the error output and fix. Common issues:
- Old references to `current_cycling_technique_name` in other files — grep and update
- Autoload order issues — CyclingManager must load before PathManager in project.godot

- [ ] **Step 3: Final commit if fixes were needed**

```bash
git add -A  # only if fixes were made
git commit -m "fix(cycling): resolve test failures from cycling technique unlock integration"
```
