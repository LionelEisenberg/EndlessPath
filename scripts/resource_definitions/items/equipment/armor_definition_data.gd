class_name ArmorDefinitionData
extends EquipmentDefinitionData

@export var defense: float = 0.0

func _init() -> void:
	super._init()
	equipment_type = EquipmentType.ARMOR

func _get_item_effects() -> Array[String]:
	var effects = super._get_item_effects()
	effects.append("Defense: %s" % defense)
	return effects
