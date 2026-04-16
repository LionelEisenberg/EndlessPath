class_name CharacterView
extends Control

## Character View — displays cultivation attributes in two groups with hover tooltips.

@onready var _tooltip: AttributeTooltip = %SharedTooltip
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

## All attribute rows, looked up by type for refreshing.
var _rows_by_type: Dictionary = {}

## Tooltip content for each attribute.
const TOOLTIP_DATA: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: {
		"title": "STRENGTH",
		"description": "Raw physical power. Scales melee damage and physical ability effects.",
		"effects": "Basic Strike: STR x 0.2",
	},
	CharacterAttributesData.AttributeType.BODY: {
		"title": "BODY",
		"description": "Physical constitution. Determines your health and stamina pools.",
		"effects": "Max Health = 100 + BODY x 10\nMax Stamina = 50 + BODY x 5",
	},
	CharacterAttributesData.AttributeType.AGILITY: {
		"title": "AGILITY",
		"description": "Speed and precision. Scales technique-based damage.",
		"effects": "Empty Palm: AGI x 0.3",
	},
	CharacterAttributesData.AttributeType.RESILIENCE: {
		"title": "RESILIENCE",
		"description": "Physical toughness. Reduces incoming physical damage.",
		"effects": "Reduction = DMG x (100 / (100 + RES))",
	},
	CharacterAttributesData.AttributeType.SPIRIT: {
		"title": "SPIRIT",
		"description": "Spiritual awareness and power. Scales Madra-based abilities and provides spiritual defense.",
		"effects": "Power Font: SPI x 1.5\nSpirit damage defense",
	},
	CharacterAttributesData.AttributeType.FOUNDATION: {
		"title": "FOUNDATION",
		"description": "Depth of your Madra channels. Determines your Madra capacity.",
		"effects": "Max Madra = 50 + FND x 10",
	},
	CharacterAttributesData.AttributeType.CONTROL: {
		"title": "CONTROL",
		"description": "Mastery over your techniques. Will reduce ability cooldowns.",
		"effects": "Not yet active",
	},
	CharacterAttributesData.AttributeType.WILLPOWER: {
		"title": "WILLPOWER",
		"description": "Mental fortitude. Reduces incoming mixed damage.",
		"effects": "Averaged with Resilience for mixed defense",
	},
}

func _ready() -> void:
	# Collect all AttributeRow children from both groups
	for row: AttributeRow in _find_all_rows():
		_rows_by_type[row.attribute_type] = row
		row.hovered.connect(_on_row_hovered)
		row.unhovered.connect(_on_row_unhovered)

## Refreshes all attribute values from CharacterManager.
func refresh() -> void:
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: CharacterAttributesData.AttributeType in _rows_by_type:
		var row: AttributeRow = _rows_by_type[attr_type]
		row.set_value(attrs.get_attribute(attr_type))

## Plays the open animation.
func animate_open() -> void:
	refresh()
	_animation_player.play("open")

## Plays the close animation.
func animate_close() -> void:
	_tooltip.hide_tooltip()
	_animation_player.play("close")

func _find_all_rows() -> Array[AttributeRow]:
	var rows: Array[AttributeRow] = []
	var physical_group: VBoxContainer = %PhysicalGroup
	var spiritual_group: VBoxContainer = %SpiritualGroup
	for child: Node in physical_group.get_children():
		if child is AttributeRow:
			rows.append(child as AttributeRow)
	for child: Node in spiritual_group.get_children():
		if child is AttributeRow:
			rows.append(child as AttributeRow)
	return rows

func _on_row_hovered(row: AttributeRow) -> void:
	var data: Dictionary = TOOLTIP_DATA.get(row.attribute_type, {})
	if not data.is_empty():
		_tooltip.show_for_row(row, data)

func _on_row_unhovered() -> void:
	_tooltip.hide_tooltip()
