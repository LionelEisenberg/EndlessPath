## State for the Abilities View.
class_name AbilitiesViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	scene_root.abilities_view.visible = true

## Called when exiting this state.
func exit() -> void:
	scene_root.abilities_view.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_abilities"):
		scene_root.pop_state()
