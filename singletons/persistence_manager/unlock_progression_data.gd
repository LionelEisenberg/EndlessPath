class_name UnlockProgressionData
extends Resource

@export var unlocked_condition_ids: Array[String] = []

func _to_string() -> String:
	return "UnlockProgressionData(UnlockedConditionIds: %s)" % str(unlocked_condition_ids)