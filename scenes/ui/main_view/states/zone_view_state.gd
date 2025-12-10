## State for the Zone View.
class_name ZoneViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.zone_view.visible = true

## Called when exiting this state.
func exit() -> void:
	scene_root.zone_view.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		scene_root.push_state(scene_root.inventory_view_state)
