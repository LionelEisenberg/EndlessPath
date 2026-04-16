extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _quest_a: QuestData
var _quest_b: QuestData
var _step_talk_eel: QuestStepData
var _step_visit_forest: QuestStepData

func _create_step(step_id: String, description: String, event_id: String = "") -> QuestStepData:
	var s := QuestStepData.new()
	s.step_id = step_id
	s.description = description
	s.completion_event_id = event_id
	return s

func _create_quest(quest_id: String, quest_name: String, steps: Array[QuestStepData]) -> QuestData:
	var q := QuestData.new()
	q.quest_id = quest_id
	q.quest_name = quest_name
	q.steps = steps
	return q

func before_each() -> void:
	_save_data = SaveGameData.new()
	_step_talk_eel = _create_step("talk_eel", "Talk to the Wisened Dirt Eel", "eel_dialogue_done")
	_step_visit_forest = _create_step("visit_forest", "Visit the Spring Forest", "spring_forest_visited")
	_quest_a = _create_quest("quest_a", "Quest A", [_step_talk_eel, _step_visit_forest] as Array[QuestStepData])
	_quest_b = _create_quest("quest_b", "Quest B", [_step_talk_eel] as Array[QuestStepData])
	QuestManager._live_save_data = _save_data
	QuestManager._quests_by_id = {
		"quest_a": _quest_a,
		"quest_b": _quest_b,
	}

func after_each() -> void:
	QuestManager._live_save_data = null
	QuestManager._quests_by_id = {}

# ----- start_quest: basic -----

func test_start_quest_adds_to_active_list() -> void:
	QuestManager.start_quest("quest_a")
	assert_true(QuestManager.has_active_quest("quest_a"), "quest_a should be active")

func test_start_quest_sets_step_index_zero() -> void:
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"newly started quest should be at step 0")

func test_start_quest_emits_signal() -> void:
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_emitted_with_parameters(QuestManager, "quest_started", ["quest_a"])

func test_start_quest_unknown_id_pushes_error() -> void:
	QuestManager.start_quest("nonexistent")
	assert_push_error("unknown quest_id")

func test_start_quest_already_active_is_noop() -> void:
	QuestManager.start_quest("quest_a")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_not_emitted(QuestManager, "quest_started")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"step index should remain 0 on re-start")

func test_start_quest_already_completed_is_noop() -> void:
	_save_data.quest_progression.completed_quest_ids.append("quest_a")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_signal_not_emitted(QuestManager, "quest_started")
	assert_false(QuestManager.has_active_quest("quest_a"),
		"already-completed quest should not become active")

# ----- step advancement: event-based -----

func test_step_advances_on_matching_event() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"quest_a should advance to step 1 after eel_dialogue_done")

func test_step_does_not_advance_on_unmatched_event() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager._on_event_triggered("unrelated_event")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 0,
		"quest_a should still be at step 0")

func test_step_advance_emits_signal() -> void:
	QuestManager.start_quest("quest_a")
	watch_signals(QuestManager)
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_signal_emitted_with_parameters(QuestManager, "quest_step_advanced", ["quest_a", 1])

func test_multiple_active_quests_share_event_advance() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager.start_quest("quest_b")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"quest_a advances to step 1")
	# quest_b only has one step matching eel_dialogue_done — it completes;
	# "completes" behavior is tested in Task 8 — for now just assert it's no
	# longer at step 0 OR has been removed from active.
	assert_true(
		not QuestManager.has_active_quest("quest_b") or
			QuestManager.get_current_step_index("quest_b") != 0,
		"quest_b should have left step 0"
	)

# ----- step advancement: condition-based -----

func _create_condition_event(event_id: String) -> UnlockConditionData:
	var c := UnlockConditionData.new()
	c.condition_id = "cond_" + event_id
	c.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	c.target_value = event_id
	return c

func test_condition_step_advances_when_all_conditions_true() -> void:
	var cond_step := QuestStepData.new()
	cond_step.step_id = "cond_step"
	cond_step.description = "Do two things"
	cond_step.completion_conditions = [
		_create_condition_event("event_x"),
		_create_condition_event("event_y"),
	] as Array[UnlockConditionData]
	var cond_quest := _create_quest("cond_quest", "Cond Quest",
		[cond_step] as Array[QuestStepData])
	QuestManager._quests_by_id["cond_quest"] = cond_quest

	QuestManager.start_quest("cond_quest")
	EventManager.trigger_event("event_x")  # one of two satisfied
	assert_true(QuestManager.has_active_quest("cond_quest"),
		"quest should still be active (only 1/2 conditions met)")

	EventManager.trigger_event("event_y")  # both now satisfied
	# After event_y, _on_event_triggered re-evaluates, both conditions pass,
	# step advances (quest has 1 step total, so it completes and is removed).
	assert_false(QuestManager.has_active_quest("cond_quest"),
		"quest should no longer be active after all conditions met")

func test_condition_step_does_not_advance_while_partial() -> void:
	var cond_step := QuestStepData.new()
	cond_step.step_id = "cond_step"
	cond_step.completion_conditions = [
		_create_condition_event("event_x"),
		_create_condition_event("event_never"),
	] as Array[UnlockConditionData]
	var cond_quest := _create_quest("cond_quest", "Cond Quest",
		[cond_step] as Array[QuestStepData])
	QuestManager._quests_by_id["cond_quest"] = cond_quest

	QuestManager.start_quest("cond_quest")
	EventManager.trigger_event("event_x")
	assert_true(QuestManager.has_active_quest("cond_quest"),
		"quest should remain active since event_never never fired")
	assert_eq(QuestManager.get_current_step_index("cond_quest"), 0,
		"step should still be 0")
