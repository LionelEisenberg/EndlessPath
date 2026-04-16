class_name StartQuestEffectData
extends EffectData

@export var quest_id: String = ""


func _init() -> void:
	effect_type = EffectType.START_QUEST


func _to_string() -> String:
	return "StartQuestEffectData { quest_id: %s }" % quest_id


func process() -> void:
	if quest_id.is_empty():
		push_error("StartQuestEffectData: empty quest_id")
		return
	if QuestManager == null:
		Log.error("StartQuestEffectData: QuestManager not available")
		return
	Log.info("StartQuestEffectData: Starting quest '%s'" % quest_id)
	QuestManager.start_quest(quest_id)
