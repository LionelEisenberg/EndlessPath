## State for the Zone View.
class_name ZoneViewState
extends MainViewState

var _input_blocker: Control = null
var _zone_transition: ZoneTransition = null

func _ready() -> void:
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)

## Called when entering this state.
func enter() -> void:
	scene_root.zone_view.visible = true
	_remove_input_blocker()
	# Cache zone transition reference
	if not _zone_transition:
		_zone_transition = scene_root.zone_view.find_child("ZoneTransition", true, false)
	# Reset camera zoom if returning from adventure
	if _zone_transition:
		_zone_transition.reset_camera()

## Called when exiting this state.
func exit() -> void:
	_remove_input_blocker()
	scene_root.zone_view.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if _input_blocker:
		return
	if event.is_action_pressed("open_inventory"):
		scene_root.push_state(scene_root.inventory_view_state)
	elif event.is_action_pressed("open_path"):
		scene_root.push_state(scene_root.path_tree_view_state)

func _on_adventure_start_requested(_action_data: AdventureActionData) -> void:
	_add_input_blocker()

func _add_input_blocker() -> void:
	if _input_blocker:
		return
	_input_blocker = Control.new()
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	scene_root.zone_view.add_child(_input_blocker)

func _remove_input_blocker() -> void:
	if _input_blocker:
		_input_blocker.queue_free()
		_input_blocker = null
