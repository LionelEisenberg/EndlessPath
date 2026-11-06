extends GutTest

## Unit tests for how BodyRefiningViewState opens and closes the body refining
## board on MainView's state stack. A start sets the board up for the action and
## pushes the state once; entering blocks the full log, turns the dock and the
## map's input off and shows the board, leaving the chest, the Goals board and the
## log where they stand. Escape stops the action; the drill's presses go to the
## board. A stop halts the set at once and closes the board, removing only the
## state. On a MainView with no transition the open and the close are instant;
## given a real BoardTransition, driven by advance() and finish(), they play out,
## the state staying on the stack until the close has ended, presses dropped while
## the board moves, and a start while it closes turning the close around.
## The MainView is never added to the tree: each test fills in the views it needs,
## as test_tribulation_view_state.gd does, with the real board on a test clock and
## plain stand-ins for the rest, and calls the state's handlers instead of emitting
## ActionManager's signals. Every test runs on a fresh save, with the original put
## back after it. main_game.tscn is only read, never instanced.

const VIEW_SCENE_PATH: String = "res://scenes/body_refining/body_refining_view/body_refining_view.tscn"
const STATE_SCRIPT_PATH: String = "res://scenes/ui/main_view/states/body_refining_view_state.gd"
const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const LOG_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/log_window/log_window.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")

const ACTION_ID: String = "riverbank_training_action"
## An idle action, which resumes when body refining stops.
const RESUMED_ACTION_ID: String = "sprint_forest_foraging_action"
const START_USEC: int = 1_000_000

var _main_view: MainView = null
var _view: BodyRefiningView = null
var _state: BodyRefiningViewState = null
## Another overlay, which can sit below the board on the stack.
var _other: MainViewState = null
var _now_usec: int = START_USEC
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_now_usec = START_USEC
	_view = (load(VIEW_SCENE_PATH) as PackedScene).instantiate() as BodyRefiningView
	add_child_autofree(_view)
	(_view.get_node("%DrillPlay") as DrillPlay).clock_usec = func() -> int: return _now_usec
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.body_refining_view = _view
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())
	_main_view.dock = autofree(Control.new())
	_main_view.zone_map_viewport = autofree(SubViewport.new())
	_state = autofree(BodyRefiningViewState.new())
	_state.scene_root = _main_view
	_other = autofree(MainViewState.new())

func after_each() -> void:
	_stop_everything()
	BodyRefiningManager.end_set_session()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	_stop_everything()
	_view = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _action() -> BodyRefiningActionData:
	return ZoneManager.get_action_by_id(ACTION_ID) as BodyRefiningActionData

func _times_on_the_stack() -> int:
	return _main_view.state_stack.count(_state)

func _play() -> DrillPlay:
	return _view.get_node("%DrillPlay") as DrillPlay

## A BoardTransition for the MainView, its processing off so the test drives it,
## bound as MainView._ready() binds it, with the furniture where the zone view
## puts it.
func _give_main_view_a_player() -> BoardTransition:
	_main_view.dock.position = Vector2(722.0, 976.0)
	_main_view.dock.size = Vector2(476.0, 80.0)
	_main_view.goals_panel.position = Vector2(24.0, 640.0)
	_main_view.goals_panel.size = Vector2(440.0, 120.0)
	_main_view.log_window.position = Vector2(24.0, 940.0)
	_main_view.log_window.size = Vector2(440.0, 116.0)
	var player: BoardTransition = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	player.set_process(false)
	_main_view.board_transition = player
	_main_view._bind_board_transition()
	return player

func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event

func _press(down: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"drill_press"
	event.pressed = down
	return event

## The I key: a menu key, which the zone view would take but the board does not.
func _inventory_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_I
	event.pressed = true
	return event

func _node_index(scene_state: SceneState, path: String) -> int:
	for index: int in scene_state.get_node_count():
		if str(scene_state.get_node_path(index)).trim_prefix("./") == path:
			return index
	return -1

func _stored(scene_state: SceneState, node_index: int, property: StringName) -> Variant:
	for slot: int in scene_state.get_node_property_count(node_index):
		if scene_state.get_node_property_name(node_index, slot) == property:
			return scene_state.get_node_property_value(node_index, slot)
	return null

func _starts_visible(scene_state: SceneState, node_index: int) -> bool:
	var stored: Variant = _stored(scene_state, node_index, &"visible")
	if stored != null:
		return stored
	var instanced: PackedScene = scene_state.get_node_instance(node_index)
	if instanced != null:
		return _starts_visible(instanced.get_state(), 0)
	return true

#-----------------------------------------------------------------------------
# OPENING AND INPUT
#-----------------------------------------------------------------------------

func test_start_pushes_once() -> void:
	_state._on_start_body_refining(_action())
	_state._on_start_body_refining(_action())
	assert_eq(_times_on_the_stack(), 1)

func test_start_sets_the_board_up_for_the_action() -> void:
	_state._on_start_body_refining(_action())
	assert_true(_view.visible, "the board shows")
	assert_eq((_view.get_node("%ActionLabel") as Label).text, "Riverbank Training")
	assert_eq(_view.get_status_text(), BodyRefiningView.READY)
	assert_false(_main_view.dock.visible, "the dock is off")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "and the map takes no input")

## The chest, the Goals board and the log stay where they stand: the board leaves
## them as cycling's does.
func test_the_goals_board_and_the_log_stay() -> void:
	_state._on_start_body_refining(_action())
	assert_true(_main_view.goals_panel.visible, "Goals shows")
	assert_true(_main_view.log_window.visible, "and the log")

## The state in the tree, listening to ActionManager as main_game's does: Esc
## stops the action, and the stop closes the board.
func test_escape_stops_the_action() -> void:
	add_child(_state)
	ActionManager.select_action(_action())
	assert_eq(_times_on_the_stack(), 1, "precondition: the start pushed the board")
	_state.handle_input(_escape())
	assert_ne(ActionManager.get_current_action(), _action(), "Escape stops body refining")
	assert_eq(_times_on_the_stack(), 0, "the board's state leaves the stack")
	assert_false(_view.visible, "and the board hides")

func test_the_press_action_reaches_the_view() -> void:
	_state._on_start_body_refining(_action())
	_state.handle_input(_press())
	assert_true(_play().is_set_running(), "a drill press starts a set")

func test_other_keys_do_nothing() -> void:
	_state._on_start_body_refining(_action())
	_state.handle_input(_inventory_key())
	assert_false(_play().is_set_running(), "no set")
	assert_eq(_times_on_the_stack(), 1, "and the board stays")

func test_the_full_log_is_blocked_while_the_board_is_up() -> void:
	var log_window: LogWindow = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view.log_window = log_window
	_state._on_start_body_refining(_action())
	log_window.toggle_full_log()
	assert_false(log_window.is_full_log_open(), "the full log stays shut")
	_state._on_stop_body_refining()
	log_window.toggle_full_log()
	assert_true(log_window.is_full_log_open(), "and opens again once the board is gone")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

func test_stop_removes_only_itself() -> void:
	_main_view.state_stack = [_other] as Array[MainViewState]
	_state._on_start_body_refining(_action())
	_state._on_stop_body_refining()
	assert_eq(_main_view.state_stack, [_other] as Array[MainViewState], "the other view stays")
	assert_false(_view.visible, "the board hides")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "and the map takes input")

func test_stop_without_the_state_on_the_stack_changes_nothing() -> void:
	_main_view.state_stack = [_other] as Array[MainViewState]
	_state._on_stop_body_refining()
	assert_eq(_main_view.state_stack, [_other] as Array[MainViewState])

#-----------------------------------------------------------------------------
# THE STATE ON THE TRANSITION
#-----------------------------------------------------------------------------

## Start hands the player the board: the view, its board's rect, a spec that leaves
## the chest and the HUD boards alone, and the state as holder.
func test_start_opens_the_board_through_the_transition() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var rest: Rect2 = _view.get_board_rect()
	_state._on_start_body_refining(_action())
	var spec: BoardTransitionSpec = player.get_spec()
	assert_not_null(spec, "the player was handed the board")
	assert_same(spec.view, _view, "the body refining view")
	assert_eq(spec.board_rect, rest, "framed by the board's own rect")
	assert_false(spec.swaps_chest, "it leaves the chest")
	assert_false(spec.moves_hud_boards, "and the Goals board and the log")
	assert_same(spec.holder, _state, "the state holds it")
	assert_true(_main_view.is_board_moving(), "the board opens")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_true(_view.visible, "the board shows")
	assert_false(_main_view.dock.visible, "the dock is off the screen")
	assert_eq(_main_view.goals_panel.position.x, 24.0, "Goals stays")

func test_presses_while_opening_are_dropped() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.advance(0.1)
	assert_true(_main_view.is_board_moving(), "precondition: the board is still opening")
	_state.handle_input(_press())
	assert_false(_play().is_set_running(), "no set while it opens")
	player.finish()
	_state.handle_input(_press())
	assert_true(_play().is_set_running(), "a press starts one once it is open")

func test_escape_while_opening_stops_the_action() -> void:
	ActionManager.select_action(_action())
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.advance(0.1)
	_state.handle_input(_escape())
	assert_ne(ActionManager.get_current_action(), _action(), "Escape still stops it")

func test_the_state_stays_until_the_close_has_finished() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.finish()
	_state._on_stop_body_refining()
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_eq(_times_on_the_stack(), 1, "the state is still on the stack")
	assert_true(_view.visible, "and the board is still drawn")
	player.finish()
	assert_true(_main_view.state_stack.is_empty(), "the state is gone when the close ends")
	assert_false(_view.visible, "the board hides")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")

## The stop halts the set at once, the board staying drawn while it shrinks.
func test_a_stop_halts_the_set_while_the_board_stays_drawn() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.finish()
	_state.handle_input(_press())
	assert_true(_play().is_set_running(), "precondition: a set runs")
	_state._on_stop_body_refining()
	assert_false(_play().is_set_running(), "the set is dropped at the stop")
	assert_false(BodyRefiningManager.is_set_running(), "and its session ended")
	assert_true(_view.visible, "though the board is still drawn")
	player.finish()
	assert_false(_view.visible, "it hides when the close ends")

func test_a_start_while_closing_reverses_and_keeps_the_state() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.finish()
	_state._on_stop_body_refining()
	player.advance(0.1)
	assert_true(_main_view.is_board_closing(), "precondition: the board is part-way through its close")
	_state._on_start_body_refining(_action())
	assert_eq(_times_on_the_stack(), 1, "the state is on the stack once")
	assert_false(_main_view.is_board_closing(), "the board opens again")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_true(_view.visible, "the board shows")
	_state.handle_input(_press())
	assert_true(_play().is_set_running(), "and a set can start")

## The action that resumed when body refining stopped runs on: Esc while the
## board closes must not stop it.
func test_input_while_closing_is_dropped() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	player.finish()
	_state._on_stop_body_refining()
	var resumed: ZoneActionData = ZoneManager.get_action_by_id(RESUMED_ACTION_ID)
	ActionManager.select_action(resumed)
	_state.handle_input(_escape())
	assert_eq(ActionManager.get_current_action(), resumed, "Escape stops nothing while the board closes")
	_state.handle_input(_press())
	assert_false(_play().is_set_running(), "and a press starts no set")

func test_the_state_keeps_one_spec() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_body_refining(_action())
	var first: BoardTransitionSpec = player.get_spec()
	player.finish()
	_state._on_stop_body_refining()
	player.finish()
	_state._on_start_body_refining(_action())
	assert_same(player.get_spec(), first, "the same object for the next run")

#-----------------------------------------------------------------------------
# THE MAIN SCENE
#-----------------------------------------------------------------------------

## MainView finds the board and its state by unique name and path. The board
## stands after the Tribulation board and before BoardTransition, so the click
## shield covers it while it moves, and before the dev panel, which stays above
## it. It starts hidden.
func test_main_game_holds_the_board_and_its_state() -> void:
	var scene_state: SceneState = (load(MAIN_GAME_SCENE_PATH) as PackedScene).get_state()
	var view_index: int = _node_index(scene_state, "MainView/BodyRefiningView")
	var state_index: int = _node_index(scene_state, "MainView/MainViewStateMachine/BodyRefiningViewState")
	assert_ne(view_index, -1, "main_game.tscn has a BodyRefiningView under MainView")
	assert_ne(state_index, -1, "and a BodyRefiningViewState under the state machine")
	if view_index == -1 or state_index == -1:
		return
	assert_eq(scene_state.get_node_instance(view_index).resource_path, VIEW_SCENE_PATH, "the board is the view's scene")
	assert_eq(_stored(scene_state, view_index, &"unique_name_in_owner"), true, "MainView finds the board by its unique name")
	assert_false(_starts_visible(scene_state, view_index), "the board starts hidden")
	assert_eq(_stored(scene_state, view_index, &"z_index"), 3, "at z 3, with the other overlays")
	var script: Script = _stored(scene_state, state_index, &"script") as Script
	assert_not_null(script, "the state has a script")
	if script != null:
		assert_eq(script.resource_path, STATE_SCRIPT_PATH, "the state runs its script")
	assert_eq(_stored(scene_state, state_index, &"unique_name_in_owner"), true, "MainView finds the state by its unique name")
	assert_lt(_node_index(scene_state, "MainView/TribulationView"), view_index, "the board stands after the Tribulation board")
	assert_lt(view_index, _node_index(scene_state, "MainView/BoardTransition"), "and before BoardTransition, whose shield covers it")
