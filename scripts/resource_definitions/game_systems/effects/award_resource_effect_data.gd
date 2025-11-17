class_name AwardResourceEffectData
extends EffectData

@export var resource_type: ResourceManager.ResourceType
@export var amount: float

func _to_string() -> String:
	return "AwardResourceEffectData {\n Resource Type: %s,\n Amount: %s\n}" % [resource_type, amount]

func process() -> void:
	Log.info("AwardResourceEffectData: Awarding resource: %s, amount: %s" % [resource_type, amount])

	if ResourceManager:
		ResourceManager.award_resource(resource_type, amount)
	else:
		Log.error("AwardResourceEffectData: ResourceManager is not found!")
