## State for the Abilities View.
## Handles open/close animation and input transitions.
class_name AbilitiesViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	scene_root.abilities_view.visible = true
	scene_root.abilities_view.animate_open()

## Called when exiting this state.
func exit() -> void:
	scene_root.abilities_view.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_abilities"):
		if not scene_root.abilities_view.abilities_closed.is_connected(_on_close_animation_finished):
			scene_root.abilities_view.abilities_closed.connect(_on_close_animation_finished)
		scene_root.abilities_view.animate_close()

## Handle completion of closing animation to pop the state.
func _on_close_animation_finished() -> void:
	scene_root.pop_state()
	scene_root.abilities_view.abilities_closed.disconnect(_on_close_animation_finished)
