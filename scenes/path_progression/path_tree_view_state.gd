## State for the Path Tree View.
## Delegates open/close animation to GreyBackground, which plays its own fade
## in parallel with PathTreeView.animate_open() / animate_close().
class_name PathTreeViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.show_with_panel(scene_root.path_tree_view)

## Called when exiting this state.
## Hiding is driven by grey_background.panel_hidden -> _on_close_finished -> pop_state,
## so by the time exit() runs the grey background and path tree view are already hidden.
func exit() -> void:
	pass

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_path"):
		if not scene_root.grey_background.panel_hidden.is_connected(_on_close_finished):
			scene_root.grey_background.panel_hidden.connect(_on_close_finished, CONNECT_ONE_SHOT)
		scene_root.grey_background.hide_with_panel(scene_root.path_tree_view)

## Handle completion of the grey background hide animation to pop the state.
func _on_close_finished() -> void:
	scene_root.pop_state()
