## State for the Tribulation board. ActionManager.start_tribulation sets the board up and
## pushes it, and stop_tribulation removes it. The board sits in the map gap with no
## backdrop, as the cycling board does, and the zone view stays up around it. Entering
## hides the log and the Goals board, turns the dock and the map off
## (MainView.set_board_mode()) and blocks the full log, as a menu book does, so that Esc
## always reaches the board. Exiting undoes all of it and closes the board, whatever
## stopped the action: a trial stopped from outside (a save reset, the dev panel) applies
## nothing.
##
## MainView sends input only to the top state, so the trial's keys come to the board from
## handle_input(); the board judges mouse presses itself. Esc turns the trial down from
## the intro and does nothing once the run has begun. The board's finished(passed) stops
## the action, and the stop removes this state, all in one synchronous chain.
class_name TribulationViewState
extends MainViewState

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

## Called when entering this state: the log and the Goals board hide, the zone view's dock
## and map are turned off, the full log is blocked and the board shows.
func enter() -> void:
	scene_root.hide_hud_boards(self)
	scene_root.set_board_mode(true)
	_block_full_log(true)
	scene_root.tribulation_view.show()

## Called when exiting this state: the board closes (a run in progress is dropped, and
## nothing of it is applied), the HUD boards, the dock and the map are given back, and the
## full log can open again.
func exit() -> void:
	scene_root.tribulation_view.close()
	scene_root.release_hud_boards(self)
	scene_root.set_board_mode(false)
	_block_full_log(false)

## Handle input events in this state. Esc turns the trial down while the intro shows (the
## board ignores it at any other time); any other event goes to the board, which takes the
## trial's input (Space) and leaves the rest.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		scene_root.tribulation_view.cancel()
		return
	scene_root.tribulation_view.handle_press_event(event)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Returns the name of the zone the player stands in, which heads the board.
func _get_current_zone_name() -> String:
	var zone: ZoneData = ZoneManager.get_current_zone()
	return zone.zone_name if zone != null else ""

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_tribulation(action_data: TribulationActionData) -> void:
	var view: TribulationView = scene_root.tribulation_view
	if not view.finished.is_connected(_on_view_finished):
		view.finished.connect(_on_view_finished)
	view.setup(action_data.tribulation, _get_current_zone_name())
	# Already on the stack: a second entry would outlive the close and stay on top of
	# the zone view, where it swallows the menu keys.
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)

## Stops the Tribulation action, and only that action: the stop closes the board and
## removes this state before it returns, so a second click on Continue finds the board
## closed. A finished that arrives while something else runs leaves it alone.
func _on_view_finished(passed: bool) -> void:
	if ActionManager.get_current_action() is TribulationActionData:
		ActionManager.stop_action(passed)

## Removes only this state, so a view pushed above the board stays open.
func _on_stop_tribulation() -> void:
	scene_root.remove_state(self)
