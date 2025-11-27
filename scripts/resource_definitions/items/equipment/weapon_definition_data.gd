class_name WeaponDefinitionData
extends EquipmentDefinitionData

@export var attack_power: float = 0.0

func _init() -> void:
	super._init()
	equipment_type = EquipmentType.WEAPON

func _get_item_effects() -> Array[String]:
	var effects = super._get_item_effects()
	effects.append("Attack Power: %s" % attack_power)
	return effects
