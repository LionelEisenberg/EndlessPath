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

## Each measurable condition reads its target and the player's live figure: a
## RESOURCE_AMOUNT condition the resource it names (Madra, which it follows as
## it changes, or gold), a CULTIVATION_LEVEL condition the Core Density level.
func test_measurable_conditions_read_current_and_target() -> void:
	ResourceManager.set_madra(60.0)
	ResourceManager.set_gold(12.0)
	PersistenceManager.save_game_data.core_density_level = 4.0
	var gold_condition := UnlockConditionData.new()
	gold_condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	gold_condition.target_value = 50
	gold_condition.optional_params = {"resource_type": "gold"}
	var cases: Array[Dictionary] = [
		{"name": "Madra", "condition": load(MADRA_FULL_PATH), "current": 60.0, "target": 100.0},
		{"name": "gold", "condition": gold_condition, "current": 12.0, "target": 50.0},
		{"name": "Core Density level", "condition": load(REACH_CD_10_PATH), "current": 4.0, "target": 10.0},
	]
	for case: Dictionary in cases:
		var condition: UnlockConditionData = case.condition
		assert_true(condition.is_measurable(), "%s is measurable" % case.name)
		assert_eq(condition.get_current_value(), case.current, "%s: current" % case.name)
		assert_eq(condition.get_target_value(), case.target, "%s: target" % case.name)

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
