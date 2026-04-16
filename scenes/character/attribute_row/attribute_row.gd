class_name AttributeRow
extends PanelContainer

## A single attribute display row with icon, name, and value.
## Emits hover signals for tooltip management by the parent CharacterView.

signal hovered(row: AttributeRow)
signal unhovered()

@export var attribute_name: String = "ATTRIBUTE"
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_name_label.text = attribute_name

## Updates the displayed attribute value.
func set_value(value: float) -> void:
	_value_label.text = "%.0f" % value

func _on_mouse_entered() -> void:
	modulate = Color(1.15, 1.1, 1.05, 1.0)
	hovered.emit(self)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	unhovered.emit()
