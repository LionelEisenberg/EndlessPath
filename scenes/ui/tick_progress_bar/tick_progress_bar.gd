class_name TickProgressBar
extends Control
## Thin 2-pixel-tall progress bar with static gradation marks at 10..90% and a
## right-aligned "current / total" counter below the bar.
##
## Call set_progress(current, total) to update the fill and counter.
## Call flash_and_reset(color, duration) to play a brief flash, fade to zero,
## and then resume showing fresh values on the next set_progress call.

const BAR_COLOR_BG: Color = Color(0.18, 0.18, 0.18, 0.9)
const BAR_COLOR_FILL_DEFAULT: Color = Color(0.83, 0.75, 0.45, 1.0)
const GRADATION_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const GRADATION_WIDTH: float = 1.0
const GRADATION_HEIGHT: float = 4.0  # slightly taller than the bar for visibility

@onready var _bar_bg: ColorRect = %BarBg
@onready var _bar_fill: ColorRect = %BarFill
@onready var _gradation_overlay: Control = %GradationOverlay
@onready var _counter_label: Label = %CounterLabel

var _fill_color: Color = BAR_COLOR_FILL_DEFAULT
var _reset_tween: Tween = null

func _ready() -> void:
	_bar_fill.color = _fill_color
	_bar_bg.color = BAR_COLOR_BG
	_gradation_overlay.draw.connect(_draw_gradations)
	_gradation_overlay.resized.connect(_gradation_overlay.queue_redraw)

## Sets the fill percentage and counter text. `total == 0` clears the bar.
func set_progress(current: int, total: int) -> void:
	_kill_reset_tween()
	_bar_fill.self_modulate.a = 1.0
	if total <= 0:
		_bar_fill.anchor_right = 0.0
		_counter_label.text = ""
		return
	var pct: float = clampf(float(current) / float(total), 0.0, 1.0)
	_bar_fill.anchor_right = pct
	_counter_label.text = "%d / %d" % [current, total]

## Sets the fill color (used by the presenter to tint per category).
func set_fill_color(color: Color) -> void:
	_kill_reset_tween()
	_fill_color = color
	if is_instance_valid(_bar_fill):
		_bar_fill.color = color
		_bar_fill.self_modulate.a = 1.0

## Briefly flashes the bar to `flash_color`, fades to transparent, then snaps
## to zero fill.
func flash_and_reset(flash_color: Color, duration: float = 0.3) -> void:
	_kill_reset_tween()
	_reset_tween = create_tween()
	_reset_tween.tween_property(_bar_fill, "color", flash_color, duration * 0.33)
	_reset_tween.tween_property(_bar_fill, "self_modulate:a", 0.0, duration * 0.66)
	_reset_tween.tween_callback(func() -> void:
		_bar_fill.anchor_right = 0.0
		_bar_fill.color = _fill_color
		_bar_fill.self_modulate.a = 1.0
	)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _kill_reset_tween() -> void:
	if _reset_tween and _reset_tween.is_valid():
		_reset_tween.kill()
	_reset_tween = null

func _draw_gradations() -> void:
	var w: float = _gradation_overlay.size.x
	var h: float = _gradation_overlay.size.y
	if w <= 0.0 or h <= 0.0:
		return
	for i in range(1, 10):
		var x: float = w * (i / 10.0)
		_gradation_overlay.draw_rect(Rect2(Vector2(x, 0), Vector2(GRADATION_WIDTH, h)), GRADATION_COLOR)
