extends Node2D

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

@onready var tile_map: HexagonTileMapLayer = %MainZoneTileMapLayer
@onready var character_body: CharacterBody2D = %CharacterBody2D
@onready var selected_zone_pulse_node: Line2D = %PulseNode

const UNLOCKED_SOURCE_ID = 0
const LOCKED_SOURCE_ID = 1
const BASE_LOCKED_VARIANT = 0
const BASE_GHOST_VARIANT = 3

# Movement and display constants
const CHARACTER_MOVE_SPEED = 150.0
const FORAGE_POSITION_MARGIN = 32
const FLOATING_TEXT_OFFSET = Vector2i(250, 250)

var floating_text_scene: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")

## variable that stores the tile the character is on
var selected_zone: ZoneData:
	set(value):
		selected_zone = value
		ZoneManager.set_current_zone(value)

func _ready() -> void:
	selected_zone = ZoneManager.get_current_zone()
	
	set_all_zones_in_tile_map()
	update_zone_tile_state(selected_zone)
	_move_character_to_tile_coord(selected_zone.tilemap_location)

	# Connect to tile map layer for zone selection
	if tile_map.has_signal("tile_clicked"):
		tile_map.tile_clicked.connect(_on_zone_tile_clicked)
	
	# Connect to ActionManager signals
	if ActionManager:
		ActionManager.start_foraging.connect(_on_start_foraging)
		ActionManager.stop_foraging.connect(_on_stop_foraging)
		ActionManager.foraging_completed.connect(_on_foraging_completed)
	else:
		Log.critical("ZoneTilemap: ActionManager is not loaded!")
	
	# Connect to UnlockManager signals
	if UnlockManager:
		UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	else:
		Log.critical("ZoneTilemap: UnlockManager is not loaded!")

## Set all zones in the tile_map
func set_all_zones_in_tile_map() -> void:
	var zone_tiles: Array[Vector2i] = []
	var all_zones = ZoneManager.get_all_zones()
	
	for zone_data in all_zones:
		zone_tiles.append(zone_data.tilemap_location)
	
	for zone_data in all_zones:
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			tile_map.set_cell_with_source_and_variant(UNLOCKED_SOURCE_ID, _get_zone_variant(zone_data), zone_data.tilemap_location)
		else:
			tile_map.set_cell_with_source_and_variant(LOCKED_SOURCE_ID, BASE_LOCKED_VARIANT, zone_data.tilemap_location)
	
	for zone_data in all_zones:
		_set_neighboring_tiles_transparent(zone_data.tilemap_location, zone_tiles)


## Returns the ZoneData at the given tile coordinate, or null if not found.
func get_zone_at_tile(tile_coord: Vector2i) -> ZoneData:
	for zone_data in ZoneManager.get_all_zones():
		if zone_data.tilemap_location == tile_coord:
			return zone_data
	return null

## Updates tile variant based on zone state (locked/unlocked/selected).
func update_zone_tile_state(zone_data: ZoneData) -> void:
	if not zone_data:
		return
	
	var previous_selected = selected_zone
	selected_zone = zone_data
	
	# Update previous selected zone back to normal (if any)
	if previous_selected and previous_selected != zone_data:
		tile_map.set_cell_with_source_and_variant(UNLOCKED_SOURCE_ID, _get_zone_variant(previous_selected), previous_selected.tilemap_location)
	
	# Update current selected zone
	tile_map.set_cell_with_source_and_variant(UNLOCKED_SOURCE_ID, _get_zone_variant(zone_data), zone_data.tilemap_location)

## Returns the tile variant index based on zone state.
func _get_zone_variant(zone_data: ZoneData) -> int:
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		return 3
	
	if selected_zone == zone_data:
		return 2

	return 1

## Sets all neighboring tiles around a zone to transparent variant (4).
## Does not overwrite tiles that are actual zone placements.
func _set_neighboring_tiles_transparent(tile_coord: Vector2i, zone_tiles: Array[Vector2i]) -> void:
	# Get all 8 neighboring tile coordinates
	var neighbor_offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), # Top row
		Vector2i(-1, 0), Vector2i(1, 0), # Middle row (left and right)
		Vector2i(0, 1), Vector2i(1, 1) # Bottom row
	]
	
	for offset in neighbor_offsets:
		var neighbor_tile = tile_coord + offset
		
		# Don't overwrite if this tile is an actual zone placement
		if neighbor_tile in zone_tiles:
			continue

		tile_map.set_cell_with_source_and_variant(UNLOCKED_SOURCE_ID, BASE_GHOST_VARIANT, neighbor_tile)

## Called when a tile is clicked on the tile map.
func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	var zone_data = get_zone_at_tile(tile_coord)
	Log.info("ZoneTilemap: Zone tile clicked: %s" % tile_coord)
	if not zone_data:
		return
	
	if zone_data == selected_zone:
		return
	
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		return
	
	if zone_data:
		zone_selected.emit(zone_data, tile_coord)
		update_zone_tile_state(zone_data)
	
	_move_character_to_tile_coord(tile_coord)

func _on_condition_unlocked(_condition_id: String) -> void:
	set_all_zones_in_tile_map()

func _move_character_to_tile_coord(tile_coord: Vector2i) -> void:
	_move_character_to_position(tile_map.map_to_local(tile_coord) + tile_map.position)
	selected_zone_pulse_node.global_position = tile_map.map_to_local(tile_coord) + tile_map.position

func _move_character_to_position(new_position: Vector2) -> void:
	character_body.move_to_position(new_position, CHARACTER_MOVE_SPEED)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_foraging() -> void:
	_character_move_to_new_foraging_location()

func _on_stop_foraging() -> void:
	_move_character_to_tile_coord(selected_zone.tilemap_location)

func _on_foraging_completed(items: Dictionary) -> void:
	_show_foraging_completion_floating_text(items)
	_character_move_to_new_foraging_location()

func _character_move_to_new_foraging_location() -> void:
	# Get a random global position within the tilemap, accounting for a margin
	var random_local_pos := tile_map.map_to_local(selected_zone.tilemap_location) + tile_map.position
	
	random_local_pos.x += randf_range(-FORAGE_POSITION_MARGIN, FORAGE_POSITION_MARGIN)
	random_local_pos.y += randf_range(-FORAGE_POSITION_MARGIN, FORAGE_POSITION_MARGIN)
	
	_move_character_to_position(random_local_pos)

func _show_foraging_completion_floating_text(items: Dictionary) -> void:
	if items.is_empty():
		return
	
	var floating_text = floating_text_scene.instantiate() as FloatingText
	if floating_text:
		get_tree().current_scene.add_child(floating_text)
		
		# Build a text string showing all items
		var text_parts: Array[String] = []
		for item in items:
			var quantity: int = items[item]
			text_parts.append("%d %s" % [quantity, item.item_name])
		
		var full_text = ", ".join(text_parts)
		floating_text.show_text(full_text, Color.WHITE, FLOATING_TEXT_OFFSET)
