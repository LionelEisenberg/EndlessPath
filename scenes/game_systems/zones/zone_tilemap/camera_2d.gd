extends Camera2D

var is_camera_panning: bool = false

const ZOOM_MIN = 0.35
const ZOOM_MAX = 1.5
const ZOOM_SPEED = 10

# Camera boundary limits for panning
@export var map_bounds_min: Vector2 = Vector2(-1400, -1400)
@export var map_bounds_max: Vector2 = Vector2(1400, 1400)

enum FocusSide {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MIDDLE_LEFT,
	MIDDLE_CENTER,
	MIDDLE_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
}

var is_zooming: bool = false
var target_zoom: Vector2:
	get:
		return target_zoom
	set(value):
		is_zooming = true
		target_zoom = value.clampf(ZOOM_MIN, ZOOM_MAX)
		if is_equal_approx(target_zoom.x, 1.0):
			target_zoom.x = 1
			target_zoom.y = 1
 
func _ready() -> void:
	target_zoom = Vector2(ZOOM_MAX, ZOOM_MAX)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				is_camera_panning = true
			elif event.is_released():
				is_camera_panning = false

	if is_camera_panning and event is InputEventMouseMotion:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_camera_position()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom *= 1.1
	
	if event.is_action_pressed("center_zone_map_camera"):
		var centered_pos = Vector2(0, 0)
		var limits = get_clamped_camera_limits()
		centered_pos = centered_pos.clamp(limits.min, limits.max)
		
		var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "position", centered_pos, 0.25)
		tween.tween_callback(func(): target_zoom = Vector2(ZOOM_MAX, ZOOM_MAX))
		tween.play()


func _process(delta: float) -> void:
	if not is_zooming:
		return

	if zoom.is_equal_approx(target_zoom):
		is_zooming = false
		zoom = target_zoom
	else:
		zoom = zoom.slerp(target_zoom, ZOOM_SPEED * delta)
	
	# Clamp position when zoom changes to keep camera within bounds
	clamp_camera_position()


func focus_tile(
	target: Vector2,
	focus_side: FocusSide = FocusSide.MIDDLE_CENTER,
	focus_ratio: Vector2 = Vector2(0.25, 0.25)
) -> void:
	position = get_focus_position(target, focus_side, focus_ratio)
	clamp_camera_position()


func get_focus_position(
	target: Vector2,
	focus_side: FocusSide = FocusSide.MIDDLE_CENTER,
	focus_ratio: Vector2 = Vector2(0.25, 0.25)
) -> Vector2:
	var result = Vector2(target)
	var viewport_size = get_viewport().get_visible_rect().size
	match focus_side:
		FocusSide.TOP_LEFT, FocusSide.MIDDLE_LEFT, FocusSide.BOTTOM_LEFT:
			result.x += viewport_size.x * focus_ratio.x / zoom.x
		FocusSide.TOP_RIGHT, FocusSide.MIDDLE_RIGHT, FocusSide.BOTTOM_RIGHT:
			result.x -= viewport_size.x * focus_ratio.x / zoom.x

	match focus_side:
		FocusSide.TOP_LEFT, FocusSide.TOP_CENTER, FocusSide.TOP_RIGHT:
			result.y += viewport_size.y * focus_ratio.y / zoom.y
		FocusSide.BOTTOM_LEFT, FocusSide.BOTTOM_CENTER, FocusSide.BOTTOM_RIGHT:
			result.y -= viewport_size.y * focus_ratio.y / zoom.y

	return result


## Get the effective camera limits based on current zoom and viewport size
func get_clamped_camera_limits() -> Dictionary:
	var viewport_size = get_viewport().get_visible_rect().size
	var half_viewport = viewport_size / (2.0 * zoom)
	
	return {
		"min": map_bounds_min + half_viewport,
		"max": map_bounds_max - half_viewport
	}


## Clamp the camera position to stay within map boundaries
func clamp_camera_position() -> void:
	var limits = get_clamped_camera_limits()
	
	# Only clamp if max is greater than min (prevents issues when viewport > map bounds)
	if limits.max.x > limits.min.x:
		position.x = clamp(position.x, limits.min.x, limits.max.x)
	else:
		position.x = (limits.min.x + limits.max.x) / 2.0
	
	if limits.max.y > limits.min.y:
		position.y = clamp(position.y, limits.min.y, limits.max.y)
	else:
		position.y = (limits.min.y + limits.max.y) / 2.0
