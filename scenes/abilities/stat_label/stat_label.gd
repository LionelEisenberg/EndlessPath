class_name StatLabel
extends PanelContainer

## A single hoverable stat pill for AbilityStatsDisplay.
## Shows a stat name + value with hover brightening.
## Tooltip is handled via Godot's built-in _make_custom_tooltip() system.

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
	mouse_filter = Control.MOUSE_FILTER_STOP

## Configures the stat label.
func setup(stat_name: String, value: float, color: Color, format_cb: Callable, tooltip: Dictionary) -> void:
	_stat_name = stat_name
	_stat_value = value
	_stat_color = color
	_format_callback = format_cb
	_tooltip_data = tooltip
	tooltip_text = stat_name  # Triggers _make_custom_tooltip
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

func _on_mouse_entered() -> void:
	modulate = Color(1.2, 1.15, 1.1, 1.0)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE

## Godot's built-in tooltip — returns a custom Control, Godot handles sizing/positioning.
func _make_custom_tooltip(_for_text: String) -> Control:
	if _tooltip_data.is_empty():
		return null

	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"PanelTooltip"
	panel.custom_minimum_size = Vector2(220, 0)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.theme_type_variation = &"LabelAbilityBody"
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var body: Label = Label.new()
	body.theme_type_variation = &"LabelAbilityMuted"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var type: String = _tooltip_data.get("type", "")
	match type:
		"total":
			title.text = "Total Damage"
			body.text = _build_total_body()
		"scaling":
			title.text = "%s Scaling" % _tooltip_data["attr_name"]
			body.text = "Your %s: %.0f\nScaling: %.0f%%\nContribution: +%.1f damage" % [
				_tooltip_data["attr_name"],
				_tooltip_data["raw_value"],
				_tooltip_data["scaling_pct"] * 100,
				_tooltip_data["contribution"]
			]
		"base":
			title.text = "Base Damage"
			body.text = "Flat damage before attribute scaling"

	return panel

func _build_total_body() -> String:
	var lines: Array[String] = []
	var effect: CombatEffectData = _tooltip_data["effect"]
	var attrs: CharacterAttributesData = _tooltip_data["attrs"]
	var AT: = CharacterAttributesData.AttributeType

	lines.append("Base Damage: %.0f" % _tooltip_data["base_value"])

	var scaling_map: Array[Array] = [
		["STR", "strength_scaling", AT.STRENGTH],
		["BODY", "body_scaling", AT.BODY],
		["AGI", "agility_scaling", AT.AGILITY],
		["SPI", "spirit_scaling", AT.SPIRIT],
		["FND", "foundation_scaling", AT.FOUNDATION],
		["CTL", "control_scaling", AT.CONTROL],
		["RES", "resilience_scaling", AT.RESILIENCE],
		["WIL", "willpower_scaling", AT.WILLPOWER],
	]

	for entry: Array in scaling_map:
		var scaling: float = effect.get(entry[1])
		if scaling == 0.0:
			continue
		var raw: float = attrs.get_attribute(entry[2])
		var contrib: float = scaling * raw
		lines.append("+ %s (%.0f x %.0f%%) = +%.1f" % [entry[0], raw, scaling * 100, contrib])

	lines.append("")
	lines.append("Total: %.1f" % _tooltip_data["total"])
	return "\n".join(lines)
