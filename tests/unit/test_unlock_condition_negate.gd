extends GutTest

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_event_condition(event_id: String, negate: bool) -> UnlockConditionData:
	var c := UnlockConditionData.new()
	c.condition_id = "test_" + event_id
	c.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	c.target_value = event_id
	c.negate = negate
	return c

func test_negate_false_returns_raw_result() -> void:
	var c: UnlockConditionData = _make_event_condition("e1", false)
	assert_false(c.evaluate(), "Event not triggered yet -> false")

	EventManager.trigger_event("e1")
	assert_true(c.evaluate(), "Event triggered -> true")

func test_negate_true_inverts_result() -> void:
	var c: UnlockConditionData = _make_event_condition("e2", true)
	assert_true(c.evaluate(), "Event not triggered yet, negated -> true")

	EventManager.trigger_event("e2")
	assert_false(c.evaluate(), "Event triggered, negated -> false")

func test_negate_defaults_to_false() -> void:
	var c := UnlockConditionData.new()
	assert_false(c.negate, "negate must default to false for backwards compatibility")
