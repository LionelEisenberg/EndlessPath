extends GutTest

const TrashSlotScene := preload("res://scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.tscn")

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_first_drop_is_held_no_destroy() -> void:
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	var inst := ItemInstanceData.new()
	inst.item_definition = EquipmentDefinitionData.new()
	inst.item_definition.item_name = "First"
	var prior: String = trash.accept(inst)
	assert_eq(prior, "")
	assert_true(trash.is_holding())

func test_second_drop_destroys_first_returns_prior_name() -> void:
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	var inst1 := ItemInstanceData.new()
	inst1.item_definition = EquipmentDefinitionData.new()
	inst1.item_definition.item_name = "First"
	var inst2 := ItemInstanceData.new()
	inst2.item_definition = EquipmentDefinitionData.new()
	inst2.item_definition.item_name = "Second"
	trash.accept(inst1)
	var prior: String = trash.accept(inst2)
	assert_eq(prior, "First")
	assert_eq(trash.get_held(), inst2)

func test_flush_returns_held_equipment_to_inventory() -> void:
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	var inst := ItemInstanceData.new()
	inst.item_definition = EquipmentDefinitionData.new()
	trash.accept(inst)
	trash.flush_to_inventory()
	assert_false(trash.is_holding())
	assert_eq(InventoryManager.get_inventory().equipment.size(), 1)

func test_flush_restores_material_with_correct_quantity() -> void:
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	var def := MaterialDefinitionData.new()
	def.item_id = "ash_powder"
	trash.accept([def, 1])
	trash.flush_to_inventory()
	assert_eq(InventoryManager.get_inventory().materials[def], 1)

func test_return_to_original_routes_back_into_hold_buffer_for_trash() -> void:
	# Spin up the EquipmentTab so we can drive _return_to_original.
	var tab_scene: PackedScene = load("res://scenes/inventory/inventory_view/inventory_view.tscn")
	# Use the inventory_view scene which contains the equipment_tab subtree —
	# because equipment_tab.gd is the script with _return_to_original.
	var view = tab_scene.instantiate()
	add_child_autofree(view)
	await get_tree().process_frame
	var equipment_tab: Node = view.find_child("EquipmentTab", true, false)
	assert_not_null(equipment_tab, "EquipmentTab node not found in inventory_view")

	var trash: TrashSlot = view.find_child("TrashSlot", true, false)
	assert_not_null(trash, "TrashSlot node not found in inventory_view")

	# Seed the hold-buffer.
	var inst := ItemInstanceData.new()
	inst.item_definition = EquipmentDefinitionData.new()
	inst.item_definition.item_name = "Held"
	trash.accept(inst)
	assert_true(trash.is_holding())

	# Simulate pick-up from trash: clear hold-buffer and stage a fake
	# dragged_item visual whose data matches the held instance.
	trash.clear_hold()
	var item_instance_scene: PackedScene = preload("res://scenes/inventory/item_instance/item_instance.tscn")
	var visual = item_instance_scene.instantiate()
	view.add_child(visual)
	visual.setup(inst)
	equipment_tab.dragged_item = visual
	equipment_tab.original_slot = trash

	# Drive the bug-fix branch.
	equipment_tab._return_to_original()

	# Assert: hold-buffer repopulated, visual queue_freed (or freed).
	assert_true(trash.is_holding(), "hold-buffer should be repopulated")
	assert_eq(trash.get_held(), inst, "held value should be the original instance")

func test_flush_clears_held_item_visual() -> void:
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	trash.accept(_equipment_instance("Held"))
	trash.flush_to_inventory()
	assert_null(trash.item_instance, "closing the book must not leave the held item's icon in the trash")

func test_reopening_after_flush_cannot_restore_the_item_twice() -> void:
	var tab: Node = await _equipment_tab()
	var trash: TrashSlot = tab.trash_slot
	var inst := _equipment_instance("Held")
	trash.accept(inst)
	trash.flush_to_inventory()  # the book closes

	# The book reopens: the player presses on the trash slot and releases.
	tab._on_slot_input(trash, _mouse_button(MOUSE_BUTTON_LEFT, true))
	tab._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	trash.flush_to_inventory()  # the book closes again

	assert_eq(_occurrences(inst), 1, "the trashed-then-restored item must exist exactly once")

func test_right_click_on_held_trash_item_leaves_the_grid_untouched() -> void:
	var tab: Node = await _equipment_tab()
	var trash: TrashSlot = tab.trash_slot
	var inv := InventoryManager.get_inventory()
	# Park an unrelated item at the grid index the trash slot's child position
	# maps to — where a grid-style quick-equip would erase or overwrite.
	var bystander := _equipment_instance("Bystander")
	var aliased_index: int = tab._grid_global_index(trash)
	inv.equipment[aliased_index] = bystander
	var held := _equipment_instance("Held")
	trash.accept(held)

	tab._on_slot_input(trash, _mouse_button(MOUSE_BUTTON_RIGHT, true))

	assert_eq(inv.equipment.get(aliased_index), bystander, "right-clicking the trash must not erase or overwrite a grid item")
	assert_true(trash.is_holding(), "the trash keeps its held item")
	trash.flush_to_inventory()
	assert_eq(_occurrences(held), 1, "the held item must exist exactly once after the book closes")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _equipment_tab() -> Node:
	var view: Node = load("res://scenes/inventory/inventory_view/inventory_view.tscn").instantiate()
	add_child_autofree(view)
	await get_tree().process_frame
	return view.find_child("EquipmentTab", true, false)

func _equipment_instance(item_name: String) -> ItemInstanceData:
	var def := EquipmentDefinitionData.new()
	def.item_name = item_name
	def.slot_type = EquipmentDefinitionData.EquipmentSlot.MAIN_HAND
	var inst := ItemInstanceData.new()
	inst.item_definition = def
	return inst

func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

## Counts every place the inventory holds `inst`: grid slots plus both gear dicts.
func _occurrences(inst: ItemInstanceData) -> int:
	var inv := InventoryManager.get_inventory()
	var count := 0
	for value in inv.equipment.values():
		if value == inst:
			count += 1
	for value in inv.equipped_gear.values():
		if value == inst:
			count += 1
	for value in inv.equipped_accessories.values():
		if value == inst:
			count += 1
	return count
