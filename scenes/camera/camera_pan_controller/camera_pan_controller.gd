class_name CameraPanController
extends Node

## Composable pan controller for Camera2D nodes
## Handles right-click drag panning with optional boundaries

#-----------------------------------------------------------------------------
# CONFIGURATION
#-----------------------------------------------------------------------------

@export_group("Pan Settings")
@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var enabled: bool = true

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal pan_started()
signal pan_ended()
signal position_changed(new_position: Vector2)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var camera: Camera2D
var is_panning: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Get parent camera
	if not get_parent() is Camera2D:
		Log.error("CameraPanController must be a child of Camera2D")
		queue_free()
		return
	
	camera = get_parent() as Camera2D

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	
	if _handle_pan_input(event):
		get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Check if currently panning
func is_pan_active() -> bool:
	return is_panning

## Enable/disable pan controller
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and is_panning:
		_stop_panning()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

## Handle pan input
func _handle_pan_input(event: InputEvent) -> bool:
	if not camera:
		return false
	
	# Start/stop panning
	if event is InputEventMouseButton and event.button_index == pan_button:
		if event.is_pressed():
			_start_panning()
		elif event.is_released():
			_stop_panning()
		return true
	
	# Pan camera during drag
	if is_panning and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera.position -= motion.relative / camera.zoom.x
		position_changed.emit(camera.position)
		return true
	
	return false

func _start_panning() -> void:
	is_panning = true
	pan_started.emit()

func _stop_panning() -> void:
	is_panning = false
	pan_ended.emit()
