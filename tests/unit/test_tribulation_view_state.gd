extends GutTest

## Unit tests for how TribulationViewState opens and closes the Tribulation board on
## MainView's state stack. A start sets the board up for the zone and pushes the state
## once; entering hides the log and the Goals board, the dock and the map's input, blocks
## the full log and shows the board. Escape turns the trial down from the intro and does
## nothing once the run has begun; the trial's keys go to the board. A stop closes the
## board whatever it was doing (a run stopped from outside applies nothing), gives the zone
## view back and removes only the state.
## On a MainView with no transition the open and the close are instant, and the tests above
## the transition section read that. Given a real BoardTransition, driven by advance() and
## finish(), the board opens and closes as an animation: the state hands the player its
## board, stays on the stack until the close has played out, halts the run at the stop, drops
## the trial's keys while the board opens (Escape still turns the trial down) and every key
## while it closes, and lets a start while it closes reverse the close.
## The MainView is never added to the tree: each test fills in the views it needs, as
## test_merchant_view_state.gd does, with the real board on a test clock and plain stand-ins
## for the rest, and calls the state's handlers instead of emitting ActionManager's signals,
## since the state never enters the tree to connect them. Every test runs on a fresh save at
## level 100 on the real stages, with the original put back after it. main_game.tscn is only
## read, never instanced: its SaveTimer would write the real save.

const VIEW_SCENE_PATH: String = "res://scenes/tribulation/tribulation_view.tscn"
const STATE_SCRIPT_PATH: String = "res://scenes/tribulation/tribulation_view_state.gd"
const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const LOG_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/log_window/log_window.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")

const TRIBULATION_ID: String = "spirit_valley_tribulation"
const ZONE_NAME: String = "Spirit Valley"

const Mode := TribulationView.Mode
const Stage := CultivationManager.AdvancementStage

## The board's clock when a run begins: _at(seconds) sets it to this plus `seconds`.
const START_USEC: int = 1_000_000

var _main_view: MainView = null
var _view: TribulationView = null
var _state: TribulationViewState = null
## Another overlay, which can sit above or below the board on the stack.
var _other: MainViewState = null
var _now_usec: int = START_USEC
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	var save := SaveGameData.new()
	save.core_density_level = 100.0
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	_now_usec = START_USEC
	_view = (load(VIEW_SCENE_PATH) as PackedScene).instantiate() as TribulationView
	add_child_autofree(_view)
	_view.clock_usec = func() -> int: return _now_usec
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.tribulation_view = _view
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())
	_main_view.dock = autofree(Control.new())
	_main_view.zone_map_viewport = autofree(SubViewport.new())
	_state = autofree(TribulationViewState.new())
	_state.scene_root = _main_view
	_other = autofree(MainViewState.new())

func after_each() -> void:
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the managers back to the original save resumes the idle action it
	# left off with: stop that one too, so no timer runs on into the next file.
	_stop_everything()
	_view = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Never leave an action running for the next test.
func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## The Spirit Valley action, as the card and ActionManager hand it to the state.
func _action() -> TribulationActionData:
	return ZoneManager.get_action_by_id(TRIBULATION_ID) as TribulationActionData

func _set_stack(states: Array[MainViewState]) -> void:
	_main_view.state_stack = states

## A BoardTransition for the MainView, built from its scene with its processing off so the
## test drives it with advance() and finish() alone, and bound as MainView._ready() binds it.
## Goals and the log stand where the zone view puts them, so the player has something to move.
func _give_main_view_a_player() -> BoardTransition:
	_main_view.dock.position = Vector2(722.0, 976.0)
	_main_view.dock.size = Vector2(476.0, 80.0)
	_main_view.goals_panel.position = Vector2(24.0, 24.0)
	_main_view.goals_panel.size = Vector2(408.0, 360.0)
	_main_view.log_window.position = Vector2(24.0, 640.0)
	_main_view.log_window.size = Vector2(520.0, 416.0)
	var player: BoardTransition = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	player.set_process(false)
	_main_view.board_transition = player
	_main_view._bind_board_transition()
	return player

## How many times the state stands on MainView's stack.
func _times_on_the_stack() -> int:
	return _main_view.state_stack.count(_state)

## Sets the board's clock to `seconds` into the run and runs one frame.
func _at(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)
	_view._process(0.0)

## A pressed Escape, as ui_cancel reaches the game.
func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event

## The trial's input as an action (`down`), or its release.
func _press(down: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"tribulation_press"
	event.pressed = down
	return event

## The Space key, as the input map binds the trial's press to it.
func _space() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event

## The I key: a menu key, which the zone view would take but the board does not.
func _inventory_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_I
	event.pressed = true
	return event

## The index of the node at `path` (from the scene's root, without "./") in a scene's own
## tree, or -1.
func _node_index(scene_state: SceneState, path: String) -> int:
	for index: int in scene_state.get_node_count():
		if str(scene_state.get_node_path(index)).trim_prefix("./") == path:
			return index
	return -1

## The value a scene stores for a node's property, or null when it stores none.
func _stored(scene_state: SceneState, node_index: int, property: StringName) -> Variant:
	for slot: int in scene_state.get_node_property_count(node_index):
		if scene_state.get_node_property_name(node_index, slot) == property:
			return scene_state.get_node_property_value(node_index, slot)
	return null

## Whether a scene's node starts visible: the value the scene stores for it, else the value
## the scene it instances stores for its root (an editor save drops an override that only
## repeats that), else a CanvasItem's default.
func _starts_visible(scene_state: SceneState, node_index: int) -> bool:
	var stored: Variant = _stored(scene_state, node_index, &"visible")
	if stored != null:
		return stored
	var instanced: PackedScene = scene_state.get_node_instance(node_index)
	if instanced != null:
		return _starts_visible(instanced.get_state(), 0)
	return true

#-----------------------------------------------------------------------------
# OPENING
#-----------------------------------------------------------------------------

func test_start_pushes_once() -> void:
	_state._on_start_tribulation(_action())
	_state._on_start_tribulation(_action())
	assert_eq(_main_view.state_stack.size(), 1, "a second entry would stay on the stack after the board closes")
	assert_same(_main_view.state_stack.back(), _state)
	assert_true(_view.visible, "the board shows")
	assert_false(_main_view.log_window.visible, "the log hides")
	assert_false(_main_view.goals_panel.visible, "Goals hides")
	assert_false(_main_view.dock.visible, "the dock hides")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input")

func test_start_opens_the_intro_for_the_zone() -> void:
	_state._on_start_tribulation(_action())
	assert_eq(_view.get_mode(), Mode.INTRO, "the board opens on its intro")
	assert_eq((_view.get_node("%ActionLabel") as Label).text, ZONE_NAME, "headed by the zone the player stands in")
	assert_eq((_view.get_node("%TitleLabel") as Label).text, "The Tribulation", "and the trial's own title")

func test_start_while_open_keeps_one_finished_connection() -> void:
	_state._on_start_tribulation(_action())
	_state._on_start_tribulation(_action())
	assert_eq(_view.finished.get_connections().size(), 1, "one connection, however often the trial starts")

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func test_escape_on_the_intro_cancels() -> void:
	_state._on_start_tribulation(_action())
	watch_signals(_view)
	_state.handle_input(_escape())
	assert_signal_emitted_with_parameters(_view, "finished", [false])

func test_escape_during_the_run_does_nothing() -> void:
	_state._on_start_tribulation(_action())
	_view.begin()
	watch_signals(_view)
	_state.handle_input(_escape())
	assert_eq(_view.get_mode(), Mode.RUNNING, "a run once begun has no way out")
	assert_signal_not_emitted(_view, "finished")

## Only Continue closes the result: Escape, like the press, leaves it up.
func test_escape_on_the_result_does_nothing() -> void:
	_state._on_start_tribulation(_action())
	_view.begin()
	_at(_view.get_run().get_beat_times()[3] + 0.15)
	assert_eq(_view.get_mode(), Mode.RESULT, "precondition: the fourth crack ended the trial")
	watch_signals(_view)
	_state.handle_input(_escape())
	assert_eq(_view.get_mode(), Mode.RESULT, "the result stays up")
	assert_signal_not_emitted(_view, "finished")

func test_space_reaches_the_view() -> void:
	_state._on_start_tribulation(_action())
	_state.handle_input(_space())
	assert_eq(_view.get_mode(), Mode.RUNNING, "Space on the intro begins the run")

func test_the_press_action_reaches_the_view() -> void:
	_state._on_start_tribulation(_action())
	_state.handle_input(_press())
	assert_eq(_view.get_mode(), Mode.RUNNING, "a tribulation_press on the intro begins the run")

## The menu keys do nothing, as with every overlay that is the top state, and they do
## not begin the trial either.
func test_other_keys_leave_the_intro_alone() -> void:
	_state._on_start_tribulation(_action())
	watch_signals(_view)
	_state.handle_input(_inventory_key())
	assert_eq(_view.get_mode(), Mode.INTRO, "the I key does not begin the run")
	assert_signal_not_emitted(_view, "finished")
	assert_eq(_main_view.state_stack.size(), 1, "and opens nothing over the board")

#-----------------------------------------------------------------------------
# THE FULL LOG
#-----------------------------------------------------------------------------

## The board closes a full log that is open and blocks it, so that Escape reaches the
## intro, and lifts the block when it closes. The board also hides the log, which is why
## the log is shown again by hand in the middle: it is the block that keeps it shut then.
func test_the_full_log_is_closed_and_blocked_while_the_board_is_up() -> void:
	var log_window: LogWindow = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view.log_window = log_window
	log_window.toggle_full_log()
	assert_true(log_window.is_full_log_open(), "precondition: the full log is open")
	_state._on_start_tribulation(_action())
	assert_false(log_window.is_full_log_open(), "entering closes it")
	log_window.visible = true
	log_window.toggle_full_log()
	assert_false(log_window.is_full_log_open(), "and it stays shut, whatever shows the log")
	_state._on_stop_tribulation()
	assert_true(log_window.visible, "precondition: the log is back")
	log_window.toggle_full_log()
	assert_true(log_window.is_full_log_open(), "leaving lets it open again")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

func test_stop_restores_and_removes_only_itself() -> void:
	_set_stack([_other])
	_state._on_start_tribulation(_action())
	assert_eq(_main_view.state_stack.size(), 2, "precondition: the board sits on the other view")
	_state._on_stop_tribulation()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other, "the view underneath is left alone")
	assert_false(_view.visible, "the board hides")
	assert_true(_main_view.log_window.visible, "the log is back")
	assert_true(_main_view.goals_panel.visible, "Goals is back")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input again")

## remove_state, not pop_state: a view opened over the board stays open.
func test_stop_under_another_view_removes_only_itself() -> void:
	_state._on_start_tribulation(_action())
	_main_view.push_state(_other)
	assert_same(_main_view.state_stack.front(), _state, "precondition: the board sits under the other view")
	_state._on_stop_tribulation()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other, "the view above the board stays open")

func test_stop_without_the_state_on_the_stack_changes_nothing() -> void:
	_set_stack([_other])
	_state._on_stop_tribulation()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other, "another view is never popped in its place")

## Review Focus 3: the action stopped from outside mid-trial (a save reset, the dev panel)
## closes the board and applies nothing.
func test_stop_mid_run_applies_nothing() -> void:
	_state._on_start_tribulation(_action())
	_view.begin()
	_at(3.0)
	assert_eq(_view.get_mode(), Mode.RUNNING, "precondition: the run is under way")
	_state._on_stop_tribulation()
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "no level was lost")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and no breakthrough happened")
	assert_eq(_view.get_mode(), Mode.CLOSED, "the board is closed")
	assert_null(_view.get_run(), "and the run dropped")

#-----------------------------------------------------------------------------
# THE STATE ON THE TRANSITION
#-----------------------------------------------------------------------------

## Start hands the player the Tribulation board: the view, its board's rect, a spec that
## leaves the chest and moves the HUD boards, and the state as holder. The full log is shut
## from the start.
func test_start_opens_the_board_through_the_transition() -> void:
	var log_window: LogWindow = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view.log_window = log_window
	var player: BoardTransition = _give_main_view_a_player()
	var rest: Rect2 = _view.get_board_rect()
	_state._on_start_tribulation(_action())
	var spec: BoardTransitionSpec = player.get_spec()
	assert_not_null(spec, "the player was handed the board")
	assert_same(spec.view, _view, "the Tribulation view")
	assert_eq(spec.board_rect, rest, "framed by the board's own rect")
	assert_false(spec.swaps_chest, "it leaves the chest")
	assert_true(spec.moves_hud_boards, "it moves the Goals board and the log")
	assert_same(spec.holder, _state, "the state holds it")
	assert_eq(_times_on_the_stack(), 1, "the state is on the stack")
	assert_true(_main_view.is_board_moving(), "the board opens")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input from the start")
	log_window.toggle_full_log()
	assert_false(log_window.is_full_log_open(), "the full log is shut from the start")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_true(_view.visible, "the board shows")
	assert_false(_main_view.dock.visible, "the dock is off the screen")

## The player slides the HUD boards and the state hides nothing, so the player alone gives
## them back at their rest, visible throughout.
func test_the_hud_boards_are_back_after_the_close() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.finish()
	assert_lt(_main_view.goals_panel.position.x, 0.0, "precondition: Goals stepped off the screen")
	assert_lt(_main_view.log_window.position.x, 0.0, "precondition: and so did the log")
	assert_true(_main_view.goals_panel.visible, "the player moves Goals, it never hides it")
	assert_true(_main_view.log_window.visible, "nor the log")
	_state._on_stop_tribulation()
	player.finish()
	assert_eq(_main_view.goals_panel.position.x, 24.0, "Goals is at its rest x")
	assert_eq(_main_view.log_window.position.x, 24.0, "and so is the log")
	assert_true(_main_view.goals_panel.visible, "Goals shows")
	assert_true(_main_view.log_window.visible, "and the log shows")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")

## Space on the intro begins the run, but not while the board opens (the shield keeps the
## clicks off the board as well).
func test_space_while_opening_does_not_begin_the_run() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.advance(0.1)
	assert_true(_main_view.is_board_moving(), "precondition: the board is still opening")
	_state.handle_input(_press())
	_state.handle_input(_space())
	assert_eq(_view.get_mode(), Mode.INTRO, "the view stays on its intro")
	player.finish()
	_state.handle_input(_space())
	assert_eq(_view.get_mode(), Mode.RUNNING, "and Space begins the run once the board is open")

## Escape still turns the trial down while the board opens.
func test_escape_while_opening_turns_the_trial_down() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.advance(0.1)
	watch_signals(_view)
	_state.handle_input(_escape())
	assert_signal_emitted_with_parameters(_view, "finished", [false])

## The state leaves MainView's stack only when the close has played out: until then it stays
## on top, with the full log shut and the board drawn.
func test_the_state_stays_until_the_close_has_finished() -> void:
	var log_window: LogWindow = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view.log_window = log_window
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.finish()
	_state._on_stop_tribulation()
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_eq(_times_on_the_stack(), 1, "the state is still on the stack")
	assert_true(_view.visible, "and the board is still drawn")
	log_window.toggle_full_log()
	assert_false(log_window.is_full_log_open(), "the full log is still shut")
	player.advance(0.1)
	assert_eq(_times_on_the_stack(), 1, "and part-way through")
	player.finish()
	assert_true(_main_view.state_stack.is_empty(), "the state is gone when the close ends")
	assert_false(_main_view.is_board_moving(), "the board is closed")
	assert_false(_view.visible, "the board hides")
	assert_eq(_view.get_mode(), Mode.CLOSED, "and is closed")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")
	log_window.toggle_full_log()
	assert_true(log_window.is_full_log_open(), "the full log can open again")

## The stop halts the run at once, the board staying drawn while it shrinks: nothing of a
## run is applied after the stop, though a close takes time.
func test_a_stop_halts_the_run_while_the_board_stays_drawn() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.finish()
	_state.handle_input(_space())
	assert_eq(_view.get_mode(), Mode.RUNNING, "precondition: the run is under way")
	var late: float = _view.get_run().get_beat_times()[3] + 0.15
	_state._on_stop_tribulation()
	assert_eq(_view.get_mode(), Mode.CLOSED, "the view is closed at the stop")
	assert_null(_view.get_run(), "and the run dropped")
	assert_true(_view.visible, "though the board is still drawn")
	player.advance(0.1)
	_at(late)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "no level was lost, however late the clock goes")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and no breakthrough happened")
	player.finish()
	assert_false(_view.visible, "the board hides when the close ends")

## Starting again while the board closes turns the close around, and keeps the state on the
## stack once.
func test_a_start_while_closing_reverses_and_keeps_the_state() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.finish()
	_state._on_stop_tribulation()
	player.advance(0.1)
	assert_true(_main_view.is_board_closing(), "precondition: the board is part-way through its close")
	_state._on_start_tribulation(_action())
	assert_eq(_times_on_the_stack(), 1, "the state is on the stack once")
	assert_false(_main_view.is_board_closing(), "the board opens again")
	assert_eq(_view.get_mode(), Mode.INTRO, "on a fresh intro")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_eq(_times_on_the_stack(), 1, "the state stayed")
	assert_true(_view.visible, "the board shows")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map stays off")
	_state.handle_input(_space())
	assert_eq(_view.get_mode(), Mode.RUNNING, "and the trial can begin")

## One spec for every run of the state: a later start hands the player the very object it
## first got.
func test_the_state_keeps_one_spec() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	var first: BoardTransitionSpec = player.get_spec()
	player.finish()
	_state._on_stop_tribulation()
	player.finish()
	_state._on_start_tribulation(_action())
	assert_same(player.get_spec(), first, "the same object for the next run")

## The board moves while it scales, and so does its rect: a reversal must not read it again,
## or the player would scale about a point that is moving.
func test_a_reversal_leaves_the_boards_rect_alone() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var rest: Rect2 = _view.get_board_rect()
	_state._on_start_tribulation(_action())
	player.finish()
	_state._on_stop_tribulation()
	player.advance(0.2)
	assert_ne(_view.get_board_rect(), rest, "precondition: the closing board's rect has moved")
	_state._on_start_tribulation(_action())
	assert_eq(player.get_spec().board_rect, rest, "the spec still frames the board at rest")

## Nothing is handled while the board closes. The view is put back on its intro by hand, as a
## start the state did not see would leave it, so that Escape and Space have something to do.
func test_input_while_closing_is_dropped() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_state._on_start_tribulation(_action())
	player.finish()
	_state._on_stop_tribulation()
	_view.setup(_action().tribulation, ZONE_NAME)
	assert_true(_main_view.is_board_closing(), "precondition: the board closes")
	watch_signals(_view)
	_state.handle_input(_escape())
	_state.handle_input(_space())
	_state.handle_input(_inventory_key())
	assert_signal_not_emitted(_view, "finished", "Escape turns nothing down")
	assert_eq(_view.get_mode(), Mode.INTRO, "and Space begins nothing")
	assert_eq(_times_on_the_stack(), 1, "the stack is as it was")

## A stop reaches every state that listens, and the player closes whichever board is up: a
## stop while the state is not on the stack must not close another one.
func test_a_stop_with_no_tribulation_board_up_leaves_another_board_alone() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var other := BoardTransitionSpec.new()
	other.view = autofree(Control.new())
	other.view.visible = false
	other.board_rect = Rect2(680.0, 24.0, 564.0, 1036.0)
	_main_view.open_board(other)
	player.finish()
	_state._on_stop_tribulation()
	assert_false(_main_view.is_board_closing(), "the other board stays up")
	assert_same(player.get_spec(), other)

#-----------------------------------------------------------------------------
# MAIN_GAME.TSCN
#-----------------------------------------------------------------------------

## MainView finds the board and its state by unique name and path. A scene that lost one
## would break the zone view at start-up, so the scene is read for them, never instanced.
## The board stands after CyclingView and before DevPanel, so it takes the click before the
## overlays ahead of it do, and the dev panel stays above it for input. It starts hidden,
## whether main_game.tscn stores that or leaves it to the board's own scene, as an editor
## save does.
func test_main_game_holds_the_board_and_its_state() -> void:
	var scene_state: SceneState = (load(MAIN_GAME_SCENE_PATH) as PackedScene).get_state()
	var view_index: int = _node_index(scene_state, "MainView/TribulationView")
	var state_index: int = _node_index(scene_state, "MainView/MainViewStateMachine/TribulationViewState")
	assert_ne(view_index, -1, "main_game.tscn has a TribulationView under MainView")
	assert_ne(state_index, -1, "and a TribulationViewState under the state machine")
	if view_index == -1 or state_index == -1:
		return
	assert_eq(scene_state.get_node_instance(view_index).resource_path, VIEW_SCENE_PATH, "the board is the Tribulation view's scene")
	assert_eq(_stored(scene_state, view_index, &"unique_name_in_owner"), true, "MainView finds the board by its unique name")
	assert_false(_starts_visible(scene_state, view_index), "the board starts hidden")
	assert_eq(_stored(scene_state, view_index, &"z_index"), 3, "at z 3, with the other overlays")
	var script: Script = _stored(scene_state, state_index, &"script") as Script
	assert_not_null(script, "the state has a script")
	if script != null:
		assert_eq(script.resource_path, STATE_SCRIPT_PATH, "the state runs its script")
	assert_eq(_stored(scene_state, state_index, &"unique_name_in_owner"), true, "MainView finds the state by its unique name")
	var cycling_index: int = _node_index(scene_state, "MainView/CyclingView")
	var dev_panel_index: int = _node_index(scene_state, "MainView/DevPanel")
	assert_lt(cycling_index, view_index, "the board stands after CyclingView")
	assert_lt(view_index, dev_panel_index, "and before the dev panel, which stays above it")
