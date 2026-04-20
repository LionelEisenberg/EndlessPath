class_name QuestData
extends Resource

## A linear multi-step quest. Started via StartQuestEffectData. Surfaced to the
## player by QuestManager. Steps complete in order; completion_effects fire when
## the last step advances.
@export var quest_id: String = ""
@export var quest_name: String = ""
@export_multiline() var description: String = ""
@export var steps: Array[QuestStepData] = []
@export var completion_effects: Array[EffectData] = []


func _to_string() -> String:
	return "QuestData(quest_id=%s, steps=%d, completion_effects=%d)" % [
		quest_id, steps.size(), completion_effects.size()
	]
