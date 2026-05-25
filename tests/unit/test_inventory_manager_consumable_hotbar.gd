extends GutTest

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_equip_consumable_sets_slot() -> void:
	var def := ConsumableDefinitionData.new()
	def.item_id = "scale"
	watch_signals(InventoryManager)
	InventoryManager.equip_consumable(def, 0)
	assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def)
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_equip_same_def_to_new_slot_clears_old() -> void:
	var def := ConsumableDefinitionData.new()
	def.item_id = "scale"
	InventoryManager.equip_consumable(def, 0)
	InventoryManager.equip_consumable(def, 2)
	assert_false(InventoryManager.get_inventory().equipped_consumables.has(0))
	assert_eq(InventoryManager.get_inventory().equipped_consumables[2], def)

func test_unequip_consumable_erases_slot() -> void:
	var def := ConsumableDefinitionData.new()
	InventoryManager.equip_consumable(def, 1)
	InventoryManager.unequip_consumable(1)
	assert_false(InventoryManager.get_inventory().equipped_consumables.has(1))

func test_equip_replaces_other_def_in_target_slot() -> void:
	var def_a := ConsumableDefinitionData.new(); def_a.item_id = "a"
	var def_b := ConsumableDefinitionData.new(); def_b.item_id = "b"
	InventoryManager.equip_consumable(def_a, 0)
	InventoryManager.equip_consumable(def_b, 0)
	assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def_b)
