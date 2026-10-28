extends GutTest

## Verifies the equipment category filter: selecting a category fades every
## slot whose item does not match into the paper (a shallow slot, the icon mixed
## towards the paper colour), leaving matches in deep slots. The fade is opaque:
## nothing sets modulate. Purely visual: no items are removed or moved.

const GridScene := preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn")
const FADE_MATERIAL_PATH: String = "res://assets/shaders/paper_fade_material.tres"
const Slot := EquipmentDefinitionData.EquipmentSlot

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func after_each() -> void:
	# The inventory view's PaginationBar frees its old page buttons a frame
	# late: let that frame pass so GUT counts no orphans.
	await wait_process_frames(1)

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

func _assert_untinted(slots: Array) -> void:
	for slot: InventorySlot in slots:
		assert_eq(slot.modulate, Color.WHITE, "%s is never tinted" % slot.name)

func test_filter_fades_non_matching_and_empty_slots() -> void:
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
	assert_false(slots[0].is_filtered_out(), "weapon slot stays in")
	assert_true(slots[1].is_filtered_out(), "armor slot fades")
	assert_true(slots[2].is_filtered_out(), "empty slot fades")
	_assert_untinted(slots)
	assert_eq(slots[0].texture, InventorySlot.DEEP_TEXTURE, "a match keeps its deep slot")
	assert_eq(slots[1].texture, InventorySlot.SHALLOW_TEXTURE, "a faded item sits in a shallow slot")
	assert_null(slots[0].item_instance.item_icon.material, "a match's icon is drawn as it is")
	assert_eq(slots[1].item_instance.item_icon.material.resource_path, FADE_MATERIAL_PATH, "a faded icon is mixed into the paper")

func test_match_all_clears_fading() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.equipment[0] = _equip(Slot.HEAD)
	var grid := GridScene.instantiate()
	add_child_autofree(grid)
	await get_tree().process_frame
	grid.set_category_filter(_weapons_match)
	await get_tree().process_frame
	grid.set_category_filter(func(_d: ItemInstanceData) -> bool: return true)
	await get_tree().process_frame
	for slot: InventorySlot in grid.get_slots():
		assert_false(slot.is_filtered_out(), "no slot fades under match-all")
	assert_null(grid.get_slots()[0].item_instance.item_icon.material, "the fade comes off")
	assert_eq(grid.get_slots()[0].texture, InventorySlot.DEEP_TEXTURE)

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
	assert_false(slots[0].is_filtered_out(), "weapon stays in after page flip")
	assert_true(slots[1].is_filtered_out(), "armor fades after page flip")
	assert_true(slots[2].is_filtered_out(), "empty slot fades after page flip")
	_assert_untinted(slots)

func test_tab_wires_filter_words_to_grid() -> void:
	var inv := PersistenceManager.save_game_data.inventory
	inv.equipment[0] = _equip(Slot.MAIN_HAND)  # weapon
	inv.equipment[1] = _equip(Slot.HEAD)       # armor
	var tab := _equipment_tab()
	await get_tree().process_frame
	tab._on_filter_changed(1)  # "WEAPONS"
	await get_tree().process_frame
	var slots: Array = tab.equipment_grid.get_slots()
	assert_false(slots[0].is_filtered_out(), "weapon stays in via tab")
	assert_true(slots[1].is_filtered_out(), "armor fades via tab")
