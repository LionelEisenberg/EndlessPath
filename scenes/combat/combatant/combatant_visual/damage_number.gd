class_name DamageNumber
extends Label

## DamageNumber
## Pops a number above a combatant, rises, and fades out. Frees itself when done.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const RISE_DISTANCE: float = 70.0
const DRIFT_RANGE: float = 30.0
const DURATION: float = 0.9

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Shows the given text in the given color, centered on `anchor_pos` (in the parent's coordinates).
func show_value(value_text: String, color: Color, anchor_pos: Vector2) -> void:
	text = value_text
	add_theme_color_override("font_color", color)
	reset_size()
	pivot_offset = size / 2.0
	position = anchor_pos - size / 2.0
	scale = Vector2(0.4, 0.4)

	var drift: float = randf_range(-DRIFT_RANGE, DRIFT_RANGE)
	var end_pos: Vector2 = position + Vector2(drift, -RISE_DISTANCE)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", end_pos, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * 0.5).set_delay(DURATION * 0.5)
	tween.chain().tween_callback(queue_free)
