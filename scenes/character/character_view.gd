class_name CharacterView
extends MenuBookView

## Character book: the eight cultivation attributes as tiles on the left page,
## a Physical and a Spiritual row of four, and the attribute you point at
## described on the right page with what it affects. The right page keeps the
## last attribute pointed at; Strength is shown when the book opens.

## What the right page says about each attribute: a description and the
## formulas it feeds. The vitals formulas are built from
## CharacterAttributesData's constants, the rules every VitalsManager runs; the
## defense ones are written to match CombatEffectData.calculate_damage.
## Abilities that scale with the attribute are added from their data.
const ATTRIBUTE_DETAILS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: {
		"description": "Raw physical power. Scales melee damage and physical ability effects.",
		"formulas": [],
	},
	CharacterAttributesData.AttributeType.BODY: {
		"description": "Physical constitution. Determines your health and stamina pools.",
		"formulas": [
			"Max Health = Body × %d" % CharacterAttributesData.HEALTH_PER_BODY,
			"Max Stamina = Body × %d" % CharacterAttributesData.STAMINA_PER_BODY,
		],
	},
	CharacterAttributesData.AttributeType.AGILITY: {
		"description": "Speed and precision. Scales technique-based damage.",
		"formulas": [],
	},
	CharacterAttributesData.AttributeType.RESILIENCE: {
		"description": "Physical toughness. Reduces incoming physical damage.",
		"formulas": ["Physical damage taken × 100 / (100 + Resilience)"],
	},
	CharacterAttributesData.AttributeType.SPIRIT: {
		"description": "Spiritual awareness and power. Scales Madra-based abilities and provides spiritual defense.",
		"formulas": ["Spirit damage taken × 100 / (100 + Spirit)"],
	},
	CharacterAttributesData.AttributeType.FOUNDATION: {
		"description": "Depth of your Madra channels. Determines your Madra capacity.",
		"formulas": ["Max Madra = Foundation × %d" % CharacterAttributesData.MADRA_PER_FOUNDATION],
	},
	CharacterAttributesData.AttributeType.CONTROL: {
		"description": "Mastery over your techniques. Will reduce ability cooldowns.",
		"formulas": [],
	},
	CharacterAttributesData.AttributeType.WILLPOWER: {
		"description": "Mental fortitude. Reduces incoming mixed damage.",
		"formulas": ["Mixed damage is defended by (Resilience + Willpower) / 2"],
	},
}

## What the effects card says for an attribute that affects nothing yet.
const NO_EFFECTS_TEXT: String = "Not yet active"

## Marks each effect line, as the Path book does.
const _EFFECT_MARK: String = "▲ "

@onready var _physical_tiles: GridContainer = %PhysicalTiles
@onready var _spiritual_tiles: GridContainer = %SpiritualTiles
@onready var _detail_plaque: Label = %DetailPlaque
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name: Label = %DetailName
@onready var _detail_value: Label = %DetailValue
@onready var _detail_group: Label = %DetailGroup
@onready var _detail_description: Label = %DetailDescription
@onready var _effects_label: Label = %EffectsLabel

## All attribute tiles, looked up by type for refreshing.
var _tiles_by_type: Dictionary = {}

## The tile the right page describes.
var _selected_tile: AttributeTile = null

func _ready() -> void:
	super._ready()
	for tile: AttributeTile in _find_all_tiles():
		_tiles_by_type[tile.attribute_type] = tile
		tile.hovered.connect(_on_tile_hovered)

## Refreshes all attribute values from CharacterManager.
func refresh() -> void:
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: CharacterAttributesData.AttributeType in _tiles_by_type:
		var tile: AttributeTile = _tiles_by_type[attr_type]
		tile.set_value(attrs.get_attribute(attr_type))
	if _selected_tile:
		_show_details(_selected_tile)

## Describes the given attribute on the right page and marks its tile.
## Pointing again at the attribute already described changes nothing.
func select_attribute(attr_type: CharacterAttributesData.AttributeType) -> void:
	var tile: AttributeTile = _tiles_by_type.get(attr_type)
	if tile == null or tile == _selected_tile:
		return
	if _selected_tile:
		_selected_tile.set_selected(false)
	_selected_tile = tile
	tile.set_selected(true)
	_show_details(tile)

## The attribute the right page describes.
func get_selected_attribute() -> CharacterAttributesData.AttributeType:
	return _selected_tile.attribute_type if _selected_tile else CharacterAttributesData.AttributeType.STRENGTH

func _before_open() -> void:
	select_attribute(CharacterAttributesData.AttributeType.STRENGTH)
	refresh()

func _find_all_tiles() -> Array[AttributeTile]:
	var tiles: Array[AttributeTile] = []
	for group: GridContainer in [_physical_tiles, _spiritual_tiles]:
		for child: Node in group.get_children():
			if child is AttributeTile:
				tiles.append(child as AttributeTile)
	return tiles

func _show_details(tile: AttributeTile) -> void:
	var data: Dictionary = ATTRIBUTE_DETAILS.get(tile.attribute_type, {})
	var value: float = CharacterManager.get_total_attributes_data().get_attribute(tile.attribute_type)
	_detail_plaque.text = tile.attribute_name
	_detail_icon.texture = tile.icon_texture
	_detail_name.text = tile.attribute_name
	_detail_value.text = "%.0f" % value
	_detail_group.text = "Physical attribute" if tile.get_parent() == _physical_tiles else "Spiritual attribute"
	_detail_description.text = data.get("description", "")
	_effects_label.text = _describe_effects(tile.attribute_type)

## The attribute's formulas, then each unlocked ability that scales with it,
## one marked line each, for example "▲ Basic Strike: +1 damage per point".
func _describe_effects(attr_type: CharacterAttributesData.AttributeType) -> String:
	var lines: PackedStringArray = []
	for formula: String in ATTRIBUTE_DETAILS.get(attr_type, {}).get("formulas", []):
		lines.append(_EFFECT_MARK + formula)
	for ability: AbilityData in AbilityManager.get_unlocked_abilities():
		for effects: Array in [ability.effects_on_target, ability.effects_on_self]:
			for effect: CombatEffectData in effects:
				var scaling: float = effect.get_scaling(attr_type)
				if scaling != 0.0:
					lines.append("%s%s: +%s %s per point" % [
						_EFFECT_MARK, ability.ability_name, AbilityRow.format_number(scaling), _describe_effect_kind(effect),
					])
	if lines.is_empty():
		return NO_EFFECTS_TEXT
	return "\n".join(lines)

func _describe_effect_kind(effect: CombatEffectData) -> String:
	match effect.effect_type:
		CombatEffectData.EffectType.DAMAGE:
			return "damage"
		CombatEffectData.EffectType.HEAL:
			return "healing"
	return "effect"

func _on_tile_hovered(tile: AttributeTile) -> void:
	select_attribute(tile.attribute_type)
