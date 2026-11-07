## State for the body refining board. ActionManager.start_body_refining sets the
## board up for the action and pushes it, and stop_body_refining closes it. The
## board sits in the map gap with no backdrop, as the cycling board does, and the
## zone view stays up around it: the Goals board and the log stay where they stand,
## so the pellets a rep pays fly into the cabinet's stats and Health, and the chest
## turns to the learned drills, as cycling turns it to the techniques, and back
## when the board closes. Entering blocks the full log, as a menu book does, so that
## Esc always reaches the board, then opens the board with MainView.open_board():
## through the board transition the board scales out of the cultivator while the
## dock steps down and the chest swaps; on a MainView with no transition the dock
## and the map turn off and the chest turns at once. Exiting hides the board and
## lifts the full-log block, whatever stopped the action.
##
## MainView sends input only to the top state, so the drill's presses (drill_press)
## come to the board from handle_input(); the board takes mouse presses on itself,
## and the chest's drawers take theirs.
## Esc stops the action. While the board opens only Esc is handled, and nothing is
## while it closes: the action that resumed when body refining stopped must not be
## stopped by it.
##
## The close. stop_body_refining halts the board's set at once (its reps stay paid
## and the pellets in flight land), then closes the board with
## MainView.close_board(). The state stays on MainView's stack, on top, until the
## close has finished: only then does it remove itself (remove_state() calls exit(),
## which hides the board). A start_body_refining that comes while the board closes
## turns the close around, and the state stays on the stack. Without a transition
## the close is instant and the state leaves at once.
##
## The spec. The state keeps one BoardTransitionSpec for every run, because the
## transition keeps the first spec object of a run. Its view and board rectangle are
## read when the board opens from closed, and never while it moves: the rectangle
## of a board that scales is not where the transition scales it about.
class_name BodyRefiningViewState
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
		ActionManager.start_body_refining.connect(_on_start_body_refining)
		ActionManager.stop_body_refining.connect(_on_stop_body_refining)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Called when entering this state: the full log is blocked and the board opens.
func enter() -> void:
	_block_full_log(true)
	scene_root.open_board(_refresh_spec())

## Called when exiting this state, once the board has closed: the board hides (a
## set in progress stops, its reps paid) and the full log can open again. The dock
## and the map are given back by the close.
func exit() -> void:
	scene_root.body_refining_view.close()
	_block_full_log(false)

## Handle input events in this state. Nothing is handled while the board closes.
## Esc stops the action; while the board opens that is all that is handled. Any
## other event goes to the board, which takes the drill's presses and leaves the
## rest.
func handle_input(event: InputEvent) -> void:
	if scene_root.is_board_closing():
		return
	if event.is_action_pressed("ui_cancel"):
		ActionManager.stop_action()
		return
	if scene_root.is_board_moving():
		return
	scene_root.body_refining_view.handle_press_event(event)

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
		_spec.chest_mode = ZonePanel.ChestMode.DRILLS
		_spec.moves_hud_boards = false
		_spec.holder = self
	var view: BodyRefiningView = scene_root.body_refining_view
	_spec.view = view
	_spec.board_rect = view.get_board_rect()
	return _spec

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_body_refining(action_data: BodyRefiningActionData) -> void:
	scene_root.body_refining_view.setup(action_data)
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)
		return
	# Already on the stack: the board is closing, and opening turns the close
	# around. A second entry would outlive the close and stay on top of the zone
	# view, where it swallows the menu keys. The spec is the one the transition
	# holds, left as it is: see _refresh_spec().
	scene_root.open_board(_spec)

## Halts the set at once, then closes the board; the state removes only itself
## when the close has finished, so a view pushed above the board stays open.
func _on_stop_body_refining() -> void:
	# The transition closes whichever board is up, so a stop with no body refining
	# board up must not reach it.
	if not scene_root.state_stack.has(self):
		return
	scene_root.body_refining_view.halt()
	scene_root.close_board(_spec, scene_root.remove_state.bind(self))
