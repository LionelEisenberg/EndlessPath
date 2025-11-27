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

func _get_item_effects() -> Array[String]:
	var slot_name = EquipmentSlot.keys()[slot_type].capitalize()
	var type_name = EquipmentType.keys()[equipment_type].capitalize()
	return [
		"Slot: %s" % slot_name,
		"Type: %s" % type_name
	]

func _get_equipment_type() -> String:
	match equipment_type:
		EquipmentType.WEAPON:
			return "Weapon"
		EquipmentType.ARMOR:
			return "Armor"
		EquipmentType.ACCESSORY:
			return "Accessory"
		_:
			Log.warn("EquipmentDefinitionData: EquipmentType is not found %s" % str(equipment_type))
			return ""
