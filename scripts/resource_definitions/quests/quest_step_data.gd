class_name QuestStepData
extends Resource

## One step in a quest. A step advances when EITHER its completion_event_id fires
## OR all its completion_conditions evaluate true. Set exactly one of the two.
@export var step_id: String = ""
@export var description: String = ""
@export var completion_event_id: String = ""
@export var completion_conditions: Array[UnlockConditionData] = []


func _to_string() -> String:
	return "QuestStepData(step_id=%s, event=%s, conditions=%d)" % [
		step_id, completion_event_id, completion_conditions.size()
	]
