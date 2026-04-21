extends GutTest

## Tests EncounterChoice.evaluate_requirements() with the new
## Dictionary[UnlockConditionData, bool] schema.

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_event_condition(event_id: String) -> UnlockConditionData:
	var c := UnlockConditionData.new()
	c.condition_id = "test_" + event_id
	c.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	c.target_value = event_id
	return c

func _make_choice_with(reqs: Dictionary[UnlockConditionData, bool]) -> EncounterChoice:
	var choice := EncounterChoice.new()
	choice.label = "test"
	choice.requirements = reqs
	return choice

func test_empty_requirements_always_met() -> void:
	var choice: EncounterChoice = _make_choice_with({})
	assert_true(choice.evaluate_requirements())

func test_expected_true_matches_triggered_event() -> void:
	var c: UnlockConditionData = _make_event_condition("e1")
	var choice: EncounterChoice = _make_choice_with({c: true})
	assert_false(choice.evaluate_requirements(), "event not fired, expected true")
	EventManager.trigger_event("e1")
	assert_true(choice.evaluate_requirements(), "event fired, expected true")

func test_expected_false_matches_non_triggered_event() -> void:
	var c: UnlockConditionData = _make_event_condition("e2")
	var choice: EncounterChoice = _make_choice_with({c: false})
	assert_true(choice.evaluate_requirements(), "event not fired, expected false -> met")
	EventManager.trigger_event("e2")
	assert_false(choice.evaluate_requirements(), "event fired, expected false -> unmet")

func test_mixed_requirements_all_must_match() -> void:
	var a: UnlockConditionData = _make_event_condition("a")
	var b: UnlockConditionData = _make_event_condition("b")
	var choice: EncounterChoice = _make_choice_with({a: true, b: false})
	assert_false(choice.evaluate_requirements(), "a not fired -> unmet")

	EventManager.trigger_event("a")
	assert_true(choice.evaluate_requirements(), "a fired + b not fired -> met")

	EventManager.trigger_event("b")
	assert_false(choice.evaluate_requirements(), "b fired -> violates expected=false")
