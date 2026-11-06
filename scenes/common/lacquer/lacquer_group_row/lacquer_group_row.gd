@tool
class_name LacquerGroupRow
extends HBoxContainer

## A group's label row in the lacquer look: the group's name in tan, then a
## carved groove with an end pin out to the row's end. The zone chest's activity
## groups (ActivityGroupLabel) and the cultivator cabinet's Physical and
## Spiritual sides use it; each instance sets its width and its text. It runs in
## the editor (@tool) so a placed row shows its text.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The group's name.
@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			_label.text = value

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _label: Label = %GroupLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_label.text = text
