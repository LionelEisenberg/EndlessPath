class_name EquipmentDefinitionData
extends ItemDefinitionData

enum EquipmentSlot {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	MAIN_HAND,
	OFF_HAND,
	ACCESSORY_1,
	ACCESSORY_2
}

enum EquipmentType {
	WEAPON,
	ARMOR,
	ACCESSORY
}

@export var slot_type: EquipmentSlot = EquipmentSlot.MAIN_HAND
@export var equipment_type: EquipmentType = EquipmentType.WEAPON

func _init() -> void:
	item_type = ItemType.EQUIPMENT
