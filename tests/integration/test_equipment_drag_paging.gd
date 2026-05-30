extends GutTest

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func _equipment_tab() -> Node:
	var view: Node = load("res://scenes/inventory/inventory_view/inventory_view.tscn").instantiate()
	add_child_autofree(view)
	return view.find_child("EquipmentTab", true, false)

func test_grid_global_index_uses_current_page() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	var tab := _equipment_tab()
	await get_tree().process_frame
	tab.equipment_grid.set_page(1)
	await get_tree().process_frame
	var slot0 = tab.equipment_grid.get_slots()[0]
	# Expected offset = one page's worth of slots, derived from the grid's
	# (tunable) page size rather than hardcoded, so this stays correct as the
	# num_rows/num_columns layout knobs change.
	var per_page: int = tab.equipment_grid.slots_per_page()
	assert_eq(tab._grid_global_index(slot0), per_page, "page 1 slot 0 -> global index equals one page offset")

func test_page_hover_flips_page_only_while_dragging() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	var tab := _equipment_tab()
	await get_tree().process_frame
	tab._on_page_hovered(1)
	assert_eq(tab.equipment_grid.current_page, 0)
	tab.is_dragging = true
	tab._on_page_hovered(1)
	assert_eq(tab.equipment_grid.current_page, 1)
