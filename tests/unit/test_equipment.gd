extends GutTest

## Unit tests for EquipmentDefinitionData
## Tests the slot enum and its ints, initialization, the gear rule (stat
## bonuses as floored percents of the trained value, then armor and Ward, as
## flat modifiers), and _get_item_effects()'s inked gear lines.
##
## _get_item_effects() reads the player's training, so every test runs on a
## fresh SaveGameData that CharacterManager is re-bound to; the original save
## is restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

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

#-----------------------------------------------------------------------------
# _get_item_effects() BBCode FORMATTING
#-----------------------------------------------------------------------------

## The item tooltip and the shop print these: one per gear_bonus_lines() line,
## for the player's trained values as they stand at each call. Each holds its
## plain line; the ink around it is a look, checked by eye.
func test_item_effects_are_the_gear_lines_at_the_trained_values() -> void:
	var cowl: EquipmentDefinitionData = GearFixture.item({&"spirit": 0.15}, 1, 0.0, 4.0)
	var cases: Array[Dictionary] = [
		{"name": "Spirit Lv 1 (10)", "level": 1, "lines": ["+15% Spirit\u00a0(+1)", "Ward 4"]},
		{"name": "Spirit Lv 5 (14)", "level": 5, "lines": ["+15% Spirit\u00a0(+2)", "Ward 4"]},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.SPIRIT, case.level)
		var effects: Array[String] = cowl._get_item_effects()
		assert_eq(effects.size(), case.lines.size(), "%s: one effect per line" % case.name)
		for i: int in range(mini(effects.size(), case.lines.size())):
			assert_true(effects[i].contains(case.lines[i]), "%s: %s" % [case.name, case.lines[i]])

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
