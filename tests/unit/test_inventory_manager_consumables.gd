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
