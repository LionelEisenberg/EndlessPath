# Beat 3b + Merchant Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Beat 3b's full chain — CD 10 → NPC dialogue 4 → map quest item → refugee camp special encounter → Merchant zone action stub. Along the way, implement the declared-but-unimplemented `UnlockConditionData.ITEM_OWNED` condition and add `unlock_conditions` support to `AdventureEncounter`.

**Architecture:** Three small script changes (Inventory, UnlockCondition, AdventureEncounter/MapGenerator, ActionManager) plus a set of `.tres` resources and a dialogue timeline label. The Merchant click is a hard-coded stub in `ActionManager` that logs a "coming soon" message; no new UI or scene is created. Map generator filters `special_encounter_pool` by per-encounter `unlock_conditions` before placement, so gated encounters silently drop out of the pool.

**Tech Stack:** Godot 4.5, GDScript, GUT v9.6.0.

**Spec reference:** [2026-04-21-beat-3b-merchant-unlock-design.md](../specs/2026-04-21-beat-3b-merchant-unlock-design.md)

**Common commands used below:**
- Run a single unit test file:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<FILE>.gd -gexit
  ```
- Run the whole suite:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
  ```
- If class names are missing ("Class not found: GutTest" etc.), import the project first:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
  ```

---

## Task 1: Add `quest_items` dictionary to `InventoryData`

Add the typed dictionary that will hold quest-item stacks. No behavior change yet — just a schema slot.

**Files:**
- Modify: `singletons/persistence_manager/inventory_data.gd`

- [ ] **Step 1: Add the field**

Open `singletons/persistence_manager/inventory_data.gd` and add the new `@export` line after the existing `equipped_gear` line so the block reads:

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

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, quest_items: %s)" % [materials, equipment, equipped_gear, quest_items]
```

Note the `_to_string()` also includes `quest_items` now.

- [ ] **Step 2: Sanity-check by opening the project**

Open the project in Godot once to trigger a re-import:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no parse errors printed.

- [ ] **Step 3: Commit**

```bash
git add singletons/persistence_manager/inventory_data.gd
git commit -m "feat(inventory): add quest_items dict to InventoryData

Prepares the schema for QUEST_ITEM awards. No behavior change yet."
```

---

## Task 2: Add QUEST_ITEM handling to `InventoryManager.award_items`

Extend the match in `award_items` so `AwardItemEffectData` can hand off a quest item without logging an error.

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager.gd`

- [ ] **Step 1: Write failing test**

Open `tests/unit/test_inventory_manager.gd` and append to the bottom (above the last section if present, otherwise at EOF) the new section:

```gdscript
#-----------------------------------------------------------------------------
# AWARD ITEMS - QUEST ITEMS
#-----------------------------------------------------------------------------

func test_award_quest_item_new() -> void:
	var def := ItemDefinitionData.new()
	def.item_id = "test_map"
	def.item_name = "Test Map"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM

	_inventory.quest_items[def] = 1
	assert_eq(_inventory.quest_items[def], 1, "quest item should be stored by definition")

func test_award_quest_item_stacks() -> void:
	var def := ItemDefinitionData.new()
	def.item_id = "test_map"
	def.item_name = "Test Map"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM

	_inventory.quest_items[def] = 1
	_inventory.quest_items[def] += 2
	assert_eq(_inventory.quest_items[def], 3, "quest items should stack")

func test_award_items_quest_item_lands_in_quest_items() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	# Reset live save data so prior tests don't leak into this one.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var def := ItemDefinitionData.new()
	def.item_id = "test_map_award"
	def.item_name = "Test Map Award"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM

	InventoryManager.award_items(def, 1)

	var inv := InventoryManager.get_inventory()
	assert_eq(inv.quest_items.get(def, 0), 1, "quest item should land in quest_items dict")
	assert_eq(inv.materials.size(), 0, "quest item must not land in materials")
	assert_eq(inv.equipment.size(), 0, "quest item must not land in equipment grid")
```

- [ ] **Step 2: Run failing test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: `test_award_items_quest_item_lands_in_quest_items` fails because `InventoryManager.award_items` currently logs an error for `QUEST_ITEM` and never adds it.

- [ ] **Step 3: Implement**

In `singletons/inventory_manager/inventory_manager.gd`, find the `func award_items(...)` match statement. Add a new arm for `QUEST_ITEM` before the catch-all `_:` arm:

```gdscript
		ItemDefinitionData.ItemType.QUEST_ITEM:
			_award_quest_item(item, quantity)
			if LogManager:
				LogManager.log_message("[color=yellow]Obtained %dx %s[/color]" % [quantity, item.item_name])
```

Then add the helper function inside the `PRIVATE FUNCTIONS` section (next to `_award_material`):

```gdscript
func _award_quest_item(item: ItemDefinitionData, quantity: int) -> void:
	if live_save_data.inventory.quest_items.has(item):
		live_save_data.inventory.quest_items[item] += quantity
	else:
		live_save_data.inventory.quest_items[item] = quantity
	inventory_changed.emit(get_inventory())
```

- [ ] **Step 4: Run test to verify pass**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: all three new tests pass. Existing tests unchanged.

- [ ] **Step 5: Commit**

```bash
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager.gd
git commit -m "feat(inventory): handle QUEST_ITEM in award_items

Quest items now land in the new quest_items dictionary. Emits
item_awarded + inventory_changed consistently with other types."
```

---

## Task 3: Add `InventoryManager.has_item`

Convenience accessor used by the new `ITEM_OWNED` condition. Checks materials, unequipped grid, equipped gear, and quest items.

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager.gd`

- [ ] **Step 1: Write failing test**

Append to `tests/unit/test_inventory_manager.gd`:

```gdscript
#-----------------------------------------------------------------------------
# HAS_ITEM
#-----------------------------------------------------------------------------

func test_has_item_false_when_inventory_empty() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	assert_false(InventoryManager.has_item("nothing"), "empty inventory should report no items")

func test_has_item_true_for_quest_item() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var def := ItemDefinitionData.new()
	def.item_id = "quest_test_x"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM
	InventoryManager.award_items(def, 1)

	assert_true(InventoryManager.has_item("quest_test_x"), "should find the quest item by id")
	assert_false(InventoryManager.has_item("unrelated_id"), "other ids should not match")

func test_has_item_true_for_material() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var mat := MaterialDefinitionData.new()
	mat.item_id = "mat_test_x"
	mat.item_type = ItemDefinitionData.ItemType.MATERIAL
	InventoryManager.award_items(mat, 5)

	assert_true(InventoryManager.has_item("mat_test_x"), "should find the material by id")

func test_has_item_true_for_equipped_gear() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var def := EquipmentDefinitionData.new()
	def.item_id = "gear_test_x"
	def.item_name = "Test Gear"
	def.item_type = ItemDefinitionData.ItemType.EQUIPMENT
	def.slot_type = EquipmentDefinitionData.EquipmentSlot.MAIN_HAND

	# Award then equip so the item lives in equipped_gear, not the grid.
	InventoryManager.award_items(def, 1)
	var inv := InventoryManager.get_inventory()
	assert_eq(inv.equipment.size(), 1, "item should first be in grid")
	var instance: ItemInstanceData = inv.equipment[inv.equipment.keys()[0]]
	InventoryManager.equip_item(instance, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)

	assert_true(InventoryManager.has_item("gear_test_x"), "equipped gear should count as owned")
```

- [ ] **Step 2: Run failing test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: tests fail with `has_item` undefined.

- [ ] **Step 3: Implement**

Add to `singletons/inventory_manager/inventory_manager.gd` in the `PUBLIC API` section (right after `get_equipped_item`):

```gdscript
## Returns true if the player owns at least one item with the given item_id
## across materials, unequipped gear, equipped gear, or quest items.
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

- [ ] **Step 4: Run test to verify pass**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: all four `has_item` tests pass.

- [ ] **Step 5: Commit**

```bash
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager.gd
git commit -m "feat(inventory): add InventoryManager.has_item

Lookup across materials, unequipped grid, equipped gear, and quest
items by item_id. Used by the ITEM_OWNED unlock condition."
```

---

## Task 4: Implement `UnlockConditionData.ITEM_OWNED`

Replace the warning stub with a real evaluation that asks `InventoryManager`.

**Files:**
- Modify: `scripts/resource_definitions/unlocks/unlock_condition_data.gd`
- Test: `tests/unit/test_unlock_condition_item_owned.gd` (new)

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_unlock_condition_item_owned.gd` with:

```gdscript
extends GutTest

## Unit tests for UnlockConditionData.ITEM_OWNED.

const ITEM_ID: String = "itm_owned_test"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_condition(negate: bool = false) -> UnlockConditionData:
	var cond := UnlockConditionData.new()
	cond.condition_id = "has_%s" % ITEM_ID
	cond.condition_type = UnlockConditionData.ConditionType.ITEM_OWNED
	cond.target_value = ITEM_ID
	cond.negate = negate
	return cond

func _award_quest_item() -> void:
	var def := ItemDefinitionData.new()
	def.item_id = ITEM_ID
	def.item_name = "Owned Test Item"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM
	InventoryManager.award_items(def, 1)

func test_item_owned_false_when_not_owned() -> void:
	var cond := _make_condition()
	assert_false(cond.evaluate(), "should be false when inventory is empty")

func test_item_owned_true_when_owned() -> void:
	_award_quest_item()
	var cond := _make_condition()
	assert_true(cond.evaluate(), "should be true after awarding the item")

func test_item_owned_negate_inverts() -> void:
	var cond := _make_condition(true)
	assert_true(cond.evaluate(), "negated + not owned -> true")

	_award_quest_item()
	assert_false(cond.evaluate(), "negated + owned -> false")
```

- [ ] **Step 2: Run failing test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_unlock_condition_item_owned.gd -gexit
```
Expected: `test_item_owned_true_when_owned` fails — current `ITEM_OWNED` arm always returns false.

- [ ] **Step 3: Implement**

In `scripts/resource_definitions/unlocks/unlock_condition_data.gd`, replace the existing `ITEM_OWNED` arm:

```gdscript
			ConditionType.ITEM_OWNED:
				Log.warn("UnlockConditionData: ITEM_OWNED not yet implemented")
				return false
```

with:

```gdscript
			ConditionType.ITEM_OWNED:
				if not InventoryManager:
					Log.error("UnlockConditionData: InventoryManager is not initialized")
					return false
				return InventoryManager.has_item(str(target_value))
```

Note: The Beat-3a `negate` refactor has already moved inversion into a wrapper (`evaluate()` calls `_evaluate_raw()` and inverts once at the end). If the file you are looking at still uses early-return `match`, the negated-inversion test will fail; check the file and follow whichever pattern is present. If the wrapper is in place, the above replacement is complete.

- [ ] **Step 4: Run test to verify pass**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_unlock_condition_item_owned.gd -gexit
```
Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/resource_definitions/unlocks/unlock_condition_data.gd tests/unit/test_unlock_condition_item_owned.gd
git commit -m "feat(unlocks): implement ITEM_OWNED condition

Queries InventoryManager.has_item with target_value as item_id.
Unblocks item-driven gating for quest items like the refugee-camp map."
```

---

## Task 5: Add `unlock_conditions` field to `AdventureEncounter`

Per-encounter gates evaluated at map-generation time. Default `[]` means "always eligible", so all existing encounters keep current behavior.

**Files:**
- Modify: `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`

- [ ] **Step 1: Read the current file**

Open `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` and confirm its current fields. Find the property block.

- [ ] **Step 2: Add the field**

Add the following `@export` to the file (after existing exports, before any methods):

```gdscript
## Optional gates evaluated at map-generation time. Encounters with unmet
## conditions are filtered out of the random pool before placement — the player
## never sees them.
@export var unlock_conditions: Array[UnlockConditionData] = []
```

- [ ] **Step 3: Sanity check**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no parse errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/resource_definitions/adventure/encounters/adventure_encounter.gd
git commit -m "feat(adventure): add unlock_conditions to AdventureEncounter

Optional gates evaluated at map-generation time. Default empty means
always eligible, so all existing encounters are unaffected."
```

---

## Task 6: Filter `special_encounter_pool` by `unlock_conditions` in the map generator

When building the pool of special encounters, drop any whose `unlock_conditions` don't all evaluate true.

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`
- Test: `tests/unit/test_adventure_map_generator_filter.gd` (new)

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_adventure_map_generator_filter.gd`:

```gdscript
extends GutTest

## Verifies that the map generator filters special_encounter_pool entries by
## their unlock_conditions before selecting one for each special tile.

const TEST_EVENT: String = "test_filter_event"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_gated_encounter() -> AdventureEncounter:
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = TEST_EVENT
	var enc := AdventureEncounter.new()
	enc.encounter_id = "gated"
	enc.unlock_conditions = [cond]
	return enc

func _make_open_encounter() -> AdventureEncounter:
	var enc := AdventureEncounter.new()
	enc.encounter_id = "open"
	return enc

func test_filter_drops_gated_encounters_when_unmet() -> void:
	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()

	var pool: Array = [_make_gated_encounter(), _make_open_encounter()]
	var eligible: Array = generator._build_eligible_special_pool(pool)

	assert_eq(eligible.size(), 1, "only the open encounter should be eligible")
	assert_eq(eligible[0].encounter_id, "open")
	generator.queue_free()

func test_filter_keeps_gated_encounters_when_met() -> void:
	EventManager.trigger_event(TEST_EVENT)

	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()

	var pool: Array = [_make_gated_encounter(), _make_open_encounter()]
	var eligible: Array = generator._build_eligible_special_pool(pool)

	assert_eq(eligible.size(), 2, "both encounters should be eligible once event fires")
	generator.queue_free()
```

- [ ] **Step 2: Run failing test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_adventure_map_generator_filter.gd -gexit
```
Expected: failure — `_build_eligible_special_pool` does not exist.

- [ ] **Step 3: Implement helper + integrate into `_assign_special_tiles`**

Open `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`. Add the new helper near the other private functions:

```gdscript
## Filters a pool of encounters by their unlock_conditions. Encounters with any
## unmet condition are dropped so gated content never lands on a tile the player
## hasn't earned access to.
func _build_eligible_special_pool(pool: Array) -> Array:
	var eligible: Array = []
	for encounter in pool:
		if encounter == null:
			continue
		var ok: bool = true
		for condition in encounter.unlock_conditions:
			if not condition.evaluate():
				ok = false
				break
		if ok:
			eligible.append(encounter)
	return eligible
```

Then replace the random-pick line in `_assign_special_tiles()` (the existing line at ~108 is):

```gdscript
		all_map_tiles[coord] = adventure_data.special_encounter_pool[randi_range(0, adventure_data.special_encounter_pool.size() - 1)]
```

Refactor the function body to build the eligible pool once, then pick from it:

```gdscript
func _assign_special_tiles() -> void:
	if adventure_data.special_encounter_pool.is_empty():
		Log.warn("AdventureMapGenerator: Can't Assign Encounters to special tiles as encounter pool is empty")
		return

	var eligible_pool: Array = _build_eligible_special_pool(adventure_data.special_encounter_pool)
	if eligible_pool.is_empty():
		Log.warn("AdventureMapGenerator: No eligible special encounters after filter; leaving tiles as no-op")
		# Still place the boss on the furthest tile below.
	var furthest_node_coord = Vector3i.ZERO
	var furthest_distance = 0
	for coord in all_map_tiles.keys():
		var distance_to_origin = tile_map.cube_distance(Vector3i.ZERO, coord)
		if distance_to_origin >= furthest_distance:
			furthest_node_coord = coord
			furthest_distance = distance_to_origin
		if coord == Vector3i.ZERO:
			continue
		if not eligible_pool.is_empty():
			all_map_tiles[coord] = eligible_pool[randi_range(0, eligible_pool.size() - 1)]
		# else: leave the NoOpEncounter placed earlier in _place_special_tiles.

	all_map_tiles[furthest_node_coord] = adventure_data.boss_encounter
```

- [ ] **Step 4: Run test to verify pass**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_adventure_map_generator_filter.gd -gexit
```
Expected: both tests pass.

- [ ] **Step 5: Run the full unit suite as a regression check**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```
Expected: no regressions in existing adventure / inventory / unlock tests.

- [ ] **Step 6: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_map_generator.gd tests/unit/test_adventure_map_generator_filter.gd
git commit -m "feat(adventure): filter special_encounter_pool by unlock_conditions

Gated encounters now drop out of the random pool when their
conditions fail. Empty filtered pools leave the no-op placeholder so
the boss tile still lands on the furthest node."
```

---

## Task 7: Add MERCHANT handlers in `ActionManager`

The Merchant zone action's click path currently hits the `_: Log.error` arm. Add a minimal stub handler that logs a "coming soon" message and immediately stops the action.

**Files:**
- Modify: `singletons/action_manager/action_manager.gd`

- [ ] **Step 1: Add the `_execute_merchant_action` handler**

Open `singletons/action_manager/action_manager.gd`. In `_execute_action`'s `match` block, add an arm for `MERCHANT` before the catch-all `_:`:

```gdscript
		ZoneActionData.ActionType.MERCHANT:
			_execute_merchant_action(action_data)
```

In `_stop_executing_current_action`'s match block, add the matching stop arm before the catch-all:

```gdscript
				ZoneActionData.ActionType.MERCHANT:
					_stop_merchant_action(successful)
```

- [ ] **Step 2: Add the handler functions**

Add these near the other `_execute_*` / `_stop_*` handlers (keep sections consistent):

```gdscript
## Handle merchant action - stub: log a "coming soon" message and end the action.
func _execute_merchant_action(action_data: ZoneActionData) -> void:
	Log.info("ActionManager: Executing merchant action (stub): %s" % action_data.action_name)
	if LogManager:
		LogManager.log_message("[color=yellow]The merchant nods at you. (Shop coming soon.)[/color]")
	stop_action()

## Handle merchant action stop - just run completion effects (none in the stub).
func _stop_merchant_action(successful: bool) -> void:
	_process_completion_effects(successful)
```

- [ ] **Step 3: Sanity-check parse**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no parse errors.

- [ ] **Step 4: Commit**

```bash
git add singletons/action_manager/action_manager.gd
git commit -m "feat(zone-actions): stub Merchant action handler

Logs a 'coming soon' message and stops the action immediately. No
new scene or UI; the real shop lands in a later beat."
```

---

## Task 8: Create the Refugee Camp Map quest item

Static data file for the map that the NPC hands over.

**Files:**
- Create: `resources/items/quest_items/refugee_camp_map.tres`

- [ ] **Step 1: Create the folder and .tres**

Create the new folder `resources/items/quest_items/` if it doesn't exist, then create `resources/items/quest_items/refugee_camp_map.tres` with this content:

```
[gd_resource type="Resource" script_class="ItemDefinitionData" load_steps=3 format=3 uid="uid://bitem_refugee_map"]

[ext_resource type="Script" uid="uid://cuag0kvf84qnl" path="res://scripts/resource_definitions/items/item_definition_data.gd" id="1_itm"]
[ext_resource type="Texture2D" uid="uid://bmt3ti63lgbi5" path="res://64.png" id="2_icon"]

[resource]
script = ExtResource("1_itm")
item_id = "refugee_camp_map"
item_name = "Refugee Camp Map"
description = "A hand-drawn map leading to a camp of survivors hidden in the valley."
icon = ExtResource("2_icon")
item_type = 3
stack_size = 1
base_value = 0.0
metadata/_custom_type_script = "uid://cuag0kvf84qnl"
```

Notes:
- `item_type = 3` corresponds to `ItemType.QUEST_ITEM` (enum order: MATERIAL=0, CONSUMABLE=1, EQUIPMENT=2, QUEST_ITEM=3).
- UIDs above are the real ones in this checkout (verified via `.uid` files). If a Godot re-import rewrites UIDs and these stop matching, copy the fresh UIDs from the `.gd.uid` files in `scripts/resource_definitions/items/` and `64.png.import` respectively.

- [ ] **Step 2: Verify resource loads**

Open the project in Godot headless import pass:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: `.tres` parses cleanly, no "Resource file not found" errors.

- [ ] **Step 3: Commit**

```bash
git add resources/items/quest_items/refugee_camp_map.tres
git commit -m "feat(items): add Refugee Camp Map quest item

Handed to the player on q_reach_core_density_10 completion. Gates
the refugee camp special encounter via ITEM_OWNED."
```

---

## Task 9: Create `merchant_discovered` condition + register it

Standalone UnlockConditionData so UnlockManager emits reactive signals when the event fires (the Merchant zone action gates on visibility).

**Files:**
- Create: `resources/unlocks/merchant_discovered.tres`
- Modify: `resources/unlocks/unlock_condition_list.tres`

- [ ] **Step 1: Create the condition**

Create `resources/unlocks/merchant_discovered.tres`:

```
[gd_resource type="Resource" script_class="UnlockConditionData" load_steps=2 format=3 uid="uid://bunlock_mrch_discov"]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_cond"]

[resource]
script = ExtResource("1_cond")
condition_id = "merchant_discovered"
condition_type = 4
target_value = "merchant_discovered"
comparison_op = ">="
metadata/_custom_type_script = "uid://bk5wuop0jogg4"
```

Notes:
- `condition_type = 4` = `EVENT_TRIGGERED`.
- `comparison_op` is unused for EVENT_TRIGGERED but kept for compatibility with the existing files.
- `negate` defaults to false.

- [ ] **Step 2: Register it in the list**

Open `resources/unlocks/unlock_condition_list.tres`. Add a new `[ext_resource]` entry and append it to the `list` array. After editing, the file should look like (only showing the lines you change — keep all other lines intact):

Add a new ext_resource line (use the next available id — e.g., `id="9_mrch"`):

```
[ext_resource type="Resource" uid="uid://bunlock_mrch_discov" path="res://resources/unlocks/merchant_discovered.tres" id="9_mrch"]
```

Update the `list` array to include the new reference:

```
list = Array[ExtResource("1_aq0o0")]([ExtResource("2_tsp8q"), ExtResource("3_pa8gf"), ExtResource("4_qfcm1"), ExtResource("5_qfc01"), ExtResource("6_qfsed"), ExtResource("7_qrcd"), ExtResource("8_awd"), ExtResource("9_mrch")])
```

- [ ] **Step 3: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no resource-loading errors.

- [ ] **Step 4: Commit**

```bash
git add resources/unlocks/merchant_discovered.tres resources/unlocks/unlock_condition_list.tres
git commit -m "feat(unlocks): register merchant_discovered condition

Wraps the merchant_discovered event so UnlockManager emits reactive
signals — the Merchant zone-action visibility depends on that."
```

---

## Task 10: Create the Refugee Camp encounter

Inline both gating conditions and the single "Approach the camp" choice.

**Files:**
- Create: `resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres`

- [ ] **Step 1: Create the encounter file**

Create `resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres`:

```
[gd_resource type="Resource" script_class="AdventureEncounter" format=3 uid="uid://brefugee_camp_enc"]

[ext_resource type="Script" uid="uid://cs335nesm7wfr" path="res://scripts/resource_definitions/adventure/encounters/adventure_encounter.gd" id="1_encounter"]
[ext_resource type="Script" uid="uid://c1b11mq3a2qya" path="res://scripts/resource_definitions/adventure/choices/encounter_choice.gd" id="2_choice"]
[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="3_effect"]
[ext_resource type="Script" uid="uid://cc0ky7w2fsg10" path="res://scripts/resource_definitions/effects/trigger_event_effect_data.gd" id="4_trigger"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="5_cond"]

[sub_resource type="Resource" id="Resource_cond_map_owned"]
script = ExtResource("5_cond")
condition_id = "refugee_camp_map_owned"
condition_type = 5
target_value = "refugee_camp_map"
comparison_op = ">="

[sub_resource type="Resource" id="Resource_cond_not_discovered"]
script = ExtResource("5_cond")
condition_id = "merchant_not_yet_discovered"
condition_type = 4
target_value = "merchant_discovered"
comparison_op = ">="
negate = true

[sub_resource type="Resource" id="Resource_trigger_merchant"]
script = ExtResource("4_trigger")
event_id = "merchant_discovered"

[sub_resource type="Resource" id="Resource_approach_choice"]
script = ExtResource("2_choice")
label = "Approach the camp"
tooltip = "Show them the map and see what they trade."
success_effects = Array[ExtResource("3_effect")]([SubResource("Resource_trigger_merchant")])

[resource]
script = ExtResource("1_encounter")
encounter_id = "refugee_camp"
encounter_name = "Refugee Camp"
description = "A cluster of makeshift tents under the trees. A merchant's wagon leans against a rock, its owner watching you approach."
text_description_completed = "The camp is empty now — they must have moved on, following your map back to the valley."
encounter_type = 4
unlock_conditions = Array[ExtResource("5_cond")]([SubResource("Resource_cond_map_owned"), SubResource("Resource_cond_not_discovered")])
choices = Array[ExtResource("2_choice")]([SubResource("Resource_approach_choice")])
metadata/_custom_type_script = "uid://cs335nesm7wfr"
```

Notes:
- `condition_type = 5` = `ITEM_OWNED`, `= 4` = `EVENT_TRIGGERED`.
- `encounter_type = 4` = `REST_SITE` (reuses the existing icon; a dedicated glyph is future polish).

- [ ] **Step 2: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres
git commit -m "feat(adventure): add refugee camp special encounter

Gated on ITEM_OWNED(refugee_camp_map) AND NOT merchant_discovered.
Visiting fires merchant_discovered, unlocking the Merchant zone
action stub."
```

---

## Task 11: Add the `dialogue_4` timeline label + NPC 4 zone action

Two sub-tasks in one — the dialogue text and the NpcDialogueActionData that opens it.

**Files:**
- Modify: `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`
- Create: `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres`

- [ ] **Step 1: Append the dialogue_4 label**

Open `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`. Append at end (keep existing labels untouched):

```
label dialogue_4
join celestial_intervener center
celestial_intervener: Look at you! Core's humming nicely now, eh? Right before I slip off, I'm gonna leave you something useful.
celestial_intervener: Here, take this map. There's a little refugee camp tucked away in the woods — go find them. Got a merchant with them who'll trade you real gear for coin. Tell 'em I sent you!
leave celestial_intervener
[end_timeline]
```

- [ ] **Step 2: Create the zone-action resource**

Create `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres`:

```
[gd_resource type="Resource" script_class="NpcDialogueActionData" format=3 uid="uid://cnpc40act001"]

[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="1_effect"]
[ext_resource type="Script" uid="uid://10xqk22j564o" path="res://scripts/resource_definitions/zones/zone_action_data/npc_dialogue_action_data/npc_dialogue_action_data.gd" id="2_npc"]
[ext_resource type="Script" uid="uid://cc0ky7w2fsg10" path="res://scripts/resource_definitions/effects/trigger_event_effect_data.gd" id="3_trigger"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="4_cond"]
[ext_resource type="Resource" uid="uid://i2xnqd3pem53" path="res://resources/unlocks/q_reach_cd_10.tres" id="5_cd10"]

[sub_resource type="Resource" id="Resource_trigger_dialogue_4"]
script = ExtResource("3_trigger")
event_id = "celestial_intervener_dialogue_4"
effect_type = 1
metadata/_custom_type_script = "uid://cc0ky7w2fsg10"

[resource]
script = ExtResource("2_npc")
dialogue_timeline_name = "celestial_intervener_introduction_1"
dialogue_timeline_label_jump = "dialogue_4"
action_id = "celestial_intervener_dialogue_4"
action_name = "Return to the [INTERVENER]"
action_type = 2
description = "Your core is tempered. Report back to the [INTERVENER] before they leave."
unlock_conditions = Array[ExtResource("4_cond")]([ExtResource("5_cd10")])
max_completions = 1
success_effects = Array[ExtResource("1_effect")]([SubResource("Resource_trigger_dialogue_4")])
metadata/_custom_type_script = "uid://10xqk22j564o"
```

- [ ] **Step 3: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no errors; dialogue label recognized.

- [ ] **Step 4: Commit**

```bash
git add assets/dialogue/timelines/celestial_intervener_introduction_1.dtl resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres
git commit -m "feat(npc): add celestial intervener dialogue 4 + action

Unlocks at CD 10, plays dialogue_4, fires
celestial_intervener_dialogue_4 event. Gates q_reach_core_density_10
step 2 and caps at a single completion."
```

---

## Task 12: Create the Merchant zone action (stub)

Plain `ZoneActionData` — no subclass — gated on `merchant_discovered`.

**Files:**
- Create: `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres`

- [ ] **Step 1: Create the resource**

Create `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres`:

```
[gd_resource type="Resource" script_class="ZoneActionData" format=3 uid="uid://cspirit_merchant_act"]

[ext_resource type="Script" uid="uid://cv640mljv33xk" path="res://scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd" id="1_action"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="2_cond"]
[ext_resource type="Resource" uid="uid://bunlock_mrch_discov" path="res://resources/unlocks/merchant_discovered.tres" id="3_discov"]

[resource]
script = ExtResource("1_action")
action_id = "spirit_valley_merchant"
action_name = "Traveling Merchant"
action_type = 3
description = "The refugee-camp merchant has set up a small stall in the valley."
unlock_conditions = Array[ExtResource("2_cond")]([ExtResource("3_discov")])
max_completions = 0
metadata/_custom_type_script = "uid://cv640mljv33xk"
```

Notes:
- `action_type = 3` = `ZoneActionData.ActionType.MERCHANT`.
- `success_effects` intentionally omitted (empty). The stub behavior lives in `ActionManager._execute_merchant_action`.

- [ ] **Step 2: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres
git commit -m "feat(zones): add Spirit Valley Merchant zone action (stub)

Gated on merchant_discovered. Click logs a 'coming soon' message via
the ActionManager merchant stub handler."
```

---

## Task 13: Wire the new actions into the Spirit Valley zone and encounter pool

Register the NPC 4 + Merchant actions with the zone, and add the refugee camp to the adventure's special encounter pool.

**Files:**
- Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`
- Modify: `resources/adventure/data/shallow_woods.tres`

- [ ] **Step 1: Add to spirit_valley_zone.tres**

Open `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`. Add two new `[ext_resource]` lines (pick fresh ids, e.g. `9_npc4`, `10_merch`):

```
[ext_resource type="Resource" uid="uid://cnpc40act001" path="res://resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres" id="9_npc4"]
[ext_resource type="Resource" uid="uid://cspirit_merchant_act" path="res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres" id="10_merch"]
```

Append both to the `all_actions` array:

```
all_actions = Array[ExtResource("1_gfpen")]([ExtResource("2_8fv6p"), ExtResource("3_4bje7"), ExtResource("3_4l7yp"), ExtResource("6_owjyk"), ExtResource("6_8sxt0"), ExtResource("7_spwtrain"), ExtResource("8_1xdtd"), ExtResource("9_npc4"), ExtResource("10_merch")])
```

- [ ] **Step 2: Add to shallow_woods.tres**

Open `resources/adventure/data/shallow_woods.tres`. Add a new ext_resource for the refugee camp (fresh id, e.g. `10_refcamp`):

```
[ext_resource type="Resource" uid="uid://brefugee_camp_enc" path="res://resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres" id="10_refcamp"]
```

Append it to `special_encounter_pool`:

```
special_encounter_pool = Array[ExtResource("6_mnoah")]([ExtResource("9_aurawell"), ExtResource("10_refcamp")])
```

- [ ] **Step 3: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no errors; both new resources load.

- [ ] **Step 4: Commit**

```bash
git add resources/zones/spirit_valley_zone/spirit_valley_zone.tres resources/adventure/data/shallow_woods.tres
git commit -m "feat(zones/adventure): wire NPC 4, Merchant, and refugee camp

Zone 1 gains the return-to-NPC and Merchant action buttons.
shallow_woods' special encounter pool now includes the refugee camp
alongside Aura Well."
```

---

## Task 14: Extend `q_reach_core_density_10` with step 2 + map award

Attach the NPC-return step and award the Refugee Camp Map on quest completion.

**Files:**
- Modify: `resources/quests/q_reach_core_density_10.tres`

- [ ] **Step 1: Update the quest resource**

Open `resources/quests/q_reach_core_density_10.tres`. The current file has step 1 only. Replace the whole file with:

```
[gd_resource type="Resource" script_class="QuestData" format=3 uid="uid://bqreachcdq001"]

[ext_resource type="Script" uid="uid://c777hl035dwml" path="res://scripts/resource_definitions/quests/quest_data.gd" id="1_qrcdq"]
[ext_resource type="Script" uid="uid://dg16ukxsxuhbr" path="res://scripts/resource_definitions/quests/quest_step_data.gd" id="2_qrcdq"]
[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="3_qrcdq"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="4_qrcdq"]
[ext_resource type="Resource" uid="uid://i2xnqd3pem53" path="res://resources/unlocks/q_reach_cd_10.tres" id="5_qrcdq"]
[ext_resource type="Script" uid="uid://dbbopeowutwja" path="res://scripts/resource_definitions/effects/award_item_effect_data.gd" id="6_awi"]
[ext_resource type="Resource" uid="uid://bitem_refugee_map" path="res://resources/items/quest_items/refugee_camp_map.tres" id="7_map"]

[sub_resource type="Resource" id="Resource_step1"]
script = ExtResource("2_qrcdq")
step_id = "reach_cd_10"
description = "Reach Core Density level 10"
completion_conditions = Array[ExtResource("4_qrcdq")]([ExtResource("5_qrcdq")])

[sub_resource type="Resource" id="Resource_step2"]
script = ExtResource("2_qrcdq")
step_id = "return_to_npc"
description = "Return to the Celestial [INTERVENER]"
completion_event_id = "celestial_intervener_dialogue_4"

[sub_resource type="Resource" id="Resource_award_map"]
script = ExtResource("6_awi")
item = ExtResource("7_map")
quantity = 1

[resource]
script = ExtResource("1_qrcdq")
quest_id = "q_reach_core_density_10"
quest_name = "Harden Your Core"
description = "Deepen your cultivation. Raise your Core Density to level 10, then report back to the Celestial [INTERVENER]."
steps = Array[ExtResource("2_qrcdq")]([SubResource("Resource_step1"), SubResource("Resource_step2")])
completion_effects = Array[ExtResource("3_qrcdq")]([SubResource("Resource_award_map")])
```

UIDs: `uid://dbbopeowutwja` (award_item_effect_data.gd) and `uid://cuag0kvf84qnl` (item_definition_data.gd) are verified real UIDs from this checkout. The map-resource UID `uid://bitem_refugee_map` is a fresh one introduced in Task 8 — just make sure the two files agree (both use the same string you wrote into `refugee_camp_map.tres`'s header).

- [ ] **Step 2: Verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no errors.

- [ ] **Step 3: Run the full unit suite as a regression check**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```
Expected: all tests pass including the existing `test_quest_manager.gd` / `test_quest_progression_persistence.gd`.

- [ ] **Step 4: Commit**

```bash
git add resources/quests/q_reach_core_density_10.tres
git commit -m "feat(quests): extend q_reach_core_density_10 with NPC return

Adds step 2 (return to NPC, completion on celestial_intervener_dialogue_4
event) and awards the Refugee Camp Map on quest completion."
```

---

## Task 15: Integration test — full Beat 3b flow

End-to-end test exercising the entire chain. Validates the wiring across inventory, conditions, encounters, quests, and zone-action visibility.

**Files:**
- Create: `tests/integration/test_beat_3b_merchant_unlock.gd`

- [ ] **Step 1: Write the test**

Create `tests/integration/test_beat_3b_merchant_unlock.gd`:

```gdscript
extends GutTest

## Integration test: full Beat 3b flow.
## 1. Quest starts. CD < 10 → NPC 4 hidden, Merchant hidden, quest step 1 not complete.
## 2. CD reaches 10 → step 1 complete, NPC 4 visible.
## 3. Fire celestial_intervener_dialogue_4 event → step 2 completes → quest
##    completes → map in inventory.
## 4. Filter a fake pool with the refugee camp + a control encounter → camp eligible.
## 5. Fire merchant_discovered → Merchant zone action visible.
## 6. Re-filter the pool → camp no longer eligible (merchant_discovered=true
##    trips the negate gate).

const ZONE_ID: String = "SpiritValley"
const QUEST_ID: String = "q_reach_core_density_10"
const NPC4_ACTION_ID: String = "celestial_intervener_dialogue_4"
const MERCHANT_ACTION_ID: String = "spirit_valley_merchant"
const MAP_ITEM_ID: String = "refugee_camp_map"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _has_action(action_id: String) -> bool:
	for a in ZoneManager.get_available_actions(ZONE_ID):
		if a.action_id == action_id:
			return true
	return false

func _refugee_camp_encounter() -> AdventureEncounter:
	return load("res://resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres") as AdventureEncounter

func _filter_pool(pool: Array) -> Array:
	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()
	var result := generator._build_eligible_special_pool(pool)
	generator.queue_free()
	return result

func _push_cd_to_10() -> void:
	# Direct save-data mutation mirrors the pattern in test_cultivation_manager.gd.
	var save := PersistenceManager.save_game_data
	save.core_density_level = 10.0
	# Emit the signal UnlockManager listens to so CULTIVATION_LEVEL conditions re-evaluate.
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)

func test_full_beat_3b_flow() -> void:
	# --- Start the quest. ---
	QuestManager.start_quest(QUEST_ID)
	assert_true(QuestManager.has_active_quest(QUEST_ID), "quest should be active")
	assert_false(_has_action(NPC4_ACTION_ID), "NPC 4 must be hidden before CD 10")
	assert_false(InventoryManager.has_item(MAP_ITEM_ID), "map must not be owned yet")

	# --- Reach CD 10 → quest step 1 completes, NPC 4 visible. ---
	_push_cd_to_10()
	assert_true(_has_action(NPC4_ACTION_ID), "NPC 4 must be visible at CD 10")

	# --- NPC 4 click fires dialogue_4 event → quest step 2 + completion. ---
	EventManager.trigger_event(NPC4_ACTION_ID)
	assert_false(QuestManager.has_active_quest(QUEST_ID), "quest should have completed")
	assert_true(QuestManager.has_completed_quest(QUEST_ID), "quest should be in the completed set")
	assert_true(InventoryManager.has_item(MAP_ITEM_ID), "map should be in inventory after quest completion")

	# --- Refugee camp encounter is eligible for placement now. ---
	var pool: Array = [_refugee_camp_encounter()]
	var eligible: Array = _filter_pool(pool)
	assert_eq(eligible.size(), 1, "refugee camp should be eligible once the map is owned and merchant undiscovered")

	# --- Visit fires merchant_discovered. Merchant zone action visible. ---
	assert_false(_has_action(MERCHANT_ACTION_ID), "Merchant must be hidden before discovery")
	EventManager.trigger_event("merchant_discovered")
	assert_true(_has_action(MERCHANT_ACTION_ID), "Merchant must be visible after discovery")

	# --- Re-generating an adventure now filters the camp out. ---
	var re_eligible: Array = _filter_pool(pool)
	assert_eq(re_eligible.size(), 0, "refugee camp must no longer be eligible once merchant_discovered fired")
```

Notes on the APIs used above (verified against the existing singletons):
- `QuestManager.start_quest(id)`, `QuestManager.has_active_quest(id)`, `QuestManager.has_completed_quest(id)` — all real (see `singletons/quest_manager/quest_manager.gd`).
- CD level is pushed by assigning directly to `PersistenceManager.save_game_data.core_density_level` and then emitting `CultivationManager.core_density_level_updated` — UnlockManager listens on that signal (see `singletons/unlock_manager/unlock_manager.gd:49`). This mirrors how `test_cultivation_manager.gd` manipulates the save directly.
- `EventManager.trigger_event` already triggers an UnlockManager re-evaluation via its connection in `unlock_manager.gd:42`, so there's no need to call a separate `reevaluate_all`. The same pattern is used in `test_aura_well_discovery_unlock.gd`.

- [ ] **Step 2: Run the test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_beat_3b_merchant_unlock.gd -gexit
```
Expected: all assertions pass.

If any fail, reconcile against the existing Aura Well integration test pattern for the correct manager method names (do not invent new manager APIs here — if the test can't express the flow with existing APIs, stop and investigate rather than editing manager source).

- [ ] **Step 3: Run the full suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: everything green.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_beat_3b_merchant_unlock.gd
git commit -m "test(integration): Beat 3b end-to-end flow

Exercises quest → dialogue 4 → map award → encounter filter →
merchant unlock → re-filter drops the camp. Catches regressions
anywhere along the chain."
```

---

## Task 16: Update Foundation playthrough doc

Promote Beat 3b from `PLANNED` to `IMPLEMENTED` and amend the misleading line about path points coming from quest completion.

**Files:**
- Modify: `docs/progression/FOUNDATION_PLAYTHROUGH.md`

- [ ] **Step 1: Update status tags**

In `docs/progression/FOUNDATION_PLAYTHROUGH.md`:

1. Find the `#### Beat 3b — Second Keystone + Merchant Handoff` heading. Change its status tag from `PLANNED` to `IMPLEMENTED (map + merchant unlock only — Merchant shop UI still PLANNED)`.
2. In the **Beat Index** table at the bottom of §1, change the `3b` row's **Status** cell from `PLANNED` to the same string.
3. In the Beat 3b section body, clarify the path-point sentence: replace
   > *"At **Core Density 10**, second path point awarded via `q_reach_core_density_10` completion effects."*
   
   with:
   > *"At **Core Density 10**, PathManager's existing CD-milestone hook awards the second path point. `q_reach_core_density_10`'s `completion_effects` award the Refugee Camp Map only — no path-point double-award."*
4. Append a line to the Change Log at the bottom:
   > *2026-04-21* — Beat 3b implementation landed (map item + refugee camp encounter + Merchant zone-action stub). Merchant UI itself still deferred to Beat 4. Implemented `UnlockConditionData.ITEM_OWNED` and added per-encounter `unlock_conditions` filtering in the map generator.

- [ ] **Step 2: Commit**

```bash
git add docs/progression/FOUNDATION_PLAYTHROUGH.md
git commit -m "docs(progression): promote Beat 3b to IMPLEMENTED (partial)

Map + merchant-unlock mechanics landed. The Merchant shop UI itself
is still deferred to a later beat."
```

---

## Done

At this point:
- CD 10 → NPC 4 → dialogue 4 → map item in inventory.
- Map enables the refugee-camp special encounter in `shallow_woods`.
- Visiting the camp fires `merchant_discovered` and makes the Merchant zone action visible.
- Clicking the Merchant logs a "coming soon" message and does nothing else.
- All unit + integration tests pass.

Manual smoke-test (non-gating):
1. Load a fresh save, advance through Beats 1 and 2 until `q_reach_core_density_10` is active.
2. Cycle until CD reaches 10. Confirm the **Return to the [INTERVENER]** button appears in Zone 1.
3. Click it. Confirm dialogue 4 plays and "Obtained 1x Refugee Camp Map" appears in the log.
4. Enter `shallow_woods` repeatedly until the refugee camp tile appears. Visit it.
5. Confirm "The merchant nods at you. (Shop coming soon.)" log line fires on Merchant click and no modal pops.
6. Start a new `shallow_woods` run — the refugee camp no longer appears.
