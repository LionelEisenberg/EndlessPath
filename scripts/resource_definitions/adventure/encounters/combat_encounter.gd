class_name CombatEncounter
extends AdventureEncounter

@export var enemy_pool : Array[CombatantData] = []
@export var is_boss: bool = false

func _init() -> void:
	is_blocking = true
	encounter_type = EncounterType.COMBAT

func process() -> void:
	Log.info("CombatEncounter: \"Processed\" Combat Encounter")
