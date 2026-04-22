class_name AdventureEncounter
extends Resource

## AdventureEncounter
## Base class for all encounter types in adventure mode
## Now acts as a container for EncounterChoices.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EncounterType {
	COMBAT_REGULAR, # Implemented
	COMBAT_AMBUSH, # Implemented
	COMBAT_BOSS, # Implemented
	COMBAT_ELITE, # Implemented
	REST_SITE, # Implemented
	TRAP, # Implemented
	TREASURE, # Implemented
	NONE, # No encounter, no implementation needed
}

enum Placement {
	ANCHOR, # Scattered first with sparse_factor + min_distance_from_origin
	FILLER, # Placed on NoOp path tiles after MST is built
}

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

## Type of encounter
@export var encounter_type: EncounterType = EncounterType.NONE

## Optional gates evaluated at map-generation time. Each key is an
## UnlockConditionData; the value is the expected evaluation result.
## Encounters whose conditions don't all match their expected booleans
## are filtered out of the random pool before placement — the player
## never sees them.
@export var unlock_conditions: Dictionary[UnlockConditionData, bool] = {}

## Placement strategy used by the map generator.
@export var placement: Placement = Placement.FILLER

## Minimum hex distance from origin for placement. 0 = no constraint.
@export var min_distance_from_origin: int = 0

## Minimum number of FILLER-placement encounters that must sit on the
## shortest path from origin to this tile. 0 = no constraint.
@export var min_fillers_on_path: int = 0

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

#-----------------------------------------------------------------------------
# ELIGIBILITY
#-----------------------------------------------------------------------------

## Returns true when all unlock_conditions evaluate to their expected bool.
## Encounters with no unlock_conditions are always eligible.
func is_eligible() -> bool:
	for condition in unlock_conditions:
		if condition.evaluate() != unlock_conditions[condition]:
			return false
	return true
