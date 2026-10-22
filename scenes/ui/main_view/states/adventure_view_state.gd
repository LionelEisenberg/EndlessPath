## State for the Adventure View.
class_name AdventureViewState
extends MainViewState

## Where the log window sits during an adventure, clear of the bottom HUD dock.
const ADVENTURE_LOG_POSITION: Vector2 = Vector2(24.0, 24.0)
## Where the Goals board sits during an adventure: the free top right. The
## left side would cover the adventure map's EncounterInfoPanel.
const ADVENTURE_GOALS_POSITION: Vector2 = Vector2(1456.0, 24.0)

var _log_window: Control
var _saved_log_position: Vector2 = Vector2.ZERO
var _goals_panel: Control
var _saved_goals_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(_on_start_adventure)
		ActionManager.stop_adventure.connect(_on_stop_adventure)

## Called when entering this state.
func enter() -> void:
	scene_root.adventure_view.visible = true
	_move_log_window_aside()
	_move_goals_panel_aside()
	# Connect to adventure_completed to show end card
	if not scene_root.adventure_view.adventure_completed.is_connected(_on_adventure_completed):
		scene_root.adventure_view.adventure_completed.connect(_on_adventure_completed)

## Called when exiting this state.
func exit() -> void:
	scene_root.adventure_view.visible = false
	_restore_log_window()
	_restore_goals_panel()
	if scene_root.adventure_view.adventure_completed.is_connected(_on_adventure_completed):
		scene_root.adventure_view.adventure_completed.disconnect(_on_adventure_completed)

## Handle input events in this state.
func handle_input(_event: InputEvent) -> void:
	pass

func _on_start_adventure(_data: AdventureActionData, _madra_budget: float = 0.0) -> void:
	scene_root.change_state(scene_root.adventure_view_state)

func _on_stop_adventure() -> void:
	# Don't transition to zone yet — wait for adventure_completed signal
	# which triggers the end card. The end card handles the zone transition.
	pass

func _on_adventure_completed(result_data: AdventureResultData) -> void:
	# Push end card as modal overlay on top of adventure view
	scene_root.push_state(scene_root.adventure_end_card_state)
	scene_root.adventure_end_card.show_results(result_data)
	# Connect return to handle close
	if not scene_root.adventure_end_card.return_requested.is_connected(_on_end_card_return):
		scene_root.adventure_end_card.return_requested.connect(_on_end_card_return, CONNECT_ONE_SHOT)

func _on_end_card_return() -> void:
	scene_root.pop_state() # Remove end card overlay
	scene_root.change_state(scene_root.zone_view_state) # Return to zone

## Moves the log window to the top-left corner for the adventure.
func _move_log_window_aside() -> void:
	if _log_window:
		return # Already moved; keep the original saved position.
	_log_window = scene_root.log_window
	if not _log_window:
		return
	_saved_log_position = _log_window.position
	_log_window.position = ADVENTURE_LOG_POSITION

## Puts the log window back where it was before the adventure.
func _restore_log_window() -> void:
	if _log_window and is_instance_valid(_log_window):
		_log_window.position = _saved_log_position
	_log_window = null

## Moves the Goals board to the top-right corner for the adventure and hides
## its cords, which would hang from nothing there.
func _move_goals_panel_aside() -> void:
	if _goals_panel:
		return # Already moved; keep the original saved position.
	_goals_panel = scene_root.goals_panel
	if not _goals_panel:
		return
	_saved_goals_position = _goals_panel.position
	_goals_panel.position = ADVENTURE_GOALS_POSITION
	_set_goals_cords_visible(false)

## Puts the Goals board back where it was before the adventure, cords and all.
func _restore_goals_panel() -> void:
	if _goals_panel and is_instance_valid(_goals_panel):
		_goals_panel.position = _saved_goals_position
		_set_goals_cords_visible(true)
	_goals_panel = null

## MainView holds the board as a Control; only a GoalsPanel has cords.
func _set_goals_cords_visible(cords_visible: bool) -> void:
	var goals: GoalsPanel = _goals_panel as GoalsPanel
	if goals:
		goals.set_cords_visible(cords_visible)
