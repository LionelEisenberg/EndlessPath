extends GutTest

## Unit tests for ActionManager.get_current_madra_per_second() while the cycling
## action runs. The cycling technique writes the running cycle's measured Madra
## rate to CyclingManager's session snapshot; while the cycling action is the
## current action, that rate is what ActionManager reports.

const CYCLING_ID: String = "wilderness_cycling_action"
const FORAGING_ID: String = "sprint_forest_foraging_action"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## select_action() does not check that the action is available, so the cycling
## action needs no unlock here.
func _select(action_id: String) -> void:
	ActionManager.select_action(ZoneManager.get_action_by_id(action_id))

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## A cycle 5 s into its 15 s that draws 13.3 Madra a second.
func _run_cycle_session() -> void:
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(5.0, 13.3)

#-----------------------------------------------------------------------------
# CYCLING RATE
#-----------------------------------------------------------------------------

func test_cycling_action_reports_the_cycle_rate() -> void:
	_select(CYCLING_ID)
	_run_cycle_session()
	assert_almost_eq(ActionManager.get_current_madra_per_second(), 13.3, 0.0001, "the running cycle's rate")

func test_rate_is_zero_once_the_cycle_ends() -> void:
	_select(CYCLING_ID)
	_run_cycle_session()
	CyclingManager.end_cycle_session()
	assert_eq(_current_id(), CYCLING_ID, "precondition: the cycling action still runs")
	assert_eq(ActionManager.get_current_madra_per_second(), 0.0, "no cycle draws Madra")

func test_cycle_rate_is_ignored_while_another_action_runs() -> void:
	_select(FORAGING_ID)
	_run_cycle_session()
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs")
	assert_eq(ActionManager.get_current_madra_per_second(), 0.0, "foraging earns no Madra, whatever a cycle session holds")
