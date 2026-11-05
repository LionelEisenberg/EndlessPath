class_name CharacterAttributesData
extends Resource

## CharacterAttributesData
## The stat block of one combatant: an enemy's authored block, or the player's
## fight snapshot from `CharacterManager.get_total_attributes_data()`. It is not
## the player's saved progress. Old saves and the enemy `.tres` files name this
## script by path, so never move or rename it.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## The six stats. Stored as ints: append only (MIND was FOUNDATION, int 4).
enum AttributeType {
	STRENGTH = 0,  ## Physical technique damage
	BODY = 1,      ## Max Health
	AGILITY = 2,   ## Max Stamina, Stamina regen and dodge
	SPIRIT = 3,    ## Spirit technique damage
	MIND = 4,      ## Max Madra
	CONTROL = 5,   ## Cheaper techniques and shorter cooldowns
}

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------
# The numbers the derived values below are built from.

## A stat's value at Lv 1.
const STAT_BASELINE: float = 10.0
const HEALTH_PER_BODY: float = 10.0
const STAMINA_PER_AGILITY: float = 5.0
const MADRA_PER_MIND: float = 10.0
## Stamina regained a second per point of Agility.
const STAMINA_REGEN_PER_AGILITY: float = 0.1
## Dodge only nears this chance, and reaches half of it at DODGE_HALF_POINT
## Agility above the baseline.
const DODGE_CEILING: float = 0.35
const DODGE_HALF_POINT: float = 15.0
## The Madra cost cut only nears this fraction, and reaches half of it at
## MADRA_COST_CUT_HALF_POINT Control above the baseline.
const MADRA_COST_CUT_CEILING: float = 0.5
const MADRA_COST_CUT_HALF_POINT: float = 20.0
## The cooldown cut only nears this fraction, and reaches half of it at
## COOLDOWN_CUT_HALF_POINT Control above the baseline.
const COOLDOWN_CUT_CEILING: float = 0.4
const COOLDOWN_CUT_HALF_POINT: float = 20.0

#-----------------------------------------------------------------------------
# STATS
#-----------------------------------------------------------------------------

@export var strength: float = 10.0
@export var body: float = 10.0
@export var agility: float = 10.0
@export var spirit: float = 10.0
@export var mind: float = 10.0
@export var control: float = 10.0

## Cuts physical damage taken.
@export var armor: float = 0.0
## Cuts Spirit damage taken.
@export var ward: float = 0.0

#-----------------------------------------------------------------------------
# CONSTRUCTION
#-----------------------------------------------------------------------------

## A new block with the given values, the rest at their defaults. Takes stat
## keys (see stat_key()) plus &"armor" and &"ward", for example
## make({&"mind": 12.0, &"armor": 6.0}). An unknown key is logged and skipped.
static func make(values: Dictionary = {}) -> CharacterAttributesData:
	var block := CharacterAttributesData.new()
	for key: StringName in values:
		var value: float = values[key]
		match key:
			&"armor":
				block.armor = value
			&"ward":
				block.ward = value
			_:
				var stat: int = stat_from_key(key)
				if stat == -1:
					Log.error("CharacterAttributesData: make() skips the unknown key '%s'" % key)
					continue
				block.set_attribute(stat as AttributeType, value)
	return block

#-----------------------------------------------------------------------------
# STAT KEYS
#-----------------------------------------------------------------------------

## The stat's key: its enum name in lower case, &"strength" to &"control".
## Logs an error and returns &"" for a value that is no stat.
static func stat_key(stat: AttributeType) -> StringName:
	var enum_name: Variant = AttributeType.find_key(stat)
	if enum_name == null:
		Log.error("CharacterAttributesData: No stat has the value %s" % stat)
		return &""
	return StringName(String(enum_name).to_lower())

## The stat with the given key, or -1 when no stat has it.
static func stat_from_key(key: StringName) -> int:
	for stat: AttributeType in AttributeType.values():
		if stat_key(stat) == key:
			return stat
	return -1

#-----------------------------------------------------------------------------
# ATTRIBUTE ACCESSORS
#-----------------------------------------------------------------------------

## The value of the given stat.
func get_attribute(stat: AttributeType) -> float:
	match stat:
		AttributeType.STRENGTH: return strength
		AttributeType.BODY: return body
		AttributeType.AGILITY: return agility
		AttributeType.SPIRIT: return spirit
		AttributeType.MIND: return mind
		AttributeType.CONTROL: return control
	Log.error("CharacterAttributesData: Unknown attribute type %s" % stat)
	return 0.0

## Sets the value of the given stat.
func set_attribute(stat: AttributeType, value: float) -> void:
	match stat:
		AttributeType.STRENGTH: strength = value
		AttributeType.BODY: body = value
		AttributeType.AGILITY: agility = value
		AttributeType.SPIRIT: spirit = value
		AttributeType.MIND: mind = value
		AttributeType.CONTROL: control = value
		_: Log.error("CharacterAttributesData: Unknown attribute type %s" % stat)

#-----------------------------------------------------------------------------
# DERIVED VALUES
#-----------------------------------------------------------------------------
# The one home of these formulas: every caller reads them here, among them every
# VitalsManager (the player's through CharacterManager.get_stat()) and the
# character sheet's formula lines.

## Maximum Health: Body x HEALTH_PER_BODY.
func get_max_health() -> float:
	return body * HEALTH_PER_BODY

## Maximum Stamina: Agility x STAMINA_PER_AGILITY.
func get_max_stamina() -> float:
	return agility * STAMINA_PER_AGILITY

## Stamina regained a second: Agility x STAMINA_REGEN_PER_AGILITY.
func get_stamina_regen() -> float:
	return agility * STAMINA_REGEN_PER_AGILITY

## Maximum Madra in an adventure (the Madra a run can carry): Mind x
## MADRA_PER_MIND. Not the core's Madra pool cap, which
## CultivationManager.get_max_madra() gives.
func get_max_madra() -> float:
	return mind * MADRA_PER_MIND

## The chance to dodge a hit, 0..1, from the Agility above the baseline: 0 at
## Lv 1, never reaching DODGE_CEILING.
func get_dodge_chance() -> float:
	return flattening_curve(agility - STAT_BASELINE, DODGE_CEILING, DODGE_HALF_POINT)

## The fraction of a technique's Madra cost cut, 0..1, from the Control above
## the baseline: 0 at Lv 1, never reaching MADRA_COST_CUT_CEILING.
func get_madra_cost_cut() -> float:
	return flattening_curve(control - STAT_BASELINE, MADRA_COST_CUT_CEILING, MADRA_COST_CUT_HALF_POINT)

## The fraction of a technique's cooldown cut, 0..1, from the Control above the
## baseline: 0 at Lv 1, never reaching COOLDOWN_CUT_CEILING.
func get_cooldown_cut() -> float:
	return flattening_curve(control - STAT_BASELINE, COOLDOWN_CUT_CEILING, COOLDOWN_CUT_HALF_POINT)

## A value that grows with the points above the baseline and flattens toward
## the ceiling: ceiling x points / (points + half_point), so half_point points
## give half the ceiling. Points below the baseline count as none.
static func flattening_curve(points_above_baseline: float, ceiling: float, half_point: float) -> float:
	var x: float = maxf(0.0, points_above_baseline)
	return ceiling * x / (x + half_point)

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "CharacterAttributesData(\n  Strength: %.1f\n  Body: %.1f\n  Agility: %.1f\n  Spirit: %.1f\n  Mind: %.1f\n  Control: %.1f\n  Armor: %.1f\n  Ward: %.1f\n)" % [
		strength, body, agility, spirit, mind, control, armor, ward
	]
