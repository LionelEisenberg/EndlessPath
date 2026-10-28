class_name QuestStepData
extends Resource

## One step in a quest. A step advances when EITHER its completion_event_id fires
## OR all its completion_conditions evaluate true. Set exactly one of the two.
@export var step_id: String = ""
@export var description: String = ""
@export var completion_event_id: String = ""
@export var completion_conditions: Array[UnlockConditionData] = []

#-----------------------------------------------------------------------------
# PROGRESS
#-----------------------------------------------------------------------------

## The condition the step's progress figure measures: the first completion
## condition, when the step completes on conditions alone (an event id takes
## precedence in QuestManager) and every one of them is measurable. Null
## otherwise.
func get_measured_condition() -> UnlockConditionData:
	if not completion_event_id.is_empty() or completion_conditions.is_empty():
		return null
	for condition: UnlockConditionData in completion_conditions:
		if condition == null or not condition.is_measurable():
			return null
	return completion_conditions[0]

## The step's progress figure, as the Goals board and the Journal print it:
## the measured condition's current and target values, whole numbers rounded
## down ("25 / 100"), or "" when the step measures nothing. A `finished` step
## reads its target as its current value ("100 / 100"), whatever that value is
## now.
func get_progress_text(finished: bool = false) -> String:
	var condition: UnlockConditionData = get_measured_condition()
	if condition == null:
		return ""
	var target: int = floori(condition.get_target_value())
	var current: int = target if finished else floori(condition.get_current_value())
	return "%d / %d" % [current, target]


func _to_string() -> String:
	return "QuestStepData(step_id=%s, event=%s, conditions=%d)" % [
		step_id, completion_event_id, completion_conditions.size()
	]
