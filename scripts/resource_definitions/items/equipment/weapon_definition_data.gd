class_name WeaponDefinitionData
extends EquipmentDefinitionData

@export var attack_power: float = 0.0
@export var scaling: Dictionary = {} # Stat -> Multiplier

func _init() -> void:
	super._init()
	equipment_type = EquipmentType.WEAPON
