## State for the Adventure View.
class_name AdventureViewState
extends MainViewState

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(_on_start_adventure)
		ActionManager.stop_adventure.connect(_on_stop_adventure)

## Called when entering this state.
func enter() -> void:
	scene_root.adventure_view.visible = true
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
