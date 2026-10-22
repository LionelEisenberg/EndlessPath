extends GutTest

## Integration tests for the "always in an idle action" rule on ActionManager:
## which idle action a zone picks (resolve_idle_action), when it resumes
## (after every session action, on arrival in a zone, on the first idle
## unlock, on a save reset), the log lines it writes, and the Madra rate of
## the running action.

const ZONE_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"
## Test Zone's own unlock condition (zone_unlock_conditions in test_zone.tres).
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"

const FORAGING_ID: String = "sprint_forest_foraging_action"
const AURA_WELL_ID: String = "aura_well_training"
const CYCLING_ID: String = "wilderness_cycling_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
const MERCHANT_ID: String = "spirit_valley_merchant"

const FORAGING_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"

const FIXTURE_IDLE_ID: String = "test_idle_resolution_fixture_forage"
const FIXTURE_IDLE_NAME: String = "Fixture Foraging"

## An idle action added to Test Zone (which has none) for travel tests.
var _fixture_idle: ForageActionData = null

## Player-log lines since the last _clear_log(). LogManager's own history is
## capped, so counting from its size would break once the run fills it.
var _logged: Array[String] = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_logged.clear()
	LogManager.message_logged.connect(_on_message_logged)

func after_each() -> void:
	LogManager.message_logged.disconnect(_on_message_logged)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	_remove_fixture_idle()

func _on_message_logged(bbcode_message: String) -> void:
	_logged.append(bbcode_message)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _action(action_id: String) -> ZoneActionData:
	return ZoneManager.get_action_by_id(action_id)

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

func _unlock_foraging() -> void:
	EventManager.trigger_event(FORAGING_EVENT)

func _unlock_aura_well() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)

## Unlocks the Aura Well, which starts it (the first idle unlock auto-starts).
func _run_aura_well() -> void:
	_unlock_aura_well()
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")

func _completions(action_id: String, zone_id: String = ZONE_ID) -> int:
	return ZoneManager.get_zone_progression(zone_id).action_completion_count.get(action_id, 0)

## Gives Test Zone an idle action and unlocks the zone, so travel there has
## something to resume.
func _add_fixture_idle_to_test_zone() -> void:
	_fixture_idle = ForageActionData.new()
	_fixture_idle.action_id = FIXTURE_IDLE_ID
	_fixture_idle.action_name = FIXTURE_IDLE_NAME
	_fixture_idle.action_type = ZoneActionData.ActionType.FORAGE
	ZoneManager.get_zone_by_id(TEST_ZONE_ID).all_actions.append(_fixture_idle)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)

func _remove_fixture_idle() -> void:
	if _fixture_idle == null:
		return
	ZoneManager.get_zone_by_id(TEST_ZONE_ID).all_actions.erase(_fixture_idle)
	_fixture_idle = null

func _clear_log() -> void:
	_logged.clear()

#-----------------------------------------------------------------------------
# RESOLUTION ORDER
#-----------------------------------------------------------------------------

func test_resolve_prefers_saved_last_idle() -> void:
	_unlock_foraging()
	_unlock_aura_well()
	ZoneManager.set_last_idle_action_id(ZONE_ID, FORAGING_ID)
	var resolved: ZoneActionData = ActionManager.resolve_idle_action(ZONE_ID)
	assert_not_null(resolved)
	if resolved:
		assert_eq(resolved.action_id, FORAGING_ID, "the saved last idle action wins over list order")

func test_resolve_falls_back_to_first_in_group_order() -> void:
	_unlock_foraging()
	_unlock_aura_well()
	ZoneManager.set_last_idle_action_id(ZONE_ID, "")
	var resolved: ZoneActionData = ActionManager.resolve_idle_action(ZONE_ID)
	assert_not_null(resolved)
	if resolved:
		assert_eq(resolved.action_id, AURA_WELL_ID, "Cultivate (Aura Well) lists before Gather (foraging)")

func test_resolve_skips_stale_saved_id() -> void:
	_unlock_aura_well()
	ZoneManager.set_last_idle_action_id(ZONE_ID, FORAGING_ID)
	var resolved: ZoneActionData = ActionManager.resolve_idle_action(ZONE_ID)
	assert_not_null(resolved)
	if resolved:
		assert_eq(resolved.action_id, AURA_WELL_ID, "locked foraging is skipped for the first available idle action")

func test_resolve_skips_saved_id_of_a_removed_action() -> void:
	_unlock_aura_well()
	ZoneManager.set_last_idle_action_id(ZONE_ID, "an_action_that_no_longer_exists")
	var resolved: ZoneActionData = ActionManager.resolve_idle_action(ZONE_ID)
	assert_not_null(resolved)
	if resolved:
		assert_eq(resolved.action_id, AURA_WELL_ID)

func test_resolve_returns_null_with_nothing_idle() -> void:
	assert_null(ActionManager.resolve_idle_action(ZONE_ID), "a fresh save has no idle action unlocked")
	assert_null(ActionManager.resolve_idle_action(TEST_ZONE_ID), "Test Zone has no actions")

#-----------------------------------------------------------------------------
# RESUME AFTER A SESSION ACTION
#-----------------------------------------------------------------------------

func test_cycling_stop_resumes_idle() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(CYCLING_ID))
	assert_eq(_current_id(), CYCLING_ID)
	ActionManager.stop_action()
	assert_eq(_current_id(), AURA_WELL_ID, "closing cycling resumes the Aura Well")

func test_adventure_stop_win_resumes_idle() -> void:
	_run_aura_well()
	ResourceManager.set_madra(ResourceManager.get_adventure_madra_threshold())
	ActionManager.select_action(_action(ADVENTURE_ID))
	assert_eq(_current_id(), ADVENTURE_ID)
	ActionManager.stop_action(true)
	assert_eq(_current_id(), AURA_WELL_ID, "a won adventure resumes the Aura Well")

func test_adventure_stop_loss_resumes_idle() -> void:
	_run_aura_well()
	ResourceManager.set_madra(ResourceManager.get_adventure_madra_threshold())
	ActionManager.select_action(_action(ADVENTURE_ID))
	assert_eq(_current_id(), ADVENTURE_ID)
	ActionManager.stop_action(false)
	assert_eq(_current_id(), AURA_WELL_ID, "a lost adventure resumes the Aura Well")

func test_dialogue_end_resumes_idle() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(DIALOGUE_ID))
	assert_eq(_current_id(), DIALOGUE_ID)
	# Ending the timeline is what the player's last click does: Dialogic emits
	# timeline_ended, DialogueManager emits dialogue_ended, ActionManager stops.
	# skip_ending ends it now instead of first playing Dialogic's ending
	# timeline. It awaits a clear; the extra frame frees Dialogic's layout.
	await Dialogic.end_timeline(true)
	await get_tree().process_frame
	assert_eq(_current_id(), AURA_WELL_ID, "the end of a dialogue resumes the Aura Well")

func test_merchant_close_resumes_idle() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(MERCHANT_ID))
	assert_eq(_current_id(), MERCHANT_ID)
	ActionManager.stop_action()
	assert_eq(_current_id(), AURA_WELL_ID, "leaving the shop resumes the Aura Well")

func test_session_stop_logs_resumed_line() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(CYCLING_ID))
	_clear_log()
	ActionManager.stop_action()
	assert_eq(_logged, ["Resumed Aura Well"] as Array[String])

func test_session_stop_with_nothing_idle_resumes_nothing() -> void:
	ActionManager.select_action(_action(CYCLING_ID))
	_clear_log()
	ActionManager.stop_action()
	assert_null(ActionManager.get_current_action())
	assert_eq(_logged, [] as Array[String], "nothing resumed, nothing logged")

func test_stopping_idle_resumes_nothing() -> void:
	_run_aura_well()
	ActionManager.stop_action()
	assert_null(ActionManager.get_current_action(), "stopping the idle action itself resumes nothing")
	assert_true(ActionManager.action_timer.is_stopped())

#-----------------------------------------------------------------------------
# SELECTING
#-----------------------------------------------------------------------------

func test_starting_idle_saves_it_as_last_idle() -> void:
	_unlock_foraging()
	_unlock_aura_well()
	ActionManager.select_action(_action(FORAGING_ID))
	assert_eq(ZoneManager.get_last_idle_action_id(ZONE_ID), FORAGING_ID)

func test_session_action_is_not_saved_as_last_idle() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(CYCLING_ID))
	assert_eq(ZoneManager.get_last_idle_action_id(ZONE_ID), AURA_WELL_ID)

func test_selecting_marks_action_seen() -> void:
	assert_false(ZoneManager.is_action_seen(MERCHANT_ID), "precondition: the merchant is locked on a fresh save")
	ActionManager.select_action(_action(MERCHANT_ID))
	assert_true(ZoneManager.is_action_seen(MERCHANT_ID))

func test_rejected_adventure_keeps_idle_running() -> void:
	_run_aura_well()
	assert_false(ResourceManager.can_start_adventure(), "precondition: a fresh save has 25 Madra, under the 50 needed")
	var completions_before: int = _completions(AURA_WELL_ID)
	_clear_log()
	ActionManager.select_action(_action(ADVENTURE_ID))
	assert_eq(_current_id(), AURA_WELL_ID, "an unaffordable adventure stops nothing")
	assert_false(ActionManager.action_timer.is_stopped(), "the Aura Well keeps ticking")
	assert_eq(_completions(AURA_WELL_ID), completions_before, "the Aura Well was never stopped")
	assert_eq(_logged, [] as Array[String], "a refused adventure logs nothing new")

#-----------------------------------------------------------------------------
# ZONE CHANGE
#-----------------------------------------------------------------------------

func test_zone_change_resolves_destination() -> void:
	_run_aura_well()
	_add_fixture_idle_to_test_zone()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq(_current_id(), FIXTURE_IDLE_ID, "arriving in Test Zone starts its idle action")

func test_zone_change_with_no_idle_leaves_nothing() -> void:
	_run_aura_well()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_null(ActionManager.get_current_action(), "Test Zone has nothing idle to resume")
	assert_true(ActionManager.action_timer.is_stopped(), "the Aura Well's timer stops")

func test_zone_change_resumes_saved_idle_on_return() -> void:
	_unlock_foraging()
	_unlock_aura_well()
	ActionManager.select_action(_action(FORAGING_ID))
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	ZoneManager.set_current_zone_by_id(ZONE_ID)
	assert_eq(_current_id(), FORAGING_ID, "coming back resumes foraging, not the Aura Well listed before it")

func test_same_zone_change_does_not_restart() -> void:
	_run_aura_well()
	var completions_before: int = _completions(AURA_WELL_ID)
	watch_signals(ActionManager)
	ZoneManager.zone_changed.emit(ZoneManager.get_current_zone())
	assert_eq(_current_id(), AURA_WELL_ID)
	assert_eq(_completions(AURA_WELL_ID), completions_before, "a repeat zone_changed (the load sends two) must not restart it")
	assert_signal_not_emitted(ActionManager, "stop_training")

func test_same_zone_change_ends_a_session_action() -> void:
	_run_aura_well()
	ActionManager.select_action(_action(MERCHANT_ID))
	_clear_log()
	ZoneManager.zone_changed.emit(ZoneManager.get_current_zone())
	assert_eq(_current_id(), AURA_WELL_ID)
	assert_eq(_logged, ["Resumed Aura Well"] as Array[String])

func test_travel_logs_travelled_line_without_idle() -> void:
	_run_aura_well()
	watch_signals(LogManager)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["Travelled to Test Zone"])

func test_travel_logs_merged_line() -> void:
	_run_aura_well()
	_add_fixture_idle_to_test_zone()
	_clear_log()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq(_logged, ["Travelled to Test Zone · resumed Fixture Foraging"] as Array[String],
		"travel writes one merged line, not a second Resumed line")

#-----------------------------------------------------------------------------
# UNLOCKS
#-----------------------------------------------------------------------------

func test_first_idle_unlock_auto_starts() -> void:
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs on a fresh save")
	_clear_log()
	_unlock_aura_well()
	assert_eq(_current_id(), AURA_WELL_ID, "the first idle action to unlock starts on its own")
	assert_has(_logged, "Started Aura Well")
	assert_true(ZoneManager.is_action_seen(AURA_WELL_ID), "starting it counts as using it")
	assert_eq(ZoneManager.get_last_idle_action_id(ZONE_ID), AURA_WELL_ID)

func test_empty_condition_id_does_not_start() -> void:
	_run_aura_well()
	ActionManager.stop_action()
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs")
	UnlockManager.condition_unlocked.emit("")
	assert_null(ActionManager.get_current_action(), "the save-reset ping (empty id) starts nothing")

func test_unlock_during_session_action_waits_for_it() -> void:
	ActionManager.select_action(_action(CYCLING_ID))
	_unlock_aura_well()
	assert_eq(_current_id(), CYCLING_ID, "an unlock never interrupts a running action")
	_clear_log()
	ActionManager.stop_action()
	assert_eq(_current_id(), AURA_WELL_ID, "the new idle action resumes when cycling ends")
	assert_eq(_logged, ["Resumed Aura Well"] as Array[String],
		"every resume after a session action reads Resumed; only the auto-start on an unlock reads Started")

## A save from before last idle ids were kept has none in its zones. The
## resume after a session action still reads Resumed.
func test_resume_without_a_saved_last_idle_logs_resumed() -> void:
	_unlock_foraging()
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs")
	ZoneManager.set_last_idle_action_id(ZONE_ID, "")
	ActionManager.select_action(_action(CYCLING_ID))
	_clear_log()
	ActionManager.stop_action()
	assert_eq(_current_id(), FORAGING_ID)
	assert_eq(_logged, ["Resumed Spring Forest Foraging"] as Array[String])

func test_resume_after_a_first_start_logs_resumed() -> void:
	ActionManager.select_action(_action(CYCLING_ID))
	_unlock_aura_well()
	ActionManager.stop_action()
	ActionManager.select_action(_action(CYCLING_ID))
	_clear_log()
	ActionManager.stop_action()
	assert_eq(_logged, ["Resumed Aura Well"] as Array[String], "the second start resumes it")

#-----------------------------------------------------------------------------
# SAVE RESET (Review Focus 5)
#-----------------------------------------------------------------------------

func test_save_reset_stops_and_resolves_once() -> void:
	_run_aura_well()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_null(ActionManager.get_current_action(), "the fresh save has no idle action unlocked")
	assert_true(ActionManager.action_timer.is_stopped(), "no orphan timer")
	assert_eq(ActionManager.action_timer.timeout.get_connections().size(), 0, "no tick callback left connected")
	assert_eq(_completions(AURA_WELL_ID), 0, "the old save's Aura Well must not count a completion in the fresh save")

#-----------------------------------------------------------------------------
# LOAD
#-----------------------------------------------------------------------------

## On load nothing runs and ZoneTilemap._ready sends zone_changed twice for
## the same zone: the idle action starts once and logs one line.
func test_load_double_zone_changed_resumes_once() -> void:
	_run_aura_well()
	ActionManager.stop_action()
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs, as on load")
	_clear_log()
	ZoneManager.set_current_zone_by_id(ZONE_ID)
	ZoneManager.set_current_zone_by_id(ZONE_ID)
	assert_eq(_current_id(), AURA_WELL_ID, "the load resumes the zone's idle action")
	assert_eq(_logged, ["Resumed Aura Well"] as Array[String], "one line, not one per zone_changed")
	assert_eq(ActionManager.action_timer.timeout.get_connections().size(), 1, "one tick callback, not one per zone_changed")

func test_save_reset_starts_the_new_saves_idle_once() -> void:
	_unlock_foraging()
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs in the old save")
	var next_save := SaveGameData.new()
	next_save.unlock_progression.unlocked_condition_ids.append(AURA_WELL_EVENT)
	_clear_log()
	PersistenceManager.save_game_data = next_save
	PersistenceManager.save_data_reset.emit()
	assert_eq(_current_id(), AURA_WELL_ID, "the new save's idle action runs")
	assert_eq(ActionManager.action_timer.timeout.get_connections().size(), 1, "one tick callback, not one per resolve")
	assert_eq(_logged.count("Resumed Aura Well"), 1, "resolved once")

#-----------------------------------------------------------------------------
# MADRA RATE
#-----------------------------------------------------------------------------

func test_madra_per_second_tracks_current_action() -> void:
	assert_eq(ActionManager.get_current_madra_per_second(), 0.0, "nothing runs")
	_run_aura_well()
	assert_almost_eq(ActionManager.get_current_madra_per_second(), 1.5, 0.001, "the Aura Well trickles 1.5 Madra a second")
	_unlock_foraging()
	ActionManager.select_action(_action(FORAGING_ID))
	assert_eq(ActionManager.get_current_madra_per_second(), 0.0, "foraging earns no Madra")
