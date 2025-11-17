extends Node2D

@onready var tile_map: HexagonTileMapLayer = %HexagonTileMapLayer
@onready var character_body: CharacterBody2D = %CharacterBody2D

var current_adventure_action_data : AdventureActionData = null
var adventure_map_generator : AdventureMapGenerator

## Main data structure for the adventure tilemap, key is the cube coordinate, value is the adventure tile event
var _adventure_tile_dictionary : Dictionary[Vector3i, AdventureTileEvent] = {}

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureTilemap: ActionManager is missing!")
		
	adventure_map_generator = AdventureMapGenerator.new()
	adventure_map_generator.set_tile_map(tile_map)

func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)
	
	current_adventure_action_data = action_data

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_map_data(current_adventure_action_data.adventure_data.map_data)
	_adventure_tile_dictionary = adventure_map_generator.generate_adventure_map()
	_draw_tiles()

func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	current_adventure_action_data = null

	_adventure_tile_dictionary.clear()
	tile_map.clear()
	character_body.move_to_position(Vector2(0, 0), 10000)

func _draw_tiles() -> void:
	for coord in _adventure_tile_dictionary.keys():
		tile_map.set_cell_with_source_and_variant(0, 1, tile_map.cube_to_map(coord))
