class_name EncounterChoice
extends Resource

## EncounterChoice
## Represents a choice available to the player during an encounter.
## This is a data container; logic is handled by AdventureTilemap.

@export var label: String = ""
@export_multiline var tooltip: String = ""

## Conditions that gate this choice. Each key is an UnlockConditionData; the
## value is the expected evaluation result. A choice's requirements are met
## when every condition's evaluate() returns its expected value.
@export var requirements: Dictionary[UnlockConditionData, bool] = {}

## Effects applied when this choice is successfully completed.
@export var success_effects: Array[EffectData] = []

## Effects applied when this choice results in failure (e.g. lost combat).
@export var failure_effects: Array[EffectData] = []

## Returns true when every condition in `requirements` evaluates to its
## expected bool. Returns true for empty requirements.
func evaluate_requirements() -> bool:
	for condition in requirements:
		if condition.evaluate() != requirements[condition]:
			return false
	return true
