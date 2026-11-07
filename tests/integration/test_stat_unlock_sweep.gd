extends GutTest

## UnlockManager re-checks its conditions whenever CharacterManager's stats
## change: a level-up, gear going on or off, a modifier source. A condition on a
## stat latches the moment the stat gets there, instead of waiting for the next
## Madra, gold, Core Density or event signal (UNLOCKS.md, WR-21's stat half).
## Each test registers conditions of its own in place of the game's list.

const Attribute := CharacterAttributesData.AttributeType
const StatSources := preload("res://tests/helpers/stat_sources.gd")

const TEST_SOURCE: StringName = &"test_stat_unlock_sweep"
const STRENGTH_LEVEL_ID: String = "test_sweep_strength_lv_2"
const STRENGTH_TOTAL_ID: String = "test_sweep_strength_total"

var _original_save: SaveGameData
var _original_save_path: String
var _original_list: UnlockConditionList

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_list = UnlockManager.unlock_condition_list
	PersistenceManager.use_save(SaveGameData.new_current(), "")

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	UnlockManager.unlock_condition_list = _original_list
	PersistenceManager.use_save(_original_save, _original_save_path)
	# Binding the original save again resumes its idle action, if it has one.
	ActionManager.cancel_current_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Makes `condition` the only registered condition.
func _register(condition: UnlockConditionData) -> void:
	var list := UnlockConditionList.new()
	var conditions: Array[UnlockConditionData] = [condition]
	list.list = conditions
	UnlockManager.unlock_condition_list = list

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_a_level_up_latches_a_stat_level_condition() -> void:
	var condition := UnlockConditionData.new()
	condition.condition_id = STRENGTH_LEVEL_ID
	condition.condition_type = UnlockConditionData.ConditionType.STAT_LEVEL
	condition.target_value = 2
	condition.optional_params = {"stat": "strength"}
	_register(condition)
	CharacterManager.add_stat_xp(Attribute.STRENGTH, 100.0)
	assert_eq(CharacterManager.get_stat_level(Attribute.STRENGTH), 2, "precondition: 100 XP buys Lv 2")
	assert_true(UnlockManager.is_condition_unlocked(STRENGTH_LEVEL_ID), "it latched at the level-up")

## A bonus moves an ATTRIBUTE_VALUE total, which the sweep now hears.
func test_a_bonus_latches_an_attribute_condition() -> void:
	var condition := UnlockConditionData.new()
	condition.condition_id = STRENGTH_TOTAL_ID
	condition.condition_type = UnlockConditionData.ConditionType.ATTRIBUTE_VALUE
	condition.target_value = CharacterManager.get_trained_value(Attribute.STRENGTH) + 1.0
	condition.optional_params = {"attribute_type": Attribute.STRENGTH}
	_register(condition)
	CharacterManager.set_modifier_source(TEST_SOURCE, StatSources.flat(StatModifierData.Stat.STRENGTH, 5.0))
	assert_true(UnlockManager.is_condition_unlocked(STRENGTH_TOTAL_ID), "it latched as the bonus went on")
