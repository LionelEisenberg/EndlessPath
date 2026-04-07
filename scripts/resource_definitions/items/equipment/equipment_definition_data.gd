class_name EquipmentDefinitionData
extends ItemDefinitionData

## EquipmentDefinitionData
## Base data for all equippable items. Slot determines role, attribute_bonuses determine effect.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EquipmentSlot {
	MAIN_HAND,
	OFF_HAND,
	HEAD,
	ARMOR,
	ACCESSORY_1,
	ACCESSORY_2
}

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var slot_type: EquipmentSlot = EquipmentSlot.MAIN_HAND

## Attribute bonuses granted while equipped. Keys are AttributeType enum values, values are float bonuses.
## Example: { AttributeType.STRENGTH: 3.0, AttributeType.AGILITY: 1.0 }
@export var attribute_bonuses: Dictionary = {}

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init() -> void:
	item_type = ItemType.EQUIPMENT

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

func _get_item_effects() -> Array[String]:
	var effects: Array[String] = []
	effects.append("Slot: %s" % EquipmentSlot.keys()[slot_type].replace("_", " ").capitalize())

	for attr_type: int in attribute_bonuses:
		var value: float = attribute_bonuses[attr_type]
		var attr_name: String = CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()
		if value > 0:
			effects.append("[color=green]+%g %s[/color]" % [value, attr_name])
		elif value < 0:
			effects.append("[color=red]%g %s[/color]" % [value, attr_name])

	return effects
