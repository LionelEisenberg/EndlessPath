class_name CameraZoomController
extends Node

## Composable zoom controller for Camera2D nodes
## Add as a child to any Camera2D to get zoom functionality

#-----------------------------------------------------------------------------
# CONFIGURATION
#-----------------------------------------------------------------------------

@export_group("Zoom Settings")
@export var zoom_min: float = 0.5
@export var zoom_max: float = 1.35
@export var zoom_speed: float = 10.0
@export var zoom_step: float = 0.1  ## How much to zoom per wheel tick
@export var enabled: bool = true

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal zoom_changed(new_zoom: Vector2)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var camera: Camera2D
var is_zooming: bool = false
var target_zoom: Vector2:
	get:
		return target_zoom
	set(value):
		is_zooming = true
		target_zoom = value.clampf(zoom_min, zoom_max)
		# Snap to 1.0 if very close
		if is_equal_approx(target_zoom.x, 1.0):
			target_zoom = Vector2.ONE
		zoom_changed.emit(target_zoom)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Get parent camera
	if not get_parent() is Camera2D:
		Log.error("CameraZoomController must be a child of Camera2D")
		queue_free()
		return
	
	camera = get_parent() as Camera2D
	target_zoom = Vector2(zoom_max, zoom_max)

func _process(delta: float) -> void:
	if not enabled:
		return
	_update_zoom(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	
	if _handle_zoom_input(event):
		get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Zoom in by one step
func zoom_in() -> void:
	target_zoom *= (1.0 + zoom_step)

## Zoom out by one step
func zoom_out() -> void:
	target_zoom *= (1.0 - zoom_step)

## Set zoom to a specific level
func set_zoom_level(level: float) -> void:
	target_zoom = Vector2(level, level)

## Get current zoom level
func get_zoom_level() -> float:
	return camera.zoom.x if camera else 1.0

## Check if currently zooming
func is_zoom_active() -> bool:
	return is_zooming

## Enable/disable zoom controller
func set_enabled(value: bool) -> void:
	enabled = value

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

## Handle mouse wheel zoom input
func _handle_zoom_input(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or not event.pressed:
		return false
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			return true
		MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			return true
	
	return false

## Smoothly interpolate zoom to target
func _update_zoom(delta: float) -> void:
	if not is_zooming or not camera:
		return
	
	if camera.zoom.is_equal_approx(target_zoom):
		is_zooming = false
		camera.zoom = target_zoom
	else:
		camera.zoom = camera.zoom.slerp(target_zoom, zoom_speed * delta)
