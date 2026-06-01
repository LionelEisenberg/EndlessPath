extends GutTest

const ItemDetailCardScene := preload("res://scenes/inventory/common/item_detail_card/item_detail_card.tscn")

func test_setup_populates_name_and_type_from_material_def() -> void:
	var card := ItemDetailCardScene.instantiate()
	add_child_autofree(card)
	await get_tree().process_frame

	var def := MaterialDefinitionData.new()
	def.item_id = "test_fern"
	def.item_name = "Spirit Fern"
	def.description = "Smells of rain on hot stone."

	card.setup_from_definition(def)
	assert_eq(card.item_name_label.text, "Spirit Fern")
	assert_eq(card.item_type_label.text, "[Material]")
	assert_eq(card.description_label.text, "Smells of rain on hot stone.")

func test_reset_clears_fields() -> void:
	var card := ItemDetailCardScene.instantiate()
	add_child_autofree(card)
	await get_tree().process_frame
	card.reset()
	assert_eq(card.item_name_label.text, "")
	assert_eq(card.description_label.text, "")
