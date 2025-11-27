class_name TrashSlot
extends InventorySlot

const GEAR_SLOT_TEXTURE = preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot04a.png")

func _ready() -> void:
	empty_texture = GEAR_SLOT_TEXTURE
	full_texture = GEAR_SLOT_TEXTURE
	super._ready()
