class_name AdventureEncounter
extends Resource

enum EncounterType {
	NONE,           # No-op, just a tile
	DIALOGUE,       # NPC dialogue
}

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
