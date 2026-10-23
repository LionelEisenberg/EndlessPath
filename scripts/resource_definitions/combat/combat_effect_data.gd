class_name CombatEffectData
extends Resource

## CombatEffectData
## Base class for combat-specific effects (damage, healing, buffs, debuffs, etc.)
## Different from EffectData which is for general game effects

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EffectType {
	DAMAGE, ## Deal damage to target
	HEAL, ## Restore health to target
	BUFF, ## Apply a buff or debuff
	CANCEL_CAST, ## Cancel target's current cast if any
	STRIP_BUFFS, ## Remove all active buffs on target
}

enum DamageType {
	PHYSICAL, ## Affected by physical defense/resilience
	SPIRIT, ## Affected by spiritual defense (Madra-type damage)
	TRUE, ## Ignores defenses
	MIXED ## Combination of physical and spirit
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

## How much of the caster's given attribute this effect adds per point.
func get_scaling(attribute: CharacterAttributesData.AttributeType) -> float:
	match attribute:
		CharacterAttributesData.AttributeType.STRENGTH: return strength_scaling
		CharacterAttributesData.AttributeType.BODY: return body_scaling
		CharacterAttributesData.AttributeType.AGILITY: return agility_scaling
		CharacterAttributesData.AttributeType.SPIRIT: return spirit_scaling
		CharacterAttributesData.AttributeType.FOUNDATION: return foundation_scaling
		CharacterAttributesData.AttributeType.CONTROL: return control_scaling
		CharacterAttributesData.AttributeType.RESILIENCE: return resilience_scaling
		CharacterAttributesData.AttributeType.WILLPOWER: return willpower_scaling
	Log.error("CombatEffectData: Unknown attribute type %s" % attribute)
	return 0.0

## What the caster's given attribute adds to this effect's value: the
## attribute times its scaling, as calculate_value() counts it. Doesn't log.
func get_scaling_contribution(attribute: CharacterAttributesData.AttributeType, caster_attributes: CharacterAttributesData) -> float:
	return caster_attributes.get_attribute(attribute) * get_scaling(attribute)

## Calculate the total effect value based on caster's attributes
func calculate_value(caster_attributes: CharacterAttributesData) -> float:
	if caster_attributes == null:
		return base_value
	
	var scaled_value: float = base_value
	Log.info("CombatEffectData: Calculating value for '%s'." % effect_name)
	Log.info("	Base: %.1f" % base_value)
	
	# Add attribute scaling
	for attribute: int in CharacterAttributesData.AttributeType.values():
		var attr_type: CharacterAttributesData.AttributeType = attribute as CharacterAttributesData.AttributeType
		var scaling: float = get_scaling(attr_type)
		if scaling != 0.0:
			var attr_val: float = caster_attributes.get_attribute(attr_type)
			var added_val: float = attr_val * scaling
			scaled_value += added_val
			var attr_name: String = CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()
			Log.info("  + %s Scaling: %.1f (Attr: %.1f * Scale: %.2f)" % [attr_name, added_val, attr_val, scaling])
	
	Log.info("  = Total Scaled Value: %.1f" % scaled_value)
	return scaled_value

## Calculate damage with defense, armor penetration, and crit
func calculate_damage(caster_attributes: CharacterAttributesData, target_attributes: CharacterAttributesData) -> float:
	if effect_type != EffectType.DAMAGE:
		Log.error("CombatEffectData: calculate_damage called on non-damage effect")
		return 0.0
	
	Log.info("CombatEffectData: Starting damage calculation for '%s'" % effect_name)
	var damage = calculate_value(caster_attributes)
	
	# Apply damage reduction based on target's defense
	if target_attributes != null:
		var defense_value = 0.0
		var defense_name = ""
		
		match damage_type:
			DamageType.PHYSICAL:
				defense_value = target_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE)
				defense_name = "Resilience"
			DamageType.SPIRIT:
				defense_value = target_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)
				defense_name = "Spirit"
			DamageType.MIXED:
				var resilience = target_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE)
				var willpower = target_attributes.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER)
				defense_value = (resilience + willpower) / 2.0
				defense_name = "Mixed (Resilience+Willpower)/2"
			DamageType.TRUE:
				Log.info("  TRUE damage — bypassing defenses.")

		if damage_type != DamageType.TRUE:
			# Damage reduction formula: damage * (100 / (100 + defense))
			var reduction_mult = (100.0 / (100.0 + defense_value))
			var original_damage = damage
			damage = damage * reduction_mult

			Log.info("  Defense Application (%s):" % defense_name)
			Log.info("    Defense Value: %.1f" % defense_value)
			Log.info("    Reduction Multiplier: %.3f" % reduction_mult)
			Log.info("    Damage Reduced: %.1f -> %.1f" % [original_damage, damage])
	else:
		Log.info("  No target attributes for defense calculation.")
	
	Log.info("  = Final Damage: %.1f" % damage)
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
