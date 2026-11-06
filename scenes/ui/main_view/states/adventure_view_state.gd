## State for the Adventure View. The adventure's own cabinet, chest and dock
## stand where the zone view keeps its furniture. The log stays where the zone
## view hung it, at the bottom left, and the Goals board moves up under the
## vitals cabinet with its cords on (adventure spec: The left column);
## ZoneViewState hangs it back under the cultivator cabinet.
class_name AdventureViewState
extends MainViewState

## Where a run hangs the Goals board: under the vitals cabinet, which shows no
## stats, 4 px under its rings at y 364 (the Core row made it a row taller).
const GOALS_POSITION: Vector2 = Vector2(24.0, 368.0)

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(_on_start_adventure)
		ActionManager.stop_adventure.connect(_on_stop_adventure)

## Called when entering this state.
func enter() -> void:
	scene_root.adventure_view.visible = true
	if scene_root.goals_panel:
		scene_root.goals_panel.position = GOALS_POSITION
	# Connect to adventure_completed to show end card
	if not scene_root.adventure_view.adventure_completed.is_connected(_on_adventure_completed):
		scene_root.adventure_view.adventure_completed.connect(_on_adventure_completed)

## Called when exiting this state.
func exit() -> void:
	scene_root.adventure_view.visible = false
	if scene_root.adventure_view.adventure_completed.is_connected(_on_adventure_completed):
		scene_root.adventure_view.adventure_completed.disconnect(_on_adventure_completed)

## Handle input events in this state.
func handle_input(_event: InputEvent) -> void:
	pass

func _on_start_adventure(_data: AdventureActionData) -> void:
	_play_dissolve()
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
	_play_dissolve()
	scene_root.pop_state() # Remove end card overlay
	scene_root.change_state(scene_root.zone_view_state) # Return to zone

## The zone view and the adventure give way to each other through the dither
## dissolve: a still of the view going out, over the one coming in.
func _play_dissolve() -> void:
	if scene_root.view_dissolve:
		scene_root.view_dissolve.play()
