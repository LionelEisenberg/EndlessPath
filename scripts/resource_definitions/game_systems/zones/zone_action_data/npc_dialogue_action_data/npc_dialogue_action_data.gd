extends ZoneActionData

## EffectType Enum
enum EffectType {
    UNLOCK_CONDITION,
    AWARD_ITEM,
}

## Effect Data
class EffectData:
    @export var effect_type: EffectType = EffectType.UNLOCK_CONDITION
    @export var effect_data: Dictionary = {}

    func _to_string() -> String:
        return "EffectData(effect_type: %s, effect_data: %s)" % [effect_type, effect_data]

@export var dialogue_timeline_name: String = ""

@export var effects: Array[EffectData] = []

