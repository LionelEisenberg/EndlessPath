class_name GridToolbar
extends HBoxContainer

## GridToolbar
## Above-grid row with a count label on the left and a holder for the
## TrashSlot on the right. Trash slot is added by the owning tab via
## set_trash_slot().

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var count_label: Label = %CountLabel
@onready var trash_slot_holder: Container = %TrashSlotHolder

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Set the count label using the standard "<used> / <total>" format.
func set_count(used: int, total: int) -> void:
	count_label.text = "%d / %d" % [used, total]

## Set the count label to an arbitrary string (e.g. just "0" or a label).
func set_count_text(text: String) -> void:
	count_label.text = text

## Replace any existing child of the trash slot holder with the given slot.
func set_trash_slot(slot: Control) -> void:
	for child in trash_slot_holder.get_children():
		trash_slot_holder.remove_child(child)
	trash_slot_holder.add_child(slot)
