extends GutTest

func test_training_tick_progress_defaults_to_empty_dict() -> void:
	var zp := ZoneProgressionData.new()
	assert_true(zp.training_tick_progress.is_empty(), "training_tick_progress should default to empty")

func test_training_tick_progress_persists_via_resource_save_load() -> void:
	var zp := ZoneProgressionData.new()
	zp.zone_id = "SpiritValley"
	zp.training_tick_progress["aura_well_training"] = 7
	zp.training_tick_progress["other_training"] = 99

	var tmp_path: String = "user://__test_zone_progression.tres"
	ResourceSaver.save(zp, tmp_path)
	var loaded: ZoneProgressionData = ResourceLoader.load(tmp_path, "ZoneProgressionData", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.training_tick_progress["aura_well_training"], 7)
	assert_eq(loaded.training_tick_progress["other_training"], 99)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

func test_last_idle_action_id_round_trips() -> void:
	var zp := ZoneProgressionData.new()
	zp.zone_id = "SpiritValley"
	zp.last_idle_action_id = "aura_well_training"

	var tmp_path: String = "user://__test_zone_progression_last_idle.tres"
	ResourceSaver.save(zp, tmp_path)
	var loaded: ZoneProgressionData = ResourceLoader.load(tmp_path, "ZoneProgressionData", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.last_idle_action_id, "aura_well_training")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

#-----------------------------------------------------------------------------
# ZoneManager.get_training_ticks / increment_training_ticks
#-----------------------------------------------------------------------------

var _original_live_save: SaveGameData
var _save_data: SaveGameData

func before_each() -> void:
	_original_live_save = ZoneManager.live_save_data
	_save_data = SaveGameData.new()
	ZoneManager.live_save_data = _save_data

func after_each() -> void:
	ZoneManager.live_save_data = _original_live_save

func test_get_training_ticks_returns_zero_for_unseen_action() -> void:
	assert_eq(ZoneManager.get_training_ticks("unknown_action", "SpiritValley"), 0)

func test_increment_training_ticks_initializes_from_zero() -> void:
	var total: int = ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	assert_eq(total, 1)
	assert_eq(ZoneManager.get_training_ticks("aura_well_training", "SpiritValley"), 1)

func test_increment_training_ticks_accumulates_across_calls() -> void:
	ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	var total: int = ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley", 3)
	assert_eq(total, 5)

func test_increment_training_ticks_independent_per_action() -> void:
	ZoneManager.increment_training_ticks("a", "SpiritValley", 2)
	ZoneManager.increment_training_ticks("b", "SpiritValley", 7)
	assert_eq(ZoneManager.get_training_ticks("a", "SpiritValley"), 2)
	assert_eq(ZoneManager.get_training_ticks("b", "SpiritValley"), 7)

#-----------------------------------------------------------------------------
# ZoneManager.is_action_used_up / increment_zone_progression_for_action
#-----------------------------------------------------------------------------

## NPC 1 in Spirit Valley: no unlock conditions, and used up after one completion.
const LIMITED_ACTION_ID: String = "celestial_intervener_dialogue_1"
const UNLIMITED_ACTION_ID: String = "sprint_forest_foraging_action"

## An action that is in no zone, with this limit (0 for none).
func _action_with_limit(limit: int) -> ZoneActionData:
	var action := ZoneActionData.new()
	action.action_id = "zone_progression_test_action"
	action.max_completions = limit
	return action

func _available_ids(zone_id: String) -> Array[String]:
	var ids: Array[String] = []
	for action: ZoneActionData in ZoneManager.get_available_actions(zone_id):
		ids.append(action.action_id)
	return ids

func test_an_action_with_no_limit_is_never_used_up() -> void:
	var action: ZoneActionData = _action_with_limit(0)
	ZoneManager.increment_zone_progression_for_action(action.action_id, "SpiritValley", 50)
	assert_false(ZoneManager.is_action_used_up(action, "SpiritValley"), "max_completions 0 means unlimited")

func test_a_limited_action_is_used_up_when_it_reaches_its_limit() -> void:
	var action: ZoneActionData = _action_with_limit(3)
	for completed: int in 3:
		assert_false(ZoneManager.is_action_used_up(action, "SpiritValley"), "%d of 3 is not enough" % completed)
		ZoneManager.increment_zone_progression_for_action(action.action_id, "SpiritValley")
	assert_true(ZoneManager.is_action_used_up(action, "SpiritValley"), "3 of 3 uses it up")
	ZoneManager.increment_zone_progression_for_action(action.action_id, "SpiritValley")
	assert_true(ZoneManager.is_action_used_up(action, "SpiritValley"), "and it stays used up past the limit")

func test_an_action_is_used_up_in_one_zone_at_a_time() -> void:
	var action: ZoneActionData = _action_with_limit(1)
	ZoneManager.increment_zone_progression_for_action(action.action_id, "SpiritValley")
	assert_true(ZoneManager.is_action_used_up(action, "SpiritValley"))
	assert_false(ZoneManager.is_action_used_up(action, "TestZone"), "its count in another zone is a count of its own")

func test_the_completion_that_uses_a_limited_action_up_announces_it() -> void:
	watch_signals(ZoneManager)
	ZoneManager.increment_zone_progression_for_action(LIMITED_ACTION_ID, "SpiritValley")
	assert_signal_emitted_with_parameters(ZoneManager, "action_completed", [LIMITED_ACTION_ID])

func test_a_completion_of_an_unlimited_action_announces_nothing() -> void:
	watch_signals(ZoneManager)
	ZoneManager.increment_zone_progression_for_action(UNLIMITED_ACTION_ID, "SpiritValley", 5)
	assert_signal_not_emitted(ZoneManager, "action_completed")

func test_available_actions_leave_out_a_used_up_action() -> void:
	assert_has(_available_ids("SpiritValley"), LIMITED_ACTION_ID)
	ZoneManager.increment_zone_progression_for_action(LIMITED_ACTION_ID, "SpiritValley")
	assert_does_not_have(_available_ids("SpiritValley"), LIMITED_ACTION_ID)
