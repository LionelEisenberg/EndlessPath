extends GutTest

## QuestStepData's progress figure, the Goals board's rule moved onto the step:
## the step's first completion condition as "current / target" in whole numbers,
## for a step that completes on measurable conditions alone, and nothing for any
## other step. A finished step reads its target twice ("100 / 100").

var _saved_save: SaveGameData = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## A fresh save holds 25 Madra.
func before_each() -> void:
	_saved_save = PersistenceManager.save_game_data
	_use_save(SaveGameData.new())

func after_each() -> void:
	_use_save(_saved_save)

## Swaps in `save` and tells the managers to re-bind, as a fresh save does.
func _use_save(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## A condition of the test's own on the player's Madra, measured against `target`.
func _madra_condition(target: float) -> UnlockConditionData:
	var condition: UnlockConditionData = UnlockConditionData.new()
	condition.condition_id = "test_step_madra"
	condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	condition.target_value = target
	condition.optional_params = {"resource_type": "madra"}
	return condition

## A condition of the test's own on owning an item, which has no figure.
func _item_condition() -> UnlockConditionData:
	var condition: UnlockConditionData = UnlockConditionData.new()
	condition.condition_id = "test_step_item"
	condition.condition_type = UnlockConditionData.ConditionType.ITEM_OWNED
	condition.target_value = "test_step_item"
	return condition

## A step that completes on `conditions`.
func _step(conditions: Array[UnlockConditionData]) -> QuestStepData:
	var step: QuestStepData = QuestStepData.new()
	step.completion_conditions = conditions
	return step

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## Steps without a figure: one that completes on an event; one with an event
## id as well as measurable conditions, since the event id wins (QuestManager
## advances such a step on its event); one with a condition that can't be
## measured among its conditions; and one with no criteria at all. None
## measures a condition, and none reads a figure, finished or not.
func test_steps_without_a_figure() -> void:
	var event_step: QuestStepData = QuestStepData.new()
	event_step.completion_event_id = "some_event"
	var event_and_conditions_step: QuestStepData = _step([_madra_condition(100.0)] as Array[UnlockConditionData])
	event_and_conditions_step.completion_event_id = "some_event"
	var cases: Array[Dictionary] = [
		{"name": "an event step", "step": event_step},
		{"name": "an event id over conditions", "step": event_and_conditions_step},
		{"name": "one unmeasurable condition",
			"step": _step([_madra_condition(100.0), _item_condition()] as Array[UnlockConditionData])},
		{"name": "no criteria", "step": QuestStepData.new()},
	]
	for case: Dictionary in cases:
		var step: QuestStepData = case.step
		assert_null(step.get_measured_condition(), "%s measures nothing" % case.name)
		assert_eq(step.get_progress_text(), "", "%s reads no figure" % case.name)
		assert_eq(step.get_progress_text(true), "", "%s: finishing it invents no figure" % case.name)

func test_madra_step_reads_like_the_goals_board() -> void:
	var step: QuestStepData = _step([_madra_condition(100.0)] as Array[UnlockConditionData])
	assert_eq(step.get_measured_condition(), step.completion_conditions[0])
	assert_eq(step.get_progress_text(), "25 / 100")
	assert_eq(step.get_progress_text(true), "100 / 100")

func test_figures_are_whole_numbers_rounded_down() -> void:
	ResourceManager.set_madra(99.9)
	var step: QuestStepData = _step([_madra_condition(100.0)] as Array[UnlockConditionData])
	assert_eq(step.get_progress_text(), "99 / 100")

func test_the_first_of_several_measurable_conditions_is_the_figure() -> void:
	var step: QuestStepData = _step([_madra_condition(80.0), _madra_condition(100.0)] as Array[UnlockConditionData])
	assert_eq(step.get_measured_condition(), step.completion_conditions[0])
	assert_eq(step.get_progress_text(), "25 / 80")
