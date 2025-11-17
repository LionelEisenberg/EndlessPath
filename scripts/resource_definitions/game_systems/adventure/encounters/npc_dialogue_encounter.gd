class_name NpcDialogueEncounter
extends AdventureEncounter

## Dialogic timeline to trigger
@export var dialogue_timeline_name: String = ""

func _init():
	encounter_type = EncounterType.NPC_DIALOGUE
	is_blocking = true  # Dialogue always blocks by default

func process() -> void:
	Log.info("NpcDialogueEncounter: Processing dialogue encounter for %s" % dialogue_timeline_name)
	if DialogueManager:
		DialogueManager.start_timeline(dialogue_timeline_name)
	else:
		Log.error("NpcDialogueEncounter: DialogueManager not found. Cannot process dialogue encounter.")

func _to_string() -> String:
	var lines: Array[String] = super._to_string().split("\n")
	lines.pop_back()
	lines.append("  Dialogue Timeline Name: %s" % dialogue_timeline_name)
	lines.append("}")
	return "\n".join(lines)
