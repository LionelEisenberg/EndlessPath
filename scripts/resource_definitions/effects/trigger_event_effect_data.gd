class_name TriggerEventEffectData
extends EffectData

@export var event_id: String = ""

func _to_string() -> String:
	var lines: Array[String] = []
	lines.append("TriggerEventEffectData {")
	lines.append("  Type: %s" % EffectType.keys()[effect_type])
	lines.append("  Event ID: %s" % event_id)
	lines.append("}")
	return "\n".join(lines)

func process() -> void:
	if not EventManager:
		Log.error("TriggerEventEffectData: EventManager not found. Cannot process effects.")
		return
		
	if event_id:
		Log.info("TriggerEventEffectData: Triggering event: %s" % event_id)
		EventManager.trigger_event(event_id)
	else:
		Log.error("TriggerEventEffectData: TRIGGER_EVENT effect has no 'event_id' in effect_data")
