extends GutTest

func test_inits_as_quest_item_type() -> void:
	var d := QuestItemDefinitionData.new()
	assert_eq(d.item_type, ItemDefinitionData.ItemType.QUEST_ITEM)

func test_from_source_field_round_trips() -> void:
	var d := QuestItemDefinitionData.new()
	d.from_source = "Old Vesh"
	assert_eq(d.from_source, "Old Vesh")
