## State for the "Head out?" board, the question the adventure card asks while
## Health or Madra is below half. ActionManager.adventure_confirm_requested
## pushes it over the zone view; entering shows the board and blocks the full
## log, so that Esc reaches the board; exiting closes it. MainView sends input
## only to the top state, so the menu books' keys do nothing while it asks.
##
## Head out takes the state off and starts the run through
## ActionManager.select_action(), as an unasked click does. Not yet, a click
## outside the board and Esc take it off and start nothing: the idle action runs
## on.
class_name AdventureConfirmState
extends MainViewState

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The run the board asks about.
var _action_data: AdventureActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if ActionManager:
		ActionManager.adventure_confirm_requested.connect(_on_adventure_confirm_requested)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Called when entering this state: the board asks, and the full log is blocked.
func enter() -> void:
	var board: AdventureConfirmBoard = scene_root.adventure_confirm_board
	board.confirmed.connect(_on_confirmed)
	board.dismissed.connect(_on_dismissed)
	_block_full_log(true)
	board.ask()

## Called when exiting this state: the board closes and the full log can open.
func exit() -> void:
	var board: AdventureConfirmBoard = scene_root.adventure_confirm_board
	board.confirmed.disconnect(_on_confirmed)
	board.dismissed.disconnect(_on_dismissed)
	board.close()
	_block_full_log(false)

## Esc is Not yet; nothing else is handled.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		scene_root.remove_state(self)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_adventure_confirm_requested(action_data: AdventureActionData) -> void:
	_action_data = action_data
	if scene_root.state_stack.has(self):
		scene_root.adventure_confirm_board.ask()
		return
	scene_root.push_state(self)

## Head out: the board goes, then the run starts.
func _on_confirmed() -> void:
	var action_data: AdventureActionData = _action_data
	_action_data = null
	scene_root.remove_state(self)
	if action_data != null:
		ActionManager.select_action(action_data)

func _on_dismissed() -> void:
	_action_data = null
	scene_root.remove_state(self)
