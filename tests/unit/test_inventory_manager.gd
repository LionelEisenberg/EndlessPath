extends GutTest

## Unit tests for InventoryManager: equip/unequip/swap/move operations,
## award_items, has_item, get_quest_items and the inventory signals.
##
## Every test runs the real manager on a fresh SaveGameData holding _inventory.
## Only InventoryManager is re-bound: no other autoload listens to its signals.
## after_each() puts the original save back.

const EquipmentSlot = EquipmentDefinitionData.EquipmentSlot

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _inventory: InventoryData
## InventoryManager's save before before_each() swapped it.
var _original_manager_save: SaveGameData = null

func before_each() -> void:
	_inventory = InventoryData.new()
	_original_manager_save = InventoryManager.live_save_data
	var save := SaveGameData.new()
	save.inventory = _inventory
	InventoryManager.live_save_data = save

func after_each() -> void:
	InventoryManager.live_save_data = _original_manager_save
	_original_manager_save = null

func _make_equipment(slot: EquipmentSlot, name: String = "Test Item") -> EquipmentDefinitionData:
	var def := EquipmentDefinitionData.new()
	def.slot_type = slot
	def.item_name = name
	return def

func _make_instance(def: ItemDefinitionData) -> ItemInstanceData:
	var inst := ItemInstanceData.new()
	inst.item_definition = def
	inst.quantity = 1
	return inst

func _make_material(name: String) -> MaterialDefinitionData:
	var mat := MaterialDefinitionData.new()
	mat.item_id = name.to_snake_case()
	mat.item_name = name
	mat.item_type = ItemDefinitionData.ItemType.MATERIAL
	return mat

func _make_quest_item(item_id: String) -> ItemDefinitionData:
	var def := ItemDefinitionData.new()
	def.item_id = item_id
	def.item_name = item_id.capitalize()
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM
	return def

#-----------------------------------------------------------------------------
# EQUIP ITEM
#-----------------------------------------------------------------------------

func test_equip_item_moves_grid_item_into_slot() -> void:
	var inst := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND))
	_inventory.equipment[0] = inst
	watch_signals(InventoryManager)

	InventoryManager.equip_item(inst, EquipmentSlot.MAIN_HAND, 0)

	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.MAIN_HAND), inst)
	assert_false(_inventory.equipment.has(0), "item should be removed from grid")
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_equip_item_without_index_finds_the_instance_in_grid() -> void:
	var inst := _make_instance(_make_equipment(EquipmentSlot.HEAD))
	_inventory.equipment[4] = inst

	InventoryManager.equip_item(inst, EquipmentSlot.HEAD)

	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.HEAD), inst)
	assert_eq(_inventory.equipment.size(), 0, "the instance should leave the grid wherever it was")

func test_equip_item_swaps_equipped_item_into_source_slot() -> void:
	var old_inst := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND, "Old Weapon"))
	var new_inst := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND, "New Weapon"))
	_inventory.equipped_gear[EquipmentSlot.MAIN_HAND] = old_inst
	_inventory.equipment[3] = new_inst

	InventoryManager.equip_item(new_inst, EquipmentSlot.MAIN_HAND, 3)

	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.MAIN_HAND), new_inst, "new item should be equipped")
	assert_eq(_inventory.equipment.get(3), old_inst, "old item should take the new item's grid slot")
	assert_eq(_inventory.equipment.size(), 1, "nothing else should land in the grid")

func test_equip_item_swap_without_index_sends_old_item_to_first_free_slot() -> void:
	# A cross-page drag lifts the instance out of the grid before equipping it,
	# so there is no source slot to swap into.
	var old_inst := _make_instance(_make_equipment(EquipmentSlot.ARMOR, "Old Robe"))
	var new_inst := _make_instance(_make_equipment(EquipmentSlot.ARMOR, "New Robe"))
	var filler := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Filler"))
	_inventory.equipped_gear[EquipmentSlot.ARMOR] = old_inst
	_inventory.equipment[0] = filler

	InventoryManager.equip_item(new_inst, EquipmentSlot.ARMOR)

	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.ARMOR), new_inst)
	assert_eq(_inventory.equipment.get(0), filler, "occupied slots are left alone")
	assert_eq(_inventory.equipment.get(1), old_inst, "old item should go to the first free slot")

func test_equip_item_accessory_index_picks_the_physical_slot() -> void:
	var ring := _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Ring"))
	_inventory.equipment[2] = ring

	InventoryManager.equip_item(ring, EquipmentSlot.ACCESSORY, 2, 1)

	assert_eq(_inventory.equipped_accessories.get(1), ring, "ring should sit in accessory slot 1")
	assert_false(_inventory.equipped_accessories.has(0), "accessory slot 0 stays empty")
	assert_false(_inventory.equipped_gear.has(EquipmentSlot.ACCESSORY), "accessories never use equipped_gear")

func test_equip_item_fills_every_gear_and_accessory_slot() -> void:
	var gear_slots: Array[EquipmentSlot] = [
		EquipmentSlot.MAIN_HAND,
		EquipmentSlot.OFF_HAND,
		EquipmentSlot.HEAD,
		EquipmentSlot.ARMOR,
	]
	for i: int in gear_slots.size():
		_inventory.equipment[i] = _make_instance(_make_equipment(gear_slots[i]))
	_inventory.equipment[4] = _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Acc 0"))
	_inventory.equipment[5] = _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Acc 1"))

	for i: int in gear_slots.size():
		InventoryManager.equip_item(_inventory.equipment[i], gear_slots[i], i)
	InventoryManager.equip_item(_inventory.equipment[4], EquipmentSlot.ACCESSORY, 4, 0)
	InventoryManager.equip_item(_inventory.equipment[5], EquipmentSlot.ACCESSORY, 5, 1)

	assert_eq(_inventory.equipped_gear.size(), 4, "4 singular gear slots")
	assert_eq(_inventory.equipped_accessories.size(), 2, "2 physical accessory slots")
	assert_eq(_inventory.equipment.size(), 0, "the grid should be empty")

#-----------------------------------------------------------------------------
# UNEQUIP ITEM
#-----------------------------------------------------------------------------

func test_unequip_item_moves_to_grid() -> void:
	var slot := EquipmentSlot.ARMOR
	var inst := _make_instance(_make_equipment(slot))
	_inventory.equipped_gear[slot] = inst

	InventoryManager.unequip_item(slot)

	assert_false(_inventory.equipped_gear.has(slot), "gear slot should be empty")
	assert_eq(_inventory.equipment.get(0), inst, "item should be in first grid slot")

func test_unequip_empty_slot_changes_nothing() -> void:
	watch_signals(InventoryManager)

	InventoryManager.unequip_item(EquipmentSlot.OFF_HAND)

	assert_eq(_inventory.equipment.size(), 0, "nothing should land in the grid")
	assert_signal_not_emitted(InventoryManager, "inventory_changed")

func test_unequip_to_slot_empty_target() -> void:
	var head := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Helm"))
	_inventory.equipped_gear[EquipmentSlot.HEAD] = head

	var moved: bool = InventoryManager.unequip_item_to_slot(EquipmentSlot.HEAD, 5)

	assert_true(moved)
	assert_false(_inventory.equipped_gear.has(EquipmentSlot.HEAD), "gear slot emptied")
	assert_eq(_inventory.equipment.get(5), head, "item placed at target slot")

func test_unequip_to_slot_swaps_compatible_item() -> void:
	var head_a := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Helm A"))
	var head_b := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Helm B"))
	_inventory.equipped_gear[EquipmentSlot.HEAD] = head_a
	_inventory.equipment[5] = head_b

	var moved: bool = InventoryManager.unequip_item_to_slot(EquipmentSlot.HEAD, 5)

	assert_true(moved)
	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.HEAD), head_b, "compatible grid item equipped")
	assert_eq(_inventory.equipment.get(5), head_a, "unequipped item placed at target")

func test_unequip_to_slot_rejects_incompatible_swap() -> void:
	# Regression: dropping an equipped item onto a grid slot holding an item
	# that does not fit the gear slot must NOT destroy the grid item or unequip.
	var head := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Helm"))
	var sword := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND, "Sword"))
	_inventory.equipped_gear[EquipmentSlot.HEAD] = head
	_inventory.equipment[5] = sword

	var moved: bool = InventoryManager.unequip_item_to_slot(EquipmentSlot.HEAD, 5)

	assert_false(moved, "invalid swap should be reported")
	assert_eq(_inventory.equipped_gear.get(EquipmentSlot.HEAD), head, "head stays equipped (invalid swap rejected)")
	assert_eq(_inventory.equipment.get(5), sword, "non-fitting grid item not lost")

func test_unequip_to_slot_from_empty_gear_slot_does_nothing() -> void:
	watch_signals(InventoryManager)

	var moved: bool = InventoryManager.unequip_item_to_slot(EquipmentSlot.HEAD, 5)

	assert_false(moved)
	assert_false(_inventory.equipment.has(5))
	assert_signal_not_emitted(InventoryManager, "inventory_changed")

#-----------------------------------------------------------------------------
# SWAP ACCESSORY SLOTS
#-----------------------------------------------------------------------------

func test_swap_accessory_slots_both_occupied() -> void:
	var ring_a := _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Ring A"))
	var ring_b := _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Ring B"))
	_inventory.equipped_accessories[0] = ring_a
	_inventory.equipped_accessories[1] = ring_b
	watch_signals(InventoryManager)

	InventoryManager.swap_accessory_slots(0, 1)

	assert_eq(_inventory.equipped_accessories.get(0), ring_b, "slot 0 should now hold Ring B")
	assert_eq(_inventory.equipped_accessories.get(1), ring_a, "slot 1 should now hold Ring A")
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_swap_accessory_slots_target_empty() -> void:
	var ring := _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Ring"))
	_inventory.equipped_accessories[0] = ring

	InventoryManager.swap_accessory_slots(0, 1)

	assert_false(_inventory.equipped_accessories.has(0), "source should be empty")
	assert_eq(_inventory.equipped_accessories.get(1), ring, "target should have the item")

func test_swap_accessory_slots_empty_source_changes_nothing() -> void:
	var ring := _make_instance(_make_equipment(EquipmentSlot.ACCESSORY, "Ring"))
	_inventory.equipped_accessories[1] = ring
	watch_signals(InventoryManager)

	# Prints an expected Log.error with a backtrace; Log.error does not push_error.
	InventoryManager.swap_accessory_slots(0, 1)

	assert_false(_inventory.equipped_accessories.has(0), "empty source stays empty")
	assert_eq(_inventory.equipped_accessories.get(1), ring, "target keeps its item")
	assert_signal_not_emitted(InventoryManager, "inventory_changed")

#-----------------------------------------------------------------------------
# MOVE EQUIPMENT (grid reorder)
#-----------------------------------------------------------------------------

func test_move_equipment_to_empty_slot() -> void:
	var inst := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND))
	_inventory.equipment[0] = inst
	watch_signals(InventoryManager)

	InventoryManager.move_equipment(0, 5)

	assert_false(_inventory.equipment.has(0), "source slot should be empty")
	assert_eq(_inventory.equipment.get(5), inst)
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_move_equipment_swaps_with_occupied_slot() -> void:
	var inst_a := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND, "A"))
	var inst_b := _make_instance(_make_equipment(EquipmentSlot.OFF_HAND, "B"))
	_inventory.equipment[0] = inst_a
	_inventory.equipment[3] = inst_b

	InventoryManager.move_equipment(0, 3)

	assert_eq(_inventory.equipment.get(0), inst_b, "slot 0 should have item B")
	assert_eq(_inventory.equipment.get(3), inst_a, "slot 3 should have item A")

func test_move_equipment_from_empty_slot_changes_nothing() -> void:
	var inst := _make_instance(_make_equipment(EquipmentSlot.MAIN_HAND))
	_inventory.equipment[3] = inst
	watch_signals(InventoryManager)

	InventoryManager.move_equipment(0, 3)

	assert_eq(_inventory.equipment.get(3), inst, "target keeps its item")
	assert_eq(_inventory.equipment.size(), 1)
	assert_signal_not_emitted(InventoryManager, "inventory_changed")

#-----------------------------------------------------------------------------
# AWARD ITEMS - EQUIPMENT
#-----------------------------------------------------------------------------

func test_award_equipment_creates_instances() -> void:
	var def := _make_equipment(EquipmentSlot.MAIN_HAND, "Sword")

	InventoryManager.award_items(def, 3)

	assert_eq(_inventory.equipment.size(), 3, "should have 3 separate instances")
	for i: int in 3:
		var instance: ItemInstanceData = _inventory.equipment.get(i)
		assert_not_null(instance, "slot %d should be filled" % i)
		if instance != null:
			assert_eq(instance.item_definition, def)
			assert_eq(instance.quantity, 1, "each instance holds one item")
	assert_ne(_inventory.equipment.get(0), _inventory.equipment.get(1), "each copy is its own instance")

func test_award_equipment_fills_slots_sequentially() -> void:
	var existing := _make_instance(_make_equipment(EquipmentSlot.HEAD, "Existing"))
	_inventory.equipment[0] = existing
	var new_def := _make_equipment(EquipmentSlot.ARMOR, "New")

	InventoryManager.award_items(new_def, 1)

	assert_eq(_inventory.equipment.get(0), existing, "slot 0 should keep existing item")
	var awarded: ItemInstanceData = _inventory.equipment.get(1)
	assert_not_null(awarded, "new item should go to first available (slot 1)")
	if awarded != null:
		assert_eq(awarded.item_definition, new_def)

#-----------------------------------------------------------------------------
# AWARD ITEMS - MATERIALS
#-----------------------------------------------------------------------------

func test_award_material_adds_a_stack() -> void:
	var mat := _make_material("Crystal")
	watch_signals(InventoryManager)

	InventoryManager.award_items(mat, 5)

	assert_eq(_inventory.materials.get(mat, 0), 5)
	assert_eq(_inventory.equipment.size(), 0, "materials never land in the equipment grid")
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_award_material_stacks() -> void:
	var mat := _make_material("Crystal")

	InventoryManager.award_items(mat, 3)
	InventoryManager.award_items(mat, 7)

	assert_eq(_inventory.materials.get(mat, 0), 10, "materials should stack")
	assert_eq(_inventory.materials.size(), 1, "one entry per material")

func test_award_material_multiple_types() -> void:
	var mat_a := _make_material("Crystal A")
	var mat_b := _make_material("Crystal B")

	InventoryManager.award_items(mat_a, 5)
	InventoryManager.award_items(mat_b, 10)

	assert_eq(_inventory.materials.get(mat_a, 0), 5)
	assert_eq(_inventory.materials.get(mat_b, 0), 10)
	assert_eq(_inventory.materials.size(), 2)

#-----------------------------------------------------------------------------
# INVENTORY DATA STRUCTURE
#-----------------------------------------------------------------------------

func test_inventory_starts_empty() -> void:
	assert_eq(_inventory.equipment.size(), 0, "equipment grid should start empty")
	assert_eq(_inventory.equipped_gear.size(), 0, "equipped gear should start empty")
	assert_eq(_inventory.equipped_accessories.size(), 0, "equipped accessories should start empty")
	assert_eq(_inventory.materials.size(), 0, "materials should start empty")

# Equipment capacity (unlocked pages x InventoryData.SLOTS_PER_PAGE) is covered
# by test_inventory_data_pagination.gd and test_inventory_manager_pages.gd.

#-----------------------------------------------------------------------------
# ITEM_AWARDED SIGNAL CONTRACT
#-----------------------------------------------------------------------------

func test_item_awarded_signal_exists() -> void:
	# Verify the InventoryManager script defines the item_awarded signal
	var mgr = Node.new()
	mgr.set_script(load("res://singletons/inventory_manager/inventory_manager.gd"))
	assert_true(mgr.has_signal("item_awarded"), "InventoryManager should have item_awarded signal")
	mgr.free()

func test_item_awarded_signal_emits_on_award() -> void:
	var test_item := _make_equipment(EquipmentSlot.MAIN_HAND, "Signal Test Sword")
	watch_signals(InventoryManager)

	InventoryManager.award_items(test_item, 3)

	assert_signal_emitted_with_parameters(InventoryManager, "item_awarded", [test_item, 3])

#-----------------------------------------------------------------------------
# AWARD ITEMS - QUEST ITEMS
#-----------------------------------------------------------------------------

func test_award_items_quest_item_lands_in_quest_items() -> void:
	var def := _make_quest_item("test_map_award")

	InventoryManager.award_items(def, 1)

	assert_eq(_inventory.quest_items.get(def, 0), 1, "quest item should land in quest_items dict")
	assert_eq(_inventory.materials.size(), 0, "quest item must not land in materials")
	assert_eq(_inventory.equipment.size(), 0, "quest item must not land in equipment grid")

func test_award_quest_item_stacks() -> void:
	var def := _make_quest_item("test_map")

	InventoryManager.award_items(def, 1)
	InventoryManager.award_items(def, 2)

	assert_eq(_inventory.quest_items.get(def, 0), 3, "quest items should stack")

#-----------------------------------------------------------------------------
# HAS_ITEM
#-----------------------------------------------------------------------------

func test_has_item_false_when_inventory_empty() -> void:
	assert_false(InventoryManager.has_item("nothing"), "empty inventory should report no items")

func test_has_item_true_for_quest_item() -> void:
	InventoryManager.award_items(_make_quest_item("quest_test_x"), 1)

	assert_true(InventoryManager.has_item("quest_test_x"), "should find the quest item by id")
	assert_false(InventoryManager.has_item("unrelated_id"), "other ids should not match")

func test_has_item_true_for_material() -> void:
	var mat := _make_material("Mat Test X")

	InventoryManager.award_items(mat, 5)

	assert_true(InventoryManager.has_item(mat.item_id), "should find the material by id")

func test_has_item_true_for_equipped_gear() -> void:
	var def := _make_equipment(EquipmentSlot.MAIN_HAND, "Test Gear")
	def.item_id = "gear_test_x"

	# Award then equip so the item lives in equipped_gear, not the grid.
	InventoryManager.award_items(def, 1)
	assert_eq(_inventory.equipment.size(), 1, "item should first be in grid")
	var instance: ItemInstanceData = _inventory.equipment[_inventory.equipment.keys()[0]]
	InventoryManager.equip_item(instance, EquipmentSlot.MAIN_HAND)

	assert_eq(_inventory.equipment.size(), 0, "the grid should be empty once it is equipped")
	assert_true(InventoryManager.has_item("gear_test_x"), "equipped gear should count as owned")

#-----------------------------------------------------------------------------
# GET_QUEST_ITEMS
#-----------------------------------------------------------------------------

func test_get_quest_items_returns_empty_on_fresh_save() -> void:
	assert_eq(InventoryManager.get_quest_items().size(), 0, "fresh save should report zero quest items")

func test_get_quest_items_reflects_awards() -> void:
	var def := _make_quest_item("get_quest_items_test")

	InventoryManager.award_items(def, 1)

	var quest_items := InventoryManager.get_quest_items()
	assert_eq(quest_items.size(), 1, "should report exactly one quest item after award")
	assert_eq(quest_items.get(def, 0), 1, "awarded item should appear with quantity 1")
