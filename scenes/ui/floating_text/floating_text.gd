class_name FloatingText
extends MarginContainer

@onready var label: Label = $Label

var tween: Tween

func _ready() -> void:
	# Initial setup
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("font_size", 24)
	modulate.a = 0.0  # Start invisible
	set_process(false)

## Display floating text at specified position.
func show_text(text: String, color: Color, pos: Vector2) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	
	# Set position
	global_position = pos
	
	# Set initial opacity to 1
	modulate.a = 1.0
	
	# Start animation
	_start_floating_animation()

## Animate the text floating upward and fading out.
func _start_floating_animation() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Float upward
	var start_y = global_position.y
	var end_y = start_y - 100
	tween.tween_method(func(y: float): global_position.y = y, start_y, end_y, 1.5)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	
	# Clean up when done
	tween.finished.connect(_on_animation_finished)

## Called when animation completes.
func _on_animation_finished() -> void:
	queue_free()
