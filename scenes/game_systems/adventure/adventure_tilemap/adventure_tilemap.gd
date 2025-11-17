extends Node2D

# Tilemap constants
const FULL_MAP_TILE_SOURCE_ID = 0
const FULL_MAP_TILE_VARIANT_ID = 3
const VISIBLE_MAP_TILE_SOURCE_ID = 0
const VISITED_MAP_TILE_VARIANT_ID = 1
const NOT_VISITED_MAP_TILE_VARIANT_ID = 2
const CHARACTER_MOVE_SPEED = 150.0
const INSTANT_MOVE_SPEED = 10000.0

@onready var full_map: HexagonTileMapLayer = %AdventureFullMap
@onready var visible_map: HexagonTileMapLayer = %AdventureVisibleMap
@onready var highlight_map: HexagonTileMapLayer = %AdventureHighlightMap
@onready var character_body: CharacterBody2D = %CharacterBody2D

var current_adventure_action_data : AdventureActionData = null
var adventure_map_generator : AdventureMapGenerator

## Main data structure for the adventure tilemap, key is the cube coordinate, value is the adventure tile event
var _adventure_tile_dictionary : Dictionary[Vector3i, AdventureTileEvent] = {}
var _visited_tile_dictionary : Dictionary[Vector3i, bool] = {}
var _highlight_tile_dictionary : Dictionary[Vector3i, int] = {}

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureTilemap: ActionManager is missing!")
	
	if visible_map:
		visible_map.tile_clicked.connect(_on_tile_clicked)
		
	adventure_map_generator = AdventureMapGenerator.new()
	adventure_map_generator.set_tile_map(full_map)

func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)
	
	current_adventure_action_data = action_data

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_map_data(current_adventure_action_data.adventure_data.map_data)
	_adventure_tile_dictionary = adventure_map_generator.generate_adventure_map()
	
	_update_full_map()
	
	_visit(Vector3i.ZERO)
	
	_update_visible_map()

func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	
	current_adventure_action_data = null
	full_map.clear()
	visible_map.clear()
	highlight_map.clear()
	_adventure_tile_dictionary.clear()
	_visited_tile_dictionary.clear()
	_highlight_tile_dictionary.clear()
	character_body.clear_movement_queue()
	character_body.move_to_position(Vector2(0, 0), INSTANT_MOVE_SPEED)

func _visit(coord: Vector3i) -> void:
	_visited_tile_dictionary[coord] = true
	_highlight_tile_dictionary.clear()
	
	for c in _visited_tile_dictionary.keys():
		for neighbour in full_map.cube_neighbors(c):
			if neighbour in _adventure_tile_dictionary.keys() and neighbour not in _visited_tile_dictionary.keys():
				_highlight_tile_dictionary[neighbour] = 0

func _on_tile_clicked(coord: Vector2i) -> void:
	Log.info("AdventureTilemap: Tile clicked: %s" % coord)
	
	# Get the character's current tile position in cube coordinates
	var char_world_pos = character_body.global_position - visible_map.position
	var char_map_coord = visible_map.local_to_map(char_world_pos)
	var char_cube_coord = visible_map.map_to_cube(char_map_coord)
	
	# Get the target tile in cube coordinates
	var target_cube_coord = visible_map.map_to_cube(coord)
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = visible_map.cube_pathfind(char_cube_coord, target_cube_coord)
	
	# Convert each cube coordinate to world position
	var world_positions: Array[Vector2] = []
	for cube_coord in path_cube_coords:
		var map_coord = visible_map.cube_to_map(cube_coord)
		var world_pos = visible_map.map_to_local(map_coord) + visible_map.position
		world_positions.append(world_pos)
	
	# Queue the movement path
	character_body.clear_movement_queue()
	if world_positions.size() > 0:
		character_body.queue_movement_path(world_positions, CHARACTER_MOVE_SPEED)

func _update_full_map() -> void:
	full_map.clear()
	for coord in _adventure_tile_dictionary.keys():
		full_map.set_cell_with_source_and_variant(FULL_MAP_TILE_SOURCE_ID, FULL_MAP_TILE_VARIANT_ID, full_map.cube_to_map(coord))

func _update_visible_map() -> void:
	visible_map.clear()
	for coord in _visited_tile_dictionary.keys():
		visible_map.set_cell_with_source_and_variant(VISIBLE_MAP_TILE_SOURCE_ID, VISITED_MAP_TILE_VARIANT_ID, full_map.cube_to_map(coord))

	for coord in _highlight_tile_dictionary.keys():
		visible_map.set_cell_with_source_and_variant(VISIBLE_MAP_TILE_SOURCE_ID, NOT_VISITED_MAP_TILE_VARIANT_ID, full_map.cube_to_map(coord))
