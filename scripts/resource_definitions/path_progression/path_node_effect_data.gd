class_name PathNodeEffectData
extends Resource

## Defines a single effect granted by a path node.
## Each node can have multiple effects. Effects stack additively
## for repeatable nodes (applied per purchase level).

enum EffectType {
	ATTRIBUTE_BONUS,             ## Adds to a character attribute (uses attribute_type + float_value)
	MADRA_GENERATION_MULT,       ## Multiplier on Madra generated per cycle (float_value, e.g. 1.1 = +10%)
	MADRA_CAPACITY_BONUS,        ## Flat bonus to max Madra capacity (float_value)
	CORE_DENSITY_XP_MULT,        ## Multiplier on Core Density XP earned (float_value, e.g. 1.15 = +15%)
	STAMINA_RECOVERY_MULT,       ## Multiplier on stamina recovery rate in combat (float_value)
	CYCLING_ACCURACY_BONUS,      ## Flat bonus to cycling zone accuracy radius (float_value in pixels)
	ADVENTURE_MADRA_RETURN_PCT,  ## Percentage of unspent adventure Madra returned (float_value, e.g. 0.1 = 10%)
	MADRA_ON_LEVEL_UP,           ## Bonus Madra granted on Core Density level-up (float_value)
	UNLOCK_ABILITY,              ## Unlocks a combat ability (string_value = resource path to AbilityData .tres)
	UNLOCK_CYCLING_TECHNIQUE,    ## Unlocks a cycling technique (string_value = technique name/resource path)
}

@export var effect_type: EffectType = EffectType.ATTRIBUTE_BONUS
@export var float_value: float = 0.0

## Used for ATTRIBUTE_BONUS to specify which attribute to boost.
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

## Used for UNLOCK_ABILITY (resource path to AbilityData .tres) and
## UNLOCK_CYCLING_TECHNIQUE (technique name or resource path).
@export var string_value: String = ""
