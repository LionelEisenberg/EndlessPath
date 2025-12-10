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

## Called when exiting this state.
func exit() -> void:
	scene_root.adventure_view.visible = false

## Handle input events in this state.
func handle_input(_event: InputEvent) -> void:
	pass

func _on_start_adventure(_data: Variant) -> void:
	scene_root.change_state(scene_root.adventure_view_state)

func _on_stop_adventure() -> void:
	scene_root.change_state(scene_root.zone_view_state)
