class_name AdventureResultData
extends Resource

## AdventureResultData
## Bundles all stats collected during an adventure for display on the end card.

#-----------------------------------------------------------------------------
# RESULT DATA
#-----------------------------------------------------------------------------

## Whether the adventure ended in victory (boss defeated)
var is_victory: bool = false

## Human-readable reason for defeat (empty string on victory)
var defeat_reason: String = ""

## Number of combat encounters fought
var combats_fought: int = 0

## Total number of combat encounters on the map
var combats_total: int = 0

## Total gold earned across all combats
var gold_earned: int = 0

## Time elapsed in seconds from adventure start to end
var time_elapsed: float = 0.0

## Player health remaining at end of adventure
var health_remaining: float = 0.0

## Player max health
var health_max: float = 0.0

## Number of unique tiles the player visited
var tiles_explored: int = 0

## Total number of tiles on the map
var tiles_total: int = 0

## Madra budget spent to start the adventure
var madra_spent: float = 0.0

## Items received from loot drops during the adventure
var loot_items: Array[Resource] = []
