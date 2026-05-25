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

## Mount the given Control as the toolbar's right-side slot. Reparents from
## the slot's current parent if necessary. Any previously-mounted slot is
## removed and freed.
func set_trash_slot(slot: Control) -> void:
	for child in trash_slot_holder.get_children():
		if child == slot:
			continue
		trash_slot_holder.remove_child(child)
		child.queue_free()
	if slot.get_parent() == trash_slot_holder:
		return
	if slot.get_parent() != null:
		slot.get_parent().remove_child(slot)
	trash_slot_holder.add_child(slot)
