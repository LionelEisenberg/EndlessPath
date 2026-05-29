class_name ChangeVitalsEffectData
extends EffectData

const AttributeType = CharacterAttributesData.AttributeType

@export var health_change: float = 0.0
@export var stamina_change: float = 0.0
@export var madra_change: float = 0.0

func _init() -> void:
	effect_type = EffectType.CHANGE_VITALS

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

## Human-readable summary of the non-zero changes only, for item tooltips.
## E.g. "+20 Madra" or "+15 Health, +50% Body as Health".
func describe() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if health_change != 0.0:
		parts.append("%s Health" % _format_signed(health_change))
	if stamina_change != 0.0:
		parts.append("%s Stamina" % _format_signed(stamina_change))
	if madra_change != 0.0:
		parts.append("%s Madra" % _format_signed(madra_change))
	if body_hp_multiplier != 0.0:
		parts.append("%s%% Body as Health" % _format_signed(body_hp_multiplier * 100.0))
	if foundation_madra_multiplier != 0.0:
		parts.append("%s%% Foundation as Madra" % _format_signed(foundation_madra_multiplier * 100.0))
	if parts.is_empty():
		return "No effect"
	return ", ".join(parts)

## Leading sign, and no trailing ".0" for whole numbers ("+20", "-7.5").
func _format_signed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%+d" % int(value)
	return "%+.1f" % value
