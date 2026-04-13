# Ability System Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance AbilityData with Madra type and source tracking, create AbilityManager singleton for unlock/equip state, wire PathManager unlocks, replace hardcoded combat abilities, and build a dedicated AbilitiesView UI.

**Architecture:** AbilityManager follows the CyclingManager pattern — preloaded catalog resource, ID-indexed dictionary, state in SaveGameData, signals for UI reactivity. AbilitiesView is a new MainViewState overlay with equipped sidebar, expandable ability cards, and filter/sort bar.

**Tech Stack:** Godot 4.5, GDScript, GUT 9.6.0 for testing

**Spec:** `docs/superpowers/specs/2026-04-12-ability-system-redesign.md`

---

## File Structure

### New Files

| File | Purpose |
|------|---------|
| `scripts/resource_definitions/abilities/ability_list_data.gd` | Catalog resource class (Array of AbilityData) |
| `resources/abilities/ability_list.tres` | Catalog instance referencing all ability .tres files |
| `singletons/ability_manager/ability_manager.gd` | AbilityManager singleton — unlock, equip, catalog lookups |
| `tests/unit/test_ability_manager.gd` | AbilityManager unit tests |
| `scenes/abilities/abilities_view_state.gd` | MainViewState subclass for abilities overlay |
| `scenes/abilities/abilities_view.gd` | AbilitiesView scene script — filter, sort, card management |
| `scenes/abilities/abilities_view.tscn` | AbilitiesView scene — layout, sidebar, filter bar, card list |
| `scenes/abilities/ability_card/ability_card.gd` | Expandable ability card component script |
| `scenes/abilities/ability_card/ability_card.tscn` | Ability card scene — collapsed row + expandable details |

### Modified Files

| File | Change |
|------|--------|
| `scripts/resource_definitions/abilities/ability_data.gd` | Add MadraType, AbilitySource enums + properties |
| `singletons/persistence_manager/save_game_data.gd` | Add ability manager section (unlocked/equipped IDs) |
| `singletons/character_manager/character_manager.gd` | Delete `get_equipped_abilities()` |
| `singletons/path_manager/path_manager.gd` | Wire UNLOCK_ABILITY to AbilityManager in `purchase_node()` |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Use `AbilityManager.get_equipped_abilities()` |
| `scenes/ui/main_view/main_view.gd` | Add abilities_view + abilities_view_state refs |
| `scenes/ui/main_view/states/zone_view_state.gd` | Handle `open_abilities` input |
| `resources/abilities/basic_strike.tres` | Add madra_type=0, ability_source=0 |
| `resources/abilities/empty_palm.tres` | Add madra_type=1, ability_source=1 |
| `resources/abilities/enforce.tres` | Add madra_type=0, ability_source=0 |
| `resources/abilities/power_font.tres` | Add madra_type=1, ability_source=1 |
| `resources/path_progression/pure_madra/nodes/madra_strike.tres` | Change string_value to ability ID |
| `project.godot` | Add AbilityManager autoload, `open_abilities` input action |
| `scenes/main/main_game/main_game.tscn` | Add AbilitiesView instance + AbilitiesViewState node |

---

## Task 1: AbilityData Enhancements

**Files:**
- Modify: `scripts/resource_definitions/abilities/ability_data.gd`

- [ ] **Step 1: Add MadraType and AbilitySource enums**

Add after the existing `TargetType` enum block:

```gdscript
enum MadraType {
	NONE, ## No Madra affinity (physical abilities)
	PURE, ## Pure Madra
}

enum AbilitySource {
	INNATE, ## Always available, persists across path changes
	PATH, ## Unlocked via path tree, resets with path
}
```

- [ ] **Step 2: Add classification export properties**

Add a new export group after the `target_type` property (after line 31):

```gdscript
@export_group("Classification")
@export var madra_type: MadraType = MadraType.NONE
@export var ability_source: AbilitySource = AbilitySource.INNATE
```

- [ ] **Step 3: Update `_to_string()`**

Replace the existing `_to_string()` method:

```gdscript
func _to_string() -> String:
	return "AbilityData[%s] '%s' (Type: %s, Target: %s, Madra: %s, Source: %s, Cost: %s, CD: %.1fs)" % [
		ability_id,
		ability_name,
		AbilityType.keys()[ability_type],
		TargetType.keys()[target_type],
		MadraType.keys()[madra_type],
		AbilitySource.keys()[ability_source],
		get_total_cost_display(),
		base_cooldown,
	]
```

- [ ] **Step 4: Commit**

```bash
git add scripts/resource_definitions/abilities/ability_data.gd
git commit -m "feat(abilities): add MadraType and AbilitySource enums to AbilityData"
```

---

## Task 2: AbilityListData Catalog Resource

**Files:**
- Create: `scripts/resource_definitions/abilities/ability_list_data.gd`
- Create: `resources/abilities/ability_list.tres`

- [ ] **Step 1: Create AbilityListData resource class**

```gdscript
class_name AbilityListData
extends Resource

## Registry of all ability definitions.
## AbilityManager preloads this and builds an ID-indexed lookup dictionary.

@export var abilities: Array[AbilityData] = []
```

- [ ] **Step 2: Create ability_list.tres catalog**

This is a Godot .tres file that references all existing ability .tres files. Create it at `resources/abilities/ability_list.tres`:

```
[gd_resource type="Resource" script_class="AbilityListData" load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/resource_definitions/abilities/ability_list_data.gd" id="1_script"]
[ext_resource type="Resource" uid="uid://dic54dwcx1ho4" path="res://resources/abilities/basic_strike.tres" id="2_basic"]
[ext_resource type="Resource" path="res://resources/abilities/empty_palm.tres" id="3_palm"]
[ext_resource type="Resource" path="res://resources/abilities/enforce.tres" id="4_enforce"]
[ext_resource type="Resource" path="res://resources/abilities/power_font.tres" id="5_font"]

[resource]
script = ExtResource("1_script")
abilities = Array[ExtResource("1_script")]([ExtResource("2_basic"), ExtResource("3_palm"), ExtResource("4_enforce"), ExtResource("5_font")])
```

Note: The .tres file may need UIDs added after Godot import. If the format above doesn't load correctly, open the file in the Godot editor and re-save it — Godot will fix the resource references. An alternative is to create it programmatically by opening the editor.

- [ ] **Step 3: Commit**

```bash
git add scripts/resource_definitions/abilities/ability_list_data.gd resources/abilities/ability_list.tres
git commit -m "feat(abilities): add AbilityListData catalog resource"
```

---

## Task 3: SaveGameData Changes

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd`

- [ ] **Step 1: Add ability manager section**

Add between the Cycling Manager section (line 79) and the Path Progression section (line 82):

```gdscript
#-----------------------------------------------------------------------------
# ABILITY MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce"]
```

- [ ] **Step 2: Add reset logic**

In the `reset()` method, add after the Cycling Manager reset (after line 166):

```gdscript
	# Ability Manager
	unlocked_ability_ids = ["basic_strike", "enforce"]
	equipped_ability_ids = ["basic_strike", "enforce"]
```

- [ ] **Step 3: Update `_to_string()`**

In the `_to_string()` method, add these fields. Add after `EquippedCyclingTechniqueId` in the format string and the values array:

Add to the format string pattern (before `\n  CurrentPathId`):
```
\n  UnlockedAbilityIds: %s\n  EquippedAbilityIds: %s
```

Add to the values array (before `current_path_id`):
```gdscript
			str(unlocked_ability_ids),
			str(equipped_ability_ids),
```

- [ ] **Step 4: Commit**

```bash
git add singletons/persistence_manager/save_game_data.gd
git commit -m "feat(abilities): add ability state to SaveGameData"
```

---

## Task 4: AbilityManager Singleton (TDD)

**Files:**
- Create: `singletons/ability_manager/ability_manager.gd`
- Create: `tests/unit/test_ability_manager.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_ability_manager.gd`:

```gdscript
extends GutTest

## Tests for AbilityManager singleton.
## Follows the same test pattern as test_path_manager.gd — directly assigns
## internal state to avoid autoload dependency ordering issues.

var _save_data: SaveGameData = null

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.unlocked_ability_ids = ["basic_strike", "enforce"]
	_save_data.equipped_ability_ids = ["basic_strike"]
	AbilityManager._live_save_data = _save_data
	AbilityManager._build_catalog_index()

# ----- Unlock Tests -----

func test_unlock_ability() -> void:
	AbilityManager.unlock_ability("empty_palm")
	assert_true(AbilityManager.is_ability_unlocked("empty_palm"),
		"empty_palm should be unlocked after unlock_ability()")

func test_unlock_idempotent() -> void:
	AbilityManager.unlock_ability("basic_strike")
	var count: int = 0
	for id: String in _save_data.unlocked_ability_ids:
		if id == "basic_strike":
			count += 1
	assert_eq(count, 1, "Duplicate unlock should not add a second entry")

func test_unlock_unknown_id() -> void:
	AbilityManager.unlock_ability("nonexistent_ability")
	assert_false(AbilityManager.is_ability_unlocked("nonexistent_ability"),
		"Unknown ability ID should not be added to unlocked list")

func test_unlock_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.unlock_ability("empty_palm")
	assert_signal_emitted(AbilityManager, "ability_unlocked",
		"ability_unlocked signal should fire on unlock")

# ----- Equip Tests -----

func test_equip_ability() -> void:
	AbilityManager.equip_ability("enforce")
	assert_true(AbilityManager.is_ability_equipped("enforce"),
		"enforce should be equipped after equip_ability()")

func test_equip_requires_unlock() -> void:
	var result: bool = AbilityManager.equip_ability("empty_palm")
	assert_false(result, "Cannot equip an ability that is not unlocked")
	assert_false(AbilityManager.is_ability_equipped("empty_palm"))

func test_equip_slot_limit() -> void:
	# Fill all 4 slots
	AbilityManager.unlock_ability("empty_palm")
	AbilityManager.unlock_ability("power_font")
	AbilityManager.equip_ability("enforce")
	AbilityManager.equip_ability("empty_palm")
	AbilityManager.equip_ability("power_font")
	assert_eq(_save_data.equipped_ability_ids.size(), 4,
		"Should have exactly 4 equipped abilities")

	# Try to equip a 5th — should fail
	# (We'd need a 5th ability in catalog for this; test the size check directly)
	assert_eq(AbilityManager.get_max_slots(), 4)

func test_equip_already_equipped() -> void:
	AbilityManager.equip_ability("basic_strike")
	var count: int = 0
	for id: String in _save_data.equipped_ability_ids:
		if id == "basic_strike":
			count += 1
	assert_eq(count, 1, "Equipping already-equipped ability should not duplicate")

func test_equip_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.equip_ability("enforce")
	assert_signal_emitted(AbilityManager, "equipped_abilities_changed",
		"equipped_abilities_changed signal should fire on equip")

# ----- Unequip Tests -----

func test_unequip_ability() -> void:
	AbilityManager.unequip_ability("basic_strike")
	assert_false(AbilityManager.is_ability_equipped("basic_strike"),
		"basic_strike should not be equipped after unequip")

func test_unequip_not_equipped() -> void:
	AbilityManager.unequip_ability("enforce")
	# Should not crash, should be a no-op
	assert_false(AbilityManager.is_ability_equipped("enforce"))

func test_unequip_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.unequip_ability("basic_strike")
	assert_signal_emitted(AbilityManager, "equipped_abilities_changed",
		"equipped_abilities_changed signal should fire on unequip")

# ----- Getter Tests -----

func test_get_equipped_abilities() -> void:
	var equipped: Array[AbilityData] = AbilityManager.get_equipped_abilities()
	assert_eq(equipped.size(), 1, "Should have 1 equipped ability (basic_strike)")
	if equipped.size() > 0:
		assert_eq(equipped[0].ability_id, "basic_strike")

func test_get_unlocked_abilities() -> void:
	var unlocked: Array[AbilityData] = AbilityManager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 2, "Should have 2 unlocked abilities")

func test_get_max_slots() -> void:
	assert_eq(AbilityManager.get_max_slots(), 4)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -ginclude_subdirs -gtest=test_ability_manager.gd -gexit`

Expected: Failures — AbilityManager class doesn't exist yet.

- [ ] **Step 3: Create AbilityManager singleton**

Create `singletons/ability_manager/ability_manager.gd`:

```gdscript
extends Node

## Manages ability state — which abilities are unlocked and equipped.
## Authoritative owner of all ability data. Mirrors CyclingManager pattern.

signal ability_unlocked(ability: AbilityData)
signal equipped_abilities_changed()

const MAX_SLOTS: int = 4

var _live_save_data: SaveGameData = null
var _ability_catalog: AbilityListData = preload("res://resources/abilities/ability_list.tres")
var _abilities_by_id: Dictionary = {}  # String -> AbilityData

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("AbilityManager: Could not get save_game_data from PersistenceManager on ready!")

# ----- Public API -----

## Returns full resource data for all unlocked ability IDs.
func get_unlocked_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if not _live_save_data:
		return result
	for ability_id: String in _live_save_data.unlocked_ability_ids:
		if _abilities_by_id.has(ability_id):
			result.append(_abilities_by_id[ability_id])
	return result

## Returns full resource data for all equipped ability IDs.
func get_equipped_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if not _live_save_data:
		return result
	for ability_id: String in _live_save_data.equipped_ability_ids:
		if _abilities_by_id.has(ability_id):
			result.append(_abilities_by_id[ability_id])
	return result

## Unlocks an ability by ID. Idempotent — skips if already unlocked.
func unlock_ability(ability_id: String) -> void:
	if not _live_save_data:
		return
	if ability_id in _live_save_data.unlocked_ability_ids:
		return
	if not _abilities_by_id.has(ability_id):
		push_error("AbilityManager: unknown ability_id '%s'" % ability_id)
		return
	_live_save_data.unlocked_ability_ids.append(ability_id)
	Log.info("AbilityManager: Unlocked ability '%s'" % ability_id)
	ability_unlocked.emit(_abilities_by_id[ability_id])

## Equips an ability by ID. Must be unlocked first. Returns false if failed.
func equip_ability(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	if not _abilities_by_id.has(ability_id):
		push_error("AbilityManager: unknown ability_id '%s'" % ability_id)
		return false
	if ability_id not in _live_save_data.unlocked_ability_ids:
		push_error("AbilityManager: cannot equip locked ability '%s'" % ability_id)
		return false
	if ability_id in _live_save_data.equipped_ability_ids:
		return true  # Already equipped, idempotent
	if _live_save_data.equipped_ability_ids.size() >= MAX_SLOTS:
		push_error("AbilityManager: cannot equip '%s' — all %d slots full" % [ability_id, MAX_SLOTS])
		return false
	_live_save_data.equipped_ability_ids.append(ability_id)
	Log.info("AbilityManager: Equipped ability '%s'" % ability_id)
	equipped_abilities_changed.emit()
	return true

## Unequips an ability by ID.
func unequip_ability(ability_id: String) -> void:
	if not _live_save_data:
		return
	if ability_id not in _live_save_data.equipped_ability_ids:
		return
	_live_save_data.equipped_ability_ids.erase(ability_id)
	Log.info("AbilityManager: Unequipped ability '%s'" % ability_id)
	equipped_abilities_changed.emit()

## Returns true if the ability is currently unlocked.
func is_ability_unlocked(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	return ability_id in _live_save_data.unlocked_ability_ids

## Returns true if the ability is currently equipped.
func is_ability_equipped(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	return ability_id in _live_save_data.equipped_ability_ids

## Returns the maximum number of ability equip slots.
func get_max_slots() -> int:
	return MAX_SLOTS

# ----- Private -----

func _build_catalog_index() -> void:
	_abilities_by_id.clear()
	for ability: AbilityData in _ability_catalog.abilities:
		if ability and not ability.ability_id.is_empty():
			_abilities_by_id[ability.ability_id] = ability

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
```

- [ ] **Step 4: Register AbilityManager autoload in project.godot**

In the `[autoload]` section of `project.godot`, add after the CyclingManager line:

```
AbilityManager="*res://singletons/ability_manager/ability_manager.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -ginclude_subdirs -gtest=test_ability_manager.gd -gexit`

Expected: All tests PASS. If catalog preload fails because ability_list.tres isn't importable in headless mode, the test's `before_each` directly calls `_build_catalog_index()` which should work since the catalog is preloaded at singleton init. If import is needed first, run `--import` before tests.

- [ ] **Step 6: Commit**

```bash
git add singletons/ability_manager/ability_manager.gd tests/unit/test_ability_manager.gd project.godot
git commit -m "feat(abilities): add AbilityManager singleton with tests"
```

---

## Task 5: Update Existing Ability .tres Files

**Files:**
- Modify: `resources/abilities/basic_strike.tres`
- Modify: `resources/abilities/empty_palm.tres`
- Modify: `resources/abilities/enforce.tres`
- Modify: `resources/abilities/power_font.tres`

- [ ] **Step 1: Add classification properties to each .tres file**

In each `.tres` file, add the new properties to the `[resource]` section. The enum values are integers: MadraType (NONE=0, PURE=1), AbilitySource (INNATE=0, PATH=1).

**basic_strike.tres** — Add before `metadata/_custom_type_script`:
```
madra_type = 0
ability_source = 0
```

**empty_palm.tres** — Add:
```
madra_type = 1
ability_source = 1
```

**enforce.tres** — Add:
```
madra_type = 0
ability_source = 0
```

**power_font.tres** — Add:
```
madra_type = 1
ability_source = 1
```

- [ ] **Step 2: Commit**

```bash
git add resources/abilities/basic_strike.tres resources/abilities/empty_palm.tres resources/abilities/enforce.tres resources/abilities/power_font.tres
git commit -m "feat(abilities): set madra_type and ability_source on existing abilities"
```

---

## Task 6: PathManager + Combat Integration

**Files:**
- Modify: `singletons/path_manager/path_manager.gd`
- Modify: `singletons/character_manager/character_manager.gd`
- Modify: `scenes/combat/adventure_combat/adventure_combat.gd`
- Modify: `resources/path_progression/pure_madra/nodes/madra_strike.tres`

- [ ] **Step 1: Wire UNLOCK_ABILITY to AbilityManager in PathManager**

In `path_manager.gd`, in the `purchase_node()` method (around line 104-108), the cycling technique unlock block currently looks like:

```gdscript
	# Apply cycling technique unlocks
	if CyclingManager:
		for effect: PathNodeEffectData in node.effects:
			if effect.effect_type == PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
				CyclingManager.unlock_technique(effect.string_value)
```

Add an ability unlock block immediately after:

```gdscript
	# Apply ability unlocks
	if AbilityManager:
		for effect: PathNodeEffectData in node.effects:
			if effect.effect_type == PathNodeEffectData.EffectType.UNLOCK_ABILITY:
				AbilityManager.unlock_ability(effect.string_value)
```

- [ ] **Step 2: Update PathManager.get_unlocked_abilities() doc comment**

Change the doc comment on `get_unlocked_abilities()` (line 115-116) from:

```gdscript
## Returns resource paths of all combat abilities unlocked by purchased nodes.
## Not yet consumed by the ability system — ready for ability rework integration.
```

To:

```gdscript
## Returns IDs of all combat abilities unlocked by purchased nodes.
## AbilityManager is the live consumer; this returns the aggregated view from path state.
```

- [ ] **Step 3: Update madra_strike.tres string_value to ability ID format**

In `resources/path_progression/pure_madra/nodes/madra_strike.tres`, change:

```
string_value = "res://resources/abilities/madra_strike.tres"
```

To:

```
string_value = "madra_strike"
```

Note: The ability `madra_strike` doesn't exist in the catalog yet. This is expected — it will be created when that ability is designed. The unlock will be a no-op (AbilityManager logs unknown ID as error) until the ability .tres is added.

- [ ] **Step 4: Replace CharacterManager.get_equipped_abilities() with AbilityManager**

In `scenes/combat/adventure_combat/adventure_combat.gd`, change line 107:

```gdscript
	player_data.abilities = CharacterManager.get_equipped_abilities()
```

To:

```gdscript
	player_data.abilities = AbilityManager.get_equipped_abilities()
```

- [ ] **Step 5: Delete CharacterManager.get_equipped_abilities()**

In `singletons/character_manager/character_manager.gd`, delete lines 63-74 (the entire ability section):

```gdscript
#-----------------------------------------------------------------------------
# ABILITY PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

func get_equipped_abilities() -> Array[AbilityData]:
	var equipped_abilities : Array[AbilityData] = []
	equipped_abilities.append(load("res://resources/abilities/basic_strike.tres"))
	equipped_abilities.append(load("res://resources/abilities/empty_palm.tres"))
	equipped_abilities.append(load("res://resources/abilities/enforce.tres"))
	equipped_abilities.append(load("res://resources/abilities/power_font.tres"))
	return equipped_abilities
```

- [ ] **Step 6: Run full test suite**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass. The path manager test `test_ability_unlock_tracked` still works because it only checks `PathManager.get_unlocked_abilities()` which still aggregates via PathEffectsSummary.

- [ ] **Step 7: Commit**

```bash
git add singletons/path_manager/path_manager.gd singletons/character_manager/character_manager.gd scenes/combat/adventure_combat/adventure_combat.gd resources/path_progression/pure_madra/nodes/madra_strike.tres
git commit -m "feat(abilities): wire PathManager unlocks to AbilityManager, replace CharacterManager placeholder"
```

---

## Task 7: Input Action Registration

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add open_abilities input action**

In the `[input]` section of `project.godot`, add:

```
open_abilities={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
```

This maps the `A` key (physical_keycode 65, unicode 97) to `open_abilities`.

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat(abilities): add open_abilities input action (A key)"
```

---

## Task 8: AbilitiesViewState + MainView Wiring

**Files:**
- Create: `scenes/abilities/abilities_view_state.gd`
- Modify: `scenes/ui/main_view/main_view.gd`
- Modify: `scenes/ui/main_view/states/zone_view_state.gd`

- [ ] **Step 1: Create AbilitiesViewState**

Create `scenes/abilities/abilities_view_state.gd`:

```gdscript
## State for the Abilities View.
class_name AbilitiesViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	scene_root.abilities_view.visible = true

## Called when exiting this state.
func exit() -> void:
	scene_root.abilities_view.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_abilities"):
		scene_root.pop_state()
```

- [ ] **Step 2: Add abilities references to MainView**

In `scenes/ui/main_view/main_view.gd`, add the new onready vars. After the `path_tree_view` line (line 14):

```gdscript
@onready var abilities_view: Control = %AbilitiesView
```

After the `path_tree_view_state` line (line 24):

```gdscript
@onready var abilities_view_state: MainViewState = %MainViewStateMachine/AbilitiesViewState
```

In `_ready()`, add after `path_tree_view_state.scene_root = self` (line 36):

```gdscript
	abilities_view_state.scene_root = self
```

- [ ] **Step 3: Wire open_abilities in ZoneViewState**

In `scenes/ui/main_view/states/zone_view_state.gd`, in `handle_input()`, add after the `open_path` block (after line 34):

```gdscript
		elif event.is_action_pressed("open_abilities"):
			scene_root.push_state(scene_root.abilities_view_state)
```

- [ ] **Step 4: Commit**

```bash
git add scenes/abilities/abilities_view_state.gd scenes/ui/main_view/main_view.gd scenes/ui/main_view/states/zone_view_state.gd
git commit -m "feat(abilities): add AbilitiesViewState and wire to MainView"
```

---

## Task 9: AbilityCard Component

**Files:**
- Create: `scenes/abilities/ability_card/ability_card.gd`
- Create: `scenes/abilities/ability_card/ability_card.tscn`

- [ ] **Step 1: Create ability_card.gd**

```gdscript
class_name AbilityCard
extends PanelContainer

## Expandable ability card for the AbilitiesView.
## Shows a collapsed summary row; click to expand for details and equip/unequip.

signal equip_requested(ability_id: String)
signal unequip_requested(ability_id: String)
signal card_selected(card: AbilityCard)

var _ability_data: AbilityData = null
var _is_expanded: bool = false
var _is_equipped: bool = false

@onready var _icon: TextureRect = %AbilityIcon
@onready var _name_label: Label = %AbilityName
@onready var _cost_label: Label = %CostLabel
@onready var _madra_badge: Label = %MadraBadge
@onready var _source_badge: Label = %SourceBadge
@onready var _equipped_dot: Control = %EquippedDot
@onready var _expanded_details: VBoxContainer = %ExpandedDetails
@onready var _description_label: Label = %DescriptionLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _equip_button: Button = %EquipButton

func _ready() -> void:
	_equip_button.pressed.connect(_on_equip_button_pressed)
	gui_input.connect(_on_gui_input)

# ----- Public API -----

## Configures the card with ability data and equipped status.
func setup(ability_data: AbilityData, is_equipped: bool) -> void:
	_ability_data = ability_data
	_is_equipped = is_equipped
	_update_display()

## Updates equipped state without full rebuild.
func set_equipped(is_equipped: bool) -> void:
	_is_equipped = is_equipped
	_update_equipped_display()

## Collapses the card.
func collapse() -> void:
	_is_expanded = false
	_expanded_details.visible = false

## Returns the ability data for this card.
func get_ability_data() -> AbilityData:
	return _ability_data

# ----- Private -----

func _update_display() -> void:
	if not _ability_data:
		return

	_icon.texture = _ability_data.icon
	_name_label.text = _ability_data.ability_name

	# Cost summary
	_cost_label.text = _ability_data.get_total_cost_display() + " · %.1fs CD" % _ability_data.base_cooldown

	# Madra badge
	if _ability_data.madra_type == AbilityData.MadraType.NONE:
		_madra_badge.visible = false
	else:
		_madra_badge.visible = true
		_madra_badge.text = AbilityData.MadraType.keys()[_ability_data.madra_type]

	# Source badge
	_source_badge.text = AbilityData.AbilitySource.keys()[_ability_data.ability_source].capitalize()

	# Expanded details
	_description_label.text = _ability_data.description

	var target_name: String = AbilityData.TargetType.keys()[_ability_data.target_type].capitalize().replace("_", " ")
	var type_name: String = AbilityData.AbilityType.keys()[_ability_data.ability_type].capitalize()
	var cast_text: String = "Instant" if _ability_data.cast_time <= 0.0 else "%.1fs" % _ability_data.cast_time
	var madra_text: String = AbilityData.MadraType.keys()[_ability_data.madra_type].capitalize()
	_stats_label.text = "%s · %s · Cast: %s · Madra: %s" % [type_name, target_name, cast_text, madra_text]

	_update_equipped_display()

func _update_equipped_display() -> void:
	_equipped_dot.visible = _is_equipped
	if _is_equipped:
		_equip_button.text = "UNEQUIP"
	else:
		if AbilityManager and AbilityManager._live_save_data:
			if AbilityManager._live_save_data.equipped_ability_ids.size() >= AbilityManager.get_max_slots():
				_equip_button.text = "SLOTS FULL"
				_equip_button.disabled = true
				return
		_equip_button.text = "EQUIP"
	_equip_button.disabled = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_expanded:
			collapse()
		else:
			card_selected.emit(self)
			_is_expanded = true
			_expanded_details.visible = true

func _on_equip_button_pressed() -> void:
	if not _ability_data:
		return
	if _is_equipped:
		unequip_requested.emit(_ability_data.ability_id)
	else:
		equip_requested.emit(_ability_data.ability_id)
```

- [ ] **Step 2: Create ability_card.tscn**

Create `scenes/abilities/ability_card/ability_card.tscn`. The scene tree structure:

```
AbilityCard (PanelContainer, ability_card.gd script)
└── CardVBox (VBoxContainer)
    ├── CollapsedRow (HBoxContainer)
    │   ├── AbilityIcon (TextureRect, 40x40, unique name)
    │   ├── InfoVBox (VBoxContainer, size_flags_horizontal=3)
    │   │   ├── NameRow (HBoxContainer)
    │   │   │   ├── AbilityName (Label, unique name, LabelPathBody type_variation)
    │   │   │   ├── MadraBadge (Label, unique name, LabelPathGreen type_variation)
    │   │   │   └── SourceBadge (Label, unique name, LabelPathMuted type_variation)
    │   │   └── CostLabel (Label, unique name, LabelPathMuted type_variation)
    │   └── EquippedDot (ColorRect, 8x8, color=#7DCE82, unique name)
    └── ExpandedDetails (VBoxContainer, visible=false, unique name)
        ├── DetailSep (HSeparator)
        ├── DescriptionLabel (Label, unique name, LabelPathMuted type_variation, autowrap=WORD_SMART)
        ├── StatsLabel (Label, unique name, LabelPathBody type_variation)
        └── ButtonRow (HBoxContainer, alignment=END)
            └── EquipButton (Button, unique name)
```

Use pixel theme type variations (LabelPathBody, LabelPathMuted, LabelPathGreen) rather than theme overrides. The PanelContainer should use the default theme panel or a stylebox from `assets/styleboxes/common/`.

Note: Since creating .tscn files by hand is error-prone, this scene should be built in the Godot editor. The structure above defines the exact node tree to create. Set `unique_name_in_owner = true` on all nodes referenced with `%` in the script.

- [ ] **Step 3: Commit**

```bash
git add scenes/abilities/ability_card/ability_card.gd scenes/abilities/ability_card/ability_card.tscn
git commit -m "feat(abilities): add AbilityCard expandable component"
```

---

## Task 10: AbilitiesView Scene

**Files:**
- Create: `scenes/abilities/abilities_view.gd`
- Create: `scenes/abilities/abilities_view.tscn`
- Modify: `scenes/main/main_game/main_game.tscn` (add view + state nodes)

- [ ] **Step 1: Create abilities_view.gd**

```gdscript
class_name AbilitiesView
extends Control

## AbilitiesView
## Manages the ability list, filter bar, sort, loadout sidebar, and card interactions.

enum FilterMode { ALL, OFFENSIVE, BUFF, EQUIPPED }
enum SortMode { EQUIPPED_FIRST, NAME_AZ, MADRA_COST, COOLDOWN }

const AbilityCardScene: PackedScene = preload("res://scenes/abilities/ability_card/ability_card.tscn")

var _filter_mode: FilterMode = FilterMode.ALL
var _sort_mode: SortMode = SortMode.EQUIPPED_FIRST
var _cards: Array[AbilityCard] = []
var _expanded_card: AbilityCard = null

@onready var _card_list: VBoxContainer = %CardList
@onready var _slot_counter: Label = %SlotCounter
@onready var _sort_dropdown: OptionButton = %SortDropdown
@onready var _equip_slots: Array[TextureRect] = [%EquipSlot1, %EquipSlot2, %EquipSlot3, %EquipSlot4]
@onready var _filter_all: Button = %FilterAll
@onready var _filter_offensive: Button = %FilterOffensive
@onready var _filter_buff: Button = %FilterBuff
@onready var _filter_equipped: Button = %FilterEquipped

func _ready() -> void:
	_setup_sort_dropdown()
	_setup_filter_buttons()
	visibility_changed.connect(_on_visibility_changed)

# ----- Public API -----

## Refreshes the entire view from AbilityManager state.
func refresh() -> void:
	_rebuild_card_list()
	_update_loadout_sidebar()
	_update_slot_counter()

# ----- Private: Setup -----

func _setup_sort_dropdown() -> void:
	_sort_dropdown.clear()
	_sort_dropdown.add_item("Equipped First", SortMode.EQUIPPED_FIRST)
	_sort_dropdown.add_item("Name A-Z", SortMode.NAME_AZ)
	_sort_dropdown.add_item("Madra Cost", SortMode.MADRA_COST)
	_sort_dropdown.add_item("Cooldown", SortMode.COOLDOWN)
	_sort_dropdown.selected = 0
	_sort_dropdown.item_selected.connect(_on_sort_changed)

func _setup_filter_buttons() -> void:
	_filter_all.pressed.connect(_on_filter_pressed.bind(FilterMode.ALL))
	_filter_offensive.pressed.connect(_on_filter_pressed.bind(FilterMode.OFFENSIVE))
	_filter_buff.pressed.connect(_on_filter_pressed.bind(FilterMode.BUFF))
	_filter_equipped.pressed.connect(_on_filter_pressed.bind(FilterMode.EQUIPPED))
	_update_filter_button_styles()

# ----- Private: Card Management -----

func _rebuild_card_list() -> void:
	# Clear existing cards
	for card: AbilityCard in _cards:
		card.queue_free()
	_cards.clear()
	_expanded_card = null

	var unlocked: Array[AbilityData] = AbilityManager.get_unlocked_abilities()
	var filtered: Array[AbilityData] = _apply_filter(unlocked)
	var sorted: Array[AbilityData] = _apply_sort(filtered)

	for ability: AbilityData in sorted:
		var card: AbilityCard = AbilityCardScene.instantiate()
		_card_list.add_child(card)
		card.setup(ability, AbilityManager.is_ability_equipped(ability.ability_id))
		card.equip_requested.connect(_on_equip_requested)
		card.unequip_requested.connect(_on_unequip_requested)
		card.card_selected.connect(_on_card_selected)
		_cards.append(card)

func _apply_filter(abilities: Array[AbilityData]) -> Array[AbilityData]:
	if _filter_mode == FilterMode.ALL:
		return abilities
	var result: Array[AbilityData] = []
	for ability: AbilityData in abilities:
		match _filter_mode:
			FilterMode.OFFENSIVE:
				if ability.target_type != AbilityData.TargetType.SELF:
					result.append(ability)
			FilterMode.BUFF:
				if ability.target_type == AbilityData.TargetType.SELF:
					result.append(ability)
			FilterMode.EQUIPPED:
				if AbilityManager.is_ability_equipped(ability.ability_id):
					result.append(ability)
	return result

func _apply_sort(abilities: Array[AbilityData]) -> Array[AbilityData]:
	var sorted: Array[AbilityData] = abilities.duplicate()
	match _sort_mode:
		SortMode.EQUIPPED_FIRST:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				var a_eq: bool = AbilityManager.is_ability_equipped(a.ability_id)
				var b_eq: bool = AbilityManager.is_ability_equipped(b.ability_id)
				if a_eq != b_eq:
					return a_eq
				return a.ability_name < b.ability_name
			)
		SortMode.NAME_AZ:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.ability_name < b.ability_name
			)
		SortMode.MADRA_COST:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.madra_cost < b.madra_cost
			)
		SortMode.COOLDOWN:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.base_cooldown < b.base_cooldown
			)
	return sorted

# ----- Private: Loadout Sidebar -----

func _update_loadout_sidebar() -> void:
	var equipped: Array[AbilityData] = AbilityManager.get_equipped_abilities()
	for i: int in range(_equip_slots.size()):
		if i < equipped.size():
			_equip_slots[i].texture = equipped[i].icon
			_equip_slots[i].modulate = Color.WHITE
		else:
			_equip_slots[i].texture = null
			_equip_slots[i].modulate = Color(1, 1, 1, 0.3)

func _update_slot_counter() -> void:
	var equipped_count: int = AbilityManager.get_equipped_abilities().size()
	_slot_counter.text = "%d / %d" % [equipped_count, AbilityManager.get_max_slots()]

func _update_filter_button_styles() -> void:
	var buttons: Array[Button] = [_filter_all, _filter_offensive, _filter_buff, _filter_equipped]
	var modes: Array[FilterMode] = [FilterMode.ALL, FilterMode.OFFENSIVE, FilterMode.BUFF, FilterMode.EQUIPPED]
	for i: int in range(buttons.size()):
		if modes[i] == _filter_mode:
			buttons[i].add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
		else:
			buttons[i].remove_theme_color_override("font_color")

# ----- Signal Handlers -----

func _on_visibility_changed() -> void:
	if visible:
		refresh()

func _on_filter_pressed(mode: FilterMode) -> void:
	_filter_mode = mode
	_update_filter_button_styles()
	_rebuild_card_list()

func _on_sort_changed(_index: int) -> void:
	_sort_mode = _sort_dropdown.get_selected_id() as SortMode
	_rebuild_card_list()

func _on_card_selected(card: AbilityCard) -> void:
	if _expanded_card and _expanded_card != card:
		_expanded_card.collapse()
	_expanded_card = card

func _on_equip_requested(ability_id: String) -> void:
	AbilityManager.equip_ability(ability_id)
	refresh()

func _on_unequip_requested(ability_id: String) -> void:
	AbilityManager.unequip_ability(ability_id)
	refresh()
```

- [ ] **Step 2: Create abilities_view.tscn**

Build this scene in the Godot editor. Scene tree structure:

```
AbilitiesView (Control, abilities_view.gd, unique_name_in_owner=true, visible=false, z_index=3)
├── UnifiedPanel (PanelContainer, anchors=full_rect, 120px margins)
│   └── MainVBox (VBoxContainer)
│       ├── Header (PanelContainer)
│       │   └── HeaderMargin (MarginContainer, 24/14px margins)
│       │       └── HeaderHBox (HBoxContainer)
│       │           ├── TitleBlock (VBoxContainer)
│       │           │   ├── Title (Label, text="ABILITIES", type_variation=LabelPathTitle)
│       │           │   └── Subtitle (Label, text="Manage your combat techniques", type_variation=LabelPathSubheading)
│       │           ├── Spacer (Control, size_flags_horizontal=3)
│       │           └── SlotCounter (Label, unique name, type_variation=LabelPathValueLarge)
│       ├── HeaderSep (HSeparator)
│       └── Body (HBoxContainer, size_flags_vertical=3)
│           ├── LoadoutSidebar (VBoxContainer, custom_minimum_size.x=100)
│           │   ├── LoadoutLabel (Label, text="LOADOUT", type_variation=LabelPathMuted)
│           │   ├── EquipSlot1 (TextureRect, 64x64, unique name)
│           │   ├── EquipSlot2 (TextureRect, 64x64, unique name)
│           │   ├── EquipSlot3 (TextureRect, 64x64, unique name)
│           │   └── EquipSlot4 (TextureRect, 64x64, unique name)
│           ├── BodyDivider (VSeparator)
│           └── MainContent (VBoxContainer, size_flags_horizontal=3)
│               ├── FilterBar (HBoxContainer)
│               │   ├── FilterToggles (HBoxContainer, size_flags_horizontal=3)
│               │   │   ├── FilterAll (Button, text="All", unique name)
│               │   │   ├── FilterOffensive (Button, text="Offensive", unique name)
│               │   │   ├── FilterBuff (Button, text="Buff", unique name)
│               │   │   └── FilterEquipped (Button, text="Equipped", unique name)
│               │   └── SortDropdown (OptionButton, unique name)
│               └── ScrollContainer (size_flags_vertical=3)
│                   └── CardList (VBoxContainer, unique name, size_flags_horizontal=3)
```

Use the same styling as PathTreeView — the UnifiedPanel should use the path tree stylebox (`assets/styleboxes/ui/panel_path_tree.tres`) or an equivalent. Use theme type variations for all labels: `LabelPathTitle`, `LabelPathSubheading`, `LabelPathMuted`, `LabelPathValueLarge`.

For the separator style, use `assets/styleboxes/ui/line_path_header_sep.tres` and `assets/styleboxes/ui/line_path_body_divider.tres`.

- [ ] **Step 3: Add AbilitiesView and state to main_game.tscn**

In the Godot editor, open `scenes/main/main_game/main_game.tscn` and:

1. Under `MainViewStateMachine`, add a new Node child named `AbilitiesViewState` with script `res://scenes/abilities/abilities_view_state.gd`, set `unique_name_in_owner = true`
2. Under `MainView`, add an instance of `res://scenes/abilities/abilities_view.tscn` named `AbilitiesView`, set `unique_name_in_owner = true`, `visible = false`, `z_index = 3`, `layout_mode = 1`, `anchors_preset = 15` (full rect)

- [ ] **Step 4: Run the game to verify the view opens/closes**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn`

Test: Press `A` to open abilities view. Press `A` or `Escape` to close. Verify the loadout sidebar shows, filter buttons respond, and cards display for unlocked abilities.

- [ ] **Step 5: Run full test suite**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add scenes/abilities/ scenes/main/main_game/main_game.tscn
git commit -m "feat(abilities): add AbilitiesView with loadout sidebar, filter bar, and expandable cards"
```

---

## Task 11: Final Verification & Cleanup

- [ ] **Step 1: End-to-end manual test**

Run the game and verify:
1. Press `A` — abilities view opens with grey background overlay
2. Basic Strike and Enforce show as equipped (green dot)
3. Click a card — it expands showing description, stats, Madra type
4. Click UNEQUIP on Basic Strike — it moves out of loadout sidebar, slot counter updates
5. Click EQUIP on Basic Strike — it goes back into loadout
6. Filter buttons work (All shows all, Equipped shows only equipped)
7. Sort dropdown works (Name A-Z reorders alphabetically)
8. Press Escape — view closes
9. Start an adventure — combat loads abilities from AbilityManager (only equipped ones)

- [ ] **Step 2: Run full test suite one final time**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass.

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "fix(abilities): address review feedback from final verification"
```
