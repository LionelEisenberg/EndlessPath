class_name AwardPathPointEffectData
extends EffectData

@export var amount: int = 1


func _init() -> void:
	effect_type = EffectType.AWARD_PATH_POINT


func _to_string() -> String:
	return "AwardPathPointEffectData { amount: %d }" % amount


func process() -> void:
	if PathManager == null:
		Log.error("AwardPathPointEffectData: PathManager not available")
		return
	Log.info("AwardPathPointEffectData: Awarding %d path point(s)" % amount)
	PathManager.add_points(amount)
