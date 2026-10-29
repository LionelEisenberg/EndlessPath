class_name StatModifierData
extends Resource

## StatModifierData
## One bonus to one of the player's stats: a flat amount, or a percentage.
## CharacterManager's StatModifierStack folds every source's modifiers into a
## stat as (base + sum of flat) x (1 + sum of percent).

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## What a modifier can raise: the eight attributes (named as in
## CharacterAttributesData.AttributeType, and mapped to it by name) and the
## derived vitals, which a modifier raises after their formula.
enum Stat {
	STRENGTH,
	BODY,
	AGILITY,
	SPIRIT,
	FOUNDATION,
	CONTROL,
	RESILIENCE,
	WILLPOWER,
	MAX_HEALTH,
	MAX_STAMINA,
	MAX_MADRA,
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

## The attribute the given stat stands for, or -1 for a derived vital.
static func attribute_of(p_stat: Stat) -> int:
	return CharacterAttributesData.AttributeType.get(Stat.keys()[p_stat], -1)
