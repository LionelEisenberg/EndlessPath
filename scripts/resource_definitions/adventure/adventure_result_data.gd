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

## The Madra the pool held when the run ended: it stays there.
var madra_left: float = 0.0

## The pool's max when the run ended.
var madra_max: float = 0.0

## The Core Density XP the run's rewards paid, won or lost (AdventureTilemap's
## run total): what the core took, nothing at a full core.
var core_density_xp_earned: float = 0.0

## The Core Density level when the run started, and when it ended.
var core_density_level_before: int = 0
var core_density_level_after: int = 0

## Items received from loot drops during the adventure
var loot_items: Array[Resource] = []
