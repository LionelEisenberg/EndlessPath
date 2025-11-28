@abstract class_name EffectData
extends Resource

enum EffectType {
	NONE,
	TRIGGER_EVENT,
	AWARD_RESOURCE,
	AWARD_ITEM,
	AWARD_LOOT_TABLE,
}

@export var effect_type: EffectType = EffectType.NONE

@abstract
func process() -> void

@abstract
func _to_string() -> String
