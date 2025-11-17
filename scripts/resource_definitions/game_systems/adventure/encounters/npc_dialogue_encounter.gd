class_name NpcDialogueEncounter
extends AdventureEncounter

## Dialogic timeline to trigger
@export var dialogue_timeline_name: String = ""

func _init():
	encounter_type = EncounterType.DIALOGUE
	is_blocking = true  # Dialogue always blocks by default
