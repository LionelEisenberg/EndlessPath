class_name GearSlot
extends InventorySlot

const ITEM_SLOT_OUTLINES : Dictionary[EquipmentDefinitionData.EquipmentSlot, String] = {
	EquipmentDefinitionData.EquipmentSlot.MAIN_HAND: "res://assets/sprites/inventory/gear_selector/item_slot_outlines/main_slot.png",
	EquipmentDefinitionData.EquipmentSlot.OFF_HAND: "res://assets/sprites/inventory/gear_selector/item_slot_outlines/offhand_slot.png",
	EquipmentDefinitionData.EquipmentSlot.HEAD: "res://assets/sprites/inventory/gear_selector/item_slot_outlines/head_slot.png",
	EquipmentDefinitionData.EquipmentSlot.ARMOR: "res://assets/sprites/inventory/gear_selector/item_slot_outlines/armor_slot.png",
	EquipmentDefinitionData.EquipmentSlot.ACCESSORY: "res://assets/sprites/inventory/gear_selector/item_slot_outlines/accessory_slot.png",
}

@export var slot_type: EquipmentDefinitionData.EquipmentSlot = EquipmentDefinitionData.EquipmentSlot.HEAD

## Only meaningful when slot_type == ACCESSORY. Selects which of the two
## physical accessory slots this GearSlot represents (0 or 1).
@export var accessory_index: int = -1

@onready var slot_background: TextureRect = $MarginContainer/SlotBackground

func _ready() -> void:
	add_to_group("GearSlots")
	slot_background.texture = load(ITEM_SLOT_OUTLINES[slot_type])
	super._ready()

func _update_slot() -> void:
	if item_instance != null:
		slot_background.visible = false
	else:
		slot_background.visible = true

## Checks if the item data is valid for this slot type.
func is_valid_item(item_data: ItemInstanceData) -> bool:
	if not item_data.item_definition is EquipmentDefinitionData:
		Log.warn("GearSlot: Item is not an equipment definition")
		return false
	if item_data.item_definition.slot_type == slot_type:
		return true
	return false
