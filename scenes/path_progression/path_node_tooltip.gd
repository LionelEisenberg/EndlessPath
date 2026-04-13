class_name PathNodeTooltip
extends Control
## Tooltip popup for path tree nodes.
## Shows node details on hover with animated show/hide.
## Positioned to the right of the parent node with effect descriptions.

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _description_label: RichTextLabel = %DescriptionLabel
@onready var _cost_label: Label = %CostLabel
@onready var _level_label: Label = %LevelLabel
@onready var _effects_container: VBoxContainer = %EffectsContainer
@onready var _effects_sep: HSeparator = %EffectsSep

var _tween: Tween = null

## Maps effect types to human-readable descriptions
const EFFECT_LABELS: Dictionary = {
	PathNodeEffectData.EffectType.ATTRIBUTE_BONUS: "Attribute Bonus",
	PathNodeEffectData.EffectType.MADRA_GENERATION_MULT: "Madra Generation",
	PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS: "Max Madra",
	PathNodeEffectData.EffectType.CORE_DENSITY_XP_MULT: "Core Density XP",
	PathNodeEffectData.EffectType.STAMINA_RECOVERY_MULT: "Stamina Recovery",
	PathNodeEffectData.EffectType.CYCLING_ACCURACY_BONUS: "Cycling Accuracy",
	PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT: "Madra Return",
	PathNodeEffectData.EffectType.MADRA_ON_LEVEL_UP: "Madra on Level Up",
	PathNodeEffectData.EffectType.UNLOCK_ABILITY: "Unlocks Ability",
	PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE: "Unlocks Technique",
}

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populate the tooltip with node data and animate it in.
func show_tooltip(data: PathNodeData, current_level: int) -> void:
	_name_label.text = data.display_name
	_type_label.text = _get_type_text(data.node_type)
	_description_label.text = data.description
	var is_fully_purchased: bool = current_level >= data.max_purchases
	var is_purchased: bool = current_level >= 1

	if is_fully_purchased:
		_cost_label.text = "Purchased"
	elif is_purchased and data.max_purchases > 1:
		_cost_label.text = "Cost: %d point%s" % [data.point_cost, "" if data.point_cost == 1 else "s"]
	else:
		_cost_label.text = "Cost: %d point%s" % [data.point_cost, "" if data.point_cost == 1 else "s"]

	if data.max_purchases > 1:
		_level_label.text = "Level: %d/%d" % [current_level, data.max_purchases]
	else:
		_level_label.text = ""

	_populate_effects(data)

	visible = true
	_animate_in()


## Animate the tooltip out and hide it.
func hide_tooltip() -> void:
	_animate_out()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _get_type_text(node_type: PathNodeData.NodeType) -> String:
	match node_type:
		PathNodeData.NodeType.KEYSTONE:
			return "Keystone"
		PathNodeData.NodeType.MAJOR:
			return "Major"
		PathNodeData.NodeType.MINOR:
			return "Minor"
		PathNodeData.NodeType.REPEATABLE:
			return "Repeatable"
	return ""


func _populate_effects(data: PathNodeData) -> void:
	# Clear old effects
	for child: Node in _effects_container.get_children():
		child.queue_free()

	if data.effects.is_empty():
		_effects_container.visible = false
		_effects_sep.visible = false
		return

	_effects_container.visible = true
	_effects_sep.visible = true

	for effect: PathNodeEffectData in data.effects:
		var effect_label: Label = Label.new()
		effect_label.theme_type_variation = &"LabelPathGreen"
		effect_label.text = _format_effect(effect)
		_effects_container.add_child(effect_label)


func _format_effect(effect: PathNodeEffectData) -> String:
	var prefix: String = "\u25B2 "  # Up triangle
	match effect.effect_type:
		PathNodeEffectData.EffectType.ATTRIBUTE_BONUS:
			return "%s+%.0f %s" % [prefix, effect.float_value, _get_attribute_name(effect.attribute_type)]
		PathNodeEffectData.EffectType.MADRA_GENERATION_MULT:
			var pct: float = (effect.float_value - 1.0) * 100.0
			return "%s+%.0f%% Madra Generation" % [prefix, pct]
		PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS:
			return "%s+%.0f Max Madra" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.CORE_DENSITY_XP_MULT:
			var pct: float = (effect.float_value - 1.0) * 100.0
			return "%s+%.0f%% Core Density XP" % [prefix, pct]
		PathNodeEffectData.EffectType.STAMINA_RECOVERY_MULT:
			var pct: float = (effect.float_value - 1.0) * 100.0
			return "%s+%.0f%% Stamina Recovery" % [prefix, pct]
		PathNodeEffectData.EffectType.CYCLING_ACCURACY_BONUS:
			return "%s+%.0f Cycling Accuracy" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT:
			var pct: float = effect.float_value * 100.0
			return "%s+%.0f%% Madra Return" % [prefix, pct]
		PathNodeEffectData.EffectType.MADRA_ON_LEVEL_UP:
			return "%s+%.0f Madra on Level Up" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.UNLOCK_ABILITY:
			return "%sUnlocks: %s" % [prefix, effect.string_value.get_file().get_basename()]
		PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
			return "%sUnlocks: %s" % [prefix, effect.string_value]
	return ""


func _get_attribute_name(attr_type: CharacterAttributesData.AttributeType) -> String:
	return CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()


func _animate_in() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _animate_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void: visible = false)
