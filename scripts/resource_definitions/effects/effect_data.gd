@abstract class_name EffectData
extends Resource

## Only grows at the end: .tres files store an effect's type as its number.
enum EffectType {
	NONE,
	TRIGGER_EVENT,
	AWARD_RESOURCE,
	AWARD_ITEM,
	AWARD_LOOT_TABLE,
	START_QUEST,
	AWARD_ATTRIBUTE,
	AWARD_PATH_POINT,
	CHANGE_VITALS,
	AWARD_CORE_DENSITY_XP,
}

@export var effect_type: EffectType = EffectType.NONE

@abstract
func process() -> void

@abstract
func _to_string() -> String

## Human-readable description for UI (e.g. item tooltips). Subclasses that are
## shown to the player override this; the default falls back to _to_string().
func describe() -> String:
	return _to_string()
