class_name GearSlot
extends InventorySlot

## GearSlot
## One of the six worn-gear slots round the figure on the Gear page. Like any
## InventorySlot it is pressed deep while it holds an item and shallow while
## empty. It accepts only equipment of its own slot type.

@export var slot_type: EquipmentDefinitionData.EquipmentSlot = EquipmentDefinitionData.EquipmentSlot.HEAD

## Only meaningful when slot_type == ACCESSORY. Selects which of the two
## physical accessory slots this GearSlot represents (0 or 1).
@export var accessory_index: int = -1

func _ready() -> void:
	add_to_group("GearSlots")
	super._ready()

## Checks if the item data is valid for this slot type.
func is_valid_item(item_data: ItemInstanceData) -> bool:
	if not item_data.item_definition is EquipmentDefinitionData:
		Log.warn("GearSlot: Item is not an equipment definition")
		return false
	if item_data.item_definition.slot_type == slot_type:
		return true
	return false
