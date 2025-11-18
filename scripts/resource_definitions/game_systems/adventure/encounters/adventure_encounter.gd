@abstract
class_name AdventureEncounter
extends Resource

## AdventureEncounter
## Base class for all encounter types in adventure mode
## Subclasses define specific encounter behaviors (dialogue, combat, etc.)

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EncounterType {
	NONE,           ## No-op, just a tile with no interaction
	NPC_DIALOGUE,   ## NPC dialogue encounter using Dialogic
	COMBAT,         ## Combat encounter with enemies
}

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Unique identifier for this encounter (used for event tracking)
@export var encounter_id: String = ""

## The name of the encounter (e.g., "Village Elder", "Spirit Well")
@export var encounter_name: String = ""

## Type of encounter
@export var encounter_type: EncounterType = EncounterType.NONE

## Description shown to player
@export var description: String = ""

## Whether this encounter blocks movement (requires interaction before continuing)
@export var is_blocking: bool = false

## Max times this encounter can be completed at this tile position (0 = unlimited)
@export var max_completion_count: int = 0

## Effects to apply when encounter is completed
@export var completion_effects: Array[EffectData] = []

#-----------------------------------------------------------------------------
# ABSTRACT METHODS
#-----------------------------------------------------------------------------

## Process this encounter - must be implemented by subclasses
@abstract
func process() -> void

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var lines: Array[String] = []
	lines.append("\nAdventureEncounter {")
	lines.append("  ID: %s" % encounter_id)
	lines.append("  Name: %s" % encounter_name)
	lines.append("  Type: %s" % EncounterType.keys()[encounter_type])
	lines.append("  Description: %s" % description)
	lines.append("  Blocking: %s" % is_blocking)
	lines.append("  Max Completions: %s" % ("Unlimited" if max_completion_count == 0 else str(max_completion_count)))
	lines.append("  Completion Effects: %d effect(s)" % completion_effects.size())
	for i in range(completion_effects.size()):
		if completion_effects[i]:
			lines.append("    [%d] %s" % [i, completion_effects[i]])
	lines.append("}")
	return "\n".join(lines)
