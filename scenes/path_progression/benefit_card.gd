class_name BenefitCard
extends HBoxContainer

## A single benefit entry in the path tree sidebar.
## Displays the node's icon, name, and effect value.

@onready var _icon_label: Label = %IconLabel
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

## Populate the card with benefit info.
func setup(benefit_name: String, benefit_value: String) -> void:
	_name_label.text = benefit_name
	_value_label.text = benefit_value
