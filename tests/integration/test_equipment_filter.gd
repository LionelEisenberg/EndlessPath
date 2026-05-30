extends GutTest

## Verifies the equipment category filter: selecting a category dims
## (modulate.a) every slot whose item does not match, leaving matches at full
## opacity. Purely visual — no items are removed or moved.

const GridScene := preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn")
const Slot := EquipmentDefinitionData.EquipmentSlot

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func _equip(slot_type: int) -> ItemInstanceData:
	var def := EquipmentDefinitionData.new()
	def.slot_type = slot_type
	var inst := ItemInstanceData.new()
	inst.item_definition = def
	return inst

func _weapons_match(d: ItemInstanceData) -> bool:
	return d != null and d.item_definition is EquipmentDefinitionData \
		and (d.item_definition as EquipmentDefinitionData).slot_type in [Slot.MAIN_HAND, Slot.OFF_HAND]

func _equipment_tab() -> Node:
	var view: Node = load("res://scenes/inventory/inventory_view/inventory_view.tscn").instantiate()
	add_child_autofree(view)
	return view.find_child("EquipmentTab", true, false)

func test_filter_dims_non_matching_and_empty_slots() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.equipment[0] = _equip(Slot.MAIN_HAND)  # weapon
	inv.equipment[1] = _equip(Slot.HEAD)       # armor
	# slot 2 left empty
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	grid.set_category_filter(_weapons_match)
	await get_tree().process_frame
	var slots: Array = grid.get_slots()
	assert_almost_eq(slots[0].modulate.a, 1.0, 0.001, "weapon slot stays full opacity")
	assert_almost_eq(slots[1].modulate.a, grid.DIM_ALPHA, 0.001, "armor slot dimmed")
	assert_almost_eq(slots[2].modulate.a, grid.DIM_ALPHA, 0.001, "empty slot dimmed")

func test_match_all_clears_dimming() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.equipment[0] = _equip(Slot.HEAD)
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	grid.set_category_filter(_weapons_match)
	await get_tree().process_frame
	grid.set_category_filter(func(_d: ItemInstanceData) -> bool: return true)
	await get_tree().process_frame
	for slot in grid.get_slots():
		assert_almost_eq(slot.modulate.a, 1.0, 0.001, "all slots full under match-all")

func test_filter_persists_across_page_flip() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.unlocked_equipment_pages = 2
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	var sp: int = grid.slots_per_page()
	inv.equipment[sp] = _equip(Slot.MAIN_HAND)      # page 1, slot 0 -> weapon
	inv.equipment[sp + 1] = _equip(Slot.HEAD)       # page 1, slot 1 -> armor
	grid.set_category_filter(_weapons_match)
	grid.set_page(1)
	await get_tree().process_frame
	var slots: Array = grid.get_slots()
	assert_almost_eq(slots[0].modulate.a, 1.0, 0.001, "weapon stays full after page flip")
	assert_almost_eq(slots[1].modulate.a, grid.DIM_ALPHA, 0.001, "armor dimmed after page flip")

func test_tab_wires_banner_to_grid_filter() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.equipment[0] = _equip(Slot.MAIN_HAND)  # weapon
	inv.equipment[1] = _equip(Slot.HEAD)       # armor
	var tab := _equipment_tab()
	await get_tree().process_frame
	tab._on_filter_changed(1)  # "Weapons"
	await get_tree().process_frame
	var slots: Array = tab.equipment_grid.get_slots()
	assert_almost_eq(slots[0].modulate.a, 1.0, 0.001, "weapon highlighted via tab")
	assert_almost_eq(slots[1].modulate.a, tab.equipment_grid.DIM_ALPHA, 0.001, "armor dimmed via tab")
