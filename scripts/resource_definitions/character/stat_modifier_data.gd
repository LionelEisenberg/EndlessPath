class_name StatModifierData
extends Resource

## StatModifierData
## One bonus to one of the player's stats: a flat amount, or a percentage.
## CharacterManager's StatModifierStack folds every source's modifiers into a
## stat as (base + sum of flat) x (1 + sum of percent).

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## What a modifier can raise: the six stats (named as in
## CharacterAttributesData.AttributeType, and mapped to it by name), then the
## derived stats, which a modifier raises after their formula. Runtime only:
## no file stores these ints.
enum Stat {
	STRENGTH,
	BODY,
	AGILITY,
	SPIRIT,
	MIND,
	CONTROL,
	MAX_HEALTH,
	MAX_STAMINA,
	MAX_MADRA,
	ARMOR,           ## From gear.
	WARD,            ## From gear.
	STAMINA_REGEN,   ## Per second.
	DODGE_CHANCE,    ## A fraction, 0..1.
	MADRA_COST_CUT,  ## A fraction, 0..1.
	COOLDOWN_CUT,    ## A fraction, 0..1.
}

enum Kind {
	FLAT,     ## Adds value to the base.
	PERCENT,  ## Adds value as a fraction: 0.1 is +10%.
}

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var stat: Stat = Stat.STRENGTH
@export var kind: Kind = Kind.FLAT
@export var value: float = 0.0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(p_stat: Stat = Stat.STRENGTH, p_kind: Kind = Kind.FLAT, p_value: float = 0.0) -> void:
	stat = p_stat
	kind = p_kind
	value = p_value

#-----------------------------------------------------------------------------
# ATTRIBUTE MAPPING
#-----------------------------------------------------------------------------

## The stat that stands for the given attribute.
static func for_attribute(attribute: CharacterAttributesData.AttributeType) -> Stat:
	return Stat[CharacterAttributesData.AttributeType.keys()[attribute]]

## The attribute the given stat stands for, or -1 for a derived stat.
static func attribute_of(p_stat: Stat) -> int:
	return CharacterAttributesData.AttributeType.get(Stat.keys()[p_stat], -1)
