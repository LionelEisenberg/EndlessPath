class_name AdventureData
extends Resource

## The data for an adventure
@export_category("Adventure Information")
@export var adventure_id: String = ""
@export var adventure_name: String = ""
@export var adventure_description: String = ""

## The parameters used to generate the map for this adventure
@export_category("Map Parameters")
## Placement Generation Parameters
@export_group("Placement Parameters")
@export var num_special_tiles: int = 5
@export var max_distance_from_start: int = 6
@export var sparse_factor: int = 2

## Tile selection parameters
@export_group("Encounter Parameters")
@export var num_path_encounters: int = 5

## Event "Pools"
@export var boss_encounter: AdventureEncounter

# An array of events to pick from for the other special tiles
@export var special_encounter_pool: Array[AdventureEncounter]

# An array of events to pick from for the path tiles (e.g., combat)
@export var path_encounter_pool: Array[AdventureEncounter]
