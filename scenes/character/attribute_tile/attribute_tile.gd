class_name AttributeTile
extends PanelContainer

## One attribute in the Character book: its icon, value and name, centred on
## a small card. Emits hovered so the CharacterView can describe it on the
## right page, and shows the selected look while it is the one described.

signal hovered(tile: AttributeTile)

const _STYLE_NORMAL: StringName = &"PanelBookTile"
const _STYLE_SELECTED: StringName = &"PanelBookTileSelected"

@export var attribute_name: String = "ATTRIBUTE"
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH
@export var icon_texture: Texture2D = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	_name_label.text = attribute_name
	if icon_texture:
		_icon.texture = icon_texture

## Updates the displayed attribute value.
func set_value(value: float) -> void:
	_value_label.text = "%.0f" % value

## Shows or clears the selected look.
func set_selected(is_selected: bool) -> void:
	theme_type_variation = _STYLE_SELECTED if is_selected else _STYLE_NORMAL

## True while this tile has the selected look.
func is_selected() -> bool:
	return theme_type_variation == _STYLE_SELECTED

func _on_mouse_entered() -> void:
	hovered.emit(self)
