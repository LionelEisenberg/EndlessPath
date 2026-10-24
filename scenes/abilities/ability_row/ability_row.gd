class_name AbilityRow
extends PanelContainer

## One ability in the Abilities book's list: icon, name and costs on the
## book's row bar, with its loadout key when equipped. Hovering selects it,
## right-click asks to equip or unequip it, and it drags onto a loadout slot.

signal hovered(row: AbilityRow)
signal quick_equip_requested(ability_id: String)

const KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
const DragPreviewScene: PackedScene = preload("res://scenes/abilities/ability_row/ability_drag_preview.tscn")

const _STYLE_NORMAL: StringName = &"PanelBookRow"
const _STYLE_SELECTED: StringName = &"PanelBookRowSelected"

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _key_chip: Label = %KeyChip

var _ability_data: AbilityData = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows the ability. slot_index is its loadout slot, or -1 when unequipped.
func setup(ability_data: AbilityData, slot_index: int) -> void:
	_ability_data = ability_data
	_icon.texture = ability_data.icon
	_name_label.text = ability_data.ability_name
	_cost_label.text = format_costs(ability_data)
	var has_key: bool = slot_index >= 0 and slot_index < KEY_LABELS.size()
	_key_chip.visible = has_key
	if has_key:
		_key_chip.text = KEY_LABELS[slot_index]

## The ability this row shows.
func get_ability_data() -> AbilityData:
	return _ability_data

## Shows or clears the selected look.
func set_selected(is_selected: bool) -> void:
	theme_type_variation = _STYLE_SELECTED if is_selected else _STYLE_NORMAL

## True while this row has the selected look.
func is_selected() -> bool:
	return theme_type_variation == _STYLE_SELECTED

## The ability's costs and timings in one short line, for example
## "8 Madra · 3 s" or "10 Madra · 15 s · 1 s cast".
static func format_costs(ability_data: AbilityData) -> String:
	var parts: PackedStringArray = []
	var cost: String = format_cost(ability_data)
	if not cost.is_empty():
		parts.append(cost)
	parts.append(format_seconds(ability_data.base_cooldown))
	if ability_data.cast_time > 0.0:
		parts.append("%s cast" % format_seconds(ability_data.cast_time))
	return " · ".join(parts)

## What casting the ability costs, for example "10 Madra" or
## "8 Madra · 5 Stamina"; "" when it is free.
static func format_cost(ability_data: AbilityData) -> String:
	var parts: PackedStringArray = []
	if ability_data.health_cost > 0.0:
		parts.append("%s Health" % format_number(ability_data.health_cost))
	if ability_data.madra_cost > 0.0:
		parts.append("%s Madra" % format_number(ability_data.madra_cost))
	if ability_data.stamina_cost > 0.0:
		parts.append("%s Stamina" % format_number(ability_data.stamina_cost))
	return " · ".join(parts)

## A duration, for example "15 s" or "0.5 s".
static func format_seconds(seconds: float) -> String:
	return "%s s" % format_number(seconds)

## Roughly what the ability hits for, for example "about 25 Physical damage":
## its first effect on the target, valued for the caster's attributes
## (CombatEffectData.calculate_value(), before the target's defence), rounded,
## with its damage type. "" when that first effect is not damage, or when the
## ability has no effect on a target.
static func format_damage(ability_data: AbilityData, caster_attributes: CharacterAttributesData) -> String:
	if ability_data.effects_on_target.is_empty():
		return ""
	var effect: CombatEffectData = ability_data.effects_on_target[0]
	if effect == null or effect.effect_type != CombatEffectData.EffectType.DAMAGE:
		return ""
	var damage_type: String = (CombatEffectData.DamageType.keys()[effect.damage_type] as String).capitalize()
	return "about %d %s damage" % [roundi(effect.calculate_value(caster_attributes)), damage_type]

## Whole numbers without a decimal point ("3"), others with up to two ("0.5").
static func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2)

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and _ability_data:
		quick_equip_requested.emit(_ability_data.ability_id)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _ability_data:
		return null
	var preview: AbilityDragPreview = DragPreviewScene.instantiate() as AbilityDragPreview
	preview.setup(_ability_data.icon)
	set_drag_preview(preview)
	return {"ability_id": _ability_data.ability_id}

func _on_mouse_entered() -> void:
	hovered.emit(self)
