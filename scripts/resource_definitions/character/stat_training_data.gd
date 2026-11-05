class_name StatTrainingData
extends Resource

## StatTrainingData
## The player's training record: a level and the XP toward the next level for
## each of the six stats, keyed by `CharacterAttributesData.stat_key()`. Saved as
## `SaveGameData.stat_training`. In play, CharacterManager is its only reader and
## writer; SaveGameData seeds it (`new_current()`) and rewrites it when a save
## loads (the version 2 migration and `repair()`).

#-----------------------------------------------------------------------------
# RECORD
#-----------------------------------------------------------------------------

## Stat key to the stat's level. A stat with no entry is at Lv 1.
@export var levels: Dictionary[StringName, int] = {}

## Stat key to the XP toward the stat's next level. A stat with no entry has none.
@export var xp: Dictionary[StringName, float] = {}

#-----------------------------------------------------------------------------
# CONSTRUCTION
#-----------------------------------------------------------------------------

## A record with every stat at Lv 1 and no XP.
static func new_default() -> StatTrainingData:
	var record := StatTrainingData.new()
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		record.set_level(stat, 1)
		record.set_xp(stat, 0.0)
	return record

#-----------------------------------------------------------------------------
# LEVELS AND XP
#-----------------------------------------------------------------------------

## The stat's level, 1 when the record holds none.
func get_level(stat: CharacterAttributesData.AttributeType) -> int:
	return levels.get(CharacterAttributesData.stat_key(stat), 1)

## Writes the stat's level as given, unclamped: CharacterManager enforces the rules.
func set_level(stat: CharacterAttributesData.AttributeType, level: int) -> void:
	levels[CharacterAttributesData.stat_key(stat)] = level

## The XP toward the stat's next level, 0.0 when the record holds none.
func get_xp(stat: CharacterAttributesData.AttributeType) -> float:
	return xp.get(CharacterAttributesData.stat_key(stat), 0.0)

## Writes the XP toward the stat's next level as given, unclamped:
## CharacterManager enforces the rules.
func set_xp(stat: CharacterAttributesData.AttributeType, value: float) -> void:
	xp[CharacterAttributesData.stat_key(stat)] = value
