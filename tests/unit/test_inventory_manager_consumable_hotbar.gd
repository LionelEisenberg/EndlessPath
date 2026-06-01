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

func test_swap_consumable_slots_moves_to_empty() -> void:
	var def := ConsumableDefinitionData.new(); def.item_id = "a"
	InventoryManager.equip_consumable(def, 0)
	InventoryManager.swap_consumable_slots(0, 2)
	var equipped = InventoryManager.get_inventory().equipped_consumables
	assert_false(equipped.has(0), "source cleared when target was empty")
	assert_eq(equipped[2], def, "consumable moved to the target slot")

func test_swap_consumable_slots_exchanges_occupied() -> void:
	var def_a := ConsumableDefinitionData.new(); def_a.item_id = "a"
	var def_b := ConsumableDefinitionData.new(); def_b.item_id = "b"
	InventoryManager.equip_consumable(def_a, 0)
	InventoryManager.equip_consumable(def_b, 1)
	InventoryManager.swap_consumable_slots(0, 1)
	var equipped = InventoryManager.get_inventory().equipped_consumables
	assert_eq(equipped[0], def_b, "target's consumable moved to the source slot")
	assert_eq(equipped[1], def_a, "source's consumable moved to the target slot")

func test_swap_consumable_slots_empty_source_is_noop() -> void:
	var def := ConsumableDefinitionData.new(); def.item_id = "a"
	InventoryManager.equip_consumable(def, 1)
	InventoryManager.swap_consumable_slots(0, 1)  # slot 0 is empty
	var equipped = InventoryManager.get_inventory().equipped_consumables
	assert_false(equipped.has(0), "empty source stays empty")
	assert_eq(equipped[1], def, "target unchanged when source is empty")
