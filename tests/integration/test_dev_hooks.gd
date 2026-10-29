extends GutTest

## The public hooks the dev tools use on the managers: the catalog accessors,
## copies of the triggered events and the latched conditions, the dev zone
## toggles' getters, clearing the player's log, a fresh set of player vitals,
## and ActionManager's complete without playing and cancel. Each test binds a
## fresh save, calls the real autoloads, stops what it started and puts the
## original save back.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const LOG_MANAGER_SCRIPT: GDScript = preload("res://singletons/log_manager/log_manager.gd")
const QUEST_LIST_PATH: String = "res://resources/quests/quest_list.tres"

const ZONE_ID: String = "SpiritValley"
const FORAGING_ID: String = "sprint_forest_foraging_action"
## NPC 1, "Talk to the [INTERVENER]": a dialogue used up after one completion.
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
## The event NPC 1's success effects fire.
const DIALOGUE_EVENT: String = "celestial_intervener_dialogue_1"
## The quest NPC 1's success effects start.
const DIALOGUE_QUEST: String = "q_fill_core"
## Fired when q_fill_core completes. It unlocks foraging, which then starts on
## its own (the first idle action to unlock does).
const FORAGING_EVENT: String = "q_fill_core_completed"

const TEST_EVENT: String = "dev_hooks_test_event"
const TEST_CONDITION: String = "dev_hooks_test_condition"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
## NPC 1's completion count at the moment its event fired, -1 until it does.
var _count_when_event_fired: int = -1

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_count_when_event_fired = -1

func after_each() -> void:
	if EventManager.event_triggered.is_connected(_on_event_triggered):
		EventManager.event_triggered.disconnect(_on_event_triggered)
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _action(action_id: String) -> ZoneActionData:
	return ZoneManager.get_action_by_id(action_id)

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

func _completions(action_id: String) -> int:
	return ZoneManager.get_zone_progression(ZONE_ID).action_completion_count.get(action_id, 0)

func _on_event_triggered(event_id: String) -> void:
	if event_id == DIALOGUE_EVENT:
		_count_when_event_fired = _completions(DIALOGUE_ID)

#-----------------------------------------------------------------------------
# CATALOGS AND COPIES
#-----------------------------------------------------------------------------

func test_catalog_accessors_list_the_catalogs() -> void:
	# Other suites replace the ability index with fakes; start from the real one.
	AbilityManager._build_catalog_index()

	var technique_ids: Array[String] = []
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		technique_ids.append(technique.id)
	for technique_id: String in ["foundation_technique", "smooth_flow", "torrential_flow"]:
		assert_has(technique_ids, technique_id)
		assert_true(CyclingManager.has_technique(technique_id), "has_technique(\"%s\")" % technique_id)
	# An unknown id is answered quietly: a push_error would fail this test.
	assert_false(CyclingManager.has_technique("nope"), "an unknown technique")

	var ability_ids: Array[String] = []
	for ability: AbilityData in AbilityManager.get_all_abilities():
		ability_ids.append(ability.ability_id)
	for ability_id: String in ["basic_strike", "empty_palm", "enforce", "power_font"]:
		assert_has(ability_ids, ability_id)
		assert_true(AbilityManager.has_ability(ability_id), "has_ability(\"%s\")" % ability_id)
	assert_false(AbilityManager.has_ability("nope"), "an unknown ability")

	var quest_ids: Array[String] = []
	for quest: QuestData in QuestManager.get_all_quests():
		quest_ids.append(quest.quest_id)
	for quest_id: String in ["q_fill_core", "q_first_steps", "q_reach_core_density_10"]:
		assert_has(quest_ids, quest_id)
	var catalog_ids: Array[String] = []
	for quest: QuestData in (load(QUEST_LIST_PATH) as QuestList).quests:
		catalog_ids.append(quest.quest_id)
	assert_eq(quest_ids, catalog_ids, "the quests come in catalog order")

func test_clear_history_empties_the_log() -> void:
	# A fresh instance of the real script, so the run's own log is left alone.
	var log_manager: Node = autofree(LOG_MANAGER_SCRIPT.new())
	log_manager.log_message("first")
	log_manager.log_message("second")
	watch_signals(log_manager)
	log_manager.clear_history()
	assert_eq(log_manager.get_history(), [] as Array[String])
	assert_signal_not_emitted(log_manager, "message_logged", "clearing the log emits nothing")

func test_triggered_events_and_conditions_are_copies() -> void:
	EventManager.trigger_event(TEST_EVENT)
	UnlockManager.force_unlock_condition(TEST_CONDITION)
	var events: Array[String] = EventManager.get_triggered_events()
	var conditions: Array[String] = UnlockManager.get_unlocked_condition_ids()
	assert_has(events, TEST_EVENT)
	assert_has(conditions, TEST_CONDITION)
	events.clear()
	conditions.clear()
	assert_true(EventManager.has_event_triggered(TEST_EVENT), "clearing the copy leaves the event triggered")
	assert_true(UnlockManager.is_condition_unlocked(TEST_CONDITION), "and the condition latched")
	assert_has(EventManager.get_triggered_events(), TEST_EVENT)
	assert_has(UnlockManager.get_unlocked_condition_ids(), TEST_CONDITION)

func test_zone_visibility_getters() -> void:
	ZoneManager.set_demo_zones_visible(true)
	ZoneManager.set_hidden_zones_visible(false)
	assert_true(ZoneManager.are_demo_zones_visible(), "the demo zones show")
	assert_false(ZoneManager.are_hidden_zones_visible(), "the hidden zones have their own toggle")
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(true)
	assert_false(ZoneManager.are_demo_zones_visible(), "the demo zones are hidden again")
	assert_true(ZoneManager.are_hidden_zones_visible(), "the hidden zones show")
	ZoneManager.set_hidden_zones_visible(false)
	assert_false(ZoneManager.are_hidden_zones_visible(), "the hidden zones are hidden again")

#-----------------------------------------------------------------------------
# PLAYER VITALS
#-----------------------------------------------------------------------------

func test_reset_vitals_gives_a_fresh_vitals_manager() -> void:
	var old_vitals: VitalsManager = PlayerManager.vitals_manager
	var stat_hooks: int = CharacterManager.stats_changed.get_connections().size()
	old_vitals.initialize_current_values()
	old_vitals.stamina_regen = 2.0
	PlayerManager.reset_vitals()
	var vitals: VitalsManager = PlayerManager.vitals_manager
	assert_not_same(vitals, old_vitals, "a new VitalsManager")
	assert_eq(vitals.current_health, 0.0, "the run's Health does not carry over")
	assert_eq(vitals.stamina_regen, 0.0, "nor its regen")
	assert_true(vitals.is_player, "it is built as at boot: the player's")
	assert_eq(vitals.get_parent(), PlayerManager, "under PlayerManager")
	assert_almost_eq(vitals.max_health, CharacterManager.get_total_attributes_data().get_max_health(), 0.001,
		"it follows the attributes, as at boot")
	await wait_process_frames(1)
	assert_freed(old_vitals, "the old VitalsManager")
	assert_eq(CharacterManager.stats_changed.get_connections().size(), stat_hooks,
		"the old manager's stats hook went with it")

#-----------------------------------------------------------------------------
# COMPLETE WITHOUT PLAYING
#-----------------------------------------------------------------------------

func test_complete_without_playing_counts_then_runs_effects() -> void:
	EventManager.event_triggered.connect(_on_event_triggered)
	watch_signals(ActionManager)
	ActionManager.complete_without_playing(_action(DIALOGUE_ID), ZONE_ID)
	assert_eq(_completions(DIALOGUE_ID), 1, "one completion counts in Spirit Valley")
	assert_true(EventManager.has_event_triggered(DIALOGUE_EVENT), "its success effects ran")
	assert_true(QuestManager.has_active_quest(DIALOGUE_QUEST), "q_fill_core is active")
	assert_eq(_count_when_event_fired, 1, "the completion counted before the effects ran")
	assert_null(ActionManager.get_current_action(), "nothing runs")
	assert_signal_not_emitted(ActionManager, "current_action_changed", "nothing started")

func test_complete_without_playing_leaves_the_running_action_alone() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_id(), FORAGING_ID, "precondition: unlocking foraging starts it")
	watch_signals(ActionManager)
	ActionManager.complete_without_playing(_action(DIALOGUE_ID), ZONE_ID)
	assert_eq(_completions(DIALOGUE_ID), 1)
	assert_eq(_current_id(), FORAGING_ID, "foraging runs on")
	assert_false(ActionManager.action_timer.is_stopped(), "its timer still ticks")
	assert_eq(_completions(FORAGING_ID), 0, "foraging was never stopped")
	assert_signal_not_emitted(ActionManager, "stop_foraging")
	assert_signal_not_emitted(ActionManager, "current_action_changed", "nothing started or stopped")

#-----------------------------------------------------------------------------
# CANCEL
#-----------------------------------------------------------------------------

## Unlocking foraging starts it, so the test cancels that run: a select_action()
## of its own would stop it first and count that stop.
func test_cancel_stops_foraging_without_counting() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_id(), FORAGING_ID, "precondition: unlocking foraging starts it")
	watch_signals(ActionManager)
	ActionManager.cancel_current_action()
	assert_null(ActionManager.get_current_action(), "nothing runs")
	assert_eq(_completions(FORAGING_ID), 0, "a cancel counts no completion")
	assert_signal_emit_count(ActionManager, "stop_foraging", 1, "the views still hear foraging stop")
	assert_true(ActionManager.action_timer.is_stopped(), "the forage timer stops")
	assert_eq(ActionManager.action_timer.timeout.get_connections().size(), 0, "no tick callback left connected")

## Review Focus 2: Dialogic's timeline_ended arrives a frame late. It must not
## stop the action that runs by then. The cancel waits until the timeline has
## begun: with no layout up yet, Dialogic adds one deferred and begins the
## timeline only at the end of the frame the dialogue started in.
func test_cancel_mid_dialogue_leaves_the_next_action_running() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(_action(DIALOGUE_ID))
	assert_eq(_current_id(), DIALOGUE_ID, "precondition: the dialogue runs")
	var begun: bool = await wait_until(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	assert_true(begun, "precondition: Dialogic plays the dialogue's timeline")
	watch_signals(DialogueManager)
	ActionManager.cancel_current_action()
	assert_null(ActionManager.get_current_action(), "a cancel resumes nothing")
	assert_eq(DialogueManager.current_timeline_name, "", "the dialogue is forgotten at once")
	ActionManager.select_action(_action(FORAGING_ID))
	await wait_process_frames(3)
	assert_signal_emitted(DialogueManager, "dialogue_ended", "Dialogic's timeline_ended came after the cancel")
	assert_eq(_current_id(), FORAGING_ID, "and foraging still runs")
	assert_eq(_completions(DIALOGUE_ID), 0, "the dialogue counts no completion")
	assert_false(EventManager.has_event_triggered(DIALOGUE_EVENT), "and runs none of its effects")
	assert_null(Dialogic.current_timeline, "the cancelled dialogue does not play on")
