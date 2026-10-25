extends GutTest

func test_default_unlocked_pages_is_two() -> void:
	var inv := InventoryData.new()
	assert_eq(inv.unlocked_equipment_pages, 2)

func test_slots_per_page_constant() -> void:
	assert_eq(InventoryData.SLOTS_PER_PAGE, 36)

func test_capacity_one_page() -> void:
	var inv := InventoryData.new()
	inv.unlocked_equipment_pages = 1
	assert_eq(inv.equipment_capacity(), 36)

func test_capacity_three_pages() -> void:
	var inv := InventoryData.new()
	inv.unlocked_equipment_pages = 3
	assert_eq(inv.equipment_capacity(), 108)

#-----------------------------------------------------------------------------
# FREE SLOTS
#-----------------------------------------------------------------------------

func test_a_new_inventory_has_every_slot_free_lowest_first() -> void:
	var inv := InventoryData.new()
	var free: PackedInt32Array = inv.free_equipment_slots()
	assert_eq(free.size(), inv.equipment_capacity())
	assert_eq(free[0], 0, "the lowest comes first")
	assert_eq(free[free.size() - 1], inv.equipment_capacity() - 1, "the highest comes last")

func test_free_slots_leave_out_the_occupied_ones() -> void:
	var inv := InventoryData.new()
	inv.equipment[0] = ItemInstanceData.new()
	inv.equipment[2] = ItemInstanceData.new()
	var free: PackedInt32Array = inv.free_equipment_slots()
	assert_eq(free.size(), inv.equipment_capacity() - 2)
	assert_eq(free[0], 1, "slot 0 is taken, so the first free one is 1")
	assert_eq(free[1], 3, "and slot 2 is skipped")

func test_free_slots_ignore_an_item_past_the_capacity() -> void:
	var inv := InventoryData.new()
	inv.unlocked_equipment_pages = 1
	inv.equipment[40] = ItemInstanceData.new()
	assert_eq(inv.free_equipment_slots().size(), InventoryData.SLOTS_PER_PAGE, "slot 40 is not one of the 36")

func test_a_full_grid_has_no_free_slot() -> void:
	var inv := InventoryData.new()
	for index: int in inv.equipment_capacity():
		inv.equipment[index] = ItemInstanceData.new()
	assert_true(inv.free_equipment_slots().is_empty())

func test_granting_a_page_adds_its_slots_to_the_free_ones() -> void:
	var inv := InventoryData.new()
	var before: int = inv.free_equipment_slots().size()
	inv.unlocked_equipment_pages += 1
	assert_eq(inv.free_equipment_slots().size(), before + InventoryData.SLOTS_PER_PAGE)
