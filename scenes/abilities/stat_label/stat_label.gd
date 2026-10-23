class_name StatLabel
extends PanelContainer

## A single hoverable stat pill for AbilityStatsDisplay.
## Emits hovered/unhovered signals — tooltip is managed by the parent display.

signal hovered(label: StatLabel)
signal unhovered()

var _stat_name: String = ""
var _stat_value: float = 0.0
var _stat_color: Color = Color.WHITE
var _format_callback: Callable
var _tooltip_data: Dictionary = {}

@onready var _label: Label = %StatText

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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

func _update_text() -> void:
	if _format_callback.is_valid():
		_label.text = _format_callback.call(_stat_name, _stat_value)

func _on_mouse_entered() -> void:
	modulate = Color(1.2, 1.15, 1.1, 1.0)
	hovered.emit(self)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	unhovered.emit()
