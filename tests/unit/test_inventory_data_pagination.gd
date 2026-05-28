extends GutTest

func test_default_unlocked_pages_is_one() -> void:
	var inv := InventoryData.new()
	assert_eq(inv.unlocked_equipment_pages, 1)

func test_slots_per_page_constant() -> void:
	assert_eq(InventoryData.SLOTS_PER_PAGE, 36)

func test_capacity_one_page() -> void:
	var inv := InventoryData.new()
	assert_eq(inv.equipment_capacity(), 36)

func test_capacity_three_pages() -> void:
	var inv := InventoryData.new()
	inv.unlocked_equipment_pages = 3
	assert_eq(inv.equipment_capacity(), 108)
