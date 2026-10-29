extends GutTest

## Integration tests for the Character book: the attribute tiles on the left
## page, the one pointed at described on the right page with effects worked
## out from the unlocked abilities, and the pages waiting for the book to open.
## AbilityManager runs on a test save, swapped in and restored around each test.

const CharacterViewScene := preload("res://scenes/character/character_view.tscn")
const ANIMATION_TIMEOUT: float = 2.0

var _view: CharacterView
var _save_data: SaveGameData
var _previous_save: SaveGameData

func before_each() -> void:
	_previous_save = AbilityManager._live_save_data
	_save_data = SaveGameData.new()
	_save_data.unlocked_ability_ids = ["basic_strike", "empty_palm"]
	AbilityManager._live_save_data = _save_data
	# Other suites replace the catalog index with fakes; start from the real one.
	AbilityManager._build_catalog_index()
	_view = CharacterViewScene.instantiate() as CharacterView
	add_child_autofree(_view)

func after_each() -> void:
	AbilityManager._live_save_data = _previous_save

func _tile(tile_name: String) -> AttributeTile:
	return _view.find_child(tile_name, true, false) as AttributeTile

func _label(label_name: String) -> Label:
	return _view.find_child(label_name, true, false) as Label

## The effect line for an ability's damage scaling with the attribute.
func _scaling_line(ability_path: String, attribute: CharacterAttributesData.AttributeType) -> String:
	var ability: AbilityData = load(ability_path) as AbilityData
	var scaling: float = ability.effects_on_target[0].get_scaling(attribute)
	return "%s: +%s damage per point" % [ability.ability_name, AbilityRow.format_number(scaling)]

#-----------------------------------------------------------------------------
# LEFT PAGE
#-----------------------------------------------------------------------------

func test_values_come_from_character_manager() -> void:
	_view.refresh()
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var value_label: Label = _tile("WillpowerTile").find_child("ValueLabel", true, false) as Label
	assert_eq(value_label.text, "%.0f" % attrs.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER))

#-----------------------------------------------------------------------------
# RIGHT PAGE
#-----------------------------------------------------------------------------

func test_opening_shows_strength() -> void:
	_view.select_attribute(CharacterAttributesData.AttributeType.WILLPOWER)
	_view.animate_open()
	assert_eq(_view.get_selected_attribute(), CharacterAttributesData.AttributeType.STRENGTH)
	assert_eq(_label("DetailPlaque").text, "Strength")
	assert_true(_tile("StrengthTile").is_selected())

func test_hovering_a_tile_describes_it() -> void:
	_view.animate_open()
	var body_tile: AttributeTile = _tile("BodyTile")
	body_tile.hovered.emit(body_tile)
	var details: Dictionary = CharacterView.ATTRIBUTE_DETAILS[CharacterAttributesData.AttributeType.BODY]
	assert_eq(_label("DetailPlaque").text, "Body")
	assert_eq(_label("DetailName").text, "Body")
	assert_eq(_label("DetailDescription").text, details["description"])
	assert_true(body_tile.is_selected())
	assert_false(_tile("StrengthTile").is_selected(), "only one tile looks selected")

func test_every_attribute_has_details() -> void:
	for attr_type: int in CharacterAttributesData.AttributeType.values():
		assert_has(CharacterView.ATTRIBUTE_DETAILS, attr_type)

#-----------------------------------------------------------------------------
# EFFECTS
#-----------------------------------------------------------------------------

func test_effects_list_unlocked_abilities_that_scale_with_it() -> void:
	_view.select_attribute(CharacterAttributesData.AttributeType.AGILITY)
	var effects: String = _label("EffectsLabel").text
	assert_string_contains(effects, _scaling_line("res://resources/abilities/basic_strike.tres", CharacterAttributesData.AttributeType.AGILITY))
	assert_string_contains(effects, _scaling_line("res://resources/abilities/empty_palm.tres", CharacterAttributesData.AttributeType.AGILITY))

func test_locked_abilities_stay_off_the_page() -> void:
	# Power Font scales with Spirit, but this save hasn't unlocked it.
	_view.select_attribute(CharacterAttributesData.AttributeType.SPIRIT)
	assert_false(_label("EffectsLabel").text.contains("Power Font"))

func test_an_attribute_with_no_effects_says_so() -> void:
	_view.select_attribute(CharacterAttributesData.AttributeType.CONTROL)
	assert_eq(_label("EffectsLabel").text, CharacterView.NO_EFFECTS_TEXT)

#-----------------------------------------------------------------------------
# OPENING
#-----------------------------------------------------------------------------

func test_pages_wait_for_the_open_book() -> void:
	var page_layer: Control = _view.find_child("PageLayer", true, false) as Control
	_view.animate_open()
	assert_false(page_layer.visible, "pages appear only once the book lies open")
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	assert_true(page_layer.visible)

func test_pages_hide_as_the_book_closes() -> void:
	var page_layer: Control = _view.find_child("PageLayer", true, false) as Control
	_view.animate_open()
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	watch_signals(_view)
	_view.animate_close()
	assert_false(page_layer.visible)
	await wait_for_signal(_view.close_finished, ANIMATION_TIMEOUT)
	assert_signal_emitted(_view, "close_finished")
