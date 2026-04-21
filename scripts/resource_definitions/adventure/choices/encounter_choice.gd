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

## Label shown when completion_condition is met. Renders grayed/disabled.
## Falls back to `label` if empty.
@export var completed_label: String = ""

## When non-null and evaluates to true, the choice renders as completed
## (grayed, using completed_label). Separate from requirements so completion
## and eligibility are independent.
@export var completion_condition: UnlockConditionData

## Returns true when every condition in `requirements` evaluates to its
## expected bool. Returns true for empty requirements.
func evaluate_requirements() -> bool:
	for condition in requirements:
		if condition.evaluate() != requirements[condition]:
			return false
	return true

## Returns true when completion_condition is set and evaluates true.
func is_completed() -> bool:
	return completion_condition != null and completion_condition.evaluate()
