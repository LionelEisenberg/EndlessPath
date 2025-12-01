class_name ChangeVitalsEffectData
extends EffectData

@export var health_change: float = 0.0
@export var stamina_change: float = 0.0
@export var mana_change: float = 0.0

func process() -> void:
    if PlayerManager.vitals_manager:
        PlayerManager.vitals_manager.apply_vitals_change(health_change, stamina_change, mana_change)
    else:
        Log.error("ChangeVitalsEffectData: No vitals manager found")

func _to_string() -> String:
    return "ChangeVitalsEffectData: {\n HealthChanged: %s, \n StaminaChanged: %s, \n ManaChanged: %s }" % [health_change, stamina_change, mana_change]