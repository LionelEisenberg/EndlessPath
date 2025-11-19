class_name AdventureData
extends Resource

## The data for an adventure
@export var adventure_id: String = ""
@export var adventure_name: String = ""
@export var adventure_description: String = ""

## The parameters used to generate the map for this adventure
@export var map_data: AdventureMapData
