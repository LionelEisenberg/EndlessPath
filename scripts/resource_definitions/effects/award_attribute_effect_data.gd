class_name AwardAttributeEffectData
extends EffectData

@export var attribute_type: CharacterAttributesData.AttributeType
@export var amount: float = 1.0

func _init() -> void:
	effect_type = EffectType.AWARD_ATTRIBUTE

func process() -> void:
	if CharacterManager == null:
		Log.error("AwardAttributeEffectData: CharacterManager is not found!")
		return
	Log.info("AwardAttributeEffectData: Awarding %s +%.1f" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		amount,
	])
	CharacterManager.add_base_attribute(attribute_type, amount)

func _to_string() -> String:
	return "AwardAttributeEffectData(%s +%.1f)" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		amount,
	]
