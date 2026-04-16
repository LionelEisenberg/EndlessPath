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
