class_name QuestProgressionData
extends Resource

## Persisted per-save quest state.
## active_quests maps quest_id -> current step index (0-based).
## completed_quest_ids is an ordered list of completed quests.
@export var active_quests: Dictionary[String, int] = {}
@export var completed_quest_ids: Array[String] = []


func _to_string() -> String:
	return "QuestProgressionData(active=%s, completed=%s)" % [
		str(active_quests), str(completed_quest_ids)
	]
