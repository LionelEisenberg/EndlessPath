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
	EventManager.live_save_data = _save_data

func after_each() -> void:
	QuestManager._live_save_data = null
	QuestManager._quests_by_id = {}
	EventManager.live_save_data = null

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

# ----- retroactive auto-complete on start -----

func test_start_skips_past_already_satisfied_event_step() -> void:
	# Pre-fire the first step's event before starting the quest.
	EventManager.trigger_event("eel_dialogue_done")
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"start should skip past the pre-satisfied step")

func test_start_stops_at_first_unsatisfied_step() -> void:
	# quest_a has two steps: eel_dialogue_done, spring_forest_visited.
	# Only the first event has fired.
	EventManager.trigger_event("eel_dialogue_done")
	QuestManager.start_quest("quest_a")
	assert_eq(QuestManager.get_current_step_index("quest_a"), 1,
		"should stop at step 1 (unfired spring_forest_visited)")
	assert_true(QuestManager.has_active_quest("quest_a"),
		"quest_a should still be active")

func test_start_completes_instantly_if_all_satisfied() -> void:
	EventManager.trigger_event("eel_dialogue_done")
	EventManager.trigger_event("spring_forest_visited")
	watch_signals(QuestManager)
	QuestManager.start_quest("quest_a")
	assert_false(QuestManager.has_active_quest("quest_a"),
		"fully-satisfied quest should not remain active")
	# quest_started still fires (the quest WAS started, just instantly finished).
	assert_signal_emitted(QuestManager, "quest_started")

# ----- quest completion -----

## A simple effect that records when it was processed — lets us assert
## completion_effects fire in order.
class TestRecordingEffect extends EffectData:
	var processed: bool = false
	func process() -> void:
		processed = true
	func _to_string() -> String:
		return "TestRecordingEffect(processed=%s)" % processed

func test_final_step_advance_completes_quest() -> void:
	QuestManager.start_quest("quest_b")  # single step
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_false(QuestManager.has_active_quest("quest_b"),
		"quest_b should be removed from active after final step")
	assert_true(QuestManager.has_completed_quest("quest_b"),
		"quest_b should be in completed list")

func test_completion_fires_completion_effects() -> void:
	var effect := TestRecordingEffect.new()
	_quest_b.completion_effects = [effect] as Array[EffectData]
	QuestManager.start_quest("quest_b")
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_true(effect.processed, "completion effect should have been processed")

func test_completion_emits_signal() -> void:
	QuestManager.start_quest("quest_b")
	watch_signals(QuestManager)
	QuestManager._on_event_triggered("eel_dialogue_done")
	assert_signal_emitted_with_parameters(QuestManager, "quest_completed", ["quest_b"])

func test_completion_preserves_insertion_order_in_completed_list() -> void:
	QuestManager.start_quest("quest_a")
	QuestManager.start_quest("quest_b")
	# Complete quest_b first (it only has 1 step).
	QuestManager._on_event_triggered("eel_dialogue_done")
	# eel_dialogue_done also advanced quest_a to step 1. Complete quest_a by
	# firing spring_forest_visited.
	QuestManager._on_event_triggered("spring_forest_visited")
	var completed: Array[String] = QuestManager.get_completed_quest_ids()
	assert_eq(completed.size(), 2)
	assert_eq(completed[0], "quest_b", "quest_b completed first")
	assert_eq(completed[1], "quest_a", "quest_a completed second")

# ----- edge cases -----

func test_zero_step_quest_completes_instantly_on_start() -> void:
	var empty_quest := _create_quest("empty_quest", "Empty Quest", [] as Array[QuestStepData])
	QuestManager._quests_by_id["empty_quest"] = empty_quest
	QuestManager.start_quest("empty_quest")
	assert_false(QuestManager.has_active_quest("empty_quest"),
		"zero-step quest should not remain active")
	assert_true(QuestManager.has_completed_quest("empty_quest"),
		"zero-step quest should be in completed list")

func test_zero_step_quest_fires_completion_effects() -> void:
	var effect := TestRecordingEffect.new()
	var empty_quest := _create_quest("empty_quest", "Empty Quest", [] as Array[QuestStepData])
	empty_quest.completion_effects = [effect] as Array[EffectData]
	QuestManager._quests_by_id["empty_quest"] = empty_quest
	QuestManager.start_quest("empty_quest")
	assert_true(effect.processed, "zero-step quest should still fire completion effects")

func test_load_drops_active_quest_with_deleted_data() -> void:
	# Simulate a save that references a quest no longer in the catalog.
	_save_data.quest_progression.active_quests["ghost_quest"] = 0
	QuestManager._prune_unknown_active_quests()
	assert_false(_save_data.quest_progression.active_quests.has("ghost_quest"),
		"unknown active quests should be pruned")

# ----- load-time validation -----

func test_step_with_both_event_and_conditions_pushes_error() -> void:
	var bad_step := QuestStepData.new()
	bad_step.step_id = "bad"
	bad_step.completion_event_id = "some_event"
	bad_step.completion_conditions = [_create_condition_event("other")] as Array[UnlockConditionData]
	var bad_quest := _create_quest("bad_quest", "Bad Quest", [bad_step] as Array[QuestStepData])
	QuestManager._quest_catalog = QuestList.new()
	QuestManager._quest_catalog.quests = [bad_quest] as Array[QuestData]
	QuestManager._build_catalog_index()
	QuestManager._validate_catalog()
	assert_push_error("has both completion_event_id and completion_conditions")

func test_step_with_neither_event_nor_conditions_pushes_error() -> void:
	var bad_step := QuestStepData.new()
	bad_step.step_id = "bad"
	# Neither completion_event_id nor completion_conditions set.
	var bad_quest := _create_quest("bad_quest2", "Bad Quest 2", [bad_step] as Array[QuestStepData])
	QuestManager._quest_catalog = QuestList.new()
	QuestManager._quest_catalog.quests = [bad_quest] as Array[QuestData]
	QuestManager._build_catalog_index()
	QuestManager._validate_catalog()
	assert_push_error("has no completion criteria")
