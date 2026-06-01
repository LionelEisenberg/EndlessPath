extends GutTest

const GridScene := preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn")

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func _inst() -> ItemInstanceData:
	var d := ItemInstanceData.new()
	d.item_definition = EquipmentDefinitionData.new()
	return d

func test_grid_always_has_36_slots() -> void:
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	assert_eq(grid.get_slots().size(), 36)

func test_set_page_renders_correct_slice() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	var marker := _inst()
	inv.equipment[36] = marker  # first slot of page 2 (0-based page index 1)

	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame

	grid.set_page(1)
	await get_tree().process_frame
	var slots: Array[InventorySlot] = grid.get_slots()
	assert_not_null(slots[0].item_instance, "page-2 slot 0 should hold the item at global index 36")

func test_set_page_clamps_to_unlocked_range() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	grid.set_page(5)  # only pages 0..1 exist
	assert_eq(grid.current_page, 1)

func test_flipping_to_empty_position_clears_slot() -> void:
	# Regression: flipping to a page where a slot position is empty must clear
	# that slot's item visual, even if the previous page had an item there.
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	inv.equipment[0] = _inst()  # page 0 slot 0 occupied; same position on page 1 empty
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	assert_not_null(grid.get_slots()[0].item_instance, "page 0 slot 0 should show its item")
	grid.set_page(1)
	await get_tree().process_frame
	assert_null(grid.get_slots()[0].item_instance, "page 1 slot 0 should be empty after the flip")
