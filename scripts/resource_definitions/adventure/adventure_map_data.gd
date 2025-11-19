class_name AdventureMapData
extends Resource

## Generation Parameters
@export var num_special_tiles: int = 5
@export var max_distance_from_start: int = 6
@export var sparse_factor: int = 2

## Event "Pools"
# These are the actual events the generator will place on the map.

# The event for the boss tile (guaranteed to be furthest away)
@export var boss_encounter: AdventureEncounter

# An array of events to pick from for the other special tiles
@export var special_encounter_pool: Array[AdventureEncounter]

# An array of events to pick from for the path tiles (e.g., combat)
@export var path_encounter_pool: Array[AdventureEncounter]
