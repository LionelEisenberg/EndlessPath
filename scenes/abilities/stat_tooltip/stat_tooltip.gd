class_name StatTooltip
extends PanelContainer

## Reusable tooltip for stat labels.
## Call show_for_label() to display, hide_tooltip() to dismiss.

var _title_label: Label = null
var _body_label: Label = null

func _init() -> void:
	theme_type_variation = &"PanelTooltip"
	top_level = true
	z_index = 100
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"LabelAbilityBody"
	vbox.add_child(_title_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_body_label = Label.new()
	_body_label.theme_type_variation = &"LabelAbilityMuted"
	_body_label.custom_minimum_size.x = 220
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body_label)

## Shows the tooltip above the given control with the provided data.
func show_for_label(label: Control, data: Dictionary) -> void:
	if data.is_empty():
		return
	_build_content(data)
	visible = true
	reset_size()
	var rect: Rect2 = label.get_global_rect()
	global_position = Vector2(rect.position.x, rect.position.y - size.y - 8)

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false

# ----- Private -----

func _build_content(data: Dictionary) -> void:
	var type: String = data.get("type", "")
	match type:
		"total":
			_title_label.text = "Total Damage"
			_body_label.text = _build_total_body(data)
		"scaling":
			_title_label.text = "%s Scaling" % data["attr_name"]
			_body_label.text = "Your %s: %.0f\nScaling: %.0f%%\nContribution: +%.1f damage" % [
				data["attr_name"], data["raw_value"],
				data["scaling_pct"] * 100, data["contribution"]
			]
		"base":
			_title_label.text = "Base Damage"
			_body_label.text = "Flat damage before attribute scaling"
		"cd":
			_title_label.text = "Cooldown"
			_body_label.text = "%.1f seconds between uses" % data["value"]
		"cast":
			_title_label.text = "Cast Time"
			if data["value"] <= 0.0:
				_body_label.text = "Fires instantly"
			else:
				_body_label.text = "%.1f second channel before firing" % data["value"]
		"cost":
			_title_label.text = "%s Cost" % data["resource"]
			_body_label.text = "Costs %.0f %s per use" % [data["value"], data["resource"]]
		_:
			_title_label.text = data.get("type", "").capitalize()
			_body_label.text = ""

func _build_total_body(data: Dictionary) -> String:
	var lines: Array[String] = []
	var effect: CombatEffectData = data["effect"]
	var attrs: CharacterAttributesData = data["attrs"]
	var AT: = CharacterAttributesData.AttributeType

	lines.append("Base Damage: %.0f" % data["base_value"])

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
	lines.append("Total: %.1f" % data["total"])
	return "\n".join(lines)
