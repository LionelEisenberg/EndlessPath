extends Node2D

# Tilemap constants
const ADVENTURE_TILE_SOURCE_ID = 0
const ADVENTURE_TILE_VARIANT_ID = 1
const CHARACTER_MOVE_SPEED = 150.0
const INSTANT_MOVE_SPEED = 10000.0

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
	
	if tile_map:
		tile_map.tile_clicked.connect(_on_tile_clicked)
		
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
	character_body.clear_movement_queue()
	character_body.move_to_position(Vector2(0, 0), INSTANT_MOVE_SPEED)

func _on_tile_clicked(coord: Vector2i) -> void:
	Log.info("AdventureTilemap: Tile clicked: %s" % coord)
	
	# Get the character's current tile position in cube coordinates
	var char_world_pos = character_body.global_position - tile_map.position
	var char_map_coord = tile_map.local_to_map(char_world_pos)
	var char_cube_coord = tile_map.map_to_cube(char_map_coord)
	
	# Get the target tile in cube coordinates
	var target_cube_coord = tile_map.map_to_cube(coord)
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = tile_map.cube_pathfind(char_cube_coord, target_cube_coord)
	
	# Convert each cube coordinate to world position
	var world_positions: Array[Vector2] = []
	for cube_coord in path_cube_coords:
		var map_coord = tile_map.cube_to_map(cube_coord)
		var world_pos = tile_map.map_to_local(map_coord) + tile_map.position
		world_positions.append(world_pos)
	
	# Queue the movement path
	if world_positions.size() > 0:
		character_body.queue_movement_path(world_positions, CHARACTER_MOVE_SPEED)

func _draw_tiles() -> void:
	for coord in _adventure_tile_dictionary.keys():
		tile_map.set_cell_with_source_and_variant(ADVENTURE_TILE_SOURCE_ID, ADVENTURE_TILE_VARIANT_ID, tile_map.cube_to_map(coord))
