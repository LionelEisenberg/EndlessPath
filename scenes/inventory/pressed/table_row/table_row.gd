class_name TableRow
extends VBoxContainer

## TableRow
## One row of a pressed details panel's table: a caption in capitals at the
## left, its value right-aligned 2 px short of the column's edge, and a pressed
## rule under the row. The value is BBCode, so an amount can print in Madra
## ink, and it wraps when it runs long, pushing the rule down.
##
## The caption and the value share a baseline 15 px down the row. The value's
## line (BM Euljiro 18) is 26 px tall, and the VBox separation of -3 puts the
## rule 8 px under the baseline, clear of descenders, which reach 7 px. A
## one-line row is 27 px tall: rows 30 px apart take a separation of 3.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _label: Label = %Label
@onready var _value: RichTextLabel = %Value
@onready var _rule: HSeparator = %Rule

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the row: `label` is the caption, which the caller writes in
## capitals, and `value_bbcode` the value, as BBCode.
func setup(label: String, value_bbcode: String) -> void:
	_label.text = label
	_value.text = value_bbcode

## Shows or hides the pressed rule under the row.
func set_rule_visible(rule_visible: bool) -> void:
	_rule.visible = rule_visible
