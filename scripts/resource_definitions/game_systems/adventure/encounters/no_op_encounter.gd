class_name NoOpEncounter
extends AdventureEncounter

func _init():
	encounter_type = EncounterType.NONE
	is_blocking = false
	completion_effects = []

func process() -> void:
	Log.info("NoOpEncounter: \"Processed\" No Op Encounter")
	return
