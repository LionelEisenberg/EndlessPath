class_name CombatEffectData
extends Resource

## CombatEffectData
## Base class for combat-specific effects (damage, healing, buffs, debuffs, etc.)
## Different from EffectData which is for general game effects

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EffectType {
	DAMAGE,             ## Deal damage to target
	HEAL,               ## Restore health to target
}

enum DamageType {
	PHYSICAL,           ## Affected by physical defense/resilience
	MADRA,              ## Affected by spiritual defense
	TRUE,               ## Ignores defenses
	MIXED               ## Combination of physical and madra
}

#-----------------------------------------------------------------------------
# BASIC INFO
#-----------------------------------------------------------------------------

@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_name: String = ""
@export_multiline var effect_description: String = ""

#-----------------------------------------------------------------------------
# VALUE & SCALING
#-----------------------------------------------------------------------------

@export_group("Values")
## Base value of the effect (damage, healing, etc.)
@export var base_value: float = 0.0

## Percentage of base value (for buffs/debuffs). 1.0 = 100%
@export var percentage_value: float = 0.0

#-----------------------------------------------------------------------------
# ATTRIBUTE SCALING
#-----------------------------------------------------------------------------

@export_group("Attribute Scaling")
## Scales with caster's Strength
@export var strength_scaling: float = 0.0

## Scales with caster's Body
@export var body_scaling: float = 0.0

## Scales with caster's Agility
@export var agility_scaling: float = 0.0

## Scales with caster's Spirit
@export var spirit_scaling: float = 0.0

## Scales with caster's Foundation
@export var foundation_scaling: float = 0.0

## Scales with caster's Control
@export var control_scaling: float = 0.0

## Scales with caster's Resilience
@export var resilience_scaling: float = 0.0

## Scales with caster's Willpower
@export var willpower_scaling: float = 0.0

#-----------------------------------------------------------------------------
# DAMAGE-SPECIFIC
#-----------------------------------------------------------------------------

@export_group("Damage Settings", "damage_")
@export var damage_type: DamageType = DamageType.PHYSICAL

#-----------------------------------------------------------------------------
# CALCULATION
#-----------------------------------------------------------------------------

## Calculate the total effect value based on caster's attributes
func calculate_value(caster_attributes: CharacterAttributesData) -> float:
	if caster_attributes == null:
		return base_value
	
	var scaled_value = base_value
	
	# Add attribute scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.STRENGTH) * strength_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY) * body_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.AGILITY) * agility_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT) * spirit_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.FOUNDATION) * foundation_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.CONTROL) * control_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE) * resilience_scaling
	scaled_value += caster_attributes.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER) * willpower_scaling
	
	return scaled_value

## Calculate damage with defense, armor penetration, and crit
func calculate_damage(caster_attributes: CharacterAttributesData, target_attributes: CharacterAttributesData) -> float:
	if effect_type != EffectType.DAMAGE:
		Log.error("CombatEffectData: calculate_damage called on non-damage effect")
		return 0.0
	
	var damage = calculate_value(caster_attributes)
	
	# Apply damage reduction based on target's defense
	if target_attributes != null:
		var defense_value = 0.0
		
		match damage_type:
			DamageType.PHYSICAL:
				defense_value = target_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE)
			DamageType.MADRA:
				defense_value = target_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)
			DamageType.MIXED:
				var resilience = target_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE)
				var spirit = target_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)
				defense_value = (resilience + spirit) / 2.0
		
		# Damage reduction formula: damage * (100 / (100 + defense))
		damage = damage * (100.0 / (100.0 + defense_value))
	
	return damage

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var type_str = EffectType.keys()[effect_type]
	var value_str = ""
	
	match effect_type:
		EffectType.DAMAGE, EffectType.HEAL:
			value_str = "Base: %.1f" % base_value
		_:
			value_str = "Base: %.1f" % base_value
	
	return "CombatEffectData[%s] '%s' (%s)" % [type_str, effect_name, value_str]
