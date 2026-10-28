class_name BonusRow
extends VBoxContainer

## BonusRow
## One row of an item's bonuses in the Equipment details: two bonuses side by
## side, each its attribute in capitals with the value right-aligned at the
## column's edge, and a pressed rule under the row. The two columns keep their
## widths, so a lone bonus sits where the first of a pair would. The text row
## is 22 px: the values sit at its foot and the captions are centred in its
## last 18 px, so both baselines fall 16 px down and the row (26 px with its
## rule) keeps the rules on even pixels.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _left_name: Label = %LeftName
@onready var _left_value: Label = %LeftValue
@onready var _right_name: Label = %RightName
@onready var _right_value: Label = %RightValue

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints two bonuses, each a [name, value] pair from BookText.bonus_pairs().
## An empty `right` hides the right half.
func setup(left: PackedStringArray, right: PackedStringArray) -> void:
	_left_name.text = left[0]
	_left_value.text = left[1]
	var has_right: bool = not right.is_empty()
	_right_name.visible = has_right
	_right_value.visible = has_right
	if has_right:
		_right_name.text = right[0]
		_right_value.text = right[1]
