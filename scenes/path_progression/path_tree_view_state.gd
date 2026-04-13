## State for the Path Tree View.
class_name PathTreeViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	scene_root.path_tree_view.visible = true

## Called when exiting this state.
func exit() -> void:
	scene_root.path_tree_view.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_path"):
		scene_root.pop_state()
