class_name ZoneTilemap
extends Node2D

## ZoneTilemap
## The zone view's hex map (spec: Map; kit §6). The camera opens at zoom 2 and
## frames the current zone's centre at screen (960, 702). Every cell out to
## half a viewport past the camera clamp is fog, its tier the hex distance to
## the nearest charted zone. The zone layer holds only the map zones
## (ZoneManager.get_map_zones()): the current zone gets the brass rim, an open
## zone the hairline, and locked and uncharted zones a veiled tile. Dotted
## routes join the current zone to the other charted zones and run on to the
## uncharted ones; MapMarkers draws the plates, glyphs, ring and floaters over
## the map in screen space.

signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

## Emitted after the map redraws its zones, fog and hex states: on load, on a
## zone change, an unlock, or a dev toggle that changes the map zones.
signal map_rebuilt

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Camera")
## How long the camera takes to glide to a newly-selected zone.
## Higher = slower, more contemplative. Lower = snappier.
@export_range(0.1, 3.0, 0.05) var camera_ease_duration: float = 0.65

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

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

## A veiled (locked or uncharted) zone keeps a clickable cell on the zone layer
## without drawing its raw tile under the veil: the base tile's transparent
## alternative, as the adventure map uses for its hit cells.
const VEILED_CELL_SOURCE_ID: int = 0
const VEILED_CELL_ALTERNATIVE_ID: int = 4

## Each fog tier's atlas (fog_tileset.tres sources 1-3, one per tier) holds
## this many natural tiles in one row.
const FOG_POOL_SIZE: int = 9

## A hex tile's size in map space, and the clamp margin around the map zones.
const TILE_SIZE: Vector2 = Vector2(164, 190)
const CLAMP_MARGIN_HEXES: float = 1.5

## Where the character stands in its zone. Its 16x24 frame is centred with a
## (1, -1) offset, so its top-left is the body position + (-7, -13); this puts
## that top-left at the zone centre + (0, 19), which is screen (960, 740) in
## Spirit Valley at zoom 2 (kit §0).
const CHARACTER_STAND_OFFSET: Vector2 = Vector2(7, 32)

## Walking speed in map px a second: an adjacent zone (about 164 px) in ~0.6 s.
const CHARACTER_MOVE_SPEED: float = 275.0

const LockedZoneOverlayScene: PackedScene = preload("res://scenes/zones/locked_zone_overlay/locked_zone_overlay.tscn")
const ZoneHexMarkerScene: PackedScene = preload("res://scenes/zones/zone_hex_marker/zone_hex_marker.tscn")
const ZoneRouteScene: PackedScene = preload("res://scenes/zones/zone_route/zone_route.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var tile_map: HexagonTileMapLayer = %MainZoneTileMapLayer
@onready var character_body: CharacterBody2D = %PlayerCharacter
@onready var _fog_layer: TileMapLayer = %FogTileMapLayer
@onready var _camera: Camera2D = %Camera2D
@onready var _zoom_controller: CameraZoomController = %CameraZoomController
@onready var _clamp_controller: CameraClampController = %CameraClampController
@onready var _hover_selector: HexHoverSelector = %HoverSelector
@onready var _veil_container: Node2D = %LockedOverlayContainer
@onready var _marker_container: Node2D = %HexMarkerContainer
@onready var _route_container: Node2D = %RouteContainer
@onready var _map_markers: MapMarkers = %MapMarkers

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The rim or veil drawn over each map zone, by zone id.
var _hex_overlays: Dictionary[String, Node2D] = {}
## The dotted route into each zone that has one, by that zone's id.
var _routes: Dictionary[String, ZoneRoute] = {}
var _camera_bounds: Rect2 = Rect2()
var _frame_tween: Tween = null
## The character's idle motion (the foraging wander or the Aura Well's bob).
var _idle_motion_tween: Tween = null
var _selected_zone: ZoneData = null

## The zone the character stands in, or walks to. Setting it makes it the
## current zone (ZoneManager.set_current_zone).
var selected_zone: ZoneData:
	get:
		return _selected_zone
	set(value):
		_selected_zone = value
		ZoneManager.set_current_zone(value)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	selected_zone = ZoneManager.get_current_zone()

	_rebuild_map()
	_place_character(selected_zone)
	frame_zone(selected_zone)

	# Connect to tile map layer for zone selection
	tile_map.tile_clicked.connect(_on_zone_tile_clicked)
	tile_map.tile_hovered.connect(_on_zone_tile_hovered)
	tile_map.tile_unhovered.connect(_on_zone_tile_unhovered)

	character_body.movement_completed.connect(_on_character_movement_completed)
	ActionManager.start_foraging.connect(_on_start_foraging)
	ActionManager.stop_foraging.connect(_on_idle_action_stopped)
	ActionManager.foraging_completed.connect(_on_foraging_completed)
	ActionManager.start_training.connect(_on_start_training)
	ActionManager.stop_training.connect(_on_idle_action_stopped)
	UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	ZoneManager.zone_changed.connect(_on_zone_changed)
	ZoneManager.map_zones_changed.connect(_on_map_zones_changed)

	# An idle action already running (the save's, or one the zone change above
	# resumed before these connections) sent its start signal unheard.
	_start_idle_motion()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## The map's camera.
func get_camera() -> Camera2D:
	return _camera

## The rect the camera's centre is clamped to: the map zones' tiles plus 1.5
## hexes on every side, in map space.
func get_camera_bounds() -> Rect2:
	return _camera_bounds

## The centre of the zone's hex in map space.
func get_zone_world_centre(zone_data: ZoneData) -> Vector2:
	return tile_map.position + tile_map.map_to_local(zone_data.tilemap_location)

## Moves the camera so the zone's centre sits at screen (960, 702) at the
## current zoom, gliding over duration seconds (0 = at once), then re-clamps.
func frame_zone(zone_data: ZoneData, duration: float = 0.0) -> void:
	if zone_data == null:
		return
	if _frame_tween and _frame_tween.is_valid():
		_frame_tween.kill()
	var zoom: float = _zoom_controller.target_zoom.x if _zoom_controller.is_zoom_active() else _camera.zoom.x
	var target: Vector2 = ZoneMapMath.camera_position_for(get_zone_world_centre(zone_data), zoom)
	if duration <= 0.0:
		_camera.position = target
		_clamp_controller.clamp_now()
		return
	_frame_tween = create_tween()
	_frame_tween.set_trans(Tween.TRANS_CUBIC)
	_frame_tween.set_ease(Tween.EASE_IN_OUT)
	_frame_tween.tween_property(_camera, "position", target, duration)
	_frame_tween.finished.connect(_clamp_controller.clamp_now)

## The fog tier (1-3) drawn on the cell, or -1 when the cell has no fog.
func get_fog_tier_at(cell: Vector2i) -> int:
	return _fog_layer.get_cell_source_id(cell)

## The rim (ZoneHexMarker) or veil (LockedZoneOverlay) drawn over the map
## zone, or null when the zone is not on the map.
func get_hex_overlay(zone_id: String) -> Node2D:
	return _hex_overlays.get(zone_id, null)

## The screen-space plates, glyphs, ring and floaters drawn over the map.
func get_map_markers() -> MapMarkers:
	return _map_markers

## The dotted route that leads into the zone (from the current zone, or for
## an uncharted zone from the nearest charted one), or null when none does.
func get_route_to(zone_id: String) -> ZoneRoute:
	return _routes.get(zone_id, null) as ZoneRoute

## Every dotted route on the map.
func get_routes() -> Array[ZoneRoute]:
	var routes: Array[ZoneRoute] = []
	routes.assign(_routes.values())
	return routes

## Returns the map zone at the given tile coordinate, or null if none.
func get_zone_at_tile(tile_coord: Vector2i) -> ZoneData:
	for zone_data: ZoneData in ZoneManager.get_map_zones():
		if zone_data.tilemap_location == tile_coord:
			return zone_data
	return null

## Updates the selected_zone bookkeeping when the player moves.
func update_zone_tile_state(zone_data: ZoneData) -> void:
	if not zone_data:
		return

	selected_zone = zone_data

#-----------------------------------------------------------------------------
# MAP BUILDING
#-----------------------------------------------------------------------------

## Redraws the zone layer, the camera bounds, the fog, the hex states and the
## routes for the current map zones, then emits map_rebuilt.
func _rebuild_map() -> void:
	var map_zones: Array[ZoneData] = ZoneManager.get_map_zones()
	_draw_zone_cells(map_zones)
	_update_camera_bounds(map_zones)
	_draw_fog(map_zones)
	_draw_hex_states(map_zones)
	_draw_routes(map_zones)
	map_rebuilt.emit()

## The zone layer holds only the map zones. Veiled zones get a transparent
## cell, so they stay clickable while the veil draws the tile.
func _draw_zone_cells(map_zones: Array[ZoneData]) -> void:
	tile_map.clear()
	for zone_data: ZoneData in map_zones:
		if _is_veiled(zone_data):
			tile_map.set_cell(zone_data.tilemap_location, VEILED_CELL_SOURCE_ID, Vector2i.ZERO, VEILED_CELL_ALTERNATIVE_ID)
		else:
			tile_map.set_cell(zone_data.tilemap_location, FOREST_ATLAS_SOURCE_ID, _get_zone_tile_atlas_coords(zone_data))

## The camera's centre is clamped to the map zones' tiles plus 1.5 hexes.
func _update_camera_bounds(map_zones: Array[ZoneData]) -> void:
	var bounds: Rect2 = Rect2(-TILE_SIZE / 2.0, TILE_SIZE)
	for index: int in map_zones.size():
		var tile_rect: Rect2 = Rect2(get_zone_world_centre(map_zones[index]) - TILE_SIZE / 2.0, TILE_SIZE)
		bounds = tile_rect if index == 0 else bounds.merge(tile_rect)
	var margin: Vector2 = TILE_SIZE * CLAMP_MARGIN_HEXES
	_camera_bounds = bounds.grow_individual(margin.x, margin.y, margin.x, margin.y)
	_clamp_controller.boundary_min = _camera_bounds.position
	_clamp_controller.boundary_max = _camera_bounds.end
	_clamp_controller.clamp_now()

## Fills every cell that reaches into the clamp bounds plus half a viewport at
## the lowest zoom, so the screen is covered wherever the camera is clamped
## (Review Focus 3). Map-zone cells are skipped; the uncharted zone charts
## nothing, so fog tiers count only from charted zones.
func _draw_fog(map_zones: Array[ZoneData]) -> void:
	_fog_layer.clear()
	var zone_cells: Dictionary[Vector2i, bool] = {}
	var charted_cubes: Array[Vector3i] = []
	for zone_data: ZoneData in map_zones:
		zone_cells[zone_data.tilemap_location] = true
		if ZoneManager.is_zone_charted(zone_data):
			charted_cubes.append(ZoneMapMath.cell_to_cube(zone_data.tilemap_location))

	var half_view: Vector2 = ZoneMapMath.VIEWPORT_SIZE / (2.0 * _zoom_controller.zoom_min)
	var fog_rect: Rect2 = _camera_bounds.grow_individual(half_view.x, half_view.y, half_view.x, half_view.y)
	var first_cell: Vector2i = _fog_layer.local_to_map(fog_rect.position - _fog_layer.position)
	var last_cell: Vector2i = _fog_layer.local_to_map(fog_rect.end - _fog_layer.position)
	for row: int in range(first_cell.y - 1, last_cell.y + 2):
		for col: int in range(first_cell.x - 1, last_cell.x + 2):
			var cell: Vector2i = Vector2i(col, row)
			if zone_cells.has(cell) or not _get_cell_world_rect(cell).intersects(fog_rect):
				continue
			var cube: Vector3i = ZoneMapMath.cell_to_cube(cell)
			var tier: int = ZoneMapMath.fog_tier(cube, charted_cubes)
			_fog_layer.set_cell(cell, tier, Vector2i(HexForestAtlas.pick_from(cube, FOG_POOL_SIZE), 0))

## Lays the current rim, the open hairline or the veil over each map zone.
func _draw_hex_states(map_zones: Array[ZoneData]) -> void:
	# Freed at once (they are plain sprites): the map never shows a stale
	# rim for a frame, and nothing outlives the rebuild.
	for container: Node2D in [_veil_container, _marker_container]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.free()
	_hex_overlays.clear()

	for zone_data: ZoneData in map_zones:
		var state: ZoneManager.ZoneMapState = ZoneManager.get_zone_map_state(zone_data)
		if _is_veiled(zone_data):
			var overlay: LockedZoneOverlay = LockedZoneOverlayScene.instantiate() as LockedZoneOverlay
			_veil_container.add_child(overlay)
			overlay.position = get_zone_world_centre(zone_data)
			overlay.setup(state)
			_hex_overlays[zone_data.zone_id] = overlay
		else:
			var marker: ZoneHexMarker = ZoneHexMarkerScene.instantiate() as ZoneHexMarker
			_marker_container.add_child(marker)
			marker.position = get_zone_world_centre(zone_data)
			marker.setup(state)
			_hex_overlays[zone_data.zone_id] = marker

## Lays the dotted routes (kit §0, the road ahead): from the current zone to
## every other charted map zone, and on to each uncharted zone from the
## charted zone nearest it (the first in map order on a tie).
func _draw_routes(map_zones: Array[ZoneData]) -> void:
	for child: Node in _route_container.get_children():
		_route_container.remove_child(child)
		child.free()
	_routes.clear()

	var current: ZoneData = ZoneManager.get_current_zone()
	var current_id: String = current.zone_id if current != null else ""
	var charted: Array[ZoneData] = []
	var current_on_map: ZoneData = null
	for zone_data: ZoneData in map_zones:
		if ZoneManager.is_zone_charted(zone_data):
			charted.append(zone_data)
			if zone_data.zone_id == current_id:
				current_on_map = zone_data

	for zone_data: ZoneData in map_zones:
		if zone_data == current_on_map:
			continue
		var from_zone: ZoneData = current_on_map if charted.has(zone_data) else _nearest_zone(zone_data, charted)
		if from_zone == null:
			continue
		var route: ZoneRoute = ZoneRouteScene.instantiate() as ZoneRoute
		_route_container.add_child(route)
		route.set_points(get_zone_world_centre(from_zone), get_zone_world_centre(zone_data))
		_routes[zone_data.zone_id] = route

## The zone in candidates with the fewest hexes to target, or null for none.
func _nearest_zone(target: ZoneData, candidates: Array[ZoneData]) -> ZoneData:
	var target_cube: Vector3i = ZoneMapMath.cell_to_cube(target.tilemap_location)
	var nearest: ZoneData = null
	var nearest_distance: int = 0
	for candidate: ZoneData in candidates:
		var distance: int = HexagonTileMap.cube_distance(target_cube, ZoneMapMath.cell_to_cube(candidate.tilemap_location))
		if nearest == null or distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _is_veiled(zone_data: ZoneData) -> bool:
	var state: ZoneManager.ZoneMapState = ZoneManager.get_zone_map_state(zone_data)
	return state == ZoneManager.ZoneMapState.LOCKED or state == ZoneManager.ZoneMapState.UNCHARTED

## A cell's tile rect in map space.
func _get_cell_world_rect(cell: Vector2i) -> Rect2:
	return Rect2(_fog_layer.position + _fog_layer.map_to_local(cell) - TILE_SIZE / 2.0, TILE_SIZE)

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

#-----------------------------------------------------------------------------
# CHARACTER
#-----------------------------------------------------------------------------

func _get_stand_position(zone_data: ZoneData) -> Vector2:
	return get_zone_world_centre(zone_data) + CHARACTER_STAND_OFFSET

func _place_character(zone_data: ZoneData) -> void:
	character_body.position = _get_stand_position(zone_data)

func _move_character_to_zone(zone_data: ZoneData) -> void:
	character_body.move_to_position(_get_stand_position(zone_data), CHARACTER_MOVE_SPEED)

## The character's idle motion for the running action, around its stand, one
## world px (two screen px) a step: foraging wanders west and back over one
## haul (restarted each haul), the Aura Well bobs it up and down. Nothing while
## it walks to a zone or while any other action runs.
func _start_idle_motion() -> void:
	_stop_idle_motion()
	if character_body.is_moving or selected_zone == null:
		return
	var action: ZoneActionData = ActionManager.get_current_action()
	if action is ForageActionData:
		_idle_motion_tween = create_tween()
		_idle_motion_tween.tween_method(_apply_forage_wander, 0.0, ZoneMapMath.FORAGE_WANDER_SECONDS, ZoneMapMath.FORAGE_WANDER_SECONDS)
	elif action is TrainingActionData:
		_idle_motion_tween = create_tween().set_loops()
		_idle_motion_tween.tween_method(_apply_training_bob, 0.0, ZoneMapMath.TRAINING_BOB_SECONDS, ZoneMapMath.TRAINING_BOB_SECONDS)

func _apply_forage_wander(elapsed: float) -> void:
	character_body.position = _get_stand_position(selected_zone) + Vector2(ZoneMapMath.forage_wander_x(elapsed), 0.0)

func _apply_training_bob(elapsed: float) -> void:
	character_body.position = _get_stand_position(selected_zone) + Vector2(0.0, ZoneMapMath.training_bob_y(elapsed))

func _stop_idle_motion() -> void:
	if _idle_motion_tween and _idle_motion_tween.is_valid():
		_idle_motion_tween.kill()
	_idle_motion_tween = null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Called when a tile is clicked on the tile map. Only an open zone travels;
## locked and uncharted zones get their popovers in the map interaction layer.
func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	var zone_data: ZoneData = get_zone_at_tile(tile_coord)
	Log.info("ZoneTilemap: Zone tile clicked: %s" % tile_coord)
	if not zone_data or zone_data == selected_zone:
		return
	if ZoneManager.get_zone_map_state(zone_data) != ZoneManager.ZoneMapState.OPEN:
		return

	zone_selected.emit(zone_data, tile_coord)
	_stop_idle_motion()
	# Walk first: the zone change below stops and starts idle actions, and
	# their handlers leave a walking character alone.
	_move_character_to_zone(zone_data)
	update_zone_tile_state(zone_data)
	frame_zone(zone_data, camera_ease_duration)

func _on_zone_tile_hovered(tile_coord: Vector2i) -> void:
	var zone_data: ZoneData = get_zone_at_tile(tile_coord)
	if not zone_data or ZoneManager.get_zone_map_state(zone_data) != ZoneManager.ZoneMapState.OPEN:
		_hover_selector.hide()
		return
	_hover_selector.show_at(get_zone_world_centre(zone_data))

func _on_zone_tile_unhovered() -> void:
	_hover_selector.hide()

func _on_condition_unlocked(_condition_id: String) -> void:
	_rebuild_map()

func _on_map_zones_changed() -> void:
	_rebuild_map()

## The current zone moved: its rim and the open hairlines follow. A change the
## map did not make (a save reset, a dev switch) also takes the character and
## the camera there, unless the character is walking to a zone.
func _on_zone_changed(zone_data: ZoneData) -> void:
	_rebuild_map()
	if zone_data == null or zone_data == _selected_zone or character_body.is_moving:
		return
	# The backing field: ZoneManager already holds this zone, no re-emit.
	_selected_zone = zone_data
	_place_character(zone_data)
	frame_zone(zone_data)
	_start_idle_motion()

## The walk ended at the zone's stand: the running idle action's motion starts.
func _on_character_movement_completed() -> void:
	_start_idle_motion()

func _on_start_foraging() -> void:
	_start_idle_motion()

func _on_start_training(_action_data: TrainingActionData) -> void:
	_start_idle_motion()

## Foraging or training stopped: the character goes back to its stand, unless
## it is walking to a zone.
func _on_idle_action_stopped() -> void:
	_stop_idle_motion()
	if not character_body.is_moving:
		_place_character(selected_zone)

func _on_foraging_completed(_items: Dictionary) -> void:
	_start_idle_motion()
