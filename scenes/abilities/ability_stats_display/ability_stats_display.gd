class_name AbilityStatsDisplay
extends HFlowContainer

## Displays ability stats as hoverable pill labels with tooltips.
## Creates StatLabel instances dynamically from AbilityData.
## Use DisplayMode to control which pills are shown.
## Tooltip display delegated to StatTooltip class.

enum DisplayMode { DAMAGE, TIMING_COSTS, DAMAGE_TOTAL }

const StatLabelScene: PackedScene = preload("res://scenes/abilities/stat_label/stat_label.tscn")

var _ability_data: AbilityData = null
var _stat_labels: Array[StatLabel] = []
var _tooltip: StatTooltip = null

func _ready() -> void:
	_tooltip = StatTooltip.new()
	add_child(_tooltip)

## Builds the stats display from ability data.
func setup(ability_data: AbilityData, mode: DisplayMode = DisplayMode.DAMAGE) -> void:
	_ability_data = ability_data
	_clear_children()

	match mode:
		DisplayMode.DAMAGE:
			_setup_damage(ability_data)
		DisplayMode.TIMING_COSTS:
			_setup_timing_costs(ability_data)
		DisplayMode.DAMAGE_TOTAL:
			_setup_damage_total(ability_data)

func _setup_damage(ability_data: AbilityData) -> void:
	var effect: CombatEffectData = null
	if not ability_data.effects_on_target.is_empty():
		effect = ability_data.effects_on_target[0]
	if not effect or not _has_damage_or_scaling(effect):
		return

	var AT: = CharacterAttributesData.AttributeType
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var total: float = effect.calculate_value(attrs)

	# Total damage label with animated pulsing gold border
	var total_label: StatLabel = _create_label(
		"DMG", total, Color("#D4A84A"),
		func(n: String, v: float) -> String: return "%s %.0f" % [n, v],
		_build_total_tooltip(effect, attrs, total)
	)
	_setup_damage_border_pulse(total_label)

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

func _setup_damage_total(ability_data: AbilityData) -> void:
	var effect: CombatEffectData = null
	if not ability_data.effects_on_target.is_empty():
		effect = ability_data.effects_on_target[0]
	if not effect or not _has_damage_or_scaling(effect):
		return

	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var total: float = effect.calculate_value(attrs)

	var total_label: StatLabel = _create_label(
		"DMG", total, Color("#D4A84A"),
		func(n: String, v: float) -> String: return "%s %.0f" % [n, v],
		_build_total_tooltip(effect, attrs, total)
	)
	_setup_damage_border_pulse(total_label)

func _setup_timing_costs(ability_data: AbilityData) -> void:
	# Cooldown
	_create_label(
		"CD", ability_data.base_cooldown, Color("#D4A84A"),
		func(n: String, v: float) -> String: return "%s: %.1fs" % [n, v],
		{"type": "cd", "value": ability_data.base_cooldown}
	)

	# Cast time
	var cast_val: float = ability_data.cast_time
	_create_label(
		"Cast", cast_val, Color("#F0E8D8"),
		func(n: String, v: float) -> String:
			return "Cast: Instant" if v <= 0.0 else "%s: %.1fs" % [n, v],
		{"type": "cast", "value": cast_val}
	)

	# Separator between timing and costs
	_add_separator()

	# Costs (only non-zero)
	if ability_data.madra_cost > 0:
		_create_label(
			"Madra", ability_data.madra_cost, Color("#6BA4D4"),
			func(n: String, v: float) -> String: return "%s: %.0f" % [n, v],
			{"type": "cost", "resource": "Madra", "value": ability_data.madra_cost}
		)
	if ability_data.stamina_cost > 0:
		_create_label(
			"Stamina", ability_data.stamina_cost, Color("#D4A84A"),
			func(n: String, v: float) -> String: return "%s: %.0f" % [n, v],
			{"type": "cost", "resource": "Stamina", "value": ability_data.stamina_cost}
		)
	if ability_data.health_cost > 0:
		_create_label(
			"Health", ability_data.health_cost, Color("#E06060"),
			func(n: String, v: float) -> String: return "%s: %.0f" % [n, v],
			{"type": "cost", "resource": "Health", "value": ability_data.health_cost}
		)

# ----- Private -----

func _add_separator() -> void:
	var sep: Label = Label.new()
	sep.text = "\u00b7"
	sep.theme_type_variation = &"LabelSeparatorDot"
	add_child(sep)

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

func _clear_children() -> void:
	for child: Node in get_children():
		if child == _tooltip:
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

func _on_label_hovered(label: StatLabel) -> void:
	_tooltip.show_for_label(label, label.get_tooltip_data())

func _on_label_unhovered() -> void:
	_tooltip.hide_tooltip()

# ----- Damage Border Pulse -----

func _setup_damage_border_pulse(label: StatLabel) -> void:
	# Create a unique StyleBoxFlat for this label with a thick gold border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.10, 0.07, 0.6)
	style.set_border_width_all(2)
	style.border_color = Color(0.83, 0.66, 0.29, 0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	label.add_theme_stylebox_override("panel", style)

	# Infinite pulse tween on the border color
	var dim_color: Color = Color(0.83, 0.66, 0.29, 0.3)
	var bright_color: Color = Color(1.0, 0.85, 0.4, 1.0)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(style, "border_color", bright_color, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(style, "border_color", dim_color, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
