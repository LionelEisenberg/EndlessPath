# Consumables MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the consumable item category and the first concrete consumable — Barely Coalesced Scale (+20 madra) — as inventory-side data and verbs only. No combat-side cooldown enforcement, no use trigger in the HUD.

**Architecture:** Mirror the existing `MaterialDefinitionData` pattern for storage (stacked `Dictionary[ConsumableDefinitionData, int]` on `InventoryData`) and for awarding. `ConsumableDefinitionData` extends `ItemDefinitionData` and reuses `Array[EffectData]` so existing effect subclasses (`ChangeVitalsEffectData`) cover the first use case without new effect types. `InventoryManager` gains an inventory-side `use_consumable(def)` verb; cooldown enforcement is deferred to a future combat-side spec that wraps this verb.

**Tech Stack:** Godot 4.x, GDScript, GUT testing framework (project uses `extends GutTest`, not GdUnit4).

**Spec reference:** [`../specs/2026-05-24-consumables-design.md`](../specs/2026-05-24-consumables-design.md)

**Worktree note:** Brainstorming did not create a dedicated worktree (user opted to skip commit). Work directly in the main checkout. Each task ends with a commit.

---

## File Structure

### Files to create

| Path | Responsibility |
|---|---|
| `resources/effects/change_vitals/barely_coalesced_scale_effect.tres` | `ChangeVitalsEffectData` resource for +20 madra. |
| `resources/items/consumables/barely_coalesced_scale.tres` | `ConsumableDefinitionData` resource referencing the effect above. |
| `tests/unit/test_consumable_definition_data.gd` | Unit tests for the resource class behavior (`_init`, `use`, `_get_item_effects`). |
| `tests/unit/test_inventory_manager_consumables.gd` | Integration tests covering `award_items`, `has_item`, and `use_consumable` for consumables. |
| `tests/unit/test_barely_coalesced_scale_tres.gd` | Asserts the `.tres` files load correctly with the expected field values. |

### Files to modify

| Path | Change |
|---|---|
| `scripts/resource_definitions/items/consumable_definition_data.gd` | Replace the 2-line stub with the full class (effects + cooldown_seconds + `use()` + `_get_item_effects()`). |
| `singletons/persistence_manager/inventory_data.gd` | Add `consumables: Dictionary[ConsumableDefinitionData, int] = {}`; update `_to_string()`. |
| `singletons/inventory_manager/inventory_manager.gd` | Add `CONSUMABLE` branch to `award_items`; add `_award_consumable` private helper; extend `has_item` to scan `consumables`; add public `use_consumable`. |

### Test command

All tests run via the project's GUT setup. Per-test invocation:

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<test_file>.gd -gexit
```

Run the full unit suite:

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

(Confirm the exact command with `tests/` or `addons/gut/` config if these don't work — the existing `test_inventory_manager.gd` runs under this harness.)

---

## Task 1: Add `consumables` dict to `InventoryData`

**Files:**
- Modify: `singletons/persistence_manager/inventory_data.gd`
- Test: `tests/unit/test_inventory_manager_consumables.gd` (created in this task; expanded in later tasks)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_inventory_manager_consumables.gd`:

```gdscript
extends GutTest

## Unit + integration tests for the consumables MVP.
## Covers InventoryData.consumables field, InventoryManager.award_items dispatch,
## InventoryManager.has_item, and InventoryManager.use_consumable.

var _inventory: InventoryData

func before_each() -> void:
	_inventory = InventoryData.new()

func test_inventory_starts_with_empty_consumables_dict() -> void:
	assert_eq(_inventory.consumables.size(), 0, "consumables should start empty")
	assert_true(_inventory.consumables is Dictionary, "consumables should be a Dictionary")
```

- [ ] **Step 2: Run test to verify it fails**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: FAIL with `Invalid get index 'consumables'` on `_inventory.consumables`.

- [ ] **Step 3: Add the field to `InventoryData`**

In `singletons/persistence_manager/inventory_data.gd`, add the field above `_to_string` and update `_to_string`:

```gdscript
class_name InventoryData
extends Resource

## Dictionary of Material -> Quantity of Material Owned
@export var materials : Dictionary[MaterialDefinitionData, int] = {}

## Dictionary of Slot Index -> ItemInstanceData (Unequipped gear)
@export var equipment: Dictionary = {} # Dictionary[int, ItemInstanceData]

## Dictionary of EquipmentSlot -> ItemInstanceData (Equipped gear)
@export var equipped_gear: Dictionary = {} # Dictionary[EquipmentDefinitionData.EquipmentSlot, ItemInstanceData]

## Dictionary of ItemDefinitionData (QUEST_ITEM type) -> Quantity owned.
@export var quest_items: Dictionary[ItemDefinitionData, int] = {}

## Dictionary of ConsumableDefinitionData -> Quantity owned. Stacks like materials.
@export var consumables: Dictionary[ConsumableDefinitionData, int] = {}

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, quest_items: %s, consumables: %s)" % [materials, equipment, equipped_gear, quest_items, consumables]
```

- [ ] **Step 4: Run test to verify it passes**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Commit**

```
git add singletons/persistence_manager/inventory_data.gd tests/unit/test_inventory_manager_consumables.gd
git commit -m "feat(inventory): add consumables dict to InventoryData"
```

---

## Task 2: Implement `ConsumableDefinitionData`

The class currently exists as a 2-line stub. Replace it with the full implementation per the spec.

**Files:**
- Modify: `scripts/resource_definitions/items/consumable_definition_data.gd` (currently a stub)
- Test: `tests/unit/test_consumable_definition_data.gd` (create)

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_consumable_definition_data.gd`:

```gdscript
extends GutTest

## Unit tests for ConsumableDefinitionData.
## Verifies item_type, use() effect dispatch, and tooltip formatting.

## Counter EffectData subclass used to observe process() invocations.
class CountingEffect extends EffectData:
	var call_count: int = 0

	func process() -> void:
		call_count += 1

	func _to_string() -> String:
		return "CountingEffect"

func test_init_sets_item_type_to_consumable() -> void:
	var def := ConsumableDefinitionData.new()
	assert_eq(def.item_type, ItemDefinitionData.ItemType.CONSUMABLE,
		"_init should set item_type to CONSUMABLE")

func test_inherits_default_stack_size() -> void:
	var def := ConsumableDefinitionData.new()
	assert_eq(def.stack_size, 99, "should inherit default stack_size from ItemDefinitionData")

func test_use_calls_process_on_each_effect_in_order() -> void:
	var def := ConsumableDefinitionData.new()
	var first := CountingEffect.new()
	var second := CountingEffect.new()
	def.effects = [first, second]

	def.use()

	assert_eq(first.call_count, 1, "first effect should be processed once")
	assert_eq(second.call_count, 1, "second effect should be processed once")

func test_use_with_empty_effects_is_noop() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = []
	# Should not raise.
	def.use()
	pass_test("use() with empty effects did not raise")

func test_get_item_effects_returns_one_line_per_effect() -> void:
	var def := ConsumableDefinitionData.new()
	var first := CountingEffect.new()
	var second := CountingEffect.new()
	def.effects = [first, second]
	def.cooldown_seconds = 0.0

	var lines := def._get_item_effects()

	assert_eq(lines.size(), 2, "should return one line per effect when cooldown is 0")
	assert_true(lines[0].contains("CountingEffect"), "line should include effect _to_string")

func test_get_item_effects_includes_cooldown_line_when_positive() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = [CountingEffect.new()]
	def.cooldown_seconds = 10.0

	var lines := def._get_item_effects()

	assert_eq(lines.size(), 2, "should return effect line + cooldown line")
	assert_true(lines[1].contains("Cooldown"), "second line should mention Cooldown")
	assert_true(lines[1].contains("10"), "second line should include the cooldown value")

func test_get_item_effects_omits_cooldown_line_when_zero() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = [CountingEffect.new()]
	def.cooldown_seconds = 0.0

	var lines := def._get_item_effects()

	for line in lines:
		assert_false(line.contains("Cooldown"), "no cooldown line when cooldown_seconds == 0")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_consumable_definition_data.gd -gexit
```

Expected: FAILs — the stub class has no `effects`, no `cooldown_seconds`, no `use()`, no `_get_item_effects()`.

- [ ] **Step 3: Replace the stub with the full implementation**

Overwrite `scripts/resource_definitions/items/consumable_definition_data.gd`:

```gdscript
class_name ConsumableDefinitionData
extends ItemDefinitionData

## ConsumableDefinitionData
## Definition-side data for a consumable item. use() applies the effects;
## stacking lives on InventoryData; cooldown enforcement will live on the
## future CombatConsumableInstance (see spec 2026-05-24-consumables-design.md).

@export var effects: Array[EffectData] = []

## Seconds before this consumable can be used again, *once cooldown is
## enforced by the combat-side manager*. Pure metadata in this slice —
## declared so .tres files are forward-compatible, but nothing reads it yet.
@export var cooldown_seconds: float = 0.0

func _init() -> void:
	item_type = ItemType.CONSUMABLE

## Apply the consumable's effects. Pure — caller is responsible for inventory
## decrement and cooldown handling.
func use() -> void:
	for effect: EffectData in effects:
		effect.process()

## Tooltip lines. Used by ItemInstanceData._to_description_box() to render the
## consumable's effects in the inventory description panel.
func _get_item_effects() -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectData in effects:
		lines.append("[color=#7ea870]%s[/color]" % str(effect))
	if cooldown_seconds > 0.0:
		lines.append("[color=#a89070]Cooldown: %.1fs[/color]" % cooldown_seconds)
	return lines
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_consumable_definition_data.gd -gexit
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```
git add scripts/resource_definitions/items/consumable_definition_data.gd tests/unit/test_consumable_definition_data.gd
git commit -m "feat(inventory): implement ConsumableDefinitionData with effects + cooldown_seconds"
```

---

## Task 3: Extend `InventoryManager.award_items` for `CONSUMABLE`

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager_consumables.gd` (append)

- [ ] **Step 1: Append failing tests to the test file**

Append to `tests/unit/test_inventory_manager_consumables.gd`:

```gdscript

#-----------------------------------------------------------------------------
# AWARD ITEMS - CONSUMABLES
#-----------------------------------------------------------------------------

func _reset_save() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_consumable(id: String = "test_consumable") -> ConsumableDefinitionData:
	var def := ConsumableDefinitionData.new()
	def.item_id = id
	def.item_name = "Test Consumable %s" % id
	return def

func test_award_consumable_new_entry() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable("award_new")
	InventoryManager.award_items(def, 5)

	var inv := InventoryManager.get_inventory()
	assert_eq(inv.consumables.get(def, 0), 5, "consumable should land in consumables dict")
	assert_eq(inv.materials.size(), 0, "consumable must not land in materials")
	assert_eq(inv.equipment.size(), 0, "consumable must not land in equipment")
	assert_eq(inv.quest_items.size(), 0, "consumable must not land in quest_items")

func test_award_consumable_stacks() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable("award_stack")
	InventoryManager.award_items(def, 3)
	InventoryManager.award_items(def, 4)

	var inv := InventoryManager.get_inventory()
	assert_eq(inv.consumables.get(def, 0), 7, "stacks should accumulate (3 + 4 = 7)")

func test_award_consumable_emits_item_awarded_signal() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	watch_signals(InventoryManager)
	var def := _make_consumable("award_signal")
	InventoryManager.award_items(def, 2)

	assert_signal_emitted(InventoryManager, "item_awarded", "item_awarded should fire on consumable award")

func test_award_consumable_emits_inventory_changed_signal() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	watch_signals(InventoryManager)
	var def := _make_consumable("award_inv_changed")
	InventoryManager.award_items(def, 1)

	assert_signal_emitted(InventoryManager, "inventory_changed", "inventory_changed should fire on consumable award")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: the four new tests FAIL — `award_items` currently logs "Item type not supported" for `CONSUMABLE` and `inv.consumables` stays empty.

- [ ] **Step 3: Add the `CONSUMABLE` branch and `_award_consumable` helper**

In `singletons/inventory_manager/inventory_manager.gd`, modify the `award_items` switch to add the `CONSUMABLE` case before the `_:` default. Find the existing `match item.item_type:` block and add a branch:

```gdscript
ItemDefinitionData.ItemType.CONSUMABLE:
    if item is ConsumableDefinitionData:
        _award_consumable(item as ConsumableDefinitionData, quantity)
        if LogManager:
            LogManager.log_message("[color=cyan]Obtained %dx %s[/color]" % [quantity, item.item_name])
    else:
        Log.error("InventoryManager: Item type not supported: %s" % item.item_type)
```

Position: insert immediately after the `QUEST_ITEM` branch and before the `_:` default branch.

Then in the `#----- PRIVATE FUNCTIONS -----` section, add the helper alongside `_award_material`:

```gdscript
func _award_consumable(consumable: ConsumableDefinitionData, quantity: int) -> void:
    if live_save_data.inventory.consumables.has(consumable):
        live_save_data.inventory.consumables[consumable] += quantity
    else:
        live_save_data.inventory.consumables[consumable] = quantity
    inventory_changed.emit(get_inventory())
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: all five tests (Task 1's test + the four new ones) PASS.

- [ ] **Step 5: Commit**

```
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager_consumables.gd
git commit -m "feat(inventory): route CONSUMABLE awards to consumables dict"
```

---

## Task 4: Extend `InventoryManager.has_item` for consumables

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd:177-193` (the `has_item` method)
- Test: `tests/unit/test_inventory_manager_consumables.gd` (append)

- [ ] **Step 1: Append failing tests**

Append to `tests/unit/test_inventory_manager_consumables.gd`:

```gdscript

#-----------------------------------------------------------------------------
# HAS_ITEM (consumables)
#-----------------------------------------------------------------------------

func test_has_item_returns_true_for_owned_consumable() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable("has_item_test")
	InventoryManager.award_items(def, 2)

	assert_true(InventoryManager.has_item("has_item_test"), "should find owned consumable by item_id")

func test_has_item_returns_false_for_unowned_consumable() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable("not_awarded")
	# NOTE: do not award
	assert_false(InventoryManager.has_item("not_awarded"), "should not find unowned consumable")

func test_has_item_ignores_consumable_with_zero_count() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable("zero_count")
	InventoryManager.award_items(def, 1)
	# Manually zero the count without erasing the key.
	var inv := InventoryManager.get_inventory()
	inv.consumables[def] = 0

	assert_false(InventoryManager.has_item("zero_count"), "consumable with 0 count should not be 'owned'")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: the three new tests FAIL — `has_item` does not scan the `consumables` dict yet.

- [ ] **Step 3: Add the consumables loop to `has_item`**

In `singletons/inventory_manager/inventory_manager.gd`, modify the `has_item` method. Find this code (around lines 177-193):

```gdscript
func has_item(item_id: String) -> bool:
	var inv := get_inventory()
	for material in inv.materials:
		if material and material.item_id == item_id and inv.materials[material] > 0:
			return true
	for slot_idx in inv.equipment:
		var instance: ItemInstanceData = inv.equipment[slot_idx]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for slot in inv.equipped_gear:
		var instance: ItemInstanceData = inv.equipped_gear[slot]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for quest_item in inv.quest_items:
		if quest_item and quest_item.item_id == item_id and inv.quest_items[quest_item] > 0:
			return true
	return false
```

Add the consumables loop *before* the final `return false`, mirroring the materials/quest_items pattern:

```gdscript
	for consumable in inv.consumables:
		if consumable and consumable.item_id == item_id and inv.consumables[consumable] > 0:
			return true
	return false
```

The full updated `has_item` looks like:

```gdscript
func has_item(item_id: String) -> bool:
	var inv := get_inventory()
	for material in inv.materials:
		if material and material.item_id == item_id and inv.materials[material] > 0:
			return true
	for slot_idx in inv.equipment:
		var instance: ItemInstanceData = inv.equipment[slot_idx]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for slot in inv.equipped_gear:
		var instance: ItemInstanceData = inv.equipped_gear[slot]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for quest_item in inv.quest_items:
		if quest_item and quest_item.item_id == item_id and inv.quest_items[quest_item] > 0:
			return true
	for consumable in inv.consumables:
		if consumable and consumable.item_id == item_id and inv.consumables[consumable] > 0:
			return true
	return false
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: all eight tests in the file PASS.

- [ ] **Step 5: Commit**

```
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager_consumables.gd
git commit -m "feat(inventory): extend has_item to scan consumables dict"
```

---

## Task 5: Implement `InventoryManager.use_consumable`

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd` (add new public method)
- Test: `tests/unit/test_inventory_manager_consumables.gd` (append)

- [ ] **Step 1: Append failing tests**

Append to `tests/unit/test_inventory_manager_consumables.gd`. The success-path tests use a `CountingEffect` to verify effects fire without needing a live `VitalsManager`:

```gdscript

#-----------------------------------------------------------------------------
# USE_CONSUMABLE
#-----------------------------------------------------------------------------

## Counter EffectData subclass used to observe process() invocations.
## Mirrors the helper from test_consumable_definition_data.gd; duplicated here
## so each test file stays independently runnable.
class CountingEffect extends EffectData:
	var call_count: int = 0

	func process() -> void:
		call_count += 1

	func _to_string() -> String:
		return "CountingEffect"

func _make_consumable_with_effect(id: String, effect: EffectData) -> ConsumableDefinitionData:
	var def := _make_consumable(id)
	def.effects = [effect]
	return def

func test_use_consumable_with_stock_returns_true_and_decrements() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var effect := CountingEffect.new()
	var def := _make_consumable_with_effect("use_success", effect)
	InventoryManager.award_items(def, 3)

	var result: bool = InventoryManager.use_consumable(def)

	assert_true(result, "use_consumable should return true on success")
	assert_eq(effect.call_count, 1, "effect.process() should be called exactly once")
	var inv := InventoryManager.get_inventory()
	assert_eq(inv.consumables.get(def, 0), 2, "stack should drop from 3 to 2")

func test_use_consumable_to_zero_erases_dict_entry() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable_with_effect("use_to_zero", CountingEffect.new())
	InventoryManager.award_items(def, 1)

	var result: bool = InventoryManager.use_consumable(def)

	assert_true(result, "use_consumable should succeed when stack is 1")
	var inv := InventoryManager.get_inventory()
	assert_false(inv.consumables.has(def), "dict entry should be erased when count drops to 0")
	assert_false(InventoryManager.has_item("use_to_zero"), "has_item should return false after stack hits 0")

func test_use_consumable_with_no_stock_returns_false() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var effect := CountingEffect.new()
	var def := _make_consumable_with_effect("use_empty", effect)
	# Do NOT award.

	var result: bool = InventoryManager.use_consumable(def)

	assert_false(result, "use_consumable should return false with no stock")
	assert_eq(effect.call_count, 0, "effects must not fire when stock is 0")

func test_use_consumable_with_null_def_returns_false() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var result: bool = InventoryManager.use_consumable(null)
	assert_false(result, "use_consumable(null) should return false")

func test_use_consumable_ignores_cooldown_seconds() -> void:
	# Cooldown enforcement is the combat instance's job — InventoryManager
	# should let back-to-back calls both succeed as long as there's stock.
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var effect := CountingEffect.new()
	var def := _make_consumable_with_effect("use_cooldown_ignored", effect)
	def.cooldown_seconds = 999.0  # Long cooldown, but nothing should enforce it here.
	InventoryManager.award_items(def, 2)

	var first: bool = InventoryManager.use_consumable(def)
	var second: bool = InventoryManager.use_consumable(def)

	assert_true(first, "first use should succeed")
	assert_true(second, "second use should ALSO succeed — no cooldown check in InventoryManager")
	assert_eq(effect.call_count, 2, "effects should fire both times")
	var inv := InventoryManager.get_inventory()
	assert_false(inv.consumables.has(def), "stack of 2 should be drained to 0 and erased")

func test_use_consumable_emits_inventory_changed() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return
	_reset_save()

	var def := _make_consumable_with_effect("use_signal", CountingEffect.new())
	InventoryManager.award_items(def, 1)

	watch_signals(InventoryManager)
	InventoryManager.use_consumable(def)

	assert_signal_emitted(InventoryManager, "inventory_changed", "inventory_changed should fire on successful use")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: the six new tests FAIL with "Invalid call. Nonexistent function 'use_consumable'" (or similar).

- [ ] **Step 3: Add `use_consumable` to `InventoryManager`**

In `singletons/inventory_manager/inventory_manager.gd`, add this method in the `#----- PUBLIC API -----` section, after `has_item`:

```gdscript
## Fire the consumable's effects and decrement the player's stack by one.
## Returns true on success, false if the definition is null or the player
## has none in stock. Does NOT check cooldown — that's the caller's job
## (the future CombatConsumableInstance handles it).
func use_consumable(def: ConsumableDefinitionData) -> bool:
	if def == null:
		Log.error("InventoryManager.use_consumable: null definition")
		return false

	var inventory := get_inventory()
	var count: int = inventory.consumables.get(def, 0)
	if count <= 0:
		Log.warn("InventoryManager.use_consumable: no %s available" % def.item_id)
		return false

	def.use()
	if count == 1:
		inventory.consumables.erase(def)
	else:
		inventory.consumables[def] = count - 1
	inventory_changed.emit(inventory)
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager_consumables.gd -gexit
```

Expected: all fourteen tests in the file PASS.

- [ ] **Step 5: Commit**

```
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager_consumables.gd
git commit -m "feat(inventory): add use_consumable verb (no cooldown check)"
```

---

## Task 6: Create the Barely Coalesced Scale effect resource

This task creates the `ChangeVitalsEffectData` `.tres` that the consumable will reference.

**Files:**
- Create: `resources/effects/change_vitals/barely_coalesced_scale_effect.tres`

- [ ] **Step 1: Create the resource via the Godot editor**

Open the Godot editor and:

1. In the FileSystem dock, right-click `resources/effects/` → New Folder → name it `change_vitals` (if it doesn't already exist).
2. Right-click `resources/effects/change_vitals/` → New Resource → search for `ChangeVitalsEffectData` → Create.
3. Set fields:
   - `madra_change`: `20.0`
   - `health_change`: `0.0`
   - `stamina_change`: `0.0`
   - `body_hp_multiplier`: `0.0`
   - `foundation_madra_multiplier`: `0.0`
4. Save as `barely_coalesced_scale_effect.tres`.

If the editor isn't available, create the file directly. The expected file content (with auto-generated uids) should look approximately like:

```
[gd_resource type="Resource" script_class="ChangeVitalsEffectData" load_steps=2 format=3 uid="uid://<NEW_UID>"]

[ext_resource type="Script" uid="uid://<EXISTING_SCRIPT_UID>" path="res://scripts/resource_definitions/effects/change_vitals_effect_data.gd" id="1_<HASH>"]

[resource]
script = ExtResource("1_<HASH>")
madra_change = 20.0
metadata/_custom_type_script = "uid://<EXISTING_SCRIPT_UID>"
```

The Godot editor will fill in real UIDs. Do NOT hand-edit UIDs — open it in the editor instead and use Save.

- [ ] **Step 2: Verify the resource loads**

Open a Godot script editor scratch buffer or just confirm the editor's "Errors" tab is clean. The file should load without parse errors.

- [ ] **Step 3: Commit**

```
git add resources/effects/change_vitals/
git commit -m "feat(consumables): add ChangeVitalsEffectData resource for +20 madra"
```

---

## Task 7: Create the `barely_coalesced_scale.tres` resource

This is the consumable definition itself, referencing the effect from Task 6.

**Files:**
- Create: `resources/items/consumables/barely_coalesced_scale.tres`

- [ ] **Step 1: Create the resource via the Godot editor**

1. In the FileSystem dock, right-click `resources/items/` → New Folder → name it `consumables`.
2. Right-click `resources/items/consumables/` → New Resource → search for `ConsumableDefinitionData` → Create.
3. Set fields in the inspector:
   - `item_id`: `barely_coalesced_scale`
   - `item_name`: `Barely Coalesced Scale`
   - `description`: `A poorly-formed flake of madra, scarcely worth the name. Crude practitioners still find a use for them.`
   - `item_type`: leave at `CONSUMABLE` (set by `_init`).
   - `icon`: leave empty for now (placeholder until art).
   - `stack_size`: `99` (inherited default).
   - `base_value`: `1.0`.
   - `effects`: array of size 1, slot 0 = drag `resources/effects/change_vitals/barely_coalesced_scale_effect.tres` from the FileSystem dock into the slot.
   - `cooldown_seconds`: `10.0`
4. Save as `barely_coalesced_scale.tres`.

Expected file content (uids vary):

```
[gd_resource type="Resource" script_class="ConsumableDefinitionData" load_steps=3 format=3 uid="uid://<NEW_UID>"]

[ext_resource type="Script" uid="uid://<CONSUMABLE_SCRIPT_UID>" path="res://scripts/resource_definitions/items/consumable_definition_data.gd" id="1_<HASH>"]
[ext_resource type="Resource" uid="uid://<EFFECT_TRES_UID>" path="res://resources/effects/change_vitals/barely_coalesced_scale_effect.tres" id="2_<HASH>"]

[resource]
script = ExtResource("1_<HASH>")
effects = Array[Resource("res://scripts/resource_definitions/effects/effect_data.gd")]([ExtResource("2_<HASH>")])
cooldown_seconds = 10.0
item_id = "barely_coalesced_scale"
item_name = "Barely Coalesced Scale"
description = "A poorly-formed flake of madra, scarcely worth the name. Crude practitioners still find a use for them."
base_value = 1.0
metadata/_custom_type_script = "uid://<CONSUMABLE_SCRIPT_UID>"
```

- [ ] **Step 2: Verify the resource loads**

Open the file in the inspector and confirm:
- `item_type` shows `CONSUMABLE`
- `effects[0]` shows the ChangeVitalsEffectData resource with `madra_change: 20.0`
- No parse errors in the Errors tab.

- [ ] **Step 3: Commit**

```
git add resources/items/consumables/
git commit -m "feat(consumables): add Barely Coalesced Scale .tres (+20 madra, 10s cd metadata)"
```

---

## Task 8: Resource-loading regression test

Lock in the `.tres` field values with a regression test so future inspector edits can't silently change them.

**Files:**
- Create: `tests/unit/test_barely_coalesced_scale_tres.gd`

- [ ] **Step 1: Write the test**

Create `tests/unit/test_barely_coalesced_scale_tres.gd`:

```gdscript
extends GutTest

## Regression test: locks in the field values on the shipped
## Barely Coalesced Scale .tres so future inspector edits are intentional.

const SCALE_PATH := "res://resources/items/consumables/barely_coalesced_scale.tres"

var _def: ConsumableDefinitionData

func before_each() -> void:
	_def = load(SCALE_PATH)

func test_tres_loads_as_consumable_definition_data() -> void:
	assert_not_null(_def, "barely_coalesced_scale.tres should load")
	assert_true(_def is ConsumableDefinitionData,
		"loaded resource should be a ConsumableDefinitionData")

func test_item_identity_fields() -> void:
	assert_eq(_def.item_id, "barely_coalesced_scale", "item_id locked")
	assert_eq(_def.item_name, "Barely Coalesced Scale", "item_name locked")
	assert_eq(_def.item_type, ItemDefinitionData.ItemType.CONSUMABLE, "item_type locked")

func test_cooldown_seconds_locked() -> void:
	assert_eq(_def.cooldown_seconds, 10.0, "cooldown_seconds locked at 10.0")

func test_effects_array_has_one_change_vitals_effect() -> void:
	assert_eq(_def.effects.size(), 1, "should have exactly one effect")
	var effect = _def.effects[0]
	assert_true(effect is ChangeVitalsEffectData,
		"effect should be a ChangeVitalsEffectData")

func test_effect_grants_twenty_madra_only() -> void:
	var effect: ChangeVitalsEffectData = _def.effects[0]
	assert_eq(effect.madra_change, 20.0, "madra_change locked at 20.0")
	assert_eq(effect.health_change, 0.0, "health_change should be 0")
	assert_eq(effect.stamina_change, 0.0, "stamina_change should be 0")
	assert_eq(effect.body_hp_multiplier, 0.0, "body_hp_multiplier should be 0")
	assert_eq(effect.foundation_madra_multiplier, 0.0, "foundation_madra_multiplier should be 0")
```

- [ ] **Step 2: Run the test to verify it passes**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_barely_coalesced_scale_tres.gd -gexit
```

Expected: all 5 tests PASS. (No red phase here — we're locking in already-correct values from Tasks 6-7.)

- [ ] **Step 3: Commit**

```
git add tests/unit/test_barely_coalesced_scale_tres.gd
git commit -m "test(consumables): lock in barely_coalesced_scale.tres field values"
```

---

## Task 9: Full suite green-light

Confirm the full unit suite still passes — no regressions in the existing inventory or vitals tests.

- [ ] **Step 1: Run the full unit suite**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: all tests PASS, including the existing `test_inventory_manager.gd`, `test_change_vitals_effect_data.gd`, and the three new consumable tests.

- [ ] **Step 2: If anything fails, diagnose and fix**

The most likely failure modes:

1. **`test_inventory_manager.gd` `test_inventory_starts_empty`** — that test asserts the existing sub-collections are empty but doesn't yet know about `consumables`. If it fails due to the added field, add an assertion: `assert_eq(_inventory.consumables.size(), 0, "consumables should start empty")`. This is a real fix — the existing test should cover the new field too.
2. **InventoryData `_to_string()` consumers** — search the codebase for any test or log that asserts on the exact string format. If found, update them. Run `grep -r "InventoryData(materials:" .` to check.
3. **Type-dict load errors** — if Godot complains about `Dictionary[ConsumableDefinitionData, int]` on save load, confirm `ConsumableDefinitionData` is preloaded (it should be via `class_name`).

- [ ] **Step 3: If fixes were needed, commit**

```
git add <touched-files>
git commit -m "test: cover consumables in existing inventory regression tests"
```

If no fixes were needed, skip the commit.

---

## Self-Review Notes

After writing this plan, I checked it against the spec:

**Spec coverage:**
- `ConsumableDefinitionData` resource with `effects` + `cooldown_seconds` + `use()` + `_get_item_effects()` → Task 2
- `InventoryData.consumables` field → Task 1
- `InventoryManager.award_items` CONSUMABLE branch + `_award_consumable` → Task 3
- `InventoryManager.has_item` extension → Task 4
- `InventoryManager.use_consumable(def) -> bool` → Task 5
- `barely_coalesced_scale.tres` with the listed field values → Tasks 6 (effect) + 7 (consumable)
- All test cases from the spec's testing section → covered across Tasks 2, 3, 4, 5, 8
- Task 9 catches any regressions in existing tests

**Type consistency:** All method signatures and field types in later tasks (`Dictionary[ConsumableDefinitionData, int]`, `Array[EffectData]`, `cooldown_seconds: float`, `use_consumable(def: ConsumableDefinitionData) -> bool`) match what Task 1-2 define.

**Test framework:** Plan uses GUT (`extends GutTest`, `assert_eq`, `before_each`, `pass_test`, `watch_signals`, `assert_signal_emitted`) matching the project's existing tests. The spec mentioned "GdUnit4" but the project actually uses GUT — the plan is correct, the spec text is a minor inaccuracy that doesn't affect implementation.

**No placeholders:** Every code block contains the full code an engineer would type. No "implement the method" or "add appropriate error handling." Commit commands and test commands include exact paths.
