class_name AdventureEncounter
extends Resource

## AdventureEncounter
## Base class for all encounter types in adventure mode
## Now acts as a container for EncounterChoices.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Unique identifier for this encounter (used for event tracking)
@export var encounter_id: String = ""

## The name of the encounter (e.g., "Village Elder", "Spirit Well")
@export var encounter_name: String = ""

## Description shown to player in the EncounterInfoPanel
@export_multiline var description: String = ""

## Description shown to player AFTER the encounter is completed
@export_multiline var text_description_completed: String = ""

## List of choices available to the player
@export var choices: Array[EncounterChoice] = []

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var lines: Array[String] = []
	lines.append("\nAdventureEncounter {")
	lines.append("  ID: %s" % encounter_id)
	lines.append("  Name: %s" % encounter_name)
	lines.append("  Description: %s" % description)
	lines.append("  Completed Text: %s" % text_description_completed)
	lines.append("  Choices: %d choice(s)" % choices.size())
	for i in range(choices.size()):
		if choices[i]:
			lines.append("    [%d] %s" % [i, choices[i].label])
	lines.append("}")
	return "\n".join(lines)
