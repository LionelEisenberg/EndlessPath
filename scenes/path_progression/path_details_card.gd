class_name PathDetailsCard
extends PanelContainer

## The path book's right-page card. Describes the path node you point at
## (type, cost or purchased state, description, effects), or the path itself
## (description, strengths, weaknesses, cycling, combat) when its plaque is
## pointed at and when the book opens.

## Icon textures per node type, and the path's own. Assign in the Inspector.
@export_group("Icons")
@export var keystone_icon: Texture2D
@export var major_icon: Texture2D
@export var minor_icon: Texture2D
@export var repeatable_icon: Texture2D
@export var path_icon: Texture2D

@onready var _icon: TextureRect = %DetailIcon
@onready var _name_label: Label = %DetailName
@onready var _type_label: Label = %DetailType
@onready var _description_label: Label = %DetailDescription
@onready var _effects_label: Label = %DetailEffects
@onready var _traits_label: Label = %DetailTraits
@onready var _footer_label: Label = %DetailFooter

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Describe a path node at the given purchase level.
func show_node(data: PathNodeData, current_level: int) -> void:
	if data.max_purchases > 1:
		_name_label.text = "%s (%d/%d)" % [data.display_name, current_level, data.max_purchases]
	else:
		_name_label.text = data.display_name
	_icon.texture = _get_icon_for_type(data.node_type)
	_type_label.text = "%s node" % node_type_name(data.node_type)
	_description_label.text = data.description

	var effect_lines: PackedStringArray = []
	for effect: PathNodeEffectData in data.effects:
		effect_lines.append(format_effect(effect))
	_effects_label.text = "\n".join(effect_lines)
	_effects_label.visible = not effect_lines.is_empty()
	_traits_label.visible = false

	if current_level >= data.max_purchases:
		_footer_label.text = "Purchased"
	else:
		_footer_label.text = "Cost: %d point%s · click the node to buy it" % [data.point_cost, "" if data.point_cost == 1 else "s"]
	_footer_label.visible = true

## Describe the path itself.
func show_path(tree: PathTreeData) -> void:
	_name_label.text = tree.path_name
	_icon.texture = path_icon
	_type_label.text = "Path"
	_description_label.text = tree.path_description
	_effects_label.visible = false
	_traits_label.text = "Strengths: %s\nWeaknesses: %s\nCycling: %s\nCombat: %s" % [
		tree.madra_strengths, tree.madra_weaknesses, tree.madra_cycling, tree.madra_combat]
	_traits_label.visible = true
	_footer_label.visible = false

## The player-facing name of a node type.
static func node_type_name(node_type: PathNodeData.NodeType) -> String:
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

## One effect as a line of text, for example "▲ +10% Madra Generation".
static func format_effect(effect: PathNodeEffectData) -> String:
	var prefix: String = "▲ "  # Up triangle
	match effect.effect_type:
		PathNodeEffectData.EffectType.ATTRIBUTE_BONUS:
			return "%s+%.0f %s" % [prefix, effect.float_value, CharacterAttributesData.AttributeType.keys()[effect.attribute_type].capitalize()]
		PathNodeEffectData.EffectType.MADRA_GENERATION_MULT:
			return "%s+%.0f%% Madra Generation" % [prefix, (effect.float_value - 1.0) * 100.0]
		PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS:
			return "%s+%.0f Max Madra" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.CORE_DENSITY_XP_MULT:
			return "%s+%.0f%% Core Density XP" % [prefix, (effect.float_value - 1.0) * 100.0]
		PathNodeEffectData.EffectType.STAMINA_RECOVERY_MULT:
			return "%s+%.0f%% Stamina Recovery" % [prefix, (effect.float_value - 1.0) * 100.0]
		PathNodeEffectData.EffectType.CYCLING_ACCURACY_BONUS:
			return "%s+%.0f Cycling Accuracy" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT:
			return "%s+%.0f%% Madra Return" % [prefix, effect.float_value * 100.0]
		PathNodeEffectData.EffectType.MADRA_ON_LEVEL_UP:
			return "%s+%.0f Madra on Level Up" % [prefix, effect.float_value]
		PathNodeEffectData.EffectType.UNLOCK_ABILITY:
			return "%sUnlocks: %s" % [prefix, effect.string_value.get_file().get_basename().capitalize()]
		PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
			return "%sUnlocks: %s" % [prefix, effect.string_value]
	Log.warn("PathDetailsCard: unhandled effect type %d" % effect.effect_type)
	return "%s(unknown effect)" % prefix

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _get_icon_for_type(node_type: PathNodeData.NodeType) -> Texture2D:
	match node_type:
		PathNodeData.NodeType.KEYSTONE:
			return keystone_icon
		PathNodeData.NodeType.MAJOR:
			return major_icon
		PathNodeData.NodeType.REPEATABLE:
			return repeatable_icon
		_:
			return minor_icon
