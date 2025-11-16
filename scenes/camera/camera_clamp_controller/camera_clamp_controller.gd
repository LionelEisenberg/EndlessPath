class_name CameraClampController
extends Node

## Composable clamp controller for Camera2D nodes
## Handles clamping view to a given boundary

@export_group("Boundaries")
@export var use_boundaries: bool = true
@export var boundary_min: Vector2 = Vector2(-1400, -1400)
@export var boundary_max: Vector2 = Vector2(1400, 1400)

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
		if camera_controller is CameraPanController:
			camera_pan_controller = camera_controller
		if camera_controller is CameraZoomController:
			camera_zoom_controller = camera_controller
		else:
			Log.warn("CameraClampController: Unable to assign controller %s" % camera_controller)
	
func _connect_signals() -> void:
	if camera_pan_controller:
		camera_pan_controller.position_changed.connect(clamp_camera_position)
	if camera_zoom_controller:
		camera_zoom_controller.zoom_changed.connect(clamp_camera_position)

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
	
	var viewport_size = camera.get_viewport().get_visible_rect().size
	var half_viewport = viewport_size / (2.0 * camera.zoom)
	
	return {
		"min": boundary_min + half_viewport,
		"max": boundary_max - half_viewport
	}
