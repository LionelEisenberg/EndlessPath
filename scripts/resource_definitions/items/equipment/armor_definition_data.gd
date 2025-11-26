class_name ArmorDefinitionData
extends EquipmentDefinitionData

@export var defense: float = 0.0

func _init() -> void:
	super._init()
	equipment_type = EquipmentType.ARMOR
