extends GutTest

## Unit tests for UnlockConditionData's progress getters, which the Goals panel
## reads to show "current / target" under a quest step. Only RESOURCE_AMOUNT
## and CULTIVATION_LEVEL conditions can be measured; an event-completed step
## (such as defeating an enemy) shows no figure.

const MADRA_FULL_PATH: String = "res://resources/unlocks/q_fill_core_madra_full.tres"
const REACH_CD_10_PATH: String = "res://resources/unlocks/q_reach_cd_10.tres"
const ENEMY_DEFEATED_PATH: String = "res://resources/unlocks/q_first_steps_enemy_defeated.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# MEASURABLE CONDITIONS
#-----------------------------------------------------------------------------

func test_resource_amount_is_measurable() -> void:
	var condition: UnlockConditionData = load(MADRA_FULL_PATH)
	assert_true(condition.is_measurable())
	assert_eq(condition.get_current_value(), 25.0, "a fresh save holds 25 Madra")
	assert_eq(condition.get_target_value(), 100.0)

func test_resource_amount_follows_madra() -> void:
	var condition: UnlockConditionData = load(MADRA_FULL_PATH)
	ResourceManager.set_madra(60.0)
	assert_eq(condition.get_current_value(), 60.0)

func test_gold_resource_amount_reads_gold() -> void:
	var condition := UnlockConditionData.new()
	condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	condition.target_value = 50
	condition.optional_params = {"resource_type": "gold"}
	ResourceManager.set_gold(12.0)
	assert_true(condition.is_measurable())
	assert_eq(condition.get_current_value(), 12.0)
	assert_eq(condition.get_target_value(), 50.0)

func test_cultivation_level_is_measurable() -> void:
	var condition: UnlockConditionData = load(REACH_CD_10_PATH)
	PersistenceManager.save_game_data.core_density_level = 4.0
	assert_true(condition.is_measurable())
	assert_eq(condition.get_current_value(), 4.0)
	assert_eq(condition.get_target_value(), 10.0)

#-----------------------------------------------------------------------------
# OTHER CONDITIONS
#-----------------------------------------------------------------------------

func test_event_condition_is_not_measurable() -> void:
	var condition: UnlockConditionData = load(ENEMY_DEFEATED_PATH)
	assert_false(condition.is_measurable())
	assert_eq(condition.get_current_value(), 0.0)
	assert_eq(condition.get_target_value(), 0.0)

func test_evaluate_still_matches_the_current_value() -> void:
	var condition: UnlockConditionData = load(MADRA_FULL_PATH)
	ResourceManager.set_madra(99.0)
	assert_false(condition.evaluate())
	ResourceManager.set_madra(100.0)
	assert_true(condition.evaluate())
