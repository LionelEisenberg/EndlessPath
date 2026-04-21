class_name ChangeVitalsEffectData
extends EffectData

const AttributeType = CharacterAttributesData.AttributeType

@export var health_change: float = 0.0
@export var stamina_change: float = 0.0
@export var madra_change: float = 0.0

## Multiplies the character's BODY attribute and adds the result to health_change.
## Defaults to 0.0 so existing flat-value resources behave identically.
@export var body_hp_multiplier: float = 0.0

## Multiplies the character's FOUNDATION attribute and adds the result to madra_change.
## Defaults to 0.0 so existing flat-value resources behave identically.
@export var foundation_madra_multiplier: float = 0.0

## Returns health_change plus BODY * body_hp_multiplier.
func get_final_health_change() -> float:
	var body: float = CharacterManager.get_total_attributes_data().get_attribute(AttributeType.BODY)
	return health_change + body_hp_multiplier * body

## Returns madra_change plus FOUNDATION * foundation_madra_multiplier.
func get_final_madra_change() -> float:
	var foundation: float = CharacterManager.get_total_attributes_data().get_attribute(AttributeType.FOUNDATION)
	return madra_change + foundation_madra_multiplier * foundation

## Returns stamina_change (not scaled by any attribute).
func get_final_stamina_change() -> float:
	return stamina_change

func process() -> void:
	if PlayerManager.vitals_manager:
		PlayerManager.vitals_manager.apply_vitals_change(
			get_final_health_change(),
			get_final_stamina_change(),
			get_final_madra_change(),
		)
	else:
		Log.error("ChangeVitalsEffectData: No vitals manager found")

func _to_string() -> String:
	return "ChangeVitalsEffectData: {\n HealthChanged: %s, \n StaminaChanged: %s, \n MadraChanged: %s, \n BodyHPMul: %s, \n FoundationMadraMul: %s }" % [
		health_change, stamina_change, madra_change, body_hp_multiplier, foundation_madra_multiplier
	]
