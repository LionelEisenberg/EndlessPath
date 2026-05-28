class_name GridToolbar
extends HBoxContainer

## GridToolbar
## Above-grid row: count label on the left + TrashSlot on the right.
## The TrashSlot is a child of this scene; consumers access it via the
## `trash_slot` property rather than wiring one in manually.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var count_label: Label = %CountLabel
@onready var trash_slot: TrashSlot = %TrashSlot

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Set the count as a "<used> / <total>" formatted string.
func set_count(used: int, total: int) -> void:
	count_label.text = "%d / %d" % [used, total]

## Set the count to an arbitrary string ("9 stacks", "3 kinds collected", etc.).
func set_count_text(text: String) -> void:
	count_label.text = text
