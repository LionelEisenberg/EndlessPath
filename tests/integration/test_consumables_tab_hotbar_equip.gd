extends GutTest

## Integration test for the Consumables tab + Combat Hotbar wiring.
## Verifies right-click on a grid slot equips the consumable to the first
## empty hotbar slot, and clicking an equipped hotbar slot unequips it.

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_right_click_consumable_slot_equips_to_first_empty_hotbar_slot() -> void:
	var def := ConsumableDefinitionData.new()
	def.item_id = "scale"
	def.item_name = "Crude Scale"
	InventoryManager.award_items(def, 3)

	var tab_scene := load("res://scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn")
	var tab = tab_scene.instantiate()
	add_child_autofree(tab)
	await get_tree().process_frame

	var first_grid_slot = tab.get_node("%ConsumablesInventoryGrid").get_slots()[0]
	var evt := InputEventMouseButton.new()
	evt.button_index = MOUSE_BUTTON_RIGHT
	evt.pressed = true
	first_grid_slot.clicked.emit(first_grid_slot, evt)

	assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def)

func test_click_equipped_hotbar_slot_unequips() -> void:
	var def := ConsumableDefinitionData.new()
	def.item_id = "scale"
	InventoryManager.award_items(def, 2)
	InventoryManager.equip_consumable(def, 0)

	var tab_scene := load("res://scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn")
	var tab = tab_scene.instantiate()
	add_child_autofree(tab)
	await get_tree().process_frame

	var hotbar = tab.get_node("%ConsumablesCombatHotbar")
	var slot = hotbar.get_node("SlotsRow").get_child(0)
	var evt := InputEventMouseButton.new()
	evt.button_index = MOUSE_BUTTON_LEFT
	evt.pressed = true
	slot.slot_clicked.emit(slot, evt)
	await get_tree().process_frame

	assert_false(InventoryManager.get_inventory().equipped_consumables.has(0))
