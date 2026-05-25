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

func test_drag_out_then_drop_outside_returns_to_hold_buffer() -> void:
	# Simulate the full flow: equip the trash, pick up (clear_hold), then
	# restore via accept() — what _return_to_original now does for TrashSlot.
	var trash := TrashSlotScene.instantiate()
	add_child_autofree(trash)
	await get_tree().process_frame
	var inst := ItemInstanceData.new()
	inst.item_definition = EquipmentDefinitionData.new()
	inst.item_definition.item_name = "Held"

	# Put item in trash hold-buffer.
	trash.accept(inst)
	assert_true(trash.is_holding())

	# Player drags it out (the controller's _pick_up_from_trash does this).
	var held = trash.get_held()
	trash.clear_hold()
	assert_false(trash.is_holding())

	# Player releases the drag in empty space — _return_to_original
	# routes the data back into the hold-buffer.
	trash.accept(held)
	assert_true(trash.is_holding())
	assert_eq(trash.get_held(), inst)
