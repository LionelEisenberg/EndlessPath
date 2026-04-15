class_name ZoneTilemap
extends Node2D

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Aura Breathing")
## Smallest scale the current-zone aura sprite shrinks to during the pulse.
@export_range(0.1, 2.0, 0.05) var aura_min_scale: float = 0.85
## Largest scale the current-zone aura sprite expands to during the pulse.
@export_range(0.1, 2.0, 0.05) var aura_max_scale: float = 1.0
## Lowest alpha the aura sprite fades to at the pulse trough.
@export_range(0.0, 1.0, 0.05) var aura_min_alpha: float = 0.65
## Brightest alpha the aura sprite blooms to at the pulse peak.
@export_range(0.0, 1.0, 0.05) var aura_max_alpha: float = 1.0
## Duration of one bloom OR contract phase. Total cycle is 2x this value.
@export_range(0.1, 5.0, 0.05) var aura_half_cycle_seconds: float = 0.9

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var tile_map: HexagonTileMapLayer = %MainZoneTileMapLayer
@onready var character_body: CharacterBody2D = %PlayerCharacter
@onready var _camera: Camera2D = %Camera2D
@onready var _hover_sprite: Sprite2D = %HoverSprite
@onready var _aura_sprite: Sprite2D = %AuraSprite
@onready var _locked_glyph_container: Node2D = %LockedGlyphContainer
@onready var _glowing_path_container: Node2D = %GlowingPathContainer

var _aura_breath_tween: Tween

const LOCKED_SOURCE_ID = 1
const BASE_LOCKED_VARIANT = 0
const BASE_GHOST_VARIANT = 3

# Zone tile forest-variant → atlas source id mapping.
# Currently only variant 0 (Hex_Forest_00_Basic at source 8) exists; the
# other 20 variants live as a TODO in docs/zones/ZONES.md. When they get
# imported, add each new atlas source id in order below and the
# tile_variant_index field on ZoneData will pick them automatically.
const ZONE_TILE_VARIANT_SOURCE_IDS := [8]

# Movement and display constants
const CHARACTER_MOVE_SPEED = 150.0
const FORAGE_POSITION_MARGIN = 32
const FLOATING_TEXT_OFFSET = Vector2i(250, 250)
const CAMERA_EASE_DURATION := 0.5

var floating_text_scene: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")
const LockedZoneGlyphScene := preload("res://scenes/zones/locked_zone_glyph/locked_zone_glyph.tscn")
const GlowingPathScene := preload("res://scenes/zones/glowing_path/glowing_path.tscn")

## variable that stores the tile the character is on
var selected_zone: ZoneData:
	set(value):
		selected_zone = value
		ZoneManager.set_current_zone(value)

func _ready() -> void:
	selected_zone = ZoneManager.get_current_zone()

	set_all_zones_in_tile_map()
	update_zone_tile_state(selected_zone)
	_refresh_locked_glyphs()
	_refresh_glowing_paths()
	_move_character_to_tile_coord(selected_zone.tilemap_location)

	# Connect to tile map layer for zone selection
	if tile_map.has_signal("tile_clicked"):
		tile_map.tile_clicked.connect(_on_zone_tile_clicked)
	if tile_map.has_signal("tile_hovered"):
		tile_map.tile_hovered.connect(_on_zone_tile_hovered)
	if tile_map.has_signal("tile_unhovered"):
		tile_map.tile_unhovered.connect(_on_zone_tile_unhovered)
	
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

## Returns the tileset atlas source id for a given zone's forest variant.
## Falls back to variant 0 if the index is out of range.
func _get_zone_tile_source_id(zone_data: ZoneData) -> int:
	var idx := zone_data.tile_variant_index
	if idx < 0 or idx >= ZONE_TILE_VARIANT_SOURCE_IDS.size():
		Log.warn("ZoneTilemap: zone '%s' has tile_variant_index %d but only %d variants exist; falling back to 0" % [zone_data.zone_id, idx, ZONE_TILE_VARIANT_SOURCE_IDS.size()])
		return ZONE_TILE_VARIANT_SOURCE_IDS[0]
	return ZONE_TILE_VARIANT_SOURCE_IDS[idx]

## Set all zones in the tile_map
func set_all_zones_in_tile_map() -> void:
	var zone_tiles: Array[Vector2i] = []
	var all_zones = ZoneManager.get_all_zones()

	for zone_data in all_zones:
		zone_tiles.append(zone_data.tilemap_location)

	for zone_data in all_zones:
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			tile_map.set_cell_with_source_and_variant(_get_zone_tile_source_id(zone_data), _get_zone_variant(zone_data), zone_data.tilemap_location)
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
		tile_map.set_cell_with_source_and_variant(_get_zone_tile_source_id(previous_selected), _get_zone_variant(previous_selected), previous_selected.tilemap_location)

	# Update current selected zone
	tile_map.set_cell_with_source_and_variant(_get_zone_tile_source_id(zone_data), _get_zone_variant(zone_data), zone_data.tilemap_location)

## Returns the tile variant index based on zone state.
func _get_zone_variant(zone_data: ZoneData) -> int:
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		return 3
	
	if selected_zone == zone_data:
		return 2

	return 1

## Sets all neighboring tiles around a zone to the ghost variant.
## Does not overwrite tiles that are actual zone placements.
## Ghost tiles always use the default forest variant (index 0) since
## they're structural bounds markers, not tied to any specific zone.
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

		tile_map.set_cell_with_source_and_variant(ZONE_TILE_VARIANT_SOURCE_IDS[0], BASE_GHOST_VARIANT, neighbor_tile)

func _ease_camera_to(world_pos: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_camera, "position", world_pos, CAMERA_EASE_DURATION)

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
	_ease_camera_to(tile_map.map_to_local(tile_coord) + tile_map.position)

func _on_condition_unlocked(_condition_id: String) -> void:
	set_all_zones_in_tile_map()
	_refresh_locked_glyphs()
	_refresh_glowing_paths()

func _refresh_locked_glyphs() -> void:
	for child in _locked_glyph_container.get_children():
		child.queue_free()
	for zone_data in ZoneManager.get_all_zones():
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			continue
		var glyph := LockedZoneGlyphScene.instantiate() as Label
		_locked_glyph_container.add_child(glyph)
		var world_pos := tile_map.map_to_local(zone_data.tilemap_location) + tile_map.position
		glyph.position = world_pos - Vector2(glyph.size.x * 0.5, glyph.size.y * 0.5)

func _refresh_glowing_paths() -> void:
	for child in _glowing_path_container.get_children():
		child.queue_free()

	var unlocked_coords := {}
	for zone_data in ZoneManager.get_all_zones():
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			unlocked_coords[zone_data.tilemap_location] = zone_data

	var seen := {}
	for coord in unlocked_coords.keys():
		for neighbor_coord in tile_map.get_surrounding_cells(coord):
			if not unlocked_coords.has(neighbor_coord):
				continue
			var min_x := mini(coord.x, neighbor_coord.x)
			var min_y := mini(coord.y, neighbor_coord.y)
			var max_x := maxi(coord.x, neighbor_coord.x)
			var max_y := maxi(coord.y, neighbor_coord.y)
			var pair_key := "%d_%d_%d_%d" % [min_x, min_y, max_x, max_y]
			if seen.has(pair_key):
				continue
			seen[pair_key] = true

			var from_world := tile_map.map_to_local(coord) + tile_map.position
			var to_world := tile_map.map_to_local(neighbor_coord) + tile_map.position
			var path := GlowingPathScene.instantiate() as GlowingPath
			_glowing_path_container.add_child(path)
			path.setup(from_world, to_world)

func _on_zone_tile_hovered(tile_coord: Vector2i) -> void:
	var zone_data := get_zone_at_tile(tile_coord)
	if not zone_data:
		_hover_sprite.visible = false
		return
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		_hover_sprite.visible = false
		return
	if zone_data == selected_zone:
		_hover_sprite.visible = false
		return
	_hover_sprite.global_position = tile_map.map_to_local(tile_coord) + tile_map.position
	_hover_sprite.visible = true

func _on_zone_tile_unhovered() -> void:
	_hover_sprite.visible = false

func _move_character_to_tile_coord(tile_coord: Vector2i) -> void:
	var world_pos := tile_map.map_to_local(tile_coord) + tile_map.position
	_move_character_to_position(world_pos)
	_aura_sprite.global_position = world_pos
	_start_aura_breathing()

func _move_character_to_position(new_position: Vector2) -> void:
	character_body.move_to_position(new_position, CHARACTER_MOVE_SPEED)

func _start_aura_breathing() -> void:
	if _aura_breath_tween and _aura_breath_tween.is_valid():
		_aura_breath_tween.kill()
	_aura_breath_tween = create_tween()
	_aura_breath_tween.set_loops()
	_aura_breath_tween.set_trans(Tween.TRANS_SINE)
	_aura_breath_tween.set_ease(Tween.EASE_IN_OUT)
	# Bloom phase: scale up + alpha up in parallel
	_aura_breath_tween.tween_property(_aura_sprite, "scale", Vector2(aura_max_scale, aura_max_scale), aura_half_cycle_seconds)
	_aura_breath_tween.parallel().tween_property(_aura_sprite, "modulate:a", aura_max_alpha, aura_half_cycle_seconds)
	# Contract phase: scale down + alpha down in parallel
	_aura_breath_tween.tween_property(_aura_sprite, "scale", Vector2(aura_min_scale, aura_min_scale), aura_half_cycle_seconds)
	_aura_breath_tween.parallel().tween_property(_aura_sprite, "modulate:a", aura_min_alpha, aura_half_cycle_seconds)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_start_foraging() -> void:
	_character_move_to_new_foraging_location()

func _on_stop_foraging() -> void:
	_move_character_to_tile_coord(selected_zone.tilemap_location)

func _on_foraging_completed(_items: Dictionary) -> void:
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
