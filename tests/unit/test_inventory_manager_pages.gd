extends GutTest

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func _make_equipment() -> EquipmentDefinitionData:
	var def := EquipmentDefinitionData.new()
	def.item_id = "test_blade"
	def.item_name = "Test Blade"
	return def

func test_grant_equipment_page_increments_and_emits() -> void:
	watch_signals(InventoryManager)
	InventoryManager.grant_equipment_page()
	assert_eq(InventoryManager.get_inventory().unlocked_equipment_pages, 2)
	assert_signal_emitted(InventoryManager, "inventory_changed")

func test_award_fills_first_page_then_stops_at_capacity() -> void:
	var def := _make_equipment()
	InventoryManager.award_items(def, 36)
	var inv := InventoryManager.get_inventory()
	assert_eq(inv.equipment.size(), 36)
	assert_true(inv.equipment.has(0))
	assert_true(inv.equipment.has(35))
	InventoryManager.award_items(def, 1)
	assert_eq(InventoryManager.get_inventory().equipment.size(), 36)

func test_granting_a_page_makes_room_for_more() -> void:
	var def := _make_equipment()
	InventoryManager.award_items(def, 36)
	InventoryManager.grant_equipment_page()
	InventoryManager.award_items(def, 1)
	var inv := InventoryManager.get_inventory()
	assert_eq(inv.equipment.size(), 37)
	assert_true(inv.equipment.has(36))
