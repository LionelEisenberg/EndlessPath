extends GutTest

## Unit tests for the zone view's board mode on the main view (spec: Behaviour ›
## Opening and closing; Implementation notes › MainView and CyclingViewState).
## MainView.open_board(spec) and close_board(spec, on_closed) open and close a
## board that stands in the map gap, through BoardTransition when MainView has
## one and instantly when it has none. Instantly, the zone view's furniture is
## turned over to the board: the chest lists the techniques (a board that swaps
## it), the dock and the chest's About hide, the map's SubViewport takes no input,
## the log and Goals hide (a board that moves them) and the board's view shows;
## the close undoes all of it in reverse and calls back once. With the transition,
## the map's input and About go off at once, About before the transition measures
## the chest, and come back, before the callback, when the close ends.
## CyclingViewState opens its board with open_board() and closes it with
## close_board(), and stays on MainView's stack until the close has finished. It
## blocks the full log, as a menu book does, and leaves the Goals and log boards
## where the zone view put them. set_board_mode() is the part of the instant switch
## the Tribulation board shares (the dock, the map and the chest's About, not the
## techniques).
## The MainView is never added to the tree: each test fills in the views it
## needs, as test_view_state_hud_positions.gd does, with the real chest and the
## real log (the techniques mode and the full-log block can only be read there)
## and plain stand-ins for the rest. main_game.tscn is only instanced, never
## added to the tree: its SaveTimer would write the real save.

const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const ZONE_PANEL_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/zone_panel.tscn")
const LOG_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/log_window/log_window.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")
const CYCLING_VIEW_SCENE: PackedScene = preload("res://scenes/cycling/cycling_view/cycling_view.tscn")

## The cycling board's rectangle, as the transition frames it.
const BOARD_RECT: Rect2 = Rect2(680, 24, 564, 1036)

const CYCLING_ACTION_ID: String = "wilderness_cycling_action"
const SMOOTH_FLOW_ID: String = "smooth_flow"

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Counts the events its viewport hands it, as the map's tile layer reads a
## press in _input.
class InputCounter:
	extends Node

	var count: int = 0

	func _input(_event: InputEvent) -> void:
		count += 1

var _main_view: MainView = null
var _state: CyclingViewState = null
var _log: LogWindow = null
## How many times a close's callback was called.
var _closed_calls: int = 0

## A zone view's worth of furniture on a MainView that never enters the tree:
## the real chest and log, plain Controls for the dock, the board, Goals, and a
## bare SubViewport for the map. The board starts hidden, as in main_game.tscn.
func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_log = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.zone_panel = add_child_autofree(ZONE_PANEL_SCENE.instantiate())
	_main_view.dock = autofree(Control.new())
	_main_view.zone_map_viewport = autofree(SubViewport.new())
	_main_view.cycling_view = autofree(Control.new())
	_main_view.cycling_view.visible = false
	_main_view.goals_panel = autofree(Control.new())
	_main_view.log_window = _log
	_state = autofree(CyclingViewState.new())
	_state.scene_root = _main_view
	_closed_calls = 0

## The Esc tests start the cycling action, and a cycle session or a last result
## left behind would leak into later files.
func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	# The transition reads the chest's techniques height, which rebuilds the
	# hidden technique list: its old drawers leave the tree and are freed at the
	# end of the frame. Let it pass before GUT counts orphans.
	await wait_process_frames(1)

func _on_closed() -> void:
	_closed_calls += 1

## The cycling board: it swaps the chest and leaves the log and Goals where they are.
func _cycling_spec() -> BoardTransitionSpec:
	var spec := BoardTransitionSpec.new()
	spec.view = _main_view.cycling_view
	spec.board_rect = BOARD_RECT
	spec.swaps_chest = true
	spec.holder = _state
	return spec

## The Tribulation board: it leaves the chest and hides the log and Goals.
func _tribulation_spec() -> BoardTransitionSpec:
	var spec := BoardTransitionSpec.new()
	spec.view = autofree(Control.new())
	spec.view.visible = false
	spec.board_rect = BOARD_RECT
	spec.moves_hud_boards = true
	spec.holder = _state
	return spec

## A BoardTransition for the MainView, built from its scene with its processing
## off so the test drives it with advance() and finish() alone. Nothing is bound
## to it, so it moves no piece of the zone view: these tests read what MainView
## does around it.
func _give_main_view_a_player() -> BoardTransition:
	var player: BoardTransition = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	player.set_process(false)
	_main_view.board_transition = player
	return player

## The same player, handed the dock, the chest and the HUD boards the way
## MainView._ready() hands them, so it moves the test's stand-ins.
func _give_main_view_a_bound_player() -> BoardTransition:
	var player: BoardTransition = _give_main_view_a_player()
	_main_view._bind_board_transition()
	return player

## The real cycling board in the tree, hidden as in main_game.tscn, in place of the
## plain Control the fixture stands in. Its technique is left to the test's steps.
func _use_the_real_cycling_view() -> CyclingView:
	CyclingManager.unlock_technique(SMOOTH_FLOW_ID)
	CyclingManager.equip_technique(SMOOTH_FLOW_ID)
	var board: CyclingView = CYCLING_VIEW_SCENE.instantiate() as CyclingView
	board.visible = false
	add_child_autofree(board)
	(board.get_node("%CyclingTechnique") as CyclingTechnique).set_process(false)
	_main_view.cycling_view = board
	return board

## A press of an input action, as the keys the project maps to it send.
func _action_press(action: StringName) -> InputEventAction:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	return press

## How many times the state stands on MainView's stack.
func _times_on_the_stack() -> int:
	return _main_view.state_stack.count(_state)

## A left press, as the SubViewportContainer pushes it into the map.
func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	press.global_position = press.position
	return press

## The chest's About, which Spirit Valley's lore shows outside the board modes.
func _about() -> Control:
	return _main_view.zone_panel.get_node("%AboutButton") as Control

#-----------------------------------------------------------------------------
# THE INSTANT BOARD
#-----------------------------------------------------------------------------

func test_open_and_close_board_without_a_transition() -> void:
	var spec: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(spec)
	assert_true(_main_view.zone_panel.is_techniques_mode(), "the chest lists the techniques")
	assert_false(_main_view.dock.visible, "the dock hides")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input")
	assert_false(_about().visible, "About hides")
	assert_true(spec.view.visible, "the board shows")
	_main_view.close_board(spec, _on_closed)
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest lists the activities again")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input again")
	assert_true(_about().visible, "About is back")
	assert_false(spec.view.visible, "the board hides")
	assert_eq(_closed_calls, 1, "the callback was called once")

## Without a transition nothing moves: a board is never mid-way.
func test_a_main_view_without_a_transition_has_no_board_moving() -> void:
	var spec: BoardTransitionSpec = _cycling_spec()
	assert_false(_main_view.is_board_moving(), "nothing moves before the open")
	assert_false(_main_view.is_board_closing())
	_main_view.open_board(spec)
	assert_false(_main_view.is_board_moving(), "the instant open has no way to move")
	_main_view.close_board(spec, _on_closed)
	assert_false(_main_view.is_board_closing(), "nor the instant close")

## A board that moves the HUD boards (the Tribulation) hides the log and Goals while
## it is up, through its holder, and leaves the chest on the activities.
func test_the_instant_open_hides_the_hud_boards_for_a_board_that_moves_them() -> void:
	var spec: BoardTransitionSpec = _tribulation_spec()
	_main_view.open_board(spec)
	assert_false(_main_view.log_window.visible, "the log hides")
	assert_false(_main_view.goals_panel.visible, "Goals hides")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest keeps listing the activities")
	assert_false(_main_view.dock.visible, "the dock hides")
	assert_false(_about().visible, "About hides")
	assert_true(spec.view.visible, "the board shows")
	_main_view.close_board(spec, _on_closed)
	assert_true(_main_view.log_window.visible, "the log is back")
	assert_true(_main_view.goals_panel.visible, "Goals is back")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_true(_about().visible, "About is back")
	assert_false(spec.view.visible, "the board hides")
	assert_eq(_closed_calls, 1, "the callback was called once")

## A board that leaves the HUD boards (the cycling board) leaves the log and Goals as
## the zone view put them.
func test_the_instant_open_leaves_the_hud_boards_for_a_board_that_does_not_move_them() -> void:
	var spec: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(spec)
	assert_true(_main_view.log_window.visible, "the log stays")
	assert_true(_main_view.goals_panel.visible, "Goals stays")
	_main_view.close_board(spec, _on_closed)

## The view-state tests run boards on a MainView with none of the zone view's
## furniture, and each piece is switched whether or not the others exist.
func test_the_instant_open_hides_the_dock_when_the_chest_and_map_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.dock = _main_view.dock
	bare.open_board(_cycling_spec())
	assert_false(bare.dock.visible)

func test_the_instant_open_stops_the_map_when_the_chest_and_dock_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.zone_map_viewport = _main_view.zone_map_viewport
	bare.open_board(_cycling_spec())
	assert_true(bare.zone_map_viewport.gui_disable_input)

func test_the_instant_open_turns_the_chest_when_the_dock_and_map_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.zone_panel = _main_view.zone_panel
	bare.open_board(_cycling_spec())
	assert_true(bare.zone_panel.is_techniques_mode())

## A MainView with no furniture at all, a spec with no view and a close with no
## callback are each left alone.
func test_the_instant_open_and_close_skip_what_is_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	var spec: BoardTransitionSpec = _tribulation_spec()
	bare.open_board(spec)
	assert_true(spec.view.visible, "the board shows with nothing around it")
	bare.close_board(spec, Callable())
	var viewless: BoardTransitionSpec = _cycling_spec()
	viewless.view = null
	_main_view.open_board(viewless)
	_main_view.close_board(viewless, _on_closed)
	assert_engine_error_count(0, "a missing piece is skipped without a word")
	assert_eq(_closed_calls, 1)

## The Tribulation board stands in the same map gap but has no use for the techniques: the
## chest keeps listing the zone's activities and hides only About, and the dock and the
## map are turned off.
func test_board_mode_leaves_the_chest() -> void:
	_main_view.set_board_mode(true)
	assert_false(_main_view.dock.visible, "the dock hides")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest keeps listing the activities")
	assert_false(_about().visible, "About hides")
	_main_view.set_board_mode(false)
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input again")
	assert_true(_about().visible, "About is back")

## Each piece is switched whether or not the other exists, as on the MainViews the
## view-state tests build.
func test_board_mode_switches_the_pieces_that_exist() -> void:
	var dock_only: MainView = autofree(MainView.new())
	dock_only.dock = _main_view.dock
	dock_only.set_board_mode(true)
	assert_false(dock_only.dock.visible, "the dock hides when there is no map")
	var map_only: MainView = autofree(MainView.new())
	map_only.zone_map_viewport = _main_view.zone_map_viewport
	map_only.set_board_mode(true)
	assert_true(map_only.zone_map_viewport.gui_disable_input, "the map stops when there is no dock")
	var bare: MainView = autofree(MainView.new())
	bare.set_board_mode(true)
	bare.set_board_mode(false)
	assert_engine_error_count(0, "a MainView with no furniture is left alone")

## The switch leans on the engine: a SubViewportContainer pushes the press it
## gets into its SubViewport with push_input(), and a viewport with its input
## disabled drops what it is pushed. If this fails, switch the map off through
## the container's mouse_filter (IGNORE) instead, in open_board() and here.
func test_a_disabled_map_viewport_takes_no_clicks() -> void:
	var viewport: SubViewport = SubViewport.new()
	var counter: InputCounter = InputCounter.new()
	viewport.add_child(counter)
	add_child_autofree(viewport)
	viewport.gui_disable_input = true
	viewport.push_input(_left_press())
	assert_eq(counter.count, 0, "a viewport with its input off takes no press")
	viewport.gui_disable_input = false
	viewport.push_input(_left_press())
	assert_eq(counter.count, 1, "the same press reaches it once input is back on")

#-----------------------------------------------------------------------------
# THE BOARD WITH A TRANSITION
#-----------------------------------------------------------------------------

## The map goes off at once, before the player has moved a frame, and the board is
## handed to the player.
func test_open_board_with_a_transition_stops_the_map_and_starts_the_player() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var spec: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(spec)
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input at once")
	assert_false(_about().visible, "About hides at once")
	assert_same(player.get_spec(), spec, "the player was handed the board")
	assert_true(_main_view.is_board_moving(), "the board is opening")
	assert_false(_main_view.is_board_closing())
	assert_true(_main_view.dock.visible, "the dock is the player's to move, not MainView's")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest is the player's to swap, not MainView's")
	player.finish()
	assert_false(_main_view.is_board_moving(), "the board is open")

## The map and About stay off through the whole close, and come back, before the
## callback, at its end.
func test_close_board_with_a_transition_gives_the_map_back_when_it_ends() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var spec: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(spec)
	player.finish()
	_main_view.close_board(spec, _on_closed)
	assert_true(_main_view.is_board_closing(), "the board is closing")
	assert_true(_main_view.is_board_moving())
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map is still off while it closes")
	assert_false(_about().visible, "About is still hidden while it closes")
	assert_eq(_closed_calls, 0, "the callback waits for the end")
	player.advance(0.1)
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "and mid-way")
	assert_false(_about().visible, "About too")
	player.finish()
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input again at the end")
	assert_true(_about().visible, "About is back at the end")
	assert_eq(_closed_calls, 1, "the callback was called once")
	assert_false(_main_view.is_board_moving())

## Reversing a close only turns it around: the callback is dropped by the player,
## and the map stays off, since the board is coming back.
func test_opening_again_during_the_close_keeps_the_map_off() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var spec: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(spec)
	player.finish()
	_main_view.close_board(spec, _on_closed)
	player.advance(0.1)
	_main_view.open_board(spec)
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map is off again at once")
	assert_false(_main_view.is_board_closing(), "the board opens again")
	player.finish()
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the board is open: the map stays off")
	assert_eq(_closed_calls, 0, "the dropped close never calls back")

## Another board opening snaps the one that is up closed, whose callback gives the
## map its input and About back: the new board has to turn them off again.
func test_opening_another_board_keeps_the_map_off() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	var first: BoardTransitionSpec = _cycling_spec()
	_main_view.open_board(first)
	player.finish()
	_main_view.close_board(first, _on_closed)
	player.advance(0.1)
	assert_true(_main_view.is_board_closing(), "the first board is part-way through its close")
	var second: BoardTransitionSpec = _tribulation_spec()
	_main_view.open_board(second)
	assert_same(player.get_spec(), second, "the second board is up")
	assert_eq(_closed_calls, 1, "the first board's close was called back")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map is off for the second board")
	assert_false(_about().visible, "About is hidden for the second board")

## An open lore pushes the chest's list down. It closes as the board opens, so
## the chest steps from its height without the lore to the techniques' height.
func test_the_lore_closes_as_the_board_opens() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	var lore: Control = _main_view.zone_panel.get_node("%LorePanel") as Control
	(_about() as BaseButton).button_pressed = true
	assert_true(lore.visible, "precondition: the lore is open")
	var height_with_lore: float = _main_view.zone_panel.chest_height_for(false)
	_main_view.open_board(_cycling_spec())
	assert_false(lore.visible, "the lore closes as the board opens")
	var height_without_lore: float = _main_view.zone_panel.chest_height_for(false)
	assert_lt(height_without_lore, height_with_lore, "precondition: the lore made the chest taller")
	player.advance(0.42)
	var techniques_height: float = _main_view.zone_panel.chest_height_for(true)
	var expected: float = BoardTransitionTiming.chest_height(420.0, height_without_lore, techniques_height)
	assert_eq(_main_view.zone_panel.size.y, expected, "mid-way, the chest steps from its height without the lore")

## With nothing up the player calls back at once, and the map is given back.
func test_closing_with_nothing_up_gives_the_map_back_at_once() -> void:
	_give_main_view_a_player()
	_main_view.zone_map_viewport.gui_disable_input = true
	_main_view.close_board(_cycling_spec(), _on_closed)
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")
	assert_eq(_closed_calls, 1, "the callback was called")

## MainView._ready() hands the player the dock, the chest and the HUD boards (the
## Goals board first, then the log): the player steps them in that order.
func test_the_transition_is_bound_to_the_dock_the_chest_and_the_hud_boards() -> void:
	var player: BoardTransition = _give_main_view_a_player()
	_main_view.log_window = autofree(Control.new())
	_main_view.dock.position = Vector2(722.0, 976.0)
	_main_view.dock.size = Vector2(476.0, 80.0)
	_main_view.goals_panel.position = Vector2(24.0, 24.0)
	_main_view.goals_panel.size = Vector2(408.0, 360.0)
	_main_view.log_window.position = Vector2(24.0, 640.0)
	_main_view.log_window.size = Vector2(520.0, 416.0)
	_main_view._bind_board_transition()
	_main_view.open_board(_tribulation_spec())
	player.advance(0.16)
	assert_almost_eq(_main_view.goals_panel.position.x, 24.0 - 432.0, 0.01, "Goals is the first board: off the screen at 160 ms")
	assert_gt(_main_view.log_window.position.x, 24.0 - 544.0, "the log is the second: still on its way")
	assert_lt(_main_view.log_window.position.x, 24.0, "the log has begun to move")
	player.finish()
	assert_false(_main_view.dock.visible, "the dock is off the screen")

#-----------------------------------------------------------------------------
# THE STATE
#-----------------------------------------------------------------------------

## Without a transition the state turns the zone view over at once on start and
## gives it back at once on stop.
func test_cycling_state_turns_the_zone_view_over_and_back() -> void:
	_state._on_start_cycling(null)
	assert_true(_main_view.zone_panel.is_techniques_mode(), "entering lists the techniques")
	assert_false(_main_view.dock.visible, "entering hides the dock")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "entering stops the map")
	_state._on_stop_cycling()
	assert_false(_main_view.zone_panel.is_techniques_mode(), "leaving lists the activities")
	assert_true(_main_view.dock.visible, "leaving brings the dock back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "leaving gives the map its input back")

func test_cycling_state_keeps_the_boards() -> void:
	_state._on_start_cycling(null)
	assert_true(_main_view.goals_panel.visible, "Goals stays where the zone view put it")
	assert_true(_main_view.log_window.visible, "the log stays")
	assert_true(_main_view.cycling_view.visible, "the board shows")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "the full log stays shut while cycling")
	_state._on_stop_cycling()
	assert_true(_main_view.goals_panel.visible, "Goals still shows")
	assert_true(_main_view.log_window.visible, "the log still shows")
	assert_false(_main_view.cycling_view.visible, "the board hides")
	_log.toggle_full_log()
	assert_true(_log.is_full_log_open(), "the full log opens again")

## The board is the close's to hide: exit() only lets the full log open again.
func test_exit_only_lifts_the_full_log_block() -> void:
	_state.enter()
	_state.exit()
	assert_true(_main_view.cycling_view.visible, "the board is still up: closing it is close_board()'s")
	assert_true(_main_view.zone_panel.is_techniques_mode(), "and so is the chest")
	_log.toggle_full_log()
	assert_true(_log.is_full_log_open(), "the full log opens again")

func test_start_cycling_twice_pushes_once() -> void:
	_state._on_start_cycling(null)
	_state._on_start_cycling(null)
	assert_eq(_main_view.state_stack.size(), 1, "a second push would stay on the stack after the close")
	assert_same(_main_view.state_stack.back(), _state)

func test_stop_cycling_undoes_start_cycling() -> void:
	_state._on_start_cycling(null)
	_state._on_stop_cycling()
	assert_true(_main_view.state_stack.is_empty(), "the state left the stack")
	assert_false(_main_view.cycling_view.visible, "the board is hidden")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest lists the activities")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")

#-----------------------------------------------------------------------------
# THE STATE ON THE TRANSITION
#-----------------------------------------------------------------------------

## Start hands the player the cycling board: the view, a spec that swaps the chest
## and leaves the HUD boards, and the state as holder. The full log is shut from
## the start.
func test_start_opens_the_board_through_the_transition() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	var spec: BoardTransitionSpec = player.get_spec()
	assert_not_null(spec, "the player was handed the board")
	assert_same(spec.view, _main_view.cycling_view, "the cycling view")
	assert_true(spec.swaps_chest, "it swaps the chest")
	assert_false(spec.moves_hud_boards, "it leaves the Goals board and the log")
	assert_same(spec.holder, _state, "the state holds it")
	assert_eq(_times_on_the_stack(), 1, "the state is on the stack")
	assert_true(_main_view.is_board_moving(), "the board opens")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "the full log is shut from the start")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_true(_main_view.cycling_view.visible, "the board shows")
	assert_true(_main_view.zone_panel.is_techniques_mode(), "the chest lists the techniques")
	assert_false(_main_view.dock.visible, "the dock is off the screen")

## A CyclingView frames its own board; a stand-in is framed by its own rectangle.
func test_the_spec_frames_the_cycling_board() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	var board: CyclingView = _use_the_real_cycling_view()
	var rest: Rect2 = board.get_board_rect()
	assert_gt(rest.size.x, 0.0, "precondition: the board has a size")
	_state._on_start_cycling(null)
	assert_eq(player.get_spec().board_rect, rest, "the board's rect, read before the view moved")

func test_the_spec_frames_a_plain_view_by_its_own_rectangle() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_main_view.cycling_view.position = Vector2(40.0, 60.0)
	_main_view.cycling_view.size = Vector2(300.0, 500.0)
	_state._on_start_cycling(null)
	assert_eq(player.get_spec().board_rect, Rect2(40.0, 60.0, 300.0, 500.0))

## The state leaves MainView's stack only when the close has played out: until
## then it stays on top, with the full log shut.
func test_the_state_stays_until_the_close_has_finished() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	player.finish()
	_state._on_stop_cycling()
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_eq(_times_on_the_stack(), 1, "the state is still on the stack")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "the full log is still shut")
	player.advance(0.1)
	assert_eq(_times_on_the_stack(), 1, "and part-way through")
	player.finish()
	assert_true(_main_view.state_stack.is_empty(), "the state is gone when the close ends")
	assert_false(_main_view.is_board_moving(), "the board is closed")
	assert_false(_main_view.cycling_view.visible, "the board hides")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest lists the activities")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")
	_log.toggle_full_log()
	assert_true(_log.is_full_log_open(), "the full log can open again")

## Starting again while the board closes turns the close around, and keeps the
## state on the stack once.
func test_a_start_while_closing_reverses_and_keeps_the_state() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	player.finish()
	_state._on_stop_cycling()
	player.advance(0.1)
	assert_true(_main_view.is_board_closing(), "precondition: the board is part-way through its close")
	_state._on_start_cycling(null)
	assert_eq(_times_on_the_stack(), 1, "the state is on the stack once")
	assert_false(_main_view.is_board_closing(), "the board opens again")
	player.finish()
	assert_true(player.is_open(), "the board is open")
	assert_eq(_times_on_the_stack(), 1, "the state stayed")
	assert_true(_main_view.cycling_view.visible, "the board shows")
	assert_true(_main_view.zone_panel.is_techniques_mode(), "the chest lists the techniques")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map stays off")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "the full log is still shut")

## One spec for every run of the state: a later start hands the player the very
## object it first got.
func test_the_state_keeps_one_spec() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	var first: BoardTransitionSpec = player.get_spec()
	player.finish()
	_state._on_stop_cycling()
	player.finish()
	_state._on_start_cycling(null)
	assert_same(player.get_spec(), first, "the same object for the next run")

## The real board moves while it scales, and so does its rect: a reversal must
## not read it again, or the player would scale about a point that is moving.
func test_a_reversal_leaves_the_boards_rect_alone() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	var board: CyclingView = _use_the_real_cycling_view()
	var rest: Rect2 = board.get_board_rect()
	_state._on_start_cycling(null)
	player.finish()
	_state._on_stop_cycling()
	player.advance(0.2)
	assert_ne(board.get_board_rect(), rest, "precondition: the closing board's rect has moved")
	_state._on_start_cycling(null)
	assert_eq(player.get_spec().board_rect, rest, "the spec still frames the board at rest")

## Esc closes the board by stopping the action, as it did. The state listens to
## ActionManager as it does in the game, so the stop reaches it.
func test_esc_while_the_board_is_open_stops_the_action_and_closes_the_board() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._ready()
	var cycling: ZoneActionData = ZoneManager.get_action_by_id(CYCLING_ACTION_ID)
	ActionManager.select_action(cycling)
	assert_eq(_times_on_the_stack(), 1, "precondition: the action's start pushed the state")
	player.finish()
	_state.handle_input(_action_press(&"close_cycling_view"))
	assert_ne(ActionManager.get_current_action(), cycling, "cycling no longer runs")
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_eq(_times_on_the_stack(), 1, "the state waits for the close to end")
	player.finish()
	assert_true(_main_view.state_stack.is_empty(), "and leaves when it has")

## Esc during the close would stop the action that resumed when cycling stopped.
func test_esc_while_closing_does_nothing() -> void:
	var cycling: ZoneActionData = ZoneManager.get_action_by_id(CYCLING_ACTION_ID)
	ActionManager.select_action(cycling)
	assert_eq(ActionManager.get_current_action(), cycling, "precondition: cycling runs")
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	player.finish()
	_state._on_stop_cycling()
	assert_true(_main_view.is_board_closing(), "precondition: the board closes")
	watch_signals(ActionManager)
	_state.handle_input(_action_press(&"close_cycling_view"))
	assert_signal_not_emitted(ActionManager, "stop_cycling")
	assert_eq(ActionManager.get_current_action(), cycling, "the current action is left alone")

## Esc while the board opens closes it again, from where it is.
func test_esc_while_the_board_opens_turns_it_around() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._ready()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ACTION_ID))
	player.advance(0.1)
	assert_true(_main_view.is_board_moving(), "precondition: the board is still opening")
	assert_false(_main_view.is_board_closing(), "precondition: it opens")
	_state.handle_input(_action_press(&"close_cycling_view"))
	assert_true(_main_view.is_board_closing(), "the board turns around")
	player.finish()
	assert_true(_main_view.state_stack.is_empty(), "and the state leaves when it has closed")

## The menu keys belong to the zone view under the board: the state ignores
## them, so none opens a book over a board that is closing.
func test_menu_keys_during_the_close_are_dropped() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	_state._on_start_cycling(null)
	player.finish()
	_state._on_stop_cycling()
	assert_eq(_main_view.state_stack.size(), 1, "precondition: the state is the whole stack")
	_state.handle_input(_action_press(&"open_inventory"))
	assert_eq(_main_view.state_stack.size(), 1, "the stack is as it was")
	assert_same(_main_view.state_stack.back(), _state)

## A stop reaches every state that listens, and the player closes whichever board
## is up: a stop with no cycling board up must not close another one.
func test_a_stop_with_no_cycling_board_up_leaves_another_board_alone() -> void:
	var player: BoardTransition = _give_main_view_a_bound_player()
	var other: BoardTransitionSpec = _tribulation_spec()
	_main_view.open_board(other)
	player.finish()
	_state._on_stop_cycling()
	assert_false(_main_view.is_board_closing(), "the other board stays up")
	assert_same(player.get_spec(), other)

#-----------------------------------------------------------------------------
# THE CABINET HAND-OFF
#-----------------------------------------------------------------------------

## MainView._ready() hands the cultivator cabinet to the board through this
## helper. Without it the board has no cabinet, and no Madra or XP pellet ever
## flies. The cabinet and the board are script-only instances that never enter
## the tree, so neither runs its _ready().
func test_the_cabinet_is_handed_to_the_cycling_view() -> void:
	var cabinet: CultivatorPlate = autofree(CultivatorPlate.new())
	var board: CyclingView = autofree(CyclingView.new())
	_main_view.cultivator_plate = cabinet
	_main_view.cycling_view = board
	_main_view._hand_cabinet_to_cycling_view()
	assert_same(board.cultivator_plate, cabinet, "the board's pellets fly into the cabinet")

## The view-state tests stand a plain Control in for the board (the fixture's
## cycling_view is one): it has nowhere to keep a cabinet, so it is skipped.
func test_handing_over_the_cabinet_skips_a_plain_control() -> void:
	_main_view.cultivator_plate = autofree(CultivatorPlate.new())
	_main_view._hand_cabinet_to_cycling_view()
	assert_engine_error_count(0, "a view that is not a CyclingView is left alone, not cast and assigned to")

#-----------------------------------------------------------------------------
# MAIN_GAME.TSCN
#-----------------------------------------------------------------------------

## MainView finds the cabinet, the chest, the dock, the map's viewport, the
## zone map and ZoneTransition by unique name, and the board transition too. open_board() skips a
## missing piece without a word, so a scene that lost a name would quietly stop
## turning that piece over. The transition's shield must come after the boards
## among MainView's children, to catch the clicks on them while it moves (Godot
## picks GUI input by tree order), and before the dev panel, which stays above it.
func test_main_game_names_the_zone_furniture_for_main_view() -> void:
	var game: Node = autofree((load(MAIN_GAME_SCENE_PATH) as PackedScene).instantiate())
	var main_view: Node = game.get_node("MainView")
	var zone_view: Node = main_view.get_node("%ZoneView")
	assert_same(main_view.get_node_or_null("%CultivatorPlate"), zone_view.get_node("CultivatorPlate"), "the cabinet")
	assert_same(main_view.get_node_or_null("%ZonePanel"), zone_view.get_node("ZonePanel"), "the chest")
	assert_same(main_view.get_node_or_null("%Dock"), zone_view.get_node("Dock"), "the dock")
	assert_same(main_view.get_node_or_null("%SubViewport"), zone_view.get_node("SubViewportContainer/SubViewport"), "the map's viewport")
	assert_same(main_view.get_node_or_null("%ZoneTilemap"), zone_view.get_node("SubViewportContainer/SubViewport/ZoneTilemap"), "the zone map")
	assert_same(main_view.get_node_or_null("%ZoneTransition"), zone_view.get_node("ZoneTransition"), "the adventure entry, whose way back the push settles")
	var transition: Node = main_view.get_node_or_null("%BoardTransition")
	assert_true(transition is BoardTransition, "the board transition")
	assert_same(transition.get_parent(), main_view, "the transition is a child of MainView")
	assert_gt(transition.get_index(), main_view.get_node("%TribulationView").get_index(), "the shield is after the boards")
	assert_gt(transition.get_index(), main_view.get_node("%CyclingView").get_index(), "and after the cycling board")
	assert_lt(transition.get_index(), main_view.get_node("%DevPanel").get_index(), "and before the dev panel")

## The map's markers place themselves from the camera in their _process(), and
## the zone map hit-tests the pointer there when the camera has moved. The
## player moves the camera in its own _process(), after both in tree order, so
## it must come first by priority, or the plates trail the push by a frame.
func test_the_player_moves_the_camera_before_the_map_reads_it() -> void:
	var game: Node = autofree((load(MAIN_GAME_SCENE_PATH) as PackedScene).instantiate())
	var main_view: Node = game.get_node("MainView")
	var transition: Node = main_view.get_node("%BoardTransition")
	var zone_map: Node = main_view.get_node("%ZoneTilemap")
	assert_lt(transition.process_priority, zone_map.get_node("%MapMarkers").process_priority, "before the markers place themselves")
	assert_lt(transition.process_priority, zone_map.process_priority, "and before the map hit-tests the pointer")
