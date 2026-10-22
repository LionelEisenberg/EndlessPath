class_name ScalingPart
extends HBoxContainer

## One attribute's share of an ability's value in the Abilities book's
## details: the attribute's icon and what it adds, for example "+16.5".

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %ValueLabel

## Shows the attribute's icon and what it adds to the value.
func setup(icon: Texture2D, contribution: float) -> void:
	_icon.texture = icon
	_value_label.text = "+%s" % AbilityRow.format_number(contribution)

## The attribute icon shown.
func get_icon() -> Texture2D:
	return _icon.texture

## The contribution as shown, for example "+16.5".
func get_value_text() -> String:
	return _value_label.text
