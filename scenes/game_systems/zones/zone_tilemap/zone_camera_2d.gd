extends Camera2D

func _process(delta: float) -> void:
	# Clamp position when zoom changes to keep camera within bounds
	clamp_camera_position()

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
