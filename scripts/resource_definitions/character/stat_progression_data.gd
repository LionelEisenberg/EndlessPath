class_name StatProgressionData
extends Resource

## StatProgressionData
## How stat levels grow: the XP each level costs and the value each level gives.
## Lv 1 is `CharacterAttributesData.STAT_BASELINE`.

#-----------------------------------------------------------------------------
# CURVE
#-----------------------------------------------------------------------------

## The XP that Lv 1 to Lv 2 costs.
@export var xp_to_level_two: float = 100.0
## Each level costs this many times the one before it.
@export var xp_growth: float = 1.25
## The value each level past Lv 1 adds to the stat.
@export var value_per_level: float = 1.0

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## The XP that going from `level` to the next level costs:
## xp_to_level_two x xp_growth^(level - 1), rounded to a whole number, so every
## cost and every count of cycles toward it reads exactly.
func get_xp_to_next(level: int) -> float:
	return roundf(xp_to_level_two * pow(xp_growth, level - 1))

## The stat's value at `level`: STAT_BASELINE at Lv 1, plus value_per_level for
## each level past it.
func get_value_for_level(level: int) -> float:
	return CharacterAttributesData.STAT_BASELINE + (level - 1) * value_per_level
