class_name ZoneTilemap
extends Node2D

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Camera")
## How long the camera takes to glide to a newly-selected zone.
## Higher = slower, more contemplative. Lower = snappier.
@export_range(0.1, 3.0, 0.05) var camera_ease_duration: float = 0.65

@export_group("Ghost Neighbors")
## Color of the hex-shaped polygon overlays that sit around real zones
## to frame the playable area (so zones don't look like they're floating
## in the middle of nowhere). Dark near-black at ~74% alpha reads as
## "edge of the known world" / bounds marker. Alpha 0 would make them
## invisible.
@export var ghost_neighbor_color: Color = Color(0.005910289, 0.0075441017, 0.018441157, 0.7411765)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var tile_map: HexagonTileMapLayer = %MainZoneTileMapLayer
@onready var character_body: CharacterBody2D = %PlayerCharacter
@onready var _camera: Camera2D = %Camera2D
@onready var _hover_selector: HexHoverSelector = %HoverSelector
@onready var _locked_overlay_container: Node2D = %LockedOverlayContainer
@onready var _glowing_path_container: Node2D = %GlowingPathContainer
@onready var _ghost_neighbor_container: Node2D = %GhostNeighborContainer

var _locked_overlays: Dictionary[Vector2i, LockedZoneOverlay] = {}

# Hex polygon points for a ghost-neighbor tile. Matches the 164x190
# tile grid so adjacent polygons touch edge-to-edge with no gaps.
# Same geometry as LockedZoneOverlay.GreyBackground. Can't be a const
# because PackedVector2Array(Vector2(...)) isn't a constant expression
# in GDScript — but it's effectively immutable at the class level.
var _ghost_hex_points: PackedVector2Array = PackedVector2Array([
	Vector2(0, -95),
	Vector2(82.2, -47.5),
	Vector2(82.2, 47.5),
	Vector2(0, 95),
	Vector2(-82.2, 47.5),
	Vector2(-82.2, -47.5),
])

# Forest tile atlas. All Hex_Forest_NN variants are packed into a single
# TileSetAtlasSource (sources/8 in tilemap_tileset.tres) backed by
# hex_forest_atlas.png. The Python script that generates the atlas
# (scenes/tilemaps/scripts/pack_hex_atlas.py) lays variants out
# left-to-right top-to-bottom in FOREST_ATLAS_COLS columns, so variant
# index N maps to atlas cell (N % FOREST_ATLAS_COLS, N / FOREST_ATLAS_COLS).
# ZoneData.tile_variant_index picks which cell each zone renders.
# Keep FOREST_ATLAS_COLS in sync with ATLAS_COLS in pack_hex_atlas.py and
# bump FOREST_VARIANT_COUNT whenever new Hex_Forest_NN variants are added.
const FOREST_ATLAS_SOURCE_ID := 8
const FOREST_ATLAS_COLS := 6
const FOREST_VARIANT_COUNT := 23

# Movement and display constants
const CHARACTER_MOVE_SPEED = 150.0
const FORAGE_POSITION_MARGIN = 32

const LockedZoneOverlayScene := preload("res://scenes/zones/locked_zone_overlay/locked_zone_overlay.tscn")
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
	_refresh_locked_overlays()
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

## Returns the atlas cell coords for a given zone's forest variant.
## Variant index N maps to (N % FOREST_ATLAS_COLS, N / FOREST_ATLAS_COLS)
## to match the layout produced by pack_hex_atlas.py. Falls back to cell
## (0, 0) if tile_variant_index is out of range.
func _get_zone_tile_atlas_coords(zone_data: ZoneData) -> Vector2i:
	var idx := zone_data.tile_variant_index
	if idx < 0 or idx >= FOREST_VARIANT_COUNT:
		Log.warn("ZoneTilemap: zone '%s' has tile_variant_index %d but only %d forest variants exist; falling back to 0" % [zone_data.zone_id, idx, FOREST_VARIANT_COUNT])
		return Vector2i.ZERO
	@warning_ignore("integer_division")
	return Vector2i(idx % FOREST_ATLAS_COLS, idx / FOREST_ATLAS_COLS)

## Set all zones in the tile_map. All zones (locked or unlocked) render
## with their assigned forest variant — locked zones get a grey+lock
## overlay on top via _refresh_locked_overlays() rather than a different
## tile source. Selected/unselected state has no tile-side difference;
## the player character sprite is the only "you are here" indicator.
func set_all_zones_in_tile_map() -> void:
	var all_zones = ZoneManager.get_all_zones()

	for zone_data in all_zones:
		tile_map.set_cell_with_source_and_variant(FOREST_ATLAS_SOURCE_ID, 0, zone_data.tilemap_location, _get_zone_tile_atlas_coords(zone_data))

	_refresh_ghost_neighbors()


## Returns the ZoneData at the given tile coordinate, or null if not found.
func get_zone_at_tile(tile_coord: Vector2i) -> ZoneData:
	for zone_data in ZoneManager.get_all_zones():
		if zone_data.tilemap_location == tile_coord:
			return zone_data
	return null

## Updates the selected_zone bookkeeping when the player moves. The tile
## itself doesn't visually change between selected/unselected states —
## the player character sprite is the only "you are here" indicator —
## so we don't need to redraw the previous tile.
func update_zone_tile_state(zone_data: ZoneData) -> void:
	if not zone_data:
		return

	selected_zone = zone_data

## Rebuilds the hex-shaped ghost neighbor polygons that frame the zone
## cluster. Uses TileMapLayer.get_surrounding_cells() so the 6 hex
## neighbors are computed correctly regardless of row parity (the
## previous hardcoded offsets only worked for one row parity).
##
## Ghost neighbors are rendered as solid-color Polygon2Ds (not tilemap
## variants) so adjacent ghosts touch edge-to-edge with zero seams —
## tilemap-based ghosts had anti-aliased edges that created visible
## double-alpha seams where two ghost hexes met.
func _refresh_ghost_neighbors() -> void:
	for child in _ghost_neighbor_container.get_children():
		child.queue_free()

	# Build a set of real zone positions so we don't place a ghost over a zone.
	var zone_coords := {}
	for zone_data in ZoneManager.get_all_zones():
		zone_coords[zone_data.tilemap_location] = true

	# Collect unique ghost positions (a position adjacent to multiple zones
	# should only get one polygon).
	var ghost_coords := {}
	for zone_data in ZoneManager.get_all_zones():
		for neighbor_coord in tile_map.get_surrounding_cells(zone_data.tilemap_location):
			if zone_coords.has(neighbor_coord):
				continue
			ghost_coords[neighbor_coord] = true

	# Spawn one hex polygon per ghost coordinate.
	for coord in ghost_coords.keys():
		var polygon := Polygon2D.new()
		polygon.polygon = _ghost_hex_points
		polygon.color = ghost_neighbor_color
		polygon.position = tile_map.map_to_local(coord) + tile_map.position
		_ghost_neighbor_container.add_child(polygon)

func _ease_camera_to(world_pos: Vector2) -> void:
	# TRANS_CUBIC + EASE_IN_OUT gives a smooth slow-start / slow-end glide
	# (no overshoot, no abrupt initial velocity). The previous TRANS_BACK
	# overshoot felt sudden because EASE_OUT starts at maximum velocity.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", world_pos, camera_ease_duration)

## Called when a tile is clicked on the tile map.
func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	var zone_data = get_zone_at_tile(tile_coord)
	Log.info("ZoneTilemap: Zone tile clicked: %s" % tile_coord)
	if not zone_data:
		return

	if zone_data == selected_zone:
		return

	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		# Locked — shake the lock icon as denied-feedback, don't move.
		if _locked_overlays.has(tile_coord):
			_locked_overlays[tile_coord].shake()
		return

	if zone_data:
		zone_selected.emit(zone_data, tile_coord)
		update_zone_tile_state(zone_data)

	_move_character_to_tile_coord(tile_coord)
	_ease_camera_to(tile_map.map_to_local(tile_coord) + tile_map.position)

func _on_condition_unlocked(_condition_id: String) -> void:
	set_all_zones_in_tile_map()
	_refresh_locked_overlays()
	_refresh_glowing_paths()

## Rebuilds the grey-+-lock overlays for all currently-locked zones.
## Runs at scene load and whenever an unlock condition changes. Overlays
## sit above the tile (the underlying forest art is still rendered) so
## players see "here's what this zone looks like, and here's why you
## can't click it yet".
func _refresh_locked_overlays() -> void:
	for child in _locked_overlay_container.get_children():
		child.queue_free()
	_locked_overlays.clear()
	for zone_data in ZoneManager.get_all_zones():
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			continue
		var overlay := LockedZoneOverlayScene.instantiate() as LockedZoneOverlay
		_locked_overlay_container.add_child(overlay)
		overlay.position = tile_map.map_to_local(zone_data.tilemap_location) + tile_map.position
		_locked_overlays[zone_data.tilemap_location] = overlay

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
		_hover_selector.hide()
		return
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		_hover_selector.hide()
		return
	_hover_selector.show_at(tile_map.map_to_local(tile_coord) + tile_map.position)

func _on_zone_tile_unhovered() -> void:
	_hover_selector.hide()

func _move_character_to_tile_coord(tile_coord: Vector2i) -> void:
	var world_pos := tile_map.map_to_local(tile_coord) + tile_map.position
	_move_character_to_position(world_pos)

func _move_character_to_position(new_position: Vector2) -> void:
	character_body.move_to_position(new_position, CHARACTER_MOVE_SPEED)

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
