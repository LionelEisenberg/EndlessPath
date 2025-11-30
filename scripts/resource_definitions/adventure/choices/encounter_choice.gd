class_name EncounterChoice
extends Resource

## EncounterChoice
## Represents a choice available to the player during an encounter.
## This is a data container; logic is handled by AdventureTilemap.

@export var label: String = ""
@export_multiline var tooltip: String = ""

## Effects applied when this choice is successfully completed.
@export var success_effects: Array[EffectData] = []

## Effects applied when this choice results in failure (e.g. lost combat).
@export var failure_effects: Array[EffectData] = []
