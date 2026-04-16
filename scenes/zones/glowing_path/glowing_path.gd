class_name GlowingPath
extends Line2D

## Renders a glowing animated line between two world points.

func setup(from: Vector2, to: Vector2) -> void:
	clear_points()
	add_point(from)
	add_point(to)
