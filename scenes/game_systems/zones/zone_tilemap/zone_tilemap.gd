extends Node2D

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

@export var zone_data_list : ZoneDataList = preload("res://resources/game_systems/zones/zone_data/zone_data_list.tres")

@onready var tile_map: TileMapLayer = $TileMapLayer

## variable that stores the tile the character is on
var selected_zone: ZoneData = null

func _ready():
	for zone_data in zone_data_list.list:
		tile_map.set_cell_to_variant(_get_zone_variant(zone_data), zone_data.tilemap_location)
	
	# Connect to tile map layer for zone selection
	if tile_map.has_signal("zone_tile_clicked"):
		tile_map.zone_tile_clicked.connect(_on_zone_tile_clicked)

func get_zone_at_tile(tile_coord: Vector2i) -> ZoneData:
	"""Returns the ZoneData at the given tile coordinate, or null if not found"""
	for zone_data in zone_data_list.list:
		if zone_data.tilemap_location == tile_coord:
			return zone_data
	return null

func update_zone_tile_state(zone_data: ZoneData) -> void:
	"""Updates tile variant based on zone state (locked/unlocked/selected)"""
	if not zone_data:
		return
	
	var previous_selected = selected_zone
	selected_zone = zone_data
	
	# Update previous selected zone back to normal (if any)
	if previous_selected and previous_selected != zone_data:
		tile_map.set_cell_to_variant(_get_zone_variant(previous_selected), previous_selected.tilemap_location)
	
	# Update current selected zone
	tile_map.set_cell_to_variant(_get_zone_variant(zone_data), zone_data.tilemap_location)

func _get_zone_variant(zone_data: ZoneData) -> int:
	"""Returns the tile variant index based on zone state"""
	# Variant 0: default/white
	# Variant 1: green (unlocked)
	# Variant 2: blue (selected)
	# Variant 3+: other states
	
	if selected_zone == zone_data:
		return 2  # Selected (blue)
	
	# Check if zone is unlocked (TODO: integrate with UnlockManager when available)
	# For now, assume all zones are unlocked
	return 1  # Unlocked (green)

func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	"""Called when a tile is clicked on the tile map"""
	var zone_data = get_zone_at_tile(tile_coord)
	if zone_data:
		zone_selected.emit(zone_data, tile_coord)
		update_zone_tile_state(zone_data)
