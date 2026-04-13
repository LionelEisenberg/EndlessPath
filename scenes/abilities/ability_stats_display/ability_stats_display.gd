class_name AbilityStatsDisplay
extends HFlowContainer

## Displays ability stats as hoverable pill labels with tooltips.
## Creates StatLabel instances dynamically from AbilityData.
## Manages a shared tooltip panel shown on StatLabel hover.

const StatLabelScene: PackedScene = preload("res://scenes/abilities/stat_label/stat_label.tscn")

var _ability_data: AbilityData = null
var _stat_labels: Array[StatLabel] = []
var _tooltip_panel: PanelContainer = null

func _ready() -> void:
	_create_tooltip_panel()

## Builds the stats display from ability data.
func setup(ability_data: AbilityData) -> void:
	_ability_data = ability_data
	_clear_children()

	var effect: CombatEffectData = null
	var has_damage: bool = false
	if not ability_data.effects.is_empty():
		effect = ability_data.effects[0]
		has_damage = _has_damage_or_scaling(effect)

	var AT: = CharacterAttributesData.AttributeType
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()

	# Damage stats (only for offensive abilities with damage)
	if effect and has_damage:
		var total: float = effect.calculate_value(attrs)

		# Total damage label (with glow shader)
		var total_label: StatLabel = _create_label(
			"DMG", total, Color("#D4A84A"),
			func(n: String, v: float) -> String: return "%s %.0f" % [n, v],
			_build_total_tooltip(effect, attrs, total)
		)
		var shader: ShaderMaterial = ShaderMaterial.new()
		shader.shader = preload("res://assets/shaders/damage_total_glow.gdshader")
		total_label.get_node("%StatText").material = shader

		# Base damage
		_create_label(
			"Base", effect.base_value, Color("#F0E8D8"),
			func(n: String, v: float) -> String: return "%s: %.0f" % [n, v],
			{"type": "base", "value": effect.base_value}
		)

		# Per-attribute scaling
		_add_scaling_label("STR", effect.strength_scaling, attrs.get_attribute(AT.STRENGTH), Color("#E06060"))
		_add_scaling_label("BODY", effect.body_scaling, attrs.get_attribute(AT.BODY), Color("#D4A84A"))
		_add_scaling_label("AGI", effect.agility_scaling, attrs.get_attribute(AT.AGILITY), Color("#7DCE82"))
		_add_scaling_label("SPI", effect.spirit_scaling, attrs.get_attribute(AT.SPIRIT), Color("#6BA4D4"))
		_add_scaling_label("FND", effect.foundation_scaling, attrs.get_attribute(AT.FOUNDATION), Color("#B07DD4"))
		_add_scaling_label("CTL", effect.control_scaling, attrs.get_attribute(AT.CONTROL), Color("#60C4B0"))
		_add_scaling_label("RES", effect.resilience_scaling, attrs.get_attribute(AT.RESILIENCE), Color("#C4884A"))
		_add_scaling_label("WIL", effect.willpower_scaling, attrs.get_attribute(AT.WILLPOWER), Color("#D470A0"))

# ----- Private -----

func _create_label(stat_name: String, value: float, color: Color, format_cb: Callable, tooltip_data: Dictionary) -> StatLabel:
	var label: StatLabel = StatLabelScene.instantiate()
	add_child(label)
	label.setup(stat_name, value, color, format_cb, tooltip_data)
	label.get_node("%StatText").add_theme_color_override("font_color", color)
	label.hovered.connect(_on_label_hovered)
	label.unhovered.connect(_on_label_unhovered)
	_stat_labels.append(label)
	return label

func _add_scaling_label(attr_name: String, scaling: float, raw_value: float, color: Color) -> void:
	if scaling == 0.0:
		return
	var contribution: float = scaling * raw_value
	_create_label(
		attr_name, contribution, color,
		func(n: String, v: float) -> String: return "%s +%.1f" % [n, v],
		{"type": "scaling", "attr_name": attr_name, "raw_value": raw_value, "scaling_pct": scaling, "contribution": contribution, "color": color}
	)

func _add_separator() -> void:
	var sep: Label = Label.new()
	sep.text = "\u00b7"
	sep.theme_type_variation = &"LabelSeparatorDot"
	add_child(sep)

func _clear_children() -> void:
	for child: Node in get_children():
		if child == _tooltip_panel:
			continue
		child.queue_free()
	_stat_labels.clear()

func _build_total_tooltip(effect: CombatEffectData, attrs: CharacterAttributesData, total: float) -> Dictionary:
	return {
		"type": "total",
		"base_value": effect.base_value,
		"total": total,
		"effect": effect,
		"attrs": attrs,
	}

func _has_damage_or_scaling(effect: CombatEffectData) -> bool:
	if effect.base_value != 0.0:
		return true
	for prop: String in ["strength_scaling", "body_scaling", "agility_scaling", "spirit_scaling", "foundation_scaling", "control_scaling", "resilience_scaling", "willpower_scaling"]:
		if effect.get(prop) != 0.0:
			return true
	return false

# ----- Tooltip -----

func _create_tooltip_panel() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.theme_type_variation = &"PanelTooltip"
	_tooltip_panel.top_level = true
	_tooltip_panel.z_index = 100
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_panel)

func _on_label_hovered(label: StatLabel) -> void:
	var data: Dictionary = label.get_tooltip_data()
	if data.is_empty():
		return

	# Build tooltip content with plain Labels (no RichTextLabel sizing issues)
	_clear_tooltip()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_tooltip_panel.add_child(vbox)

	var title: Label = Label.new()
	title.theme_type_variation = &"LabelAbilityBody"
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var body: Label = Label.new()
	body.theme_type_variation = &"LabelAbilityMuted"
	body.custom_minimum_size.x = 220
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var type: String = data.get("type", "")
	match type:
		"total":
			title.text = "Total Damage"
			body.text = _build_total_body(data)
		"scaling":
			title.text = "%s Scaling" % data["attr_name"]
			body.text = "Your %s: %.0f\nScaling: %.0f%%\nContribution: +%.1f damage" % [
				data["attr_name"], data["raw_value"],
				data["scaling_pct"] * 100, data["contribution"]
			]
		"base":
			title.text = "Base Damage"
			body.text = "Flat damage before attribute scaling"

	# Show and position
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	var label_rect: Rect2 = label.get_global_rect()
	_tooltip_panel.global_position = Vector2(
		label_rect.position.x,
		label_rect.position.y - _tooltip_panel.size.y - 8
	)

func _on_label_unhovered() -> void:
	_tooltip_panel.visible = false

func _clear_tooltip() -> void:
	for child: Node in _tooltip_panel.get_children():
		child.queue_free()

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
