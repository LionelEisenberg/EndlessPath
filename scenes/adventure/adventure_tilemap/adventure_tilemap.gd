class_name AdventureTilemap
extends Node2D

## AdventureTilemap
## Manages the adventure map grid, tile visitation, character movement, and encounter triggers
## Handles pathfinding, tile visibility, and encounter processing

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal start_combat(choice: CombatChoice)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

# Tilemap tile source IDs
const BASE_TILE_SOURCE_ID = 0
const WHITE_TILE_VARIANT_ID = 0
const YELLOW_TILE_VARIANT_ID = 1
const ORANGE_TILE_VARIANT_ID = 2
const HALF_TRANSPARENT_TILE_VARIANT_ID = 3
const TRANSPARENT_TILE_VARIANT_ID = 4

const CONTOUR_SOURCE_ID = 2
const RED_CONTOUR_VARIANT_ID = 1

# Character movement speeds
const CHARACTER_MOVE_SPEED = 150.0
const INSTANT_MOVE_SPEED = 10000.0

# TODO: Calculate this dynamically based on terrain/stats instead of a constant
const MOVEMENT_STAMINA_COST = 5.0

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum HighlightType {
	VISIBLE_NEIGHBOUR,
}

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var full_map: HexagonTileMapLayer = %AdventureFullMap
@onready var visible_map: HexagonTileMapLayer = %AdventureVisibleMap
@onready var highlight_map: HexagonTileMapLayer = %AdventureHighlightMap
@onready var character_body: CharacterBody2D = %CharacterBody2D
@onready var encounter_info_panel: EncounterInfoPanel = %EncounterInfoPanel

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var current_adventure_action_data: AdventureActionData = null
var adventure_map_generator: AdventureMapGenerator

## Main data structure for the adventure tilemap, key is the cube coordinate, value is the Adventure encounter
var _encounter_tile_dictionary: Dictionary[Vector3i, AdventureEncounter] = {}
var _visited_tile_dictionary: Dictionary[Vector3i, bool] = {}
var _highlight_tile_dictionary: Dictionary[Vector3i, HighlightType] = {}

## Visitation queue - tiles the character will visit in order
var _visitation_queue: Array[Vector3i] = []
var _current_tile: Vector3i = Vector3i.ZERO

var _is_movement_locked: bool = false
var _current_combat_choice: CombatChoice = null # Store for post-combat processing
var _current_dialogue_choice: DialogueChoice = null # Store for post-dialogue processing

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("AdventureTilemap: Initializing")
	
	if visible_map:
		visible_map.tile_clicked.connect(_on_tile_clicked)
	else:
		Log.critical("AdventureTilemap: Visible map is missing!")
	
	if character_body:
		character_body.movement_completed.connect(_on_character_movement_completed)
	else:
		Log.critical("AdventureTilemap: CharacterBody2D is missing!")
	
	adventure_map_generator = AdventureMapGenerator.new()
	adventure_map_generator.set_tile_map(full_map)
	
	# Instantiate EncounterInfoPanel
	encounter_info_panel.visible = false
	encounter_info_panel.choice_selected.connect(_on_choice_selected)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts the adventure with the given action data.
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)

	current_adventure_action_data = action_data

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_data(current_adventure_action_data.adventure_data)
	_encounter_tile_dictionary = adventure_map_generator.generate_adventure_map()
	
	_update_full_map()
	
	# Initialize starting position
	_current_tile = Vector3i.ZERO
	_visit(_current_tile)

## Stops the current adventure and cleans up the map.
func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	
	# Stop character movement
	character_body.stop_moving()
	character_body.global_position = Vector2.ZERO
	
	current_adventure_action_data = null
	full_map.clear()
	visible_map.clear()
	highlight_map.clear()
	_encounter_tile_dictionary.clear()
	_visited_tile_dictionary.clear()
	_highlight_tile_dictionary.clear()
	_visitation_queue.clear()
	_current_tile = Vector3i.ZERO
	_is_movement_locked = false
	encounter_info_panel.visible = false
	

## Handles the result of a combat encounter.
func handle_combat_result(successful: bool, gold_earned: int = 0) -> void:
	Log.info("AdventureTilemap: Combat ended - Success: %s, Gold: %d" % [successful, gold_earned])
	
	if successful:
		# Award gold alongside other effects
		if gold_earned > 0:
			ResourceManager.add_gold(gold_earned)
		
		if _current_combat_choice:
			_apply_effects(_current_combat_choice.success_effects)
			
			if _current_combat_choice.is_boss:
				Log.info("AdventureTilemap: Boss defeated! Adventure Successful.")
				ActionManager.stop_action(true)
				return

		_complete_current_tile()
	else:
		if _current_combat_choice:
			_apply_effects(_current_combat_choice.failure_effects)
		# Usually failure means death/end of run, handled by ActionManager or PlayerResourceManager
	
	_current_combat_choice = null

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _visit(coord: Vector3i) -> void:
	# Always show the panel if there's an encounter
	if _encounter_tile_dictionary.has(coord):
		var tile_encounter: AdventureEncounter = _encounter_tile_dictionary[coord]
		
		# Check for NoOpEncounter (or empty choices) and auto-complete
		if tile_encounter is NoOpEncounter or tile_encounter.choices.is_empty():
			Log.info("AdventureTilemap: Auto-completing NoOp/Empty encounter at %s" % coord)
			_mark_tile_visited(coord)
			if _visited_tile_dictionary.has(coord):
				_process_next_visitation()
			encounter_info_panel.visible = false
			return

		var is_completed = _visited_tile_dictionary.has(coord)
		
		encounter_info_panel.setup(tile_encounter, is_completed)
		encounter_info_panel.visible = true
		
		if not is_completed:
			_is_movement_locked = true
			_visitation_queue.clear() # Stop any further queued movement
	else:
		encounter_info_panel.visible = false
		
	if _visited_tile_dictionary.has(coord):
		_process_next_visitation()
		return

func _on_choice_selected(choice: EncounterChoice) -> void:
	Log.info("AdventureTilemap: Choice selected: %s" % choice.label)
	
	if choice is CombatChoice:
		_current_combat_choice = choice
		start_combat.emit(choice)
		# Combat view will take over. _stop_combat will be called when done.
		
	elif choice is DialogueChoice:
		if DialogueManager:
			_current_dialogue_choice = choice
			DialogueManager.start_timeline(choice.timeline_name)
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		else:
			Log.error("AdventureTilemap: DialogueManager missing!")
			
	else:
		# Standard choice (e.g. Loot, Leave)
		_apply_effects(choice.success_effects)
		_complete_current_tile()

func _on_dialogue_ended(_resource: Resource = null) -> void:
	Log.info("AdventureTilemap: Dialogue ended")
	if _current_dialogue_choice:
		_apply_effects(_current_dialogue_choice.success_effects)
		_current_dialogue_choice = null
	_complete_current_tile()

func _complete_current_tile() -> void:
	_is_movement_locked = false
	encounter_info_panel.show_completed_state()
	_mark_tile_visited(_current_tile)

func _apply_effects(effects: Array[EffectData]) -> void:
	for effect in effects:
		if effect:
			effect.process() # TODO: Pass context if needed (player, etc.)

func _on_tile_clicked(coord: Vector2i) -> void:
	if _is_movement_locked:
		Log.info("AdventureTilemap: Movement locked. Complete the encounter first.")
		return
		
	Log.info("AdventureTilemap: Tile clicked: %s" % coord)
	
	# Don't allow new clicks if we're already processing a visitation queue
	if _visitation_queue.size() > 0 or character_body.is_moving:
		return
	
	# Get the target tile in cube coordinates
	var target_cube_coord = visible_map.map_to_cube(coord)
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = visible_map.cube_pathfind(_current_tile, target_cube_coord)
	
	# Check stamina for the full path (approximation, actual deduction happens per step)
	var _total_cost = (path_cube_coords.size() - 1) * MOVEMENT_STAMINA_COST
	if PlayerManager.vitals_manager and PlayerManager.vitals_manager.current_stamina < MOVEMENT_STAMINA_COST:
		Log.info("AdventureTilemap: Not enough stamina to move!")
		# TODO: Show UI feedback
		return
	
	# Store as visitation queue (skip first tile as we're already there)
	if path_cube_coords.size() > 1:
		_visitation_queue = path_cube_coords.slice(1) # Skip current tile
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
		
		_visit(_current_tile)

func _mark_tile_visited(coord: Vector3i) -> void:
	_visited_tile_dictionary[coord] = true
	_highlight_tile_dictionary.clear()
	
	for c in _visited_tile_dictionary.keys():
		for neighbour in full_map.cube_neighbors(c):
			if neighbour in _encounter_tile_dictionary.keys() and neighbour not in _visited_tile_dictionary.keys():
				_highlight_tile_dictionary[neighbour] = HighlightType.VISIBLE_NEIGHBOUR
	
	_update_visible_map()

## Process the next tile in the visitation queue
func _process_next_visitation() -> void:
	if _visitation_queue.size() == 0:
		Log.info("AdventureTilemap: Visitation queue empty, movement complete")
		return
	
	# Get next tile to visit
	var next_tile = _visitation_queue[0] # Peek first
	
	# Check stamina before moving
	if PlayerManager.vitals_manager:
		if PlayerManager.vitals_manager.current_stamina >= MOVEMENT_STAMINA_COST:
			PlayerManager.vitals_manager.apply_vitals_change(0, -MOVEMENT_STAMINA_COST, 0)
		else:
			Log.info("AdventureTilemap: Out of stamina, stopping movement.")
			_visitation_queue.clear()
			return

	_visitation_queue.pop_front() # Actually remove it
	
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
	for coord in _encounter_tile_dictionary.keys():
		full_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, TRANSPARENT_TILE_VARIANT_ID, full_map.cube_to_map(coord))

func _update_visible_map() -> void:
	var pulse_node_scene: PackedScene = load("res://scenes/tilemaps/pulse_node.tscn")
	visible_map.clear()
	highlight_map.clear()
	
	for child in get_children():
		if child is PulseNode:
			child.queue_free()
	
	var visible_coords = _visited_tile_dictionary.keys()
	for highlight_coord in _highlight_tile_dictionary.keys():
		if _highlight_tile_dictionary[highlight_coord] == HighlightType.VISIBLE_NEIGHBOUR:
			visible_coords.append(highlight_coord)
			var pulse_node_instance = pulse_node_scene.instantiate()
			pulse_node_instance.setup(8.0, Color("Dark Red"), 0.6)
			pulse_node_instance.global_position = full_map.cube_to_local(highlight_coord) + full_map.position
			add_child(pulse_node_instance)

	for coord in visible_coords:
		if not _encounter_tile_dictionary[coord] is NoOpEncounter:
			visible_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, YELLOW_TILE_VARIANT_ID, full_map.cube_to_map(coord))
			
			_update_cell_highlight(coord)
		else:
			visible_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, WHITE_TILE_VARIANT_ID, full_map.cube_to_map(coord))

func _update_cell_highlight(coord: Vector3i) -> void:
	const BOSS_OVERLAY_SOURCE_ID = 3
	const COMBAT_OVERLAY_SOURCE_ID = 4
	const REST_OVERLAY_SOURCE_ID = 5
	const TREASURE_OVERLAY_SOURCE_ID = 6
	const UNKNOWN_OVERLAY_SOURCE_ID = 7
	
	match _encounter_tile_dictionary[coord].encounter_type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR:
			highlight_map.set_cell_with_source_and_variant(COMBAT_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			highlight_map.set_cell_with_source_and_variant(BOSS_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			highlight_map.set_cell_with_source_and_variant(COMBAT_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			highlight_map.set_cell_with_source_and_variant(COMBAT_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		AdventureEncounter.EncounterType.REST_SITE:
			highlight_map.set_cell_with_source_and_variant(REST_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		AdventureEncounter.EncounterType.TREASURE:
			highlight_map.set_cell_with_source_and_variant(TREASURE_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
		_:
			highlight_map.set_cell_with_source_and_variant(UNKNOWN_OVERLAY_SOURCE_ID, 0, full_map.cube_to_map(coord))
