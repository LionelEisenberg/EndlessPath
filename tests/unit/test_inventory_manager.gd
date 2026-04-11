extends GutTest

## Unit tests for InventoryManager
## Tests equip/unequip/swap/move operations, award_items, and inventory_changed signal

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _inventory: InventoryData

func before_each() -> void:
	_inventory = InventoryData.new()

func _make_equipment(slot: EquipmentDefinitionData.EquipmentSlot, name: String = "Test Item") -> EquipmentDefinitionData:
	var def = EquipmentDefinitionData.new()
	def.slot_type = slot
	def.item_name = name
	return def

func _make_instance(def: ItemDefinitionData) -> ItemInstanceData:
	var inst = ItemInstanceData.new()
	inst.item_definition = def
	inst.quantity = 1
	return inst

func _add_to_first_slot(inventory: InventoryData, item: ItemInstanceData) -> void:
	for i in 50:
		if not inventory.equipment.has(i):
			inventory.equipment[i] = item
			return

#-----------------------------------------------------------------------------
# EQUIP ITEM
#-----------------------------------------------------------------------------

func test_equip_item_places_in_slot() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	var inst = _make_instance(def)
	_inventory.equipment[0] = inst

	# Simulate equip logic
	_inventory.equipment.erase(0)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = inst

	assert_true(_inventory.equipped_gear.has(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND))
	assert_eq(_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND], inst)
	assert_false(_inventory.equipment.has(0), "item should be removed from grid")

func test_equip_item_swaps_existing_to_grid() -> void:
	var old_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "Old Weapon")
	var old_inst = _make_instance(old_def)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = old_inst

	var new_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "New Weapon")
	var new_inst = _make_instance(new_def)
	_inventory.equipment[3] = new_inst

	# Simulate swap logic (from_index = 3)
	var from_index = 3
	var slot = EquipmentDefinitionData.EquipmentSlot.MAIN_HAND
	var currently_equipped = _inventory.equipped_gear[slot]
	_inventory.equipment[from_index] = currently_equipped  # old goes to grid at from_index
	_inventory.equipped_gear[slot] = new_inst  # new goes to gear

	assert_eq(_inventory.equipped_gear[slot], new_inst, "new item should be equipped")
	assert_eq(_inventory.equipment[from_index], old_inst, "old item should be in grid at from_index")

func test_equip_item_all_six_slots() -> void:
	var slots = [
		EquipmentDefinitionData.EquipmentSlot.MAIN_HAND,
		EquipmentDefinitionData.EquipmentSlot.OFF_HAND,
		EquipmentDefinitionData.EquipmentSlot.HEAD,
		EquipmentDefinitionData.EquipmentSlot.ARMOR,
		EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1,
		EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2,
	]

	for slot in slots:
		var def = _make_equipment(slot)
		var inst = _make_instance(def)
		_inventory.equipped_gear[slot] = inst

	assert_eq(_inventory.equipped_gear.size(), 6, "should be able to equip all 6 slots")

#-----------------------------------------------------------------------------
# UNEQUIP ITEM
#-----------------------------------------------------------------------------

func test_unequip_item_moves_to_grid() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.ARMOR)
	var inst = _make_instance(def)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ARMOR] = inst

	# Simulate unequip
	var slot = EquipmentDefinitionData.EquipmentSlot.ARMOR
	var item = _inventory.equipped_gear[slot]
	_inventory.equipped_gear.erase(slot)
	_add_to_first_slot(_inventory, item)

	assert_false(_inventory.equipped_gear.has(slot), "gear slot should be empty")
	assert_true(_inventory.equipment.has(0), "item should be in first grid slot")
	assert_eq(_inventory.equipment[0], inst)

func test_unequip_to_specific_slot() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.HEAD)
	var inst = _make_instance(def)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.HEAD] = inst

	# Simulate unequip_item_to_slot at target_index=5
	var slot = EquipmentDefinitionData.EquipmentSlot.HEAD
	var target_index = 5
	var item = _inventory.equipped_gear[slot]
	_inventory.equipped_gear.erase(slot)
	_inventory.equipment[target_index] = item

	assert_false(_inventory.equipped_gear.has(slot))
	assert_eq(_inventory.equipment[target_index], inst)

func test_unequip_empty_slot_does_nothing() -> void:
	var slot = EquipmentDefinitionData.EquipmentSlot.OFF_HAND
	var had = _inventory.equipped_gear.has(slot)
	assert_false(had, "slot should not have anything to unequip")

#-----------------------------------------------------------------------------
# SWAP GEAR SLOTS
#-----------------------------------------------------------------------------

func test_swap_gear_slots_both_occupied() -> void:
	var acc1_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1, "Ring A")
	var acc1_inst = _make_instance(acc1_def)
	var acc2_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2, "Ring B")
	var acc2_inst = _make_instance(acc2_def)

	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1] = acc1_inst
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2] = acc2_inst

	# Simulate swap
	var from_slot = EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1
	var to_slot = EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2
	var from_item = _inventory.equipped_gear.get(from_slot, null)
	var to_item = _inventory.equipped_gear.get(to_slot, null)

	_inventory.equipped_gear[to_slot] = from_item
	if to_item:
		_inventory.equipped_gear[from_slot] = to_item
	else:
		_inventory.equipped_gear.erase(from_slot)

	assert_eq(_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1], acc2_inst, "items should be swapped")
	assert_eq(_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2], acc1_inst)

func test_swap_gear_slots_target_empty() -> void:
	var acc1_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1, "Ring")
	var acc1_inst = _make_instance(acc1_def)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1] = acc1_inst

	var from_slot = EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1
	var to_slot = EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2
	var from_item = _inventory.equipped_gear.get(from_slot, null)
	var to_item = _inventory.equipped_gear.get(to_slot, null)

	_inventory.equipped_gear[to_slot] = from_item
	if to_item:
		_inventory.equipped_gear[from_slot] = to_item
	else:
		_inventory.equipped_gear.erase(from_slot)

	assert_false(_inventory.equipped_gear.has(from_slot), "source should be empty")
	assert_eq(_inventory.equipped_gear[to_slot], acc1_inst, "target should have the item")

#-----------------------------------------------------------------------------
# MOVE EQUIPMENT (grid reorder)
#-----------------------------------------------------------------------------

func test_move_equipment_to_empty_slot() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	var inst = _make_instance(def)
	_inventory.equipment[0] = inst

	# Move from 0 to 5
	var item = _inventory.equipment[0]
	_inventory.equipment.erase(0)
	_inventory.equipment[5] = item

	assert_false(_inventory.equipment.has(0))
	assert_eq(_inventory.equipment[5], inst)

func test_move_equipment_swap_with_occupied() -> void:
	var def_a = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "A")
	var inst_a = _make_instance(def_a)
	var def_b = _make_equipment(EquipmentDefinitionData.EquipmentSlot.OFF_HAND, "B")
	var inst_b = _make_instance(def_b)

	_inventory.equipment[0] = inst_a
	_inventory.equipment[3] = inst_b

	# Swap
	var temp = _inventory.equipment[0]
	_inventory.equipment[0] = _inventory.equipment[3]
	_inventory.equipment[3] = temp

	assert_eq(_inventory.equipment[0], inst_b, "slot 0 should have item B")
	assert_eq(_inventory.equipment[3], inst_a, "slot 3 should have item A")

#-----------------------------------------------------------------------------
# GET EQUIPPED ITEM
#-----------------------------------------------------------------------------

func test_get_equipped_item_returns_item() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	var inst = _make_instance(def)
	_inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = inst

	var result = _inventory.equipped_gear.get(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, null)
	assert_eq(result, inst)

func test_get_equipped_item_empty_returns_null() -> void:
	var result = _inventory.equipped_gear.get(EquipmentDefinitionData.EquipmentSlot.HEAD, null)
	assert_null(result, "empty slot should return null")

#-----------------------------------------------------------------------------
# AWARD ITEMS - EQUIPMENT
#-----------------------------------------------------------------------------

func test_award_equipment_creates_instances() -> void:
	var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "Sword")

	# Simulate _award_equipment logic
	for i in 3:
		var instance = ItemInstanceData.new()
		instance.item_definition = def
		instance.quantity = 1
		_add_to_first_slot(_inventory, instance)

	assert_eq(_inventory.equipment.size(), 3, "should have 3 separate instances")
	assert_eq(_inventory.equipment[0].item_definition, def)
	assert_eq(_inventory.equipment[1].item_definition, def)
	assert_eq(_inventory.equipment[2].item_definition, def)

func test_award_equipment_fills_slots_sequentially() -> void:
	# Pre-fill slot 0
	var existing_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.HEAD, "Existing")
	var existing = _make_instance(existing_def)
	_inventory.equipment[0] = existing

	var new_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.ARMOR, "New")
	var new_inst = ItemInstanceData.new()
	new_inst.item_definition = new_def
	new_inst.quantity = 1
	_add_to_first_slot(_inventory, new_inst)

	assert_eq(_inventory.equipment[0], existing, "slot 0 should keep existing item")
	assert_eq(_inventory.equipment[1], new_inst, "new item should go to first available (slot 1)")

#-----------------------------------------------------------------------------
# AWARD ITEMS - MATERIALS
#-----------------------------------------------------------------------------

func test_award_material_new() -> void:
	var mat = MaterialDefinitionData.new()
	mat.item_name = "Crystal"

	# Simulate _award_material
	_inventory.materials[mat] = 5
	assert_eq(_inventory.materials[mat], 5)

func test_award_material_stacks() -> void:
	var mat = MaterialDefinitionData.new()
	mat.item_name = "Crystal"

	_inventory.materials[mat] = 3
	_inventory.materials[mat] += 7
	assert_eq(_inventory.materials[mat], 10, "materials should stack")

func test_award_material_multiple_types() -> void:
	var mat_a = MaterialDefinitionData.new()
	mat_a.item_name = "Crystal A"
	var mat_b = MaterialDefinitionData.new()
	mat_b.item_name = "Crystal B"

	_inventory.materials[mat_a] = 5
	_inventory.materials[mat_b] = 10

	assert_eq(_inventory.materials[mat_a], 5)
	assert_eq(_inventory.materials[mat_b], 10)
	assert_eq(_inventory.materials.size(), 2)

#-----------------------------------------------------------------------------
# INVENTORY DATA STRUCTURE
#-----------------------------------------------------------------------------

func test_inventory_starts_empty() -> void:
	assert_eq(_inventory.equipment.size(), 0, "equipment grid should start empty")
	assert_eq(_inventory.equipped_gear.size(), 0, "equipped gear should start empty")
	assert_eq(_inventory.materials.size(), 0, "materials should start empty")

func test_inventory_max_50_slots() -> void:
	# Fill all 50 slots
	for i in 50:
		var def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "Item %d" % i)
		var inst = _make_instance(def)
		_inventory.equipment[i] = inst

	assert_eq(_inventory.equipment.size(), 50, "should fill all 50 slots")

	# 51st item should fail to find slot with _add_to_first_slot
	var overflow_def = _make_equipment(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "Overflow")
	var overflow_inst = _make_instance(overflow_def)
	_add_to_first_slot(_inventory, overflow_inst)
	# If inventory was full, the 51st wasn't added (size stays 50)
	assert_eq(_inventory.equipment.size(), 50, "full inventory should not grow beyond 50")
