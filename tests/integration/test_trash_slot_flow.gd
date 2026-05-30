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
