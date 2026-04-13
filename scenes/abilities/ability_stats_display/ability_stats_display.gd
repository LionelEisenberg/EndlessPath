class_name AbilityStatsDisplay
extends HFlowContainer

## Displays ability stats as hoverable pill labels with tooltips.
## Creates StatLabel instances dynamically from AbilityData.

const StatLabelScene: PackedScene = preload("res://scenes/abilities/stat_label/stat_label.tscn")

var _ability_data: AbilityData = null
var _stat_labels: Array[StatLabel] = []
var _tooltip_tween: Tween = null

@onready var _tooltip: PanelContainer = %StatTooltip
@onready var _tooltip_title: Label = %TooltipTitle
@onready var _tooltip_body: RichTextLabel = %TooltipBody

func _ready() -> void:
	_tooltip.visible = false
	_tooltip.z_index = 100
	_tooltip.top_level = true

## Builds the stats display from ability data.
func setup(ability_data: AbilityData) -> void:
	_ability_data = ability_data
	_clear_stat_labels()

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

func _create_label(stat_name: String, value: float, color: Color, format_cb: Callable, tooltip: Dictionary) -> StatLabel:
	var label: StatLabel = StatLabelScene.instantiate()
	add_child(label)
	label.setup(stat_name, value, color, format_cb, tooltip)
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

func _clear_stat_labels() -> void:
	for label: StatLabel in _stat_labels:
		label.queue_free()
	_stat_labels.clear()
	# Also remove separators
	for child: Node in get_children():
		if child is Label and child != _tooltip and not child.is_in_group("tooltip"):
			child.queue_free()

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

func _on_label_hovered(label: StatLabel) -> void:
	var data: Dictionary = label.get_tooltip_data()
	_build_tooltip_content(data)
	_tooltip.reset_size()
	_tooltip.visible = true
	# Position above the label after size is resolved
	await get_tree().process_frame
	var label_rect: Rect2 = label.get_global_rect()
	_tooltip.global_position = Vector2(
		label_rect.position.x,
		label_rect.position.y - _tooltip.size.y - 8
	)
	# Fade in
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip.modulate = Color(1, 1, 1, 0)
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_label_unhovered() -> void:
	_tooltip.visible = false

func _build_tooltip_content(data: Dictionary) -> void:
	var type: String = data.get("type", "")
	_tooltip_body.clear()

	match type:
		"total":
			_tooltip_title.text = "Total Damage"
			var effect: CombatEffectData = data["effect"]
			var attrs: CharacterAttributesData = data["attrs"]
			var AT2: = CharacterAttributesData.AttributeType
			_tooltip_body.append_text("[color=#A89070]Base Damage:[/color] [color=#F0E8D8]%.0f[/color]\n" % data["base_value"])
			_append_tooltip_scaling(effect, "strength_scaling", "STR", attrs.get_attribute(AT2.STRENGTH), "#E06060")
			_append_tooltip_scaling(effect, "body_scaling", "BODY", attrs.get_attribute(AT2.BODY), "#D4A84A")
			_append_tooltip_scaling(effect, "agility_scaling", "AGI", attrs.get_attribute(AT2.AGILITY), "#7DCE82")
			_append_tooltip_scaling(effect, "spirit_scaling", "SPI", attrs.get_attribute(AT2.SPIRIT), "#6BA4D4")
			_append_tooltip_scaling(effect, "foundation_scaling", "FND", attrs.get_attribute(AT2.FOUNDATION), "#B07DD4")
			_append_tooltip_scaling(effect, "control_scaling", "CTL", attrs.get_attribute(AT2.CONTROL), "#60C4B0")
			_append_tooltip_scaling(effect, "resilience_scaling", "RES", attrs.get_attribute(AT2.RESILIENCE), "#C4884A")
			_append_tooltip_scaling(effect, "willpower_scaling", "WIL", attrs.get_attribute(AT2.WILLPOWER), "#D470A0")
			_tooltip_body.append_text("\n[color=#D4A84A]Total: %.1f[/color]" % data["total"])
		"scaling":
			_tooltip_title.text = "%s Scaling" % data["attr_name"]
			_tooltip_body.append_text("[color=#A89070]Your %s:[/color] [color=#F0E8D8]%.0f[/color]\n" % [data["attr_name"], data["raw_value"]])
			_tooltip_body.append_text("[color=#A89070]Scaling:[/color] [color=#F0E8D8]%.0f%%[/color]\n" % [data["scaling_pct"] * 100])
			_tooltip_body.append_text("\n[color=%s]Contribution: +%.1f damage[/color]" % [data["color"].to_html(), data["contribution"]])
		"base":
			_tooltip_title.text = "Base Damage"
			_tooltip_body.append_text("[color=#A89070]Flat damage before attribute scaling[/color]")

func _append_tooltip_scaling(effect: CombatEffectData, prop: String, attr_name: String, raw: float, color: String) -> void:
	var scaling: float = effect.get(prop)
	if scaling == 0.0:
		return
	var contrib: float = scaling * raw
	_tooltip_body.append_text("[color=%s]+ %s (%.0f \u00d7 %.0f%%) = +%.1f[/color]\n" % [color, attr_name, raw, scaling * 100, contrib])
