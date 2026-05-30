extends GutTest

## Integration test for the Journal (Quest Items) tab. Verifies that a
## QuestItemDefinitionData with a from_source renders through to the
## QuestJournalCard's Name + From row.

func before_each() -> void:
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_journal_renders_quest_item_from_source() -> void:
	var def := QuestItemDefinitionData.new()
	def.item_id = "test_map"
	def.item_name = "Test Map"
	def.description = "A folded scrap of parchment."
	def.from_source = "Old Vesh"
	InventoryManager.award_items(def, 1)

	var tab_scene := load("res://scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn")
	var tab = tab_scene.instantiate()
	add_child_autofree(tab)
	await get_tree().process_frame

	var card = tab.get_node("%QuestJournalCard")
	assert_eq(card.get_node("%Name").text, "Test Map")
	assert_true(card.get_node("%FromRow").visible)
	assert_eq(card.get_node("%FromValue").text, "Old Vesh")
