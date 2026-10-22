class_name CameraClampController
extends Node

## Composable clamp controller for Camera2D nodes
## Handles clamping view to a given boundary

@export_group("Boundaries")
@export var use_boundaries: bool = false
@export var boundary_min: Vector2 = Vector2(-1400, -1400)
@export var boundary_max: Vector2 = Vector2(1400, 1400)
## When true, only the camera's centre is kept inside the boundary, so the view
## may reach half a viewport past it (the zone map, whose fog covers that
## margin). When false, the whole view stays inside the boundary.
@export var clamp_centre_only: bool = false

var camera: Camera2D = null

var camera_pan_controller : CameraPanController = null
var camera_zoom_controller : CameraZoomController = null

func _ready() -> void:
	camera = get_parent() as Camera2D
	if not camera:
		Log.critical("CameraClampController: Camera is not a Camera2D")
		return

	_get_camera_controllers()
	
	_connect_signals()

func _get_camera_controllers() -> void:
	for camera_controller in get_parent().get_children():
		if camera_controller is CameraClampController:
			continue
		elif camera_controller is CameraPanController:
			camera_pan_controller = camera_controller
		elif camera_controller is CameraZoomController:
			camera_zoom_controller = camera_controller
		else:
			Log.warn("CameraClampController: Unable to assign controller %s" % camera_controller)
	
func _connect_signals() -> void:
	if camera_pan_controller:
		camera_pan_controller.position_changed.connect(clamp_camera_position)
	if camera_zoom_controller:
		camera_zoom_controller.zoom_changed.connect(clamp_camera_position)

## Clamps the camera where it is now, e.g. after a tween moved it or the
## boundary changed.
func clamp_now() -> void:
	clamp_camera_position(camera.position if camera else Vector2.ZERO)

func clamp_camera_position(position: Vector2) -> void:
	if not camera or not use_boundaries:
		return
	
	var limits = _get_clamped_limits()
	
	if limits.max.x > limits.min.x:
		camera.position.x = clamp(camera.position.x, limits.min.x, limits.max.x)
	else:
		camera.position.x = (limits.min.x + limits.max.x) / 2.0
	
	if limits.max.y > limits.min.y:
		camera.position.y = clamp(camera.position.y, limits.min.y, limits.max.y)
	else:
		camera.position.y = (limits.min.y + limits.max.y) / 2.0

func _get_clamped_limits() -> Dictionary:
	if not camera:
		return {"min": Vector2.ZERO, "max": Vector2.ZERO}
	
	if clamp_centre_only:
		return {"min": boundary_min, "max": boundary_max}

	var viewport_size = camera.get_viewport().get_visible_rect().size
	var half_viewport = viewport_size / (2.0 * camera.zoom)
	
	return {
		"min": boundary_min + half_viewport,
		"max": boundary_max - half_viewport
	}
