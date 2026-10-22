class_name AwardResourceEffectData
extends EffectData

@export var resource_type: ResourceManager.ResourceType
@export var amount: float
## Adds the resource without a player-facing log line (for per-tick trickles).
@export var quiet: bool = false

func _to_string() -> String:
	return "AwardResourceEffectData {\n Resource Type: %s,\n Amount: %s,\n Quiet: %s\n}" % [resource_type, amount, quiet]

## Awards the resource through ResourceManager.
func process() -> void:
	Log.info("AwardResourceEffectData: Awarding resource: %s, amount: %s" % [resource_type, amount])

	if ResourceManager:
		ResourceManager.award_resource(resource_type, amount, quiet)
	else:
		Log.error("AwardResourceEffectData: ResourceManager is not found!")
