extends GutTest

## Integration tests for the BODY_REFINING zone action type: its number, the
## ActionManager start and stop signals and its branch in each dispatch, so a
## stop announces itself and runs the action's completion effects, and the
## zone's idle action pausing while it runs and resuming once it stops. Each test
## runs on a fresh save, with the original put back after it.

const AURA_WELL_ID: String = "aura_well_training"
const AURA_WELL_EVENT: String = "aura_well_discovered"
const FIXTURE_ID: String = "test_body_refining_fixture"

var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding back to the original save resumes its idle action: stop that too.
	_stop_everything()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _fixture() -> BodyRefiningActionData:
	var action := BodyRefiningActionData.new()
	action.action_id = FIXTURE_ID
	action.action_name = "Fixture Training"
	return action

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current != null else ""

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_body_refining_type_is_eight() -> void:
	assert_eq(ZoneActionData.ActionType.BODY_REFINING, 8, "appended after TRIBULATION (7): saved .tres files store the number")
	assert_eq(BodyRefiningActionData.new().action_type, ZoneActionData.ActionType.BODY_REFINING, "the data class sets its own type")

func test_selecting_starts_body_refining_and_stopping_stops_it() -> void:
	var action: BodyRefiningActionData = _fixture()
	watch_signals(ActionManager)
	ActionManager.select_action(action)
	assert_signal_emit_count(ActionManager, "start_body_refining", 1, "selecting announces the start once")
	assert_signal_emitted_with_parameters(ActionManager, "start_body_refining", [action])
	assert_same(ActionManager.get_current_action(), action, "the action is current")
	ActionManager.stop_action()
	assert_signal_emit_count(ActionManager, "stop_body_refining", 1, "stopping announces the stop once")
	assert_null(ActionManager.get_current_action(), "and nothing is current after it")

func test_stopping_runs_the_completion_effects() -> void:
	var action: BodyRefiningActionData = _fixture()
	var gold := AwardResourceEffectData.new()
	gold.resource_type = ResourceManager.ResourceType.GOLD
	gold.amount = 10.0
	gold.quiet = true
	action.success_effects.append(gold)
	var before: float = ResourceManager.get_gold()
	ActionManager.select_action(action)
	ActionManager.stop_action()
	assert_eq(ResourceManager.get_gold(), before + 10.0, "the stop ran the success effects")

func test_it_pauses_the_idle_action_and_stopping_resumes_it() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")
	ActionManager.select_action(_fixture())
	assert_eq(_current_id(), FIXTURE_ID, "body refining stands in for the idle action")
	ActionManager.stop_action()
	assert_eq(_current_id(), AURA_WELL_ID, "and the Aura Well resumes when it stops")
