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
