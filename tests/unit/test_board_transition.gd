extends GutTest

## Unit tests for BoardTransition, the reversible player that opens and closes a
## board in the zone view's map gap from one progress value (design: "Behaviour
## rules"): the shield that takes the mouse while it moves, the close callbacks
## and the opened and closed signals, the zone chest swapping to its techniques
## (cycling) and the HUD boards stepping off the left edge (Tribulation), and the
## camera, the dock, the chest and the boards back at rest after a close, played
## back from wherever a reversal finds them.
## The player is built from its scene with its processing off and driven by
## advance() and finish() alone, never by frames. It is bound to plain Controls
## for the dock, the Goals board, the log and the board's view, the real zone
## chest (its modes, rows and height can only be read there), a Camera2D that
## never enters the tree (the push only sets its zoom and position) and a Node2D
## cultivator. The chest is built on a fresh save with every cycling technique
## unlocked, so its technique list has three drawers.

const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")
const ZONE_PANEL_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/zone_panel.tscn")

## The cycling board's rectangle, which puts the cultivator at screen (962, 612):
## the board's horizontal centre, 70 px under its vertical centre.
const BOARD_RECT: Rect2 = Rect2(680, 24, 564, 1036)
const CULTIVATOR_SCREEN: Vector2 = Vector2(962, 612)

## The zone map's camera as the player left it, and the cultivator in the world.
const START_ZOOM: Vector2 = Vector2(2, 2)
const START_CAMERA_POSITION: Vector2 = Vector2(500, 300)
const CULTIVATOR_WORLD: Vector2 = Vector2(640, 420)

## The dock where main_game.tscn puts it, and the Goals board and the log where
## the zone view puts them.
const DOCK_REST: Vector2 = Vector2(722, 976)
const DOCK_SIZE: Vector2 = Vector2(476, 80)
const GOALS_REST: Vector2 = Vector2(24, 24)
const GOALS_SIZE: Vector2 = Vector2(408, 360)
const LOG_REST: Vector2 = Vector2(24, 640)
const LOG_SIZE: Vector2 = Vector2(520, 416)

## The cycling techniques after the first, unlocked so the chest has three drawers.
const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"

const NEAR: float = 0.001

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _transition: BoardTransition = null
var _dock: Control = null
var _goals: Control = null
var _log: Control = null
var _view: Control = null
var _chest: ZonePanel = null
var _camera: Camera2D = null
var _cultivator: Node2D = null
var _spec: BoardTransitionSpec = null
## How many times the close's callback was called.
var _calls: int = 0

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	CyclingManager.unlock_technique(SMOOTH_ID)
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	_dock = _add_control(DOCK_REST, DOCK_SIZE)
	_goals = _add_control(GOALS_REST, GOALS_SIZE)
	_log = _add_control(LOG_REST, LOG_SIZE)
	_view = _add_control(Vector2.ZERO, ZoneMapMath.VIEWPORT_SIZE)
	_view.visible = false
	_chest = add_child_autofree(ZONE_PANEL_SCENE.instantiate()) as ZonePanel
	_camera = autofree(Camera2D.new())
	_camera.zoom = START_ZOOM
	_camera.position = START_CAMERA_POSITION
	_cultivator = add_child_autofree(Node2D.new()) as Node2D
	_cultivator.position = CULTIVATOR_WORLD
	_transition = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	_transition.set_process(false)
	_transition.bind(_dock, _chest, [_goals, _log], _camera, _cultivator)
	_spec = _cycling_spec()
	_calls = 0
	# The chest's containers lay its rows out over the next frames.
	await wait_process_frames(2)

func after_each() -> void:
	# Reading the techniques' height rebuilds the chest's hidden technique list,
	# which takes its old drawers out of the tree and frees them at the end of
	# the frame: let it pass before GUT counts orphans.
	await wait_process_frames(1)

func _add_control(at: Vector2, size: Vector2) -> Control:
	var control: Control = add_child_autofree(Control.new()) as Control
	control.position = at
	control.size = size
	return control

## The cycling board: it swaps the chest's rows and leaves the HUD boards.
func _cycling_spec() -> BoardTransitionSpec:
	var spec := BoardTransitionSpec.new()
	spec.view = _view
	spec.board_rect = BOARD_RECT
	spec.swaps_chest = true
	return spec

## The Tribulation board: it leaves the chest and moves the HUD boards.
func _tribulation_spec() -> BoardTransitionSpec:
	var spec := BoardTransitionSpec.new()
	spec.view = _view
	spec.board_rect = BOARD_RECT
	spec.moves_hud_boards = true
	return spec

## Where the transition is on the open's timeline, in ms.
func _t() -> float:
	return _transition.get_progress() * BoardTransitionTiming.duration_ms(_spec.swaps_chest)

func _on_closed() -> void:
	_calls += 1

## The rows' x positions, in order.
func _xs(rows: Array[Control]) -> Array[float]:
	var xs: Array[float] = []
	for row: Control in rows:
		xs.append(row.position.x)
	return xs

#-----------------------------------------------------------------------------
# THE SHIELD AND THE CAMERA
#-----------------------------------------------------------------------------

func test_the_shield_blocks_the_mouse_only_while_moving() -> void:
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_IGNORE, "closed")
	_transition.open(_spec)
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_STOP, "from the moment it opens")
	_transition.advance(0.1)
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_STOP, "while opening")
	_transition.finish()
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_IGNORE, "open: the board takes its own input")
	_transition.close()
	_transition.advance(0.1)
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_STOP, "while closing")
	_transition.finish()
	assert_eq(_transition.mouse_filter, Control.MOUSE_FILTER_IGNORE, "closed again")

func test_the_camera_is_restored_exactly() -> void:
	_transition.open(_spec)
	_transition.finish()
	_transition.close()
	_transition.finish()
	assert_eq(_camera.zoom, START_ZOOM, "the player's zoom")
	assert_eq(_camera.position, START_CAMERA_POSITION, "where the player left it")

#-----------------------------------------------------------------------------
# REVERSAL
#-----------------------------------------------------------------------------

func test_a_reversal_mid_open_restores_everything() -> void:
	var chest_height: float = _chest.size.y
	var rows: Array[Control] = _chest.get_slide_rows()
	var rest: Array[float] = _xs(rows)
	_transition.open(_spec)
	_transition.advance(0.3)
	_transition.close(_on_closed)
	assert_true(_transition.is_closing(), "it turned around")
	_transition.finish()
	assert_false(_view.visible, "the board is hidden")
	assert_eq(_view.scale, Vector2.ONE, "at full size for the next open")
	assert_eq(_view.pivot_offset, Vector2.ZERO)
	assert_eq(_camera.zoom, START_ZOOM, "the camera's zoom")
	assert_eq(_camera.position, START_CAMERA_POSITION, "and position")
	assert_true(_dock.visible, "the dock")
	assert_eq(_dock.position.y, DOCK_REST.y)
	assert_false(_chest.is_techniques_mode(), "the chest lists the activities")
	assert_eq(_chest.size.y, chest_height, "at its height")
	assert_eq(_xs(_chest.get_slide_rows()), rest, "every row at rest")
	assert_eq(_calls, 1, "the callback, once")
	assert_false(_transition.is_moving())
	assert_eq(_transition.get_progress(), 0.0)

func test_reopening_mid_close_drops_the_callback() -> void:
	_transition.open(_spec)
	_transition.finish()
	_transition.close(_on_closed)
	_transition.advance(0.1)
	_transition.open(_spec)
	assert_false(_transition.is_closing(), "it turned around")
	assert_true(_transition.is_moving())
	_transition.finish()
	assert_eq(_calls, 0, "the close never ended, so its callback is not called")
	assert_true(_transition.is_open())
	assert_true(_view.visible)
	assert_eq(_view.scale, Vector2.ONE)

func test_close_when_closed_calls_back_at_once() -> void:
	_transition.close(_on_closed)
	assert_eq(_calls, 1)
	assert_false(_transition.is_moving())

## A second close replaces the first one's callback: only the last is called.
func test_a_second_close_replaces_the_callback() -> void:
	var first_calls: Array[int] = [0]
	_transition.open(_spec)
	_transition.advance(0.1)
	_transition.close(func() -> void: first_calls[0] += 1)
	_transition.close(_on_closed)
	_transition.finish()
	assert_eq(first_calls[0], 0, "the first callback was replaced")
	assert_eq(_calls, 1)

func test_opening_while_open_or_opening_does_nothing() -> void:
	watch_signals(_transition)
	_transition.open(_spec)
	_transition.advance(0.1)
	var progress: float = _transition.get_progress()
	_transition.open(_spec)
	assert_eq(_transition.get_progress(), progress, "it keeps going from where it is")
	_transition.finish()
	_transition.open(_spec)
	assert_true(_transition.is_open())
	assert_false(_transition.is_moving())
	assert_signal_emit_count(_transition, "opened", 1)

## Another board's open while one is up snaps the first one closed, its callback
## called, before the new one opens.
func test_opening_another_board_snaps_the_first_closed() -> void:
	var other_view: Control = _add_control(Vector2.ZERO, ZoneMapMath.VIEWPORT_SIZE)
	other_view.visible = false
	var other: BoardTransitionSpec = _tribulation_spec()
	other.view = other_view
	_transition.open(_spec)
	_transition.advance(0.4)
	_transition.close(_on_closed)
	_transition.advance(0.02)
	_transition.open(other)
	assert_eq(_calls, 1, "the first board's callback")
	assert_false(_view.visible, "the first board is hidden")
	assert_eq(_view.scale, Vector2.ONE)
	assert_false(_chest.is_techniques_mode(), "the chest lists the activities")
	assert_same(_transition.get_spec(), other)
	assert_true(_transition.is_moving(), "the new board opens")
	assert_eq(_transition.get_progress(), 0.0, "from the start")
	_transition.finish()
	assert_true(other_view.visible)
	assert_true(_transition.is_open())

#-----------------------------------------------------------------------------
# THE CHEST
#-----------------------------------------------------------------------------

func test_the_chest_swaps_at_the_swap_point_both_ways() -> void:
	_transition.open(_spec)
	_transition.advance(0.299)
	assert_almost_eq(_t(), 299.0, NEAR, "precondition: t 299")
	assert_false(_chest.is_techniques_mode(), "the activities until the swap")
	_transition.advance(0.002)
	assert_true(_chest.is_techniques_mode(), "the techniques from the swap")
	_transition.close()
	_transition.advance(0.002)
	assert_almost_eq(_t(), 299.0, NEAR, "precondition: back to t 299")
	assert_false(_chest.is_techniques_mode(), "back below the swap, the activities again")

## The plain way a row goes is a rebuild of the chest's list; this frees one row
## by hand, so the player holds one freed row among live ones.
func test_a_row_freed_mid_slide_is_skipped() -> void:
	var rows: Array[Control] = _chest.get_slide_rows()
	var rest: Array[float] = _xs(rows)
	assert_eq(rows.size(), 3, "precondition: the header, a group's label row and its card")
	_transition.open(_spec)
	_transition.advance(0.1)
	rows[1].free()
	_transition.finish()
	assert_engine_error_count(0, "the freed row is skipped")
	assert_eq(rows[0].position.x, rest[0], "the header is at rest")
	assert_eq(rows[2].position.x, rest[2], "and the card")

## A rebuild of the activity list mid-slide (an action completed, an unlock)
## frees the rows the player slides and builds new ones at rest.
func test_a_list_rebuilt_mid_slide_ends_at_rest() -> void:
	var rest: Array[float] = _xs(_chest.get_slide_rows())
	_transition.open(_spec)
	_transition.advance(0.1)
	var list: ActivityList = _chest.get_node("%ActivityList") as ActivityList
	list.build(ZoneManager.get_available_actions(ZoneManager.get_current_zone().zone_id), true)
	# The old rows are freed at the end of the frame, and the new ones sort.
	await wait_process_frames(2)
	_transition.finish()
	_transition.close()
	_transition.finish()
	assert_engine_error_count(0, "the freed rows are skipped")
	assert_eq(_xs(_chest.get_slide_rows()), rest, "every row at rest")

#-----------------------------------------------------------------------------
# THE HUD BOARDS
#-----------------------------------------------------------------------------

func test_hud_boards_step_off_left_and_back() -> void:
	_spec = _tribulation_spec()
	var chest_rows: Array[Control] = _chest.get_slide_rows()
	var chest_rest: Array[float] = _xs(chest_rows)
	_transition.open(_spec)
	_transition.finish()
	assert_lte(_goals.global_position.x + _goals.size.x, 0.0, "the Goals board is off the left edge")
	assert_lte(_log.global_position.x + _log.size.x, 0.0, "and the log")
	assert_false(_chest.is_techniques_mode(), "the chest keeps its activities")
	assert_eq(_xs(chest_rows), chest_rest, "and its rows stay put")
	_transition.close()
	_transition.finish()
	assert_eq(_goals.position.x, GOALS_REST.x, "the Goals board is back")
	assert_eq(_log.position.x, LOG_REST.x, "and the log")

## The cycling board leaves the HUD boards where they are.
func test_a_board_that_keeps_the_hud_boards_leaves_them() -> void:
	_transition.open(_spec)
	_transition.advance(0.1)
	assert_eq(_goals.position, GOALS_REST)
	assert_eq(_log.position, LOG_REST)

#-----------------------------------------------------------------------------
# TIME AND MISSING PIECES
#-----------------------------------------------------------------------------

func test_a_long_hitch_finishes_in_one_step() -> void:
	watch_signals(_transition)
	_transition.open(_spec)
	_transition.advance(5.0)
	assert_eq(_transition.get_progress(), 1.0)
	assert_true(_transition.is_open())
	assert_signal_emit_count(_transition, "opened", 1)
	_transition.close(_on_closed)
	_transition.advance(5.0)
	assert_eq(_transition.get_progress(), 0.0)
	assert_false(_transition.is_moving())
	assert_eq(_calls, 1)
	assert_signal_emit_count(_transition, "closed", 1)

func test_missing_pieces_are_skipped() -> void:
	_transition.bind(null, null, [], null, null)
	_spec.moves_hud_boards = true
	_transition.open(_spec)
	_transition.advance(0.1)
	_transition.finish()
	assert_true(_view.visible, "the board it has opens")
	_transition.close(_on_closed)
	_transition.advance(0.1)
	_transition.finish()
	assert_engine_error_count(0, "every missing piece is skipped")
	assert_false(_view.visible, "and closes")
	assert_eq(_calls, 1)
	assert_eq(_camera.zoom, START_ZOOM, "an unbound camera is left alone")
	assert_eq(_dock.position, DOCK_REST, "and an unbound dock")

## The view-state tests stand Controls that never enter the tree in for the
## dock, the HUD boards and the view: their own positions stand for their places
## on the screen.
func test_pieces_outside_the_tree_still_play() -> void:
	var dock: Control = autofree(Control.new())
	dock.position = DOCK_REST
	var goals: Control = autofree(Control.new())
	goals.position = GOALS_REST
	goals.size = GOALS_SIZE
	var view: Control = autofree(Control.new())
	var cultivator: Node2D = autofree(Node2D.new())
	cultivator.position = CULTIVATOR_WORLD
	_transition.bind(dock, null, [goals], _camera, cultivator)
	_spec = _tribulation_spec()
	_spec.view = view
	_transition.open(_spec)
	_transition.finish()
	assert_eq(view.pivot_offset, CULTIVATOR_SCREEN, "the view's own position is its place")
	assert_false(dock.visible, "the dock steps off")
	assert_lte(goals.position.x + goals.size.x, 0.0, "the Goals board steps off")
	_transition.close(_on_closed)
	_transition.finish()
	assert_engine_error_count(0, "nothing asks for a place in the tree")
	assert_eq(dock.position, DOCK_REST)
	assert_eq(goals.position, GOALS_REST)
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_calls, 1)

func test_a_spec_with_no_view_still_plays() -> void:
	_spec.view = null
	_transition.open(_spec)
	_transition.finish()
	assert_true(_transition.is_open())
	_transition.close(_on_closed)
	_transition.finish()
	assert_engine_error_count(0)
	assert_eq(_calls, 1)
