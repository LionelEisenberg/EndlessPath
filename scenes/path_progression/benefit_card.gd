class_name BenefitCard
extends HBoxContainer

## A single benefit entry in the path tree sidebar.
## Displays an icon based on node type, the node's name, and effect value.

@onready var _icon_rect: TextureRect = %IconRect
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

## Populate the card with benefit info and node type icon.
func setup(benefit_name: String, benefit_value: String, icon: Texture2D = null) -> void:
	_name_label.text = benefit_name
	_value_label.text = benefit_value
	if icon:
		_icon_rect.texture = icon
