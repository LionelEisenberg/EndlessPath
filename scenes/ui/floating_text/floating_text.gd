class_name FloatingText
extends MarginContainer
## Floating text popup that animates along a trajectory and fades out.

# Animation constants
const FONT_SIZE: int = 24
const FLOAT_DISTANCE: float = 100.0
const ANIMATION_DURATION: float = 1.5

@onready var _label: Label = $Label

var _tween: Tween = null

func _ready() -> void:
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("font_size", FONT_SIZE)
	modulate.a = 0.0
	set_process(false)

## Display floating text at specified position with optional trajectory.
## trajectory: movement vector from start to end (default: straight up).
func show_text(text: String, color: Color, pos: Vector2, trajectory: Vector2 = Vector2(0, -FLOAT_DISTANCE)) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	global_position = pos
	modulate.a = 1.0
	_start_floating_animation(trajectory)

func _start_floating_animation(trajectory: Vector2) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	# Float along trajectory
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + trajectory
	_tween.tween_method(func(t: float) -> void:
		global_position = start_pos.lerp(end_pos, t)
	, 0.0, 1.0, ANIMATION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade out (hold opaque briefly, then fade in the second half)
	_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION).set_delay(ANIMATION_DURATION * 0.3)

	_tween.finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()
