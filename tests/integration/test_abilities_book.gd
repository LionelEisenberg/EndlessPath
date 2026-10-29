extends GutTest

## Integration tests for the Abilities book: the inventory-style filter, the
## ability rows in loadout order, right-click quick equip, the loadout, and the
## details of the ability pointed at. AbilityManager runs on a test save,
## swapped in and restored around each test.

const AbilitiesViewScene := preload("res://scenes/abilities/abilities_view.tscn")
const EXTRA_ID: String = "test_extra_ability"
const STRENGTH_ICON: Texture2D = preload("res://assets/sprites/ui/attribute_icons/strength_icon.png")
const AGILITY_ICON: Texture2D = preload("res://assets/sprites/ui/attribute_icons/agility_icon.png")

## A damage effect that counts its previews, so tests can tell when the book
## recomputes one.
class CountingEffect extends CombatEffectData:
	var calls: int = 0

	func calculate_value(_caster_attributes: CharacterAttributesData) -> float:
		calls += 1
		return 42.0

var _view: AbilitiesView
var _save_data: SaveGameData
var _previous_save: SaveGameData

func before_each() -> void:
	_previous_save = AbilityManager._live_save_data
	_save_data = SaveGameData.new()
	_save_data.unlocked_ability_ids = ["basic_strike", "empty_palm", "enforce", "power_font"]
	_save_data.equipped_ability_ids = ["basic_strike", "", "", ""]
	AbilityManager._live_save_data = _save_data
	# Other suites replace the catalog index with fakes; start from the real one.
	AbilityManager._build_catalog_index()
	_view = AbilitiesViewScene.instantiate() as AbilitiesView
	add_child_autofree(_view)
	_view.refresh()

func after_each() -> void:
	AbilityManager._live_save_data = _previous_save
	AbilityManager._abilities_by_id.erase(EXTRA_ID)

func _row_for(ability_id: String) -> AbilityRow:
	for row: AbilityRow in _view.get_rows():
		if row.get_ability_data().ability_id == ability_id:
			return row
	return null

func _label(label_name: String) -> Label:
	return _view.find_child(label_name, true, false) as Label

func _listed_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: AbilityRow in _view.get_rows():
		ids.append(row.get_ability_data().ability_id)
	return ids

## Unlocks an extra damage ability whose effect counts its previews.
func _add_counting_ability() -> CountingEffect:
	var effect := CountingEffect.new()
	effect.base_value = 1.0
	var effects: Array[CombatEffectData] = [effect]
	var extra := AbilityData.new()
	extra.ability_id = EXTRA_ID
	extra.ability_name = "Extra"
	extra.effects_on_target = effects
	AbilityManager._abilities_by_id[EXTRA_ID] = extra
	_save_data.unlocked_ability_ids.append(EXTRA_ID)
	_view.refresh()
	return effect

func _hover(ability_id: String) -> void:
	var row: AbilityRow = _row_for(ability_id)
	row.hovered.emit(row)

#-----------------------------------------------------------------------------
# SELECTORS AND LIST
#-----------------------------------------------------------------------------

func test_loadout_order_follows_the_slots() -> void:
	_save_data.equipped_ability_ids = ["enforce", "", "basic_strike", ""]
	_view.refresh()
	assert_eq(_listed_ids(), ["enforce", "basic_strike", "empty_palm", "power_font"] as Array[String],
		"equipped in Q, W, E, R order, then the rest by name")

func test_rows_list_every_unlocked_ability() -> void:
	assert_eq(_view.get_rows().size(), 4)

func test_equipped_filter_lists_only_the_loadout() -> void:
	var filter: SortSubBanner = _view.find_child("FilterSelector", true, false) as SortSubBanner
	filter.prev()  # wraps from All to Equipped
	assert_eq(_listed_ids(), ["basic_strike"] as Array[String])

func test_equipped_rows_show_their_key() -> void:
	var chip: Label = _row_for("basic_strike").find_child("KeyChip", true, false) as Label
	assert_true(chip.visible)
	assert_eq(chip.text, "Q")

#-----------------------------------------------------------------------------
# QUICK EQUIP
#-----------------------------------------------------------------------------

func test_right_click_on_a_row_asks_to_equip() -> void:
	var row: AbilityRow = _row_for("empty_palm")
	watch_signals(row)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	row._gui_input(click)
	assert_signal_emitted_with_parameters(row, "quick_equip_requested", ["empty_palm"])

func test_quick_equip_fills_the_first_free_slot() -> void:
	_view.toggle_equipped("empty_palm")
	assert_eq(AbilityManager.get_ability_at_slot(1), "empty_palm")

func test_quick_equip_unequips() -> void:
	_view.toggle_equipped("basic_strike")
	assert_false(AbilityManager.is_ability_equipped("basic_strike"))

func test_quick_equip_with_full_loadout_changes_nothing() -> void:
	var extra := AbilityData.new()
	extra.ability_id = EXTRA_ID
	extra.ability_name = "Extra"
	AbilityManager._abilities_by_id[EXTRA_ID] = extra
	_save_data.unlocked_ability_ids.append(EXTRA_ID)
	_save_data.equipped_ability_ids = ["basic_strike", "empty_palm", "enforce", "power_font"]
	_view.refresh()
	_view.toggle_equipped(EXTRA_ID)
	assert_false(AbilityManager.is_ability_equipped(EXTRA_ID))
	assert_eq(_save_data.equipped_ability_ids, ["basic_strike", "empty_palm", "enforce", "power_font"])

#-----------------------------------------------------------------------------
# DETAILS
#-----------------------------------------------------------------------------

func test_hover_selects_and_describes() -> void:
	var row: AbilityRow = _row_for("enforce")
	row.hovered.emit(row)
	assert_eq(_view.get_selected_ability_id(), "enforce")
	assert_eq(_label("DetailName").text, "Enforce")
	assert_true(row.is_selected())
	assert_false(_row_for("basic_strike").is_selected(), "only one row looks selected")

func test_opening_selects_the_first_row() -> void:
	_view.select_ability("power_font")
	_view.animate_open()
	assert_eq(_view.get_selected_ability_id(), _view.get_rows()[0].get_ability_data().ability_id)

func test_damage_shows_the_total_and_each_attributes_part() -> void:
	_view.select_ability("basic_strike")
	var effect: CombatEffectData = (load("res://resources/abilities/basic_strike.tres") as AbilityData).effects_on_target[0]
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	assert_eq(_label("PrimaryValue").text, AbilityRow.format_number(effect.calculate_value(attrs)))
	assert_eq(_label("ExplainText").text, "%s base" % AbilityRow.format_number(effect.base_value))
	var strength_part: ScalingPart = _view.find_child("ScalingPart1", true, false) as ScalingPart
	var agility_part: ScalingPart = _view.find_child("ScalingPart2", true, false) as ScalingPart
	assert_true(strength_part.visible and agility_part.visible)
	assert_false((_view.find_child("ScalingPart3", true, false) as Control).visible, "basic strike scales with two attributes")
	assert_eq(strength_part.get_icon(), STRENGTH_ICON)
	assert_eq(strength_part.get_value_text(),
		"+%s" % AbilityRow.format_number(effect.get_scaling_contribution(CharacterAttributesData.AttributeType.STRENGTH, attrs)))
	assert_eq(agility_part.get_icon(), AGILITY_ICON)

func test_buffs_say_what_they_do() -> void:
	# Enforce: the next attack deals 1.5x damage.
	_view.select_ability("enforce")
	assert_eq(_label("PrimaryValue").text, "×1.5 damage")
	assert_false((_view.find_child("ScalingPart1", true, false) as Control).visible)

func test_details_show_timing_and_cost() -> void:
	_view.select_ability("enforce")
	assert_eq(_label("CooldownValue").text, "15 s")
	assert_eq(_label("CastValue").text, "1 s")
	assert_eq(_label("CostValue").text, "10 Madra")

func test_hovering_back_and_forth_previews_damage_once() -> void:
	var effect: CountingEffect = _add_counting_ability()
	for i: int in range(3):
		_hover(EXTRA_ID)
		_hover("enforce")
	assert_eq(effect.calls, 1, "one damage preview per ability while the book is open")

func test_reopening_previews_damage_again() -> void:
	# Attributes can change between openings (gear, path), so the preview can't outlive one.
	var effect: CountingEffect = _add_counting_ability()
	_view.select_ability(EXTRA_ID)
	_view.animate_open()
	_view.select_ability(EXTRA_ID)
	assert_eq(effect.calls, 2)
