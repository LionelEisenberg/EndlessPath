class_name AwardAttributeEffectData
extends EffectData

## Raises one stat by `amount` whole levels (the Aura Well's +1 Spirit per
## training level), up to the stage's cap; levels past the cap are lost.

@export var attribute_type: CharacterAttributesData.AttributeType
@export var amount: float = 1.0

func _init() -> void:
	effect_type = EffectType.AWARD_ATTRIBUTE

## Adds `amount`, rounded to whole levels, to the stat through CharacterManager.
func process() -> void:
	if CharacterManager == null:
		Log.error("AwardAttributeEffectData: CharacterManager is not found!")
		return
	Log.info("AwardAttributeEffectData: Awarding %s +%d levels" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		roundi(amount),
	])
	CharacterManager.add_stat_levels(attribute_type, roundi(amount))

func _to_string() -> String:
	return "AwardAttributeEffectData(%s +%.1f)" % [
		CharacterAttributesData.AttributeType.keys()[attribute_type],
		amount,
	]
