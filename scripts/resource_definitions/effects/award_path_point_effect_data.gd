class_name AwardPathPointEffectData
extends EffectData

@export var amount: int = 1


func _init() -> void:
	effect_type = EffectType.AWARD_PATH_POINT


func _to_string() -> String:
	return "AwardPathPointEffectData { amount: %d }" % amount


## Awards `amount` path points to the player via PathManager.
## Non-positive amounts (0 or negative) are a no-op — prevents accidental
## drains from malformed .tres authoring.
func process() -> void:
	if amount <= 0:
		return
	if PathManager == null:
		Log.error("AwardPathPointEffectData: PathManager not available")
		return
	Log.info("AwardPathPointEffectData: Awarding %d path point(s)" % amount)
	PathManager.add_points(amount)
