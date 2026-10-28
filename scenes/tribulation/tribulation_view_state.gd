## State for the Tribulation board. ActionManager.start_tribulation sets the board up and
## pushes it, and stop_tribulation closes it. The board sits in the map gap with no
## backdrop, as the cycling board does, and the zone view stays up around it. Entering
## blocks the full log, as a menu book does, so that Esc always reaches the board, then
## opens the board with MainView.open_board(): through the board transition the board scales
## out of the cultivator while the dock steps down and the Goals board and the log slide off
## the left edge; on a MainView with no transition the dock and the map turn off and the
## Goals board and the log hide at once. Exiting lifts the full-log block and closes the
## board, whatever stopped the action: a trial stopped from outside (a save reset, the dev
## panel) applies nothing.
##
## MainView sends input only to the top state, so the trial's keys come to the board from
## handle_input(); the board judges mouse presses itself. Esc turns the trial down from the
## intro and does nothing once the run has begun. The board's finished(passed) stops the
## action. While the board opens only Esc is handled, and nothing is while it closes.
##
## The close. stop_tribulation halts the board's run at once (halt() drops a run and applies
## nothing, though the board stays drawn), then closes the board with MainView.close_board().
## The state stays on MainView's stack, on top, until the close has finished: only then does
## it remove itself (remove_state() calls exit(), which hides the board). A start_tribulation
## that comes while the board closes turns the close around, and the state stays on the
## stack. Without a transition the close is instant and the state leaves at once.
##
## The spec. The state keeps one BoardTransitionSpec for every run, because the transition
## keeps the first spec object of a run. Its view and board rectangle are read when the board
## opens from closed, and never while it moves: the rectangle of a board that scales is not
## where the transition scales it about.
class_name TribulationViewState
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
		ActionManager.start_tribulation.connect(_on_start_tribulation)
		ActionManager.stop_tribulation.connect(_on_stop_tribulation)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Called when entering this state: the full log is blocked and the board opens.
func enter() -> void:
	_block_full_log(true)
	scene_root.open_board(_refresh_spec())

## Called when exiting this state, once the board has closed: the board hides (a run in
## progress is dropped, and nothing of it is applied) and the full log can open again. The
## HUD boards, the dock and the map are given back by the close.
func exit() -> void:
	scene_root.tribulation_view.close()
	_block_full_log(false)

## Handle input events in this state. Nothing is handled while the board closes. Esc turns
## the trial down while the intro shows (the board ignores it at any other time); while the
## board opens that is all that is handled. Any other event goes to the board, which takes
## the trial's input (Space) and leaves the rest.
func handle_input(event: InputEvent) -> void:
	if scene_root.is_board_closing():
		return
	if event.is_action_pressed("ui_cancel"):
		scene_root.tribulation_view.cancel()
		return
	if scene_root.is_board_moving():
		return
	scene_root.tribulation_view.handle_press_event(event)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Returns the name of the zone the player stands in, which heads the board.
func _get_current_zone_name() -> String:
	var zone: ZoneData = ZoneManager.get_current_zone()
	return zone.zone_name if zone != null else ""

## Returns the state's spec with its view and board rectangle read again. Call it only while
## the board rests: the rectangle of a board that moves is not where the transition scales
## the board about.
func _refresh_spec() -> BoardTransitionSpec:
	if _spec == null:
		_spec = BoardTransitionSpec.new()
		_spec.swaps_chest = false
		_spec.moves_hud_boards = true
		_spec.holder = self
	var view: TribulationView = scene_root.tribulation_view
	_spec.view = view
	_spec.board_rect = view.get_board_rect()
	return _spec

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_tribulation(action_data: TribulationActionData) -> void:
	var view: TribulationView = scene_root.tribulation_view
	if not view.finished.is_connected(_on_view_finished):
		view.finished.connect(_on_view_finished)
	view.setup(action_data.tribulation, _get_current_zone_name())
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)
		return
	# Already on the stack: the board is closing, and opening turns the close around. A
	# second entry would outlive the close and stay on top of the zone view, where it
	# swallows the menu keys. The spec is the one the transition holds, left as it is: see
	# _refresh_spec().
	scene_root.open_board(_spec)

## Stops the Tribulation action, and only that action. A finished that arrives while
## something else runs leaves it alone.
func _on_view_finished(passed: bool) -> void:
	if ActionManager.get_current_action() is TribulationActionData:
		ActionManager.stop_action(passed)

## Halts the run at once, so nothing of it is applied while the board shrinks away, then
## closes the board; the state removes only itself when the close has finished, so a view
## pushed above the board stays open.
func _on_stop_tribulation() -> void:
	# The transition closes whichever board is up, so a stop with no Tribulation board up
	# must not reach it.
	if not scene_root.state_stack.has(self):
		return
	scene_root.tribulation_view.halt()
	scene_root.close_board(_spec, scene_root.remove_state.bind(self))
