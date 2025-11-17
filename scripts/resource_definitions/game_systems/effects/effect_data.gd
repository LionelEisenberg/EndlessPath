class_name EffectData
extends Resource

enum EffectType {
	NONE,
	TRIGGER_EVENT,
	AWARD_RESOURCE,
}

@export var effect_type: EffectType = EffectType.NONE
