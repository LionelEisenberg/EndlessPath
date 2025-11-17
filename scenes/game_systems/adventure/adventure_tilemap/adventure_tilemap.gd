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

## Visitation queue - tiles the character will visit in order
var _visitation_queue : Array[Vector3i] = []
var _current_tile : Vector3i = Vector3i.ZERO

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureTilemap: ActionManager is missing!")
	
	if visible_map:
		visible_map.tile_clicked.connect(_on_tile_clicked)
	
	if character_body:
		character_body.movement_completed.connect(_on_character_movement_completed)
	else:
		Log.critical("AdventureTilemap: CharacterBody2D is missing!")
		
	adventure_map_generator = AdventureMapGenerator.new()
	adventure_map_generator.set_tile_map(full_map)

func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)
	
	current_adventure_action_data = action_data

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_map_data(current_adventure_action_data.adventure_data.map_data)
	_adventure_tile_dictionary = adventure_map_generator.generate_adventure_map()
	
	_update_full_map()
	
	# Initialize starting position
	_current_tile = Vector3i.ZERO
	_visit(_current_tile)
	
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
	_visitation_queue.clear()
	_current_tile = Vector3i.ZERO
	
	# Stop character movement
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
	
	# Don't allow new clicks if we're already processing a visitation queue
	if _visitation_queue.size() > 0:
		Log.info("AdventureTilemap: Already processing a visitation queue, ignoring click")
		return
	
	# Get the target tile in cube coordinates
	var target_cube_coord = visible_map.map_to_cube(coord)
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = visible_map.cube_pathfind(_current_tile, target_cube_coord)
	
	# Store as visitation queue (skip first tile as we're already there)
	if path_cube_coords.size() > 1:
		_visitation_queue = path_cube_coords.slice(1)  # Skip current tile
		Log.info("AdventureTilemap: Created visitation queue with %d tiles" % _visitation_queue.size())
		_process_next_visitation()
	else:
		Log.info("AdventureTilemap: Path is empty or only contains current tile")

## Called when character completes movement to a tile
func _on_character_movement_completed() -> void:
	# Update current tile position
	var reached_tile = _get_current_tile_from_character_position()
	
	if reached_tile != _current_tile:
		_current_tile = reached_tile
		Log.info("AdventureTilemap: Character reached tile: %s" % _current_tile)
		
		# Visit the tile if it hasn't been visited yet
		var was_unvisited = not _visited_tile_dictionary.has(_current_tile)
		if was_unvisited:
			_visit(_current_tile)
			_update_visible_map()
			
			# TODO: Trigger tile event/action here
			if _adventure_tile_dictionary.has(_current_tile):
				var tile_event = _adventure_tile_dictionary[_current_tile]
				Log.info("AdventureTilemap: Tile has event: %s" % tile_event)
				# Handle tile event logic here (combat, loot, dialogue, etc.)
	
	# Process next tile in visitation queue
	_process_next_visitation()

## Process the next tile in the visitation queue
func _process_next_visitation() -> void:
	if _visitation_queue.size() == 0:
		Log.info("AdventureTilemap: Visitation queue empty, movement complete")
		return
	
	# Get next tile to visit
	var next_tile = _visitation_queue.pop_front()
	
	# Convert to world position and move character
	var map_coord = visible_map.cube_to_map(next_tile)
	var world_pos = visible_map.map_to_local(map_coord) + visible_map.position
	
	Log.info("AdventureTilemap: Moving to next tile: %s (%d remaining in queue)" % [next_tile, _visitation_queue.size()])
	character_body.move_to_position(world_pos, CHARACTER_MOVE_SPEED * (1 + 0.2 * (_visitation_queue.size() + 1)))

## Gets the character's current tile coordinate from their world position
func _get_current_tile_from_character_position() -> Vector3i:
	var char_world_pos = character_body.global_position - visible_map.position
	var char_map_coord = visible_map.local_to_map(char_world_pos)
	return visible_map.map_to_cube(char_map_coord)

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
