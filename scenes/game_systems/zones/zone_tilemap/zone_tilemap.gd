extends Node2D

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var character_body: CharacterBody2D = $CharacterBody2D

var floating_text_scene : PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")

## variable that stores the tile the character is on
var selected_zone: ZoneData = null:
	set(value):
		selected_zone = value
		ZoneManager.set_current_zone(value)

func _ready():
	selected_zone = ZoneManager.get_current_zone()
	
	for zone_data in ZoneManager.get_all_zones():
		tile_map.set_cell_to_variant(_get_zone_variant(zone_data), zone_data.tilemap_location)

	update_zone_tile_state(selected_zone)
	_move_character_to(selected_zone.tilemap_location)

	# Connect to tile map layer for zone selection
	if tile_map.has_signal("zone_tile_clicked"):
		tile_map.zone_tile_clicked.connect(_on_zone_tile_clicked)
	
	ActionManager.start_foraging.connect(_on_start_foraging)
	ActionManager.stop_foraging.connect(_on_stop_foraging)
	ActionManager.foraging_completed.connect(_on_foraging_completed)

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
		tile_map.set_cell_to_variant(_get_zone_variant(previous_selected), previous_selected.tilemap_location)
	
	# Update current selected zone
	tile_map.set_cell_to_variant(_get_zone_variant(zone_data), zone_data.tilemap_location)

## Returns the tile variant index based on zone state.
func _get_zone_variant(zone_data: ZoneData) -> int:
	# Variant 0: default/white
	# Variant 1: green (unlocked)
	# Variant 2: blue (selected)
	# Variant 3+: other states
	
	if selected_zone == zone_data:
		return 2  # Selected (blue)
	
	# Check if zone is unlocked (TODO: integrate with UnlockManager when available)
	# For now, assume all zones are unlocked
	return 1  # Unlocked (green)

## Called when a tile is clicked on the tile map.
func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	var zone_data = get_zone_at_tile(tile_coord)
	if zone_data == selected_zone:
		return
	
	if zone_data:
		zone_selected.emit(zone_data, tile_coord)
		update_zone_tile_state(zone_data)
	
	_move_character_to(tile_coord)

func _move_character_to(tile_coord: Vector2i) -> void:
	character_body.global_position = tile_map.map_to_local(tile_coord) + tile_map.position

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_foraging() -> void:
	_character_move_to_new_foraging_location()

func _on_stop_foraging() -> void:
	_move_character_to(selected_zone.tilemap_location)

func _on_foraging_completed(item_amount: int, item_definition: ItemDefinitionData) -> void:
	_show_foraging_completion_floating_text(item_amount, item_definition)
	_character_move_to_new_foraging_location()

func _character_move_to_new_foraging_location() -> void:
	# Get a random global position within the tilemap, accounting for a margin
	var margin := 32
	var random_local_pos := tile_map.map_to_local(selected_zone.tilemap_location) + tile_map.position
	
	random_local_pos.x += randf_range(-margin, margin)
	random_local_pos.y += randf_range(-margin, margin)
	
	character_body.position = random_local_pos

func _show_foraging_completion_floating_text(item_amount: int, item_definition: ItemDefinitionData) -> void:
	print("granted %d of %s" % [item_amount, item_definition])
	var floating_text = floating_text_scene.instantiate() as FloatingText
	if floating_text:
		get_tree().current_scene.add_child(floating_text)
		floating_text.show_text("%d of %s" % [item_amount, item_definition.item_name], Color.WHITE, Vector2i(250, 250))
		print(InventoryManager.get_inventory())
