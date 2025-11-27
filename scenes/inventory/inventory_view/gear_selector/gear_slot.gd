class_name GearSlot
extends InventorySlot

const GEAR_SLOT_TEXTURE = preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot03a.png")

@export var slot_type: EquipmentDefinitionData.EquipmentSlot = EquipmentDefinitionData.EquipmentSlot.HEAD

func _ready() -> void:
	add_to_group("GearSlots")
	empty_texture = GEAR_SLOT_TEXTURE
	full_texture = GEAR_SLOT_TEXTURE
	super._ready()

# We might need a way to check if an item instance (Control) is valid for this slot
func is_valid_item(item_data: ItemInstanceData) -> bool:
	if not item_data.item_definition is EquipmentDefinitionData:
		Log.warn("GearSlot: Item is not an equipment definition")
		return false
	if item_data.item_definition.slot_type == slot_type:
		return true
	return false
