class_name BonusRow
extends VBoxContainer

## BonusRow
## One row of an item's bonuses in the Equipment details: two bonuses side by
## side, each printed the way the item's tooltip words it ("+2 Strength") in
## dark ink at body size, and a pressed rule under the row. The two columns keep
## their widths, so a lone bonus sits where the first of a pair would. The text
## row is 22 px with the text at its foot, so the baseline falls 16 px down and
## the row (28 px with its rule) keeps the rules on even pixels.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _left: Label = %LeftBonus
@onready var _right: Label = %RightBonus

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints two bonuses, each a line from BookText.bonus_lines(). An empty
## `right` hides the right half.
func setup(left: String, right: String) -> void:
	_left.text = left
	_right.text = right
	_right.visible = not right.is_empty()
