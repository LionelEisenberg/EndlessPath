extends GutTest

func before_each() -> void:
	# Reset inventory between tests
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_restore_equipment_instance_puts_into_first_available_slot() -> void:
	var def := EquipmentDefinitionData.new()
	def.item_id = "test_blade"
	def.item_name = "Test Blade"
	var inst := ItemInstanceData.new()
	inst.item_definition = def
	InventoryManager.restore_equipment_instance(inst)
	assert_eq(InventoryManager.get_inventory().equipment.size(), 1)
	assert_eq(InventoryManager.get_inventory().equipment[0].item_definition.item_id, "test_blade")

func test_restore_equipment_at_specific_index_when_empty() -> void:
	var def := EquipmentDefinitionData.new()
	var inst := ItemInstanceData.new()
	inst.item_definition = def
	InventoryManager.restore_equipment_instance(inst, 5)
	assert_true(InventoryManager.get_inventory().equipment.has(5))

func test_restore_equipment_falls_back_to_first_available_if_target_occupied() -> void:
	var def := EquipmentDefinitionData.new()
	var a := ItemInstanceData.new(); a.item_definition = def
	var b := ItemInstanceData.new(); b.item_definition = def
	InventoryManager.restore_equipment_instance(a, 0)
	InventoryManager.restore_equipment_instance(b, 0) # 0 occupied, falls back to 1
	assert_true(InventoryManager.get_inventory().equipment.has(0))
	assert_true(InventoryManager.get_inventory().equipment.has(1))

func test_restore_material_increments_count() -> void:
	var def := MaterialDefinitionData.new()
	def.item_id = "fern"
	InventoryManager.restore_material(def, 3)
	assert_eq(InventoryManager.get_inventory().materials[def], 3)
	InventoryManager.restore_material(def, 2)
	assert_eq(InventoryManager.get_inventory().materials[def], 5)
