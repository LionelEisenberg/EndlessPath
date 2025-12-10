## State for the Cycling View.
class_name CyclingViewState
extends MainViewState

func _ready() -> void:
	if ActionManager:
		ActionManager.start_cycling.connect(_on_start_cycling)
		ActionManager.stop_cycling.connect(_on_stop_cycling)

## Called when entering this state.
func enter() -> void:
	scene_root.cycling_view.visible = true

## Called when exiting this state.
func exit() -> void:
	scene_root.cycling_view.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("close_cycling_view"):
		ActionManager.stop_action()

func _on_start_cycling(_data: Variant) -> void:
	scene_root.push_state(scene_root.cycling_view_state)

func _on_stop_cycling() -> void:
	scene_root.pop_state()
