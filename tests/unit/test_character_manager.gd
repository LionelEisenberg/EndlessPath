extends GutTest

## Unit tests for CharacterManager and CharacterAttributesData: the default stat
## block, total attributes (trained values + the bonuses of equipped gear and
## both accessory slots, where each item adds floored percents of the trained
## values, armor and Ward) through the real CharacterManager, get_gear_bonus(),
## get_stat() and the modifier sources, the derived stats (regen, dodge, the
## cuts, armor and Ward), the training API (levels and XP up to the stage's cap:
## add_stat_xp(), add_stat_levels(), set_stat_level() and their signals), and
## stats_changed.
##
## Manager tests run on a fresh SaveGameData that every manager is re-bound
## to, so CharacterManager and InventoryManager share it, with a test stage
## whose stat cap is TEST_CAP and a test level curve. The original save, stages
## and curve are restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType
const EquipmentSlot = EquipmentDefinitionData.EquipmentSlot
const Stat = StatModifierData.Stat
const Kind = StatModifierData.Kind
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")

## The modifier source these tests set; after_each() removes it.
const TEST_SOURCE: StringName = &"test"
## The stat level cap of the test stage.
const TEST_CAP: int = 5
## A stat's value at Lv 1.
const BASELINE: float = CharacterAttributesData.STAT_BASELINE

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_stages: Array[AdvancementStageResource]
var _original_progression: StatProgressionData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_stages = CultivationManager.advancement_stage_resources
	_original_progression = CharacterManager.stat_progression

	var stage := AdvancementStageResource.new()
	stage.stat_level_cap = TEST_CAP
	var stages: Array[AdvancementStageResource] = [stage]
	CultivationManager.advancement_stage_resources = stages

	# Levels cost 10, 20, 40, 80 XP, and each adds 1 to the stat.
	var curve := StatProgressionData.new()
	curve.xp_to_level_two = 10.0
	curve.xp_growth = 2.0
	curve.value_per_level = 1.0
	CharacterManager.stat_progression = curve

	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	CultivationManager.advancement_stage_resources = _original_stages
	CharacterManager.stat_progression = _original_progression
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## An instance of GearFixture's item for the slot: stat key to percent, the
## floor, armor and Ward.
func _make_gear(slot: EquipmentSlot, percents: Dictionary, bonus_floor: int = 1, armor: float = 0.0, ward: float = 0.0) -> ItemInstanceData:
	var definition: EquipmentDefinitionData = GearFixture.item(percents, bonus_floor, armor, ward)
	definition.item_id = "test_gear_%d" % slot
	definition.slot_type = slot
	var instance := ItemInstanceData.new()
	instance.item_definition = definition
	return instance

func _inventory() -> InventoryData:
	return InventoryManager.get_inventory()

func _total(attr_type: AttributeType) -> float:
	return CharacterManager.get_total_attributes_data().get_attribute(attr_type)

## A modifier source that always returns the given modifiers.
func _source(modifiers: Array[StatModifierData]) -> Callable:
	return func() -> Array[StatModifierData]: return modifiers

func _robes() -> ItemInstanceData:
	return _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4})

#-----------------------------------------------------------------------------
# ATTRIBUTES DATA INITIALIZATION
#-----------------------------------------------------------------------------

func test_default_init_all_ten() -> void:
	var attrs := CharacterAttributesData.new()
	for attr_type: AttributeType in AttributeType.values():
		assert_eq(attrs.get_attribute(attr_type), 10.0, "default attribute should be 10.0")

#-----------------------------------------------------------------------------
# TRAINED LEVELS
#-----------------------------------------------------------------------------

func test_a_new_save_starts_every_stat_at_level_one() -> void:
	for stat: AttributeType in AttributeType.values():
		var stat_name: String = AttributeType.keys()[stat]
		assert_eq(CharacterManager.get_stat_level(stat), 1, "%s starts at Lv 1" % stat_name)
		assert_eq(CharacterManager.get_stat_xp(stat), 0.0, "%s starts with no XP" % stat_name)
		assert_eq(CharacterManager.get_trained_value(stat), CharacterAttributesData.STAT_BASELINE,
			"%s starts at the baseline value" % stat_name)
		assert_false(CharacterManager.is_stat_capped(stat), "%s starts below the cap" % stat_name)

func test_levels_come_from_the_bound_save() -> void:
	var save := SaveGameData.new_current()
	save.stat_training.set_level(AttributeType.SPIRIT, 6)
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	assert_eq(CharacterManager.get_stat_level(AttributeType.SPIRIT), 6, "the bound save's level")
	assert_eq(CharacterManager.get_stat(Stat.SPIRIT), 15.0, "Lv 6 on the test curve")

func test_trained_values_list_every_stat() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, 3)
	CharacterManager.set_stat_level(AttributeType.MIND, 2)
	var expected: Dictionary = {
		AttributeType.STRENGTH: 12.0,
		AttributeType.BODY: 10.0,
		AttributeType.AGILITY: 10.0,
		AttributeType.SPIRIT: 10.0,
		AttributeType.MIND: 11.0,
		AttributeType.CONTROL: 10.0,
	}
	assert_eq(CharacterManager.get_trained_values(), expected, "Strength Lv 3, Mind Lv 2, the rest Lv 1")

## The cap counts trained levels only: gear can lift the total past it.
func test_capped_reads_the_trained_level_not_the_total() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, TEST_CAP - 1)
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.STRENGTH, Kind.FLAT, 10.0)]))
	assert_false(CharacterManager.is_stat_capped(AttributeType.STRENGTH), "gear does not cap it")
	CharacterManager.set_stat_level(AttributeType.STRENGTH, TEST_CAP)
	assert_true(CharacterManager.is_stat_capped(AttributeType.STRENGTH), "the trained level at the cap does")
	assert_eq(CharacterManager.get_stat_level_cap(), TEST_CAP, "the cap is the test stage's")

#-----------------------------------------------------------------------------
# STAT XP
#-----------------------------------------------------------------------------

## XP pays for each level it covers, and what is left goes toward the next one.
func test_stat_xp_buys_levels_and_keeps_the_remainder() -> void:
	var cases: Array[Dictionary] = [
		{"name": "5 of 10, short of Lv 2", "xp": 5.0, "level": 1, "left": 5.0},
		{"name": "the exact cost of Lv 2", "xp": 10.0, "level": 2, "left": 0.0},
		{"name": "Lv 2 and 3 over", "xp": 13.0, "level": 2, "left": 3.0},
		{"name": "Lv 3 and 5 over", "xp": 35.0, "level": 3, "left": 5.0},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.SPIRIT, 1)
		CharacterManager.add_stat_xp(AttributeType.SPIRIT, case.xp)
		assert_eq(CharacterManager.get_stat_level(AttributeType.SPIRIT), case.level, "%s: the level" % case.name)
		assert_eq(CharacterManager.get_stat_xp(AttributeType.SPIRIT), case.left, "%s: the XP left" % case.name)

func test_the_level_that_reaches_the_cap_drops_the_leftover() -> void:
	CharacterManager.add_stat_xp(AttributeType.SPIRIT, 1000.0)
	assert_eq(CharacterManager.get_stat_level(AttributeType.SPIRIT), TEST_CAP, "the XP buys levels up to the cap")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.SPIRIT), 0.0, "and what is left over is lost")

func test_xp_at_the_cap_is_lost() -> void:
	CharacterManager.set_stat_level(AttributeType.SPIRIT, TEST_CAP, 3.0)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.SPIRIT), 3.0, "precondition: Spirit holds 3 XP at the cap")
	watch_signals(CharacterManager)
	CharacterManager.add_stat_xp(AttributeType.SPIRIT, 50.0)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.SPIRIT), 0.0, "the 3 held and the 50 earned are both lost")
	assert_signal_not_emitted(CharacterManager, "stat_level_changed", "no level past the cap")
	assert_signal_emitted_with_parameters(CharacterManager, "stat_xp_changed",
		[AttributeType.SPIRIT, 0.0, CharacterManager.get_stat_xp_to_next(AttributeType.SPIRIT)])

func test_each_level_gained_signals_and_logs_once() -> void:
	watch_signals(CharacterManager)
	watch_signals(LogManager)
	CharacterManager.add_stat_xp(AttributeType.SPIRIT, 35.0)
	assert_signal_emit_count(CharacterManager, "stat_level_changed", 2, "one signal a level")
	assert_signal_emitted_with_parameters(CharacterManager, "stat_level_changed", [AttributeType.SPIRIT, 2], 0)
	assert_signal_emitted_with_parameters(CharacterManager, "stat_level_changed", [AttributeType.SPIRIT, 3], 1)
	assert_signal_emit_count(CharacterManager, "stats_changed", 1, "the stats change once for the call")
	assert_signal_emit_count(LogManager, "message_logged", 2, "one log line a level")
	for index: int in mini(get_signal_emit_count(LogManager, "message_logged"), 2):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		assert_string_contains(line, "reached Lv")

func test_xp_alone_leaves_the_stats_alone() -> void:
	watch_signals(CharacterManager)
	CharacterManager.add_stat_xp(AttributeType.SPIRIT, 5.0)
	assert_signal_not_emitted(CharacterManager, "stats_changed", "no level was gained, so no stat changed")
	assert_signal_emitted_with_parameters(CharacterManager, "stat_xp_changed", [AttributeType.SPIRIT, 5.0, 10.0])

func test_a_free_level_does_not_level() -> void:
	CharacterManager.stat_progression.xp_to_level_two = 0.0
	CharacterManager.add_stat_xp(AttributeType.SPIRIT, 5.0)
	assert_eq(CharacterManager.get_stat_level(AttributeType.SPIRIT), 1, "a level that costs no XP is never bought")

#-----------------------------------------------------------------------------
# STAT LEVELS
#-----------------------------------------------------------------------------

## Levels come one at a time up to the cap; the ones past it are lost, and a
## stat at or past the cap stays where it is.
func test_add_stat_levels_stops_at_the_cap() -> void:
	var cases: Array[Dictionary] = [
		{"name": "two from Lv 1", "from": 1, "plus": 2, "level": 3},
		{"name": "three from Lv 4 stop at the cap", "from": 4, "plus": 3, "level": TEST_CAP},
		{"name": "none at the cap", "from": TEST_CAP, "plus": 1, "level": TEST_CAP},
		{"name": "none past the cap", "from": TEST_CAP + 2, "plus": 1, "level": TEST_CAP + 2},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.BODY, case.from)
		CharacterManager.add_stat_levels(AttributeType.BODY, case.plus)
		assert_eq(CharacterManager.get_stat_level(AttributeType.BODY), case.level, case.name)

func test_add_stat_levels_keeps_the_xp_until_the_cap() -> void:
	CharacterManager.set_stat_level(AttributeType.BODY, 2, 7.0)
	CharacterManager.add_stat_levels(AttributeType.BODY, 1)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 7.0, "a level below the cap keeps the XP")
	CharacterManager.add_stat_levels(AttributeType.BODY, 5)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 0.0, "reaching the cap drops it")

func test_add_stat_levels_signals_each_level() -> void:
	watch_signals(CharacterManager)
	CharacterManager.add_stat_levels(AttributeType.BODY, 2)
	assert_signal_emit_count(CharacterManager, "stat_level_changed", 2, "one signal a level")
	assert_signal_emit_count(CharacterManager, "stat_xp_changed", 1, "the XP once for the call")
	assert_signal_emit_count(CharacterManager, "stats_changed", 1, "the stats once for the call")

#-----------------------------------------------------------------------------
# SET STAT LEVEL (dev)
#-----------------------------------------------------------------------------

## The dev setter: any level from 1, past the cap too, with its XP held inside
## the level, at most one point short of the next level's cost.
func test_set_stat_level_sets_level_and_xp() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a level and XP", "level": 3, "xp": 15.0, "stored_level": 3, "stored_xp": 15.0},
		{"name": "past the cap", "level": TEST_CAP + 2, "xp": 0.0, "stored_level": TEST_CAP + 2, "stored_xp": 0.0},
		{"name": "below Lv 1", "level": 0, "xp": 0.0, "stored_level": 1, "stored_xp": 0.0},
		{"name": "negative XP", "level": 2, "xp": -4.0, "stored_level": 2, "stored_xp": 0.0},
		{"name": "XP at the cost of Lv 3 (20)", "level": 2, "xp": 20.0, "stored_level": 2, "stored_xp": 19.0},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.AGILITY, case.level, case.xp)
		assert_eq(CharacterManager.get_stat_level(AttributeType.AGILITY), case.stored_level, "%s: the level" % case.name)
		assert_eq(CharacterManager.get_stat_xp(AttributeType.AGILITY), case.stored_xp, "%s: the XP" % case.name)

func test_set_stat_level_signals_once_and_logs_nothing() -> void:
	watch_signals(CharacterManager)
	watch_signals(LogManager)
	CharacterManager.set_stat_level(AttributeType.AGILITY, 4, 5.0)
	assert_signal_emit_count(CharacterManager, "stat_level_changed", 1, "the level once")
	assert_signal_emitted_with_parameters(CharacterManager, "stat_level_changed", [AttributeType.AGILITY, 4])
	assert_signal_emit_count(CharacterManager, "stat_xp_changed", 1, "the XP once")
	assert_signal_emitted_with_parameters(CharacterManager, "stat_xp_changed", [AttributeType.AGILITY, 5.0, 80.0])
	assert_signal_emit_count(CharacterManager, "stats_changed", 1, "the stats once")
	assert_signal_not_emitted(LogManager, "message_logged", "a dev set is no level reached")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: NO EQUIPMENT
#-----------------------------------------------------------------------------

func test_totals_equal_base_with_nothing_equipped() -> void:
	var levels: Dictionary = {
		AttributeType.STRENGTH: 3,
		AttributeType.BODY: 6,
		AttributeType.AGILITY: 11,
		AttributeType.SPIRIT: 1,
		AttributeType.MIND: 4,
		AttributeType.CONTROL: 2,
	}
	for attr_type: AttributeType in levels:
		CharacterManager.set_stat_level(attr_type, levels[attr_type])
	var totals: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: AttributeType in levels:
		assert_eq(totals.get_attribute(attr_type), CharacterAttributesData.STAT_BASELINE + levels[attr_type] - 1,
			"%s total with no gear" % AttributeType.keys()[attr_type])

#-----------------------------------------------------------------------------
# GEAR: FLOORED PERCENTS OF THE TRAINED VALUE, ARMOR AND WARD
#-----------------------------------------------------------------------------

func test_worn_gear_adds_its_floored_bonus_to_the_trained_value() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.1}, 3)
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.STRENGTH), 3.0, "the floor beats 10% of 10")
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), BASELINE + 3.0)
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.AGILITY), 0.0, "no Agility percent")
	assert_eq(CharacterManager.get_stat(Stat.AGILITY), BASELINE)

## Each percent counts the trained value, never a total that holds another
## item's bonus (a gear source reading get_stat() would also recurse).
func test_gear_percents_count_the_trained_value_not_the_total() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.5})
	_inventory().equipped_accessories[0] = _make_gear(EquipmentSlot.ACCESSORY, {&"strength": 0.5})
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), BASELINE * 2.0, "10 + 5 + 5, not 10 + 5 + 7")

func test_gear_lifts_a_capped_stat_past_the_cap() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, TEST_CAP)
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.5})
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.STRENGTH), 7.0, "50% of 14, the value at the test cap")
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), 21.0, "the total passes the capped value")
	assert_eq(CharacterManager.get_stat_level(AttributeType.STRENGTH), TEST_CAP, "training stays at the cap")
	assert_true(CharacterManager.is_stat_capped(AttributeType.STRENGTH))

func test_unequipping_gear_removes_its_bonus_and_armor() -> void:
	var robes: ItemInstanceData = _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}, 1, 6.0)
	_inventory().equipment[0] = robes
	InventoryManager.equip_item(robes, EquipmentSlot.ARMOR, 0)
	assert_eq(CharacterManager.get_stat(Stat.BODY), BASELINE + 4.0, "precondition: worn")
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 6.0, "precondition: worn")
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_eq(CharacterManager.get_stat(Stat.BODY), BASELINE)
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 0.0)

func test_armor_and_ward_come_from_gear_into_the_fight_block() -> void:
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 0.0, "no armor without gear")
	assert_eq(CharacterManager.get_stat(Stat.WARD), 0.0, "no Ward without gear")
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {}, 1, 6.0)
	_inventory().equipped_gear[EquipmentSlot.HEAD] = _make_gear(EquipmentSlot.HEAD, {}, 1, 0.0, 4.0)
	var block: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	assert_eq(block.armor, 6.0, "armor reaches the fight snapshot")
	assert_eq(block.ward, 4.0, "Ward reaches the fight snapshot")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: EQUIPPED GEAR
#-----------------------------------------------------------------------------

func test_bonuses_stack_across_gear_slots() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		&"strength": 0.5,
	})
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {
		&"strength": 0.3,
		&"body": 1.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 18.0, "10 base + 5 weapon + 3 armor")
	assert_eq(_total(AttributeType.BODY), 20.0)

func test_each_attribute_receives_its_own_bonus() -> void:
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {
		&"strength": 0.1,
		&"body": 0.2,
		&"agility": 0.3,
		&"spirit": 0.4,
		&"mind": 0.5,
		&"control": 0.6,
	})
	var expected: Dictionary = {
		AttributeType.STRENGTH: 11.0,
		AttributeType.BODY: 12.0,
		AttributeType.AGILITY: 13.0,
		AttributeType.SPIRIT: 14.0,
		AttributeType.MIND: 15.0,
		AttributeType.CONTROL: 16.0,
	}
	var totals: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: AttributeType in expected:
		assert_eq(totals.get_attribute(attr_type), expected[attr_type],
			"%s total should be base + its own bonus" % AttributeType.keys()[attr_type])

func test_items_without_equipment_definition_are_ignored() -> void:
	var no_definition := ItemInstanceData.new()
	var material := ItemInstanceData.new()
	material.item_definition = MaterialDefinitionData.new()
	_inventory().equipped_gear[EquipmentSlot.HEAD] = no_definition
	_inventory().equipped_gear[EquipmentSlot.OFF_HAND] = material
	_inventory().equipped_accessories[0] = no_definition
	_inventory().equipped_accessories[1] = material
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		&"strength": 0.2,
	})
	assert_eq(_total(AttributeType.STRENGTH), 12.0, "only the real equipment counts")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: ACCESSORIES
#-----------------------------------------------------------------------------

func test_gear_and_both_accessories_stack() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		&"strength": 0.5,
	})
	_inventory().equipped_accessories[0] = _make_gear(EquipmentSlot.ACCESSORY, {
		&"strength": 0.2,
	})
	_inventory().equipped_accessories[1] = _make_gear(EquipmentSlot.ACCESSORY, {
		&"strength": 0.1,
		&"control": 0.3,
	})
	assert_eq(_total(AttributeType.STRENGTH), 18.0, "10 base + 5 weapon + 2 + 1 accessories")
	assert_eq(_total(AttributeType.CONTROL), 13.0)

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: EQUIPPING THROUGH INVENTORY MANAGER
#-----------------------------------------------------------------------------

func test_equip_and_unequip_accessory_updates_totals() -> void:
	var ring := _make_gear(EquipmentSlot.ACCESSORY, {&"mind": 0.3})
	_inventory().equipment[0] = ring

	InventoryManager.equip_item(ring, EquipmentSlot.ACCESSORY, 0, 1)
	assert_eq(_total(AttributeType.MIND), 13.0, "an accessory in the second slot adds its bonus")

	InventoryManager.unequip_item(EquipmentSlot.ACCESSORY, 1)
	assert_eq(_total(AttributeType.MIND), 10.0)

#-----------------------------------------------------------------------------
# STATS CHANGED SIGNAL
#-----------------------------------------------------------------------------

func test_equipping_gear_emits_stats_changed() -> void:
	var armor := _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4})
	_inventory().equipment[0] = armor
	watch_signals(CharacterManager)
	InventoryManager.equip_item(armor, EquipmentSlot.ARMOR, 0)
	assert_signal_emitted(CharacterManager, "stats_changed")

func test_unequipping_gear_emits_stats_changed() -> void:
	var armor := _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4})
	_inventory().equipment[0] = armor
	InventoryManager.equip_item(armor, EquipmentSlot.ARMOR, 0)
	watch_signals(CharacterManager)
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_signal_emitted(CharacterManager, "stats_changed")

func test_save_reset_emits_stats_changed_once() -> void:
	watch_signals(CharacterManager)
	PersistenceManager.save_data_reset.emit()
	assert_signal_emit_count(CharacterManager, "stats_changed", 1)

func test_a_listener_during_save_reset_sees_the_new_saves_gear() -> void:
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _robes()
	var bodies: Array[float] = []
	var record := func() -> void: bodies.append(CharacterManager.get_stat(Stat.BODY))
	CharacterManager.stats_changed.connect(record)
	var next_save := SaveGameData.new()
	next_save.inventory.equipped_gear[EquipmentSlot.HEAD] = _make_gear(EquipmentSlot.HEAD, {&"body": 0.2})
	PersistenceManager.save_game_data = next_save
	PersistenceManager.save_data_reset.emit()
	CharacterManager.stats_changed.disconnect(record)
	assert_eq(bodies, [12.0] as Array[float], "the new save's Body and gear, with none of the old save's gear")

#-----------------------------------------------------------------------------
# STATS AND MODIFIER SOURCES
#-----------------------------------------------------------------------------

func test_get_stat_reads_base_plus_gear() -> void:
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _robes()
	assert_eq(CharacterManager.get_stat(Stat.BODY), 14.0)
	assert_eq(CharacterManager.get_stat(Stat.MAX_HEALTH), 140.0, "the formula runs on the total Body")

func test_a_source_raises_the_total_attributes() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.BODY, Kind.FLAT, 3.0)]))
	assert_eq(_total(AttributeType.BODY), 13.0)

func test_a_source_can_raise_a_derived_vital_directly() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.MAX_HEALTH, Kind.FLAT, 20.0)]))
	assert_eq(CharacterManager.get_stat(Stat.MAX_HEALTH), 120.0)
	assert_eq(CharacterManager.get_stat(Stat.BODY), 10.0, "Body itself does not move")

func test_attribute_and_derived_bonuses_combine_in_order() -> void:
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _robes()
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([
		StatModifierData.new(Stat.MAX_HEALTH, Kind.FLAT, 20.0),
		StatModifierData.new(Stat.MAX_HEALTH, Kind.PERCENT, 0.1),
	]))
	assert_almost_eq(CharacterManager.get_stat(Stat.MAX_HEALTH), 176.0, 0.0001, "(14 Body x 10 + 20) x 1.1")

func test_setting_a_source_emits_stats_changed() -> void:
	watch_signals(CharacterManager)
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([]))
	assert_signal_emit_count(CharacterManager, "stats_changed", 1)

func test_removing_a_source_emits_stats_changed() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([]))
	watch_signals(CharacterManager)
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	assert_signal_emit_count(CharacterManager, "stats_changed", 1)

func test_removing_a_source_restores_the_value() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.SPIRIT, Kind.PERCENT, 0.5)]))
	assert_eq(CharacterManager.get_stat(Stat.SPIRIT), 15.0, "precondition: the source counts")
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	assert_eq(CharacterManager.get_stat(Stat.SPIRIT), 10.0)

#-----------------------------------------------------------------------------
# DERIVED STATS
#-----------------------------------------------------------------------------

## At Lv 1: today's regen, no dodge, no cuts, no armor or Ward.
func test_derived_stats_at_level_one() -> void:
	var cases: Array[Dictionary] = [
		{"stat": Stat.STAMINA_REGEN, "value": 1.0},
		{"stat": Stat.DODGE_CHANCE, "value": 0.0},
		{"stat": Stat.MADRA_COST_CUT, "value": 0.0},
		{"stat": Stat.COOLDOWN_CUT, "value": 0.0},
		{"stat": Stat.ARMOR, "value": 0.0},
		{"stat": Stat.WARD, "value": 0.0},
	]
	for case: Dictionary in cases:
		assert_eq(CharacterManager.get_stat(case.stat), case.value, "%s at Lv 1" % Stat.keys()[case.stat])

## Each derived stat is its CharacterAttributesData formula over the trained totals.
func test_derived_stats_follow_the_trained_totals() -> void:
	CharacterManager.set_stat_level(AttributeType.AGILITY, 6)
	CharacterManager.set_stat_level(AttributeType.CONTROL, 11)
	var trained := CharacterAttributesData.make({&"agility": 15.0, &"control": 20.0})
	var untrained := CharacterAttributesData.make()
	var cases: Array[Dictionary] = [
		{"stat": Stat.MAX_STAMINA, "formula": &"get_max_stamina"},
		{"stat": Stat.STAMINA_REGEN, "formula": &"get_stamina_regen"},
		{"stat": Stat.DODGE_CHANCE, "formula": &"get_dodge_chance"},
		{"stat": Stat.MADRA_COST_CUT, "formula": &"get_madra_cost_cut"},
		{"stat": Stat.COOLDOWN_CUT, "formula": &"get_cooldown_cut"},
	]
	for case: Dictionary in cases:
		var stat_name: String = Stat.keys()[case.stat]
		var value: float = CharacterManager.get_stat(case.stat)
		var expected: float = trained.call(case.formula)
		assert_almost_eq(value, expected, 0.000001, "%s is its formula over Agility 15 and Control 20" % stat_name)
		assert_gt(value, untrained.call(case.formula), "%s moved with its stat" % stat_name)

## The formulas read the total stats, so a stat modifier moves them too.
func test_derived_stats_count_stat_modifiers() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.AGILITY, Kind.FLAT, 5.0)]))
	assert_almost_eq(CharacterManager.get_stat(Stat.DODGE_CHANCE),
		CharacterAttributesData.make({&"agility": 15.0}).get_dodge_chance(), 0.000001,
		"dodge reads the trained Agility 10 plus the modifier's 5")

func test_armor_and_ward_come_from_modifiers_into_the_snapshot() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([
		StatModifierData.new(Stat.ARMOR, Kind.FLAT, 6.0),
		StatModifierData.new(Stat.WARD, Kind.FLAT, 4.0),
	]))
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 6.0, "armor is its modifier on a base of 0")
	assert_eq(CharacterManager.get_stat(Stat.WARD), 4.0, "Ward is its modifier on a base of 0")
	var snapshot: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	assert_eq(snapshot.armor, 6.0, "the snapshot a fight starts with holds the armor")
	assert_eq(snapshot.ward, 4.0, "the snapshot a fight starts with holds the Ward")

func test_a_derived_stat_takes_its_own_modifiers() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _source([StatModifierData.new(Stat.STAMINA_REGEN, Kind.FLAT, 0.5)]))
	assert_eq(CharacterManager.get_stat(Stat.STAMINA_REGEN), 1.5, "Agility 10's 1.0 a second plus the modifier's 0.5")
