## State for the Cycling View. ActionManager.start_cycling pushes it and
## stop_cycling closes it. Cycling does not cover the zone view: the board sits in
## the map gap, with no backdrop, and the cultivator cabinet, Goals and the log
## stay where the zone view put them.
##
## Enter blocks the full log, as a menu book does, so that Esc always reaches the
## board, then opens the board with MainView.open_board(): through the board
## transition the board scales out of the cultivator while the chest swaps to the
## techniques and the dock steps down; on a MainView with no transition all of it
## happens at once. Exit only lifts the full-log block.
##
## The close. stop_cycling closes the board with MainView.close_board(), and the
## state stays on MainView's stack, on top, until the close has finished: only then
## does it remove itself (remove_state() calls exit()). A start_cycling that comes
## while the board closes turns the close around, and the state stays on the stack.
##
## Esc. close_cycling_view stops the action, unless the board is closing: the
## action that resumed when cycling stopped must not be stopped by it. Nothing else
## is handled here, so the menu keys do nothing until the close has ended and the
## zone view is the current state again.
##
## The spec. The state keeps one BoardTransitionSpec for every run, because the
## transition keeps the first spec object of a run. Its view and board rectangle are
## read when the board opens from closed, and never while it moves: the rectangle
## of a board that scales is not where the transition scales it about.
class_name CyclingViewState
extends MainViewState

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## What the board needs of the zone view, built on the first open and kept.
var _spec: BoardTransitionSpec = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if ActionManager:
		ActionManager.start_cycling.connect(_on_start_cycling)
		ActionManager.stop_cycling.connect(_on_stop_cycling)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Called when entering this state: the full log is blocked and the board opens.
func enter() -> void:
	_block_full_log(true)
	scene_root.open_board(_refresh_spec())

## Called when exiting this state, once the board has closed: the full log can
## open again. The board and the zone view are given back by the close.
func exit() -> void:
	_block_full_log(false)

## Handle input events in this state. Esc stops the cycling action, unless the
## board is already closing.
func handle_input(event: InputEvent) -> void:
	if scene_root.is_board_closing():
		return
	if event.is_action_pressed("close_cycling_view"):
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Returns the state's spec with its view and board rectangle read again. Call it
## only while the board rests: the rectangle of a board that moves is not where
## the transition scales the board about.
func _refresh_spec() -> BoardTransitionSpec:
	if _spec == null:
		_spec = BoardTransitionSpec.new()
		_spec.swaps_chest = true
		_spec.holder = self
	var view: Control = scene_root.cycling_view
	_spec.view = view
	var board: CyclingView = view as CyclingView
	_spec.board_rect = board.get_board_rect() if board != null else view.get_global_rect()
	return _spec

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_cycling(_data: Variant) -> void:
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)
		return
	# Already on the stack: the board is closing, and opening turns the close
	# around. A second entry would outlive the close and stay on top of the zone
	# view, where it swallows the menu keys. The spec is the one the transition
	# holds, left as it is: see _refresh_spec().
	scene_root.open_board(_spec)

func _on_stop_cycling() -> void:
	# The transition closes whichever board is up, so a stop with no cycling board
	# up must not reach it.
	if not scene_root.state_stack.has(self):
		return
	scene_root.close_board(_spec, scene_root.remove_state.bind(self))
