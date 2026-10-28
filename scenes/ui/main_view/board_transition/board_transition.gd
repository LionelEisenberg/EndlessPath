class_name BoardTransition
extends Control

## BoardTransition
## Opens and closes a board in the zone view's map gap (the cycling board, the
## Tribulation board) as one reversible transition, described by the board's
## BoardTransitionSpec.
##
## Progress. The whole transition is one progress value, 0 (closed) to 1
## (open), and a direction: opening, open, closing or closed. advance() moves
## the progress in its direction at the rate that crosses the open's timeline
## (BoardTransitionTiming.duration_ms) in its length, clamped to 0..1, and draws
## every piece from it. _process() calls advance() while it moves; nothing else
## moves time, so tests drive it with advance() and finish().
##
## Reversal. A close while it opens, or an open while it closes, only turns the
## direction around: every piece plays back from where the progress is, and
## nothing jumps. The close plays the open's timeline backwards.
##
## The camera. The push saves the camera when a run starts and puts it back at
## the run's end, and nothing else may move the camera in between. So a run
## starts by calling the camera hold bind() is given with true, which ends
## every other camera move under way at its end (a zoom ease after a wheel
## tick, a glide to a zone, the way back from the adventure zoom) and keeps
## those movers still, and the push saves the camera where it comes to rest;
## the run's end calls the hold with false after the push has restored the
## camera.
##
## Each frame, at t = progress x duration (ms of the open's timeline), it applies:
## - the camera: the push on the cultivator (CameraPush) to camera_weight(t),
##   1.5 times the player's zoom with the cultivator under the board at 1;
## - the dock: stepped down dock_offset(t) toward the bottom of the screen, and
##   hidden once it is off it;
## - the board's view: hidden before the board's start, then scaled to
##   board_scale(t) about the point the camera brings the cultivator to;
## - the zone chest, for a board that swaps it (cycling): the activities mode
##   before CHEST_SWAP_MS and the techniques mode from it; the rows of the list
##   that shows slid right by their position.x (the activities stepping out, the
##   techniques stepping in); and the chest's frame held between the two modes'
##   heights from the swap to CHEST_END_MS;
## - the HUD boards (the Goals board, then the log), for a board that moves them
##   (the Tribulation): stepped off the left edge of the screen;
## - itself: a full-screen shield that takes every click while it moves, and
##   lets every click through while it rests.
##
## Rows. The chest's rows are taken, with the x each rests at, when a run
## starts, when a close starts from open, and at each mode switch. Their
## containers lay them out at the end of a frame whenever something asks (the
## switch builds the drawers and shows the other list), which puts a row back
## at its rest; so the player watches each container's sort_children, reads the
## rows' rest x again there and slides them back before the frame is drawn. A
## row freed meanwhile (a rebuild of the list) is skipped; rows that appear
## meanwhile stay at rest.
##
## Ends. At the open's end the view is at full size, the rows at rest and the
## chest at its own height, and opened is emitted. At the close's end every
## piece is back where open() found it (the camera exactly), the close's
## callback is called once, and closed is emitted. A missing piece (not bound,
## freed, or a spec without a view) is skipped; a piece outside the tree (the
## view-state tests' stand-ins) counts its own position as its place.

## Emitted when an open reaches its end: the board is at full size.
signal opened
## Emitted when a close reaches its end, after its callback: every piece is
## back where open() found it.
signal closed

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Where the transition stands. OPENING and CLOSING move; CLOSED has no board.
enum Phase { CLOSED, OPENING, OPEN, CLOSING }

## The pieces bind() hands it.
var _dock: Control = null
var _zone_panel: ZonePanel = null
var _hud_boards: Array[Control] = []
var _camera: Camera2D = null
var _cultivator: Node2D = null
## Called with true before the push saves the camera, with false after it
## restores it: see the class doc.
var _camera_hold: Callable = Callable()

## The board that is up or moving, or null while closed.
var _spec: BoardTransitionSpec = null
var _phase: Phase = Phase.CLOSED
var _progress: float = 0.0
## Called once when the close reaches its end.
var _on_closed: Callable = Callable()
var _camera_push: CameraPush = CameraPush.new()

## Where open() found the pieces, which the close puts them back to, and how
## far each has to go to leave the screen.
var _dock_rest_y: float = 0.0
var _dock_travel: float = 0.0
var _hud_rest_x: Array[float] = []
var _hud_travel: Array[float] = []
## The view's top-left on the screen at full size.
var _view_origin: Vector2 = Vector2.ZERO

## The chest's height in the activities mode and in the techniques mode.
var _activities_height: float = 0.0
var _techniques_height: float = 0.0
## True while the chest's frame is held to a height.
var _holds_height: bool = false
## The rows the chest slides and the x each rests at. A row may be freed while
## it is held, so it is read back as a Variant and checked first.
var _rows: Array[Control] = []
var _row_rest_x: Array[float] = []
## The containers that lay the rows out, and the callable each one's
## sort_children is connected to.
var _row_containers: Array[Container] = []
var _row_container_calls: Array[Callable] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_moving():
		advance(delta)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Hands it the pieces it moves: the dock, the zone chest, the HUD boards (the
## Goals board, then the log), the zone map's camera and the cultivator the
## camera pushes in on, and the camera hold, a callable taking a bool that
## holds the camera's other movers still (true) and lets them go (false). Any
## of them may be null or empty: a missing piece is skipped. Bind before the
## first open().
func bind(dock: Control, zone_panel: ZonePanel, hud_boards: Array[Control], camera: Camera2D, cultivator: Node2D, camera_hold: Callable = Callable()) -> void:
	_dock = dock
	_zone_panel = zone_panel
	_hud_boards = hud_boards
	_camera = camera
	_cultivator = cultivator
	_camera_hold = camera_hold

## Opens the board spec describes. From closed, it records where the dock and
## the HUD boards rest, begins the camera push on the cultivator, reads the
## chest's two heights, takes the chest's rows, and starts from progress 0.
## While that board closes, it turns around from where it is and drops the
## close's callback; while it opens or is open, it does nothing. If another
## board is up or moving, that board is first snapped closed: every piece put
## back and its callback called.
func open(spec: BoardTransitionSpec) -> void:
	if spec == null:
		Log.warn("BoardTransition: open() was given no spec")
		return
	if _spec != null and not _is_same_board(spec):
		_snap_closed()
	match _phase:
		Phase.CLOSED:
			_begin(spec)
		Phase.CLOSING:
			_phase = Phase.OPENING
			_on_closed = Callable()
			_apply()

## Closes the board that is up or moving, from where it is, and calls on_closed
## once the close has reached its end (a later close's callback replaces this
## one; an open before the end drops it). When nothing is up, calls on_closed
## at once.
func close(on_closed: Callable = Callable()) -> void:
	if _phase == Phase.CLOSED:
		if on_closed.is_valid():
			on_closed.call()
		return
	var was_open: bool = _phase == Phase.OPEN
	_phase = Phase.CLOSING
	_on_closed = on_closed
	if _swaps_chest():
		_read_chest_heights()
		if was_open:
			_take_rows()
	_apply()

## Moves the progress delta seconds on in its direction, clamped to 0..1, and
## draws every piece from it; at the end of the way it finishes the open or
## the close. Does nothing while it rests.
func advance(delta: float) -> void:
	if not is_moving():
		return
	var step: float = delta * 1000.0 / BoardTransitionTiming.duration_ms(_spec.swaps_chest)
	if _phase == Phase.CLOSING:
		step = -step
	_progress = clampf(_progress + step, 0.0, 1.0)
	_apply()
	_end_if_reached()

## Jumps to the end of the current direction: open while it opens, closed
## while it closes. Does nothing while it rests.
func finish() -> void:
	if not is_moving():
		return
	_progress = 1.0 if _phase == Phase.OPENING else 0.0
	_apply()
	_end_if_reached()

## Returns true while it opens or closes.
func is_moving() -> bool:
	return _phase == Phase.OPENING or _phase == Phase.CLOSING

## Returns true while it closes.
func is_closing() -> bool:
	return _phase == Phase.CLOSING

## Returns true while a board is open and at rest.
func is_open() -> bool:
	return _phase == Phase.OPEN

## Returns the progress, from 0 (closed) to 1 (open).
func get_progress() -> float:
	return _progress

## Returns the spec of the board that is up or moving, or null while closed.
func get_spec() -> BoardTransitionSpec:
	return _spec

#-----------------------------------------------------------------------------
# RUNS
#-----------------------------------------------------------------------------

## True when spec describes the board that is up: the same spec, or another
## spec for the same view.
func _is_same_board(spec: BoardTransitionSpec) -> bool:
	return spec == _spec or (spec.view != null and spec.view == _spec.view)

## Starts an open from closed.
func _begin(spec: BoardTransitionSpec) -> void:
	_spec = spec
	_phase = Phase.OPENING
	_progress = 0.0
	_on_closed = Callable()
	_record_rests()
	_begin_camera_push()
	if _swaps_chest():
		_read_chest_heights()
		_take_rows()
	_apply()

## Puts the board that is up or moving straight back to closed, as if its
## close had played to its end: every piece back, its callback called.
func _snap_closed() -> void:
	_phase = Phase.CLOSING
	_progress = 0.0
	_apply()
	_end_close()

## Ends the open or the close once the progress has reached its end.
func _end_if_reached() -> void:
	if _phase == Phase.OPENING and _progress >= 1.0:
		_end_open()
	elif _phase == Phase.CLOSING and _progress <= 0.0:
		_end_close()

## The open's end: the view at full size, the rows at rest and the chest at its
## own height.
func _end_open() -> void:
	_phase = Phase.OPEN
	if is_instance_valid(_spec.view):
		_spec.view.scale = Vector2.ONE
	_restore_rows()
	_let_go_of_rows()
	_release_height()
	_apply_shield()
	opened.emit()

## The close's end: every piece back where open() found it, the camera exactly,
## then the callback once, then closed.
func _end_close() -> void:
	if is_instance_valid(_spec.view):
		_spec.view.visible = false
		_spec.view.scale = Vector2.ONE
		_spec.view.pivot_offset = Vector2.ZERO
	if is_instance_valid(_dock):
		_dock.position.y = _dock_rest_y
		_dock.visible = true
	if _spec.moves_hud_boards:
		_restore_hud_boards()
	_restore_rows()
	_let_go_of_rows()
	_release_height()
	var was_pushed: bool = _camera_push.is_active()
	_camera_push.restore()
	if was_pushed and _camera_hold.is_valid():
		_camera_hold.call(false)
	_spec = null
	_phase = Phase.CLOSED
	_progress = 0.0
	_apply_shield()
	var on_closed: Callable = _on_closed
	_on_closed = Callable()
	if on_closed.is_valid():
		on_closed.call()
	closed.emit()

## Records where the dock, the HUD boards and the view rest, and how far the
## dock and the HUD boards go to leave the screen.
func _record_rests() -> void:
	if is_instance_valid(_dock):
		_dock_rest_y = _dock.position.y
		_dock_travel = ZoneMapMath.VIEWPORT_SIZE.y - _screen_position(_dock).y
	_hud_rest_x.clear()
	_hud_travel.clear()
	for index: int in _hud_boards.size():
		var board: Variant = _hud_boards[index]
		var is_there: bool = is_instance_valid(board)
		_hud_rest_x.append((board as Control).position.x if is_there else 0.0)
		_hud_travel.append(_screen_position(board as Control).x + (board as Control).size.x if is_there else 0.0)
	if is_instance_valid(_spec.view):
		# The close leaves the view at full size, so this is its top-left then.
		_view_origin = _screen_position(_spec.view)

## Holds the camera's other movers still, then saves the camera where it has
## come to rest and aims the push so the cultivator ends under the board, at
## 1.5 times the zoom the player had. Skipped without a camera or a cultivator.
func _begin_camera_push() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_cultivator):
		return
	if _camera_hold.is_valid():
		_camera_hold.call(true)
	var cultivator_world: Vector2 = _cultivator.global_position if _cultivator.is_inside_tree() else _cultivator.position
	var end_zoom: float = _camera.zoom.x * BoardTransitionTiming.CAMERA_ZOOM_FACTOR
	_camera_push.begin(_camera, cultivator_world, BoardTransitionTiming.cultivator_target(_spec.board_rect), end_zoom)

## A Control's top-left on the screen: its global position in the tree, or its
## own position outside it.
func _screen_position(control: Control) -> Vector2:
	return control.global_position if control.is_inside_tree() else control.position

#-----------------------------------------------------------------------------
# EACH FRAME
#-----------------------------------------------------------------------------

## The open's timeline position of the progress, in ms.
func _current_ms() -> float:
	return _progress * BoardTransitionTiming.duration_ms(_spec.swaps_chest)

## Draws every piece at the progress.
func _apply() -> void:
	var t: float = _current_ms()
	_camera_push.apply(BoardTransitionTiming.camera_weight(t))
	_apply_dock(t)
	_apply_view(t)
	if _swaps_chest():
		_apply_chest(t)
	if _spec.moves_hud_boards:
		_apply_hud_boards(t)
	_apply_shield()

## Steps the dock down toward the bottom of the screen, and hides it once it
## is off it.
func _apply_dock(t: float) -> void:
	if not is_instance_valid(_dock):
		return
	var offset: float = BoardTransitionTiming.dock_offset(t, _dock_travel)
	_dock.position.y = _dock_rest_y + offset
	_dock.visible = offset < _dock_travel

## Shows the view from the board's start and scales it about the point the
## camera brings the cultivator to. The pivot is worked out from the view's
## full-size top-left: its global position moves while it is scaled.
func _apply_view(t: float) -> void:
	if not is_instance_valid(_spec.view):
		return
	var view: Control = _spec.view
	view.visible = BoardTransitionTiming.is_board_shown(t)
	view.pivot_offset = BoardTransitionTiming.cultivator_target(_spec.board_rect) - _view_origin
	view.scale = Vector2.ONE * BoardTransitionTiming.board_scale(t)

## Steps each HUD board left off the screen, the Goals board first.
func _apply_hud_boards(t: float) -> void:
	for index: int in mini(_hud_boards.size(), _hud_rest_x.size()):
		var board: Variant = _hud_boards[index]
		if is_instance_valid(board):
			(board as Control).position.x = _hud_rest_x[index] - BoardTransitionTiming.hud_offset(t, index, _hud_travel[index])

## Puts each HUD board back at the x open() found it at.
func _restore_hud_boards() -> void:
	for index: int in mini(_hud_boards.size(), _hud_rest_x.size()):
		var board: Variant = _hud_boards[index]
		if is_instance_valid(board):
			(board as Control).position.x = _hud_rest_x[index]

## Takes every click while it moves; lets them through while it rests.
func _apply_shield() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if is_moving() else Control.MOUSE_FILTER_IGNORE

#-----------------------------------------------------------------------------
# THE CHEST
#-----------------------------------------------------------------------------

## True when the board swaps the chest and there is a chest to swap.
func _swaps_chest() -> bool:
	return _spec.swaps_chest and is_instance_valid(_zone_panel)

## The chest's mode, its rows and its height at t.
func _apply_chest(t: float) -> void:
	var techniques: bool = t >= BoardTransitionTiming.CHEST_SWAP_MS
	if _zone_panel.is_techniques_mode() != techniques:
		_switch_chest(techniques)
	_slide_rows(t)
	if t > BoardTransitionTiming.CHEST_SWAP_MS and t < BoardTransitionTiming.CHEST_END_MS:
		_zone_panel.set_height_override(BoardTransitionTiming.chest_height(t, _activities_height, _techniques_height))
		_holds_height = true
	else:
		_release_height()

## Turns the chest to the other list: the rows that showed go back to rest,
## the heights are read again (the last cycle's line may have changed since),
## and the new list's rows are taken.
func _switch_chest(techniques: bool) -> void:
	_restore_rows()
	_zone_panel.set_techniques_mode(techniques)
	_read_chest_heights()
	_take_rows()

## Reads the chest's height in each mode. Asking for the techniques' height
## may rebuild the hidden technique list.
func _read_chest_heights() -> void:
	_activities_height = _zone_panel.chest_height_for(false)
	_techniques_height = _zone_panel.chest_height_for(true)

## Takes the rows of the list that shows and the x each rests at now, and
## watches the containers that lay them out.
func _take_rows() -> void:
	_let_go_of_rows()
	_rows = _zone_panel.get_slide_rows()
	for row: Control in _rows:
		_row_rest_x.append(row.position.x)
		var container: Container = row.get_parent() as Container
		if container != null and not _row_containers.has(container):
			var call: Callable = _on_row_container_sorted.bind(container)
			container.sort_children.connect(call)
			_row_containers.append(container)
			_row_container_calls.append(call)

## Stops watching the rows' containers and forgets the rows.
func _let_go_of_rows() -> void:
	for index: int in _row_containers.size():
		var container: Variant = _row_containers[index]
		if is_instance_valid(container) and (container as Container).sort_children.is_connected(_row_container_calls[index]):
			(container as Container).sort_children.disconnect(_row_container_calls[index])
	_row_containers.clear()
	_row_container_calls.clear()
	_rows.clear()
	_row_rest_x.clear()

## Slides the rows to t: the activities' rows out to the right, the
## techniques' rows in from the right, each from the x it rests at.
func _slide_rows(t: float) -> void:
	var stepping_in: bool = _zone_panel.is_techniques_mode()
	var travel: float = _zone_panel.size.x
	var count: int = _rows.size()
	for index: int in count:
		var row: Variant = _rows[index]
		if not is_instance_valid(row):
			continue
		var offset: float
		if stepping_in:
			offset = BoardTransitionTiming.row_in_offset(t, index, count, travel)
		else:
			offset = BoardTransitionTiming.row_out_offset(t, index, count, travel)
		(row as Control).position.x = _row_rest_x[index] + offset

## Puts every row that is still there back at the x it rests at.
func _restore_rows() -> void:
	for index: int in _rows.size():
		var row: Variant = _rows[index]
		if is_instance_valid(row):
			(row as Control).position.x = _row_rest_x[index]

## Lets the chest hug its list again, if its frame is held.
func _release_height() -> void:
	if _holds_height and is_instance_valid(_zone_panel):
		_zone_panel.clear_height_override()
	_holds_height = false

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A container of the rows has laid them out, which put its rows at rest: their
## rest x is read again, and every row is slid back to where the progress has
## it before the frame is drawn.
func _on_row_container_sorted(container: Container) -> void:
	if _spec == null or not _swaps_chest():
		return
	for index: int in _rows.size():
		var row: Variant = _rows[index]
		if is_instance_valid(row) and (row as Control).get_parent() == container:
			_row_rest_x[index] = (row as Control).position.x
	_slide_rows(_current_ms())
