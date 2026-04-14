class_name PathPreview
extends Line2D

## PathPreview
## Renders a flowing animated line from the player's current tile through
## intermediate tiles to a hover-target tile. Uses the flowing_path shader.

func show_path(world_points: Array[Vector2]) -> void:
	clear_points()
	for p in world_points:
		add_point(p)
	visible = world_points.size() >= 2

func clear_path() -> void:
	clear_points()
	visible = false
