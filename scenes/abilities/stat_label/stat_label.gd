class_name StatLabel
extends PanelContainer

## A single hoverable stat pill for AbilityStatsDisplay.
## Shows a stat name + value with hover brightening and tooltip support.

signal hovered(label: StatLabel)
signal unhovered()

var _stat_name: String = ""
var _stat_value: float = 0.0
var _stat_color: Color = Color.WHITE
var _format_callback: Callable
var _tooltip_data: Dictionary = {}
var _value_tween: Tween = null

@onready var _label: Label = %StatText

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_style()

## Configures the stat label.
func setup(stat_name: String, value: float, color: Color, format_cb: Callable, tooltip: Dictionary) -> void:
	_stat_name = stat_name
	_stat_value = value
	_stat_color = color
	_format_callback = format_cb
	_tooltip_data = tooltip
	_update_text()

## Returns tooltip data for this label.
func get_tooltip_data() -> Dictionary:
	return _tooltip_data

## Animates the value to a new number over 0.3s.
func set_value(new_val: float) -> void:
	if _value_tween and _value_tween.is_valid():
		_value_tween.kill()
	_value_tween = create_tween()
	_value_tween.set_ease(Tween.EASE_OUT)
	_value_tween.set_trans(Tween.TRANS_CUBIC)
	var start: float = _stat_value
	_value_tween.tween_method(func(v: float) -> void:
		_stat_value = v
		_update_text()
	, start, new_val, 0.3)

func _update_text() -> void:
	if _format_callback.is_valid():
		_label.text = _format_callback.call(_stat_name, _stat_value)

func _build_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.18, 0.13, 0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	add_theme_stylebox_override("panel", style)

func _on_mouse_entered() -> void:
	modulate = Color(1.2, 1.15, 1.1, 1.0)
	hovered.emit(self)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	unhovered.emit()
