class_name TimerPanel
extends PanelContainer

## TimerPanel
## Displays and manages the adventure timer. In the final seconds the time
## turns red and the pill ticks once per second.

const LOW_TIME_SECONDS: float = 30.0
const COLOR_LOW: Color = Color("#e86a5c")

@onready var timer_label: Label = %TimerLabel
@onready var timer: Timer = %Timer

var _default_color: Color
var _last_whole_second: int = -1
var _tick_tween: Tween

func _ready() -> void:
	_default_color = timer_label.get_theme_color("font_color")

## Starts the timer with the given duration in seconds
func start(time_sec: float) -> void:
	_last_whole_second = -1
	timer_label.add_theme_color_override("font_color", _default_color)
	timer.start(time_sec)

## Stops the timer
func stop() -> void:
	timer.stop()

func _process(_delta: float) -> void:
	if timer.is_stopped():
		return
	var time_left: float = timer.time_left
	var whole_seconds: int = int(time_left)
	timer_label.text = "%d:%02d" % [floori(time_left / 60.0), whole_seconds % 60]

	var is_low: bool = time_left <= LOW_TIME_SECONDS
	timer_label.add_theme_color_override("font_color", COLOR_LOW if is_low else _default_color)
	if is_low and whole_seconds != _last_whole_second:
		_last_whole_second = whole_seconds
		_tick()

## Small scale bump once per second while time is running out.
func _tick() -> void:
	pivot_offset = size / 2.0
	if _tick_tween and _tick_tween.is_valid():
		_tick_tween.kill()
	_tick_tween = create_tween()
	_tick_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.06)
	_tick_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
