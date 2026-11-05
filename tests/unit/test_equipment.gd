extends GutTest

## Unit tests for EquipmentDefinitionData
## Tests slot enum, attribute bonuses, BBCode effects, initialization, and the
## gear rule: stat bonuses as floored percents of the trained value, then armor
## and Ward, as flat modifiers

const AttributeType = CharacterAttributesData.AttributeType
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")

#-----------------------------------------------------------------------------
# EQUIPMENT SLOT ENUM
#-----------------------------------------------------------------------------

func test_equipment_slot_has_five_values() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.size(), 5, "should have exactly 5 equipment slot types")

## Each slot's int, which item .tres files and saves store: renumbering one
## would corrupt them.
func test_equipment_slot_ints_are_fixed() -> void:
	var cases: Array[Dictionary] = [
		{"name": "MAIN_HAND", "slot": EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "expected": 0},
		{"name": "OFF_HAND", "slot": EquipmentDefinitionData.EquipmentSlot.OFF_HAND, "expected": 1},
		{"name": "HEAD", "slot": EquipmentDefinitionData.EquipmentSlot.HEAD, "expected": 2},
		{"name": "ARMOR", "slot": EquipmentDefinitionData.EquipmentSlot.ARMOR, "expected": 3},
		{"name": "ACCESSORY", "slot": EquipmentDefinitionData.EquipmentSlot.ACCESSORY, "expected": 4},
	]
	for case: Dictionary in cases:
		assert_eq(case.slot, case.expected, "%s's int" % case.name)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func test_init_sets_item_type_to_equipment() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.item_type, ItemDefinitionData.ItemType.EQUIPMENT, "_init should set item_type to EQUIPMENT")

func test_init_default_slot_is_main_hand() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.slot_type, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "default slot should be MAIN_HAND")

func test_init_empty_bonuses() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.attribute_bonuses.size(), 0, "default bonuses should be empty")

#-----------------------------------------------------------------------------
# ATTRIBUTE BONUSES DICTIONARY
#-----------------------------------------------------------------------------

## attribute_bonuses keeps each bonus as set: two bonuses together, a negative
## one and a fractional one.
func test_attribute_bonuses_stores_values() -> void:
	var cases: Array[Dictionary] = [
		{"name": "two bonuses", "bonuses": {
			CharacterAttributesData.AttributeType.STRENGTH: 5.0,
			CharacterAttributesData.AttributeType.AGILITY: 3.0,
		}},
		{"name": "a negative bonus", "bonuses": {CharacterAttributesData.AttributeType.AGILITY: -5.0}},
		{"name": "a fractional bonus", "bonuses": {CharacterAttributesData.AttributeType.SPIRIT: 2.5}},
	]
	for case: Dictionary in cases:
		var equip = EquipmentDefinitionData.new()
		equip.attribute_bonuses = case.bonuses
		for attr_type: int in case.bonuses:
			assert_almost_eq(equip.attribute_bonuses[attr_type], case.bonuses[attr_type], 0.001, "%s: attribute %d" % [case.name, attr_type])

func test_attribute_bonuses_supports_all_types() -> void:
	var equip = EquipmentDefinitionData.new()
	for attr_type in CharacterAttributesData.AttributeType.values():
		equip.attribute_bonuses[attr_type] = float(attr_type) + 1.0
	assert_eq(equip.attribute_bonuses.size(), 6, "all six stats")

#-----------------------------------------------------------------------------
# _get_item_effects() BBCode FORMATTING
#-----------------------------------------------------------------------------

## _get_item_effects() gives one line per non-zero bonus: none for no bonuses,
## three for three, and a zero bonus left out.
func test_get_item_effects_one_line_per_nonzero_bonus() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no bonuses", "bonuses": {}, "expected": 0},
		{"name": "three bonuses", "bonuses": {
			CharacterAttributesData.AttributeType.STRENGTH: 5.0,
			CharacterAttributesData.AttributeType.BODY: 3.0,
			CharacterAttributesData.AttributeType.AGILITY: -1.0,
		}, "expected": 3},
		# Zero values are excluded by the > 0 and < 0 checks
		{"name": "a zero bonus", "bonuses": {
			CharacterAttributesData.AttributeType.STRENGTH: 5.0,
			CharacterAttributesData.AttributeType.BODY: 0.0,
		}, "expected": 1},
	]
	for case: Dictionary in cases:
		var equip = EquipmentDefinitionData.new()
		equip.attribute_bonuses = case.bonuses
		assert_eq(equip._get_item_effects().size(), case.expected, "%s: one line per non-zero bonus" % case.name)

## A bonus's line names its attribute and shows its value: "+" before a
## positive one, a negative one's own "-" and no "+", a fraction's decimal, and
## a whole number without one.
func test_get_item_effects_formats_each_bonus() -> void:
	var cases: Array[Dictionary] = [
		{"name": "positive", "attr": CharacterAttributesData.AttributeType.STRENGTH, "value": 5.0,
			"shows": ["+5", "Strength"], "hides": []},
		{"name": "negative", "attr": CharacterAttributesData.AttributeType.AGILITY, "value": -3.0,
			"shows": ["-3", "Agility"], "hides": ["+"]},
		{"name": "fractional", "attr": CharacterAttributesData.AttributeType.SPIRIT, "value": 2.5,
			"shows": ["2.5"], "hides": []},
		{"name": "whole number", "attr": CharacterAttributesData.AttributeType.MIND, "value": 10.0,
			"shows": ["+10"], "hides": []},
	]
	for case: Dictionary in cases:
		var equip = EquipmentDefinitionData.new()
		equip.attribute_bonuses = {case.attr: case.value}
		var effects = equip._get_item_effects()
		assert_eq(effects.size(), 1, "%s: one line for one bonus" % case.name)
		if effects.size() != 1:
			continue
		for text: String in case.shows:
			assert_true(effects[0].contains(text), "%s bonus should show %s: %s" % [case.name, text, effects[0]])
		for text: String in case.hides:
			assert_false(effects[0].contains(text), "%s bonus should not show %s: %s" % [case.name, text, effects[0]])

#-----------------------------------------------------------------------------
# SLOT TYPE ASSIGNMENT
#-----------------------------------------------------------------------------

func test_different_slot_types() -> void:
	for slot in EquipmentDefinitionData.EquipmentSlot.values():
		var equip = EquipmentDefinitionData.new()
		equip.slot_type = slot
		assert_eq(equip.slot_type, slot, "should accept slot type %d" % slot)

#-----------------------------------------------------------------------------
# INHERITANCE
#-----------------------------------------------------------------------------

func test_extends_item_definition_data() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_true(equip is ItemDefinitionData, "should extend ItemDefinitionData")

#-----------------------------------------------------------------------------
# STAT BONUSES AND MODIFIERS
#-----------------------------------------------------------------------------

func test_stat_bonus_is_the_rounded_down_percent_with_the_item_floor() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the floor at a low value", "percent": 0.1, "floor": 2, "trained": 10.0, "expected": 2.0},
		{"name": "the percent above the floor", "percent": 0.25, "floor": 2, "trained": 20.0, "expected": 5.0},
		{"name": "rounded down", "percent": 0.25, "floor": 1, "trained": 18.0, "expected": 4.0},
		{"name": "a floor of 1 under a small percent", "percent": 0.05, "floor": 1, "trained": 10.0, "expected": 1.0},
	]
	for case: Dictionary in cases:
		var item := GearFixture.item({&"strength": case.percent}, case.floor)
		assert_eq(item.get_stat_bonus(AttributeType.STRENGTH, case.trained), case.expected, case.name)

func test_stat_bonus_without_a_percent_is_zero() -> void:
	var cases: Array[Dictionary] = [
		{"name": "another stat's percent", "percents": {&"agility": 0.5}},
		{"name": "a 0% entry", "percents": {&"strength": 0.0}},
	]
	for case: Dictionary in cases:
		assert_eq(GearFixture.item(case.percents, 3).get_stat_bonus(AttributeType.STRENGTH, 10.0), 0.0, case.name)

func test_stat_modifiers_are_flat_bonuses_with_armor_and_ward() -> void:
	var item := GearFixture.item({&"strength": 0.5, &"mind": 0.25}, 1, 6.0, 4.0)
	var trained: Dictionary = {AttributeType.STRENGTH: 10.0, AttributeType.MIND: 20.0}
	var values: Dictionary = {}
	for modifier: StatModifierData in item.get_stat_modifiers(trained):
		assert_eq(modifier.kind, StatModifierData.Kind.FLAT, "%s is flat" % StatModifierData.Stat.keys()[modifier.stat])
		values[modifier.stat] = modifier.value
	assert_eq(values, {StatModifierData.Stat.STRENGTH: 5.0, StatModifierData.Stat.MIND: 5.0,
		StatModifierData.Stat.ARMOR: 6.0, StatModifierData.Stat.WARD: 4.0})

func test_a_bare_item_gives_no_modifiers() -> void:
	assert_eq(EquipmentDefinitionData.new().get_stat_modifiers({}).size(), 0)
