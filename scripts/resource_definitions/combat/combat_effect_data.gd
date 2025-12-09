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
}

enum DamageType {
	PHYSICAL, ## Affected by physical defense/resilience
	MADRA, ## Affected by spiritual defense
	TRUE, ## Ignores defenses
	MIXED ## Combination of physical and madra
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
	Log.info("CombatEffectData: Calculating value for '%s'." % effect_name)
	Log.info("	Base: %.1f" % base_value)
	
	# Add attribute scaling
	var attr_types = {
		CharacterAttributesData.AttributeType.STRENGTH: ["Strength", strength_scaling],
		CharacterAttributesData.AttributeType.BODY: ["Body", body_scaling],
		CharacterAttributesData.AttributeType.AGILITY: ["Agility", agility_scaling],
		CharacterAttributesData.AttributeType.SPIRIT: ["Spirit", spirit_scaling],
		CharacterAttributesData.AttributeType.FOUNDATION: ["Foundation", foundation_scaling],
		CharacterAttributesData.AttributeType.CONTROL: ["Control", control_scaling],
		CharacterAttributesData.AttributeType.RESILIENCE: ["Resilience", resilience_scaling],
		CharacterAttributesData.AttributeType.WILLPOWER: ["Willpower", willpower_scaling]
	}
	
	for attr_type in attr_types:
		var info = attr_types[attr_type]
		var name = info[0]
		var scaling = info[1]
		
		if scaling != 0.0:
			var attr_val = caster_attributes.get_attribute(attr_type)
			var added_val = attr_val * scaling
			scaled_value += added_val
			Log.info("  + %s Scaling: %.1f (Attr: %.1f * Scale: %.2f)" % [name, added_val, attr_val, scaling])
	
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
			DamageType.MADRA:
				defense_value = target_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)
				defense_name = "WILLPOWER"
			DamageType.MIXED:
				var resilience = target_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE)
				var willpower = target_attributes.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER)
				defense_value = (resilience + willpower) / 2.0
				defense_name = "Mixed (Resilience+WILLPOWER)/2"
		
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
