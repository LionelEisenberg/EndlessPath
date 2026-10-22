class_name ZoneTilemap
extends Node2D

## ZoneTilemap
## The zone view's hex map (spec: Map; kit §6). The camera opens at zoom 2 and
## frames the current zone's centre at screen (960, 702). The camera clamp
## keeps at least one map zone's centre in the free map window between the
## panels at every zoom (ZoneMapMath.FREE_MAP_WINDOW). Every cell out to half
## a viewport past the widest clamp is fog, its tier the hex distance to the
## nearest charted zone. The zone layer holds only the map zones
## (ZoneManager.get_map_zones()): the current zone gets the brass rim, an open
## zone the hairline, and locked and uncharted zones a veiled tile. Dotted
## routes lead from the current zone, neighbour to neighbour, to the other
## charted zones and run on to the uncharted ones; MapMarkers draws the
## plates, glyphs, ring, floaters and popover over the map in screen space.
##
## Map interaction (spec: Behaviour › Map interaction). Hovering a hex, its
## plate or the popover is reported to MapMarkers, which decides through its
## MapPopoverState; the map then swaps the hex rims (a travelable open hex's
## brighter rim, a veiled hex's thin or heavy inner rim) and lights the route
## toward a zone you can travel to. A click on an open hex (or its plate)
## walks the character there at CHARACTER_MOVE_SPEED while the old action
## keeps running; the zone changes (ZoneManager.set_current_zone) only on
## arrival, then the camera frames it. A second click during the walk
## retargets it (the zone you are in walks back home); starting a session
## action (cycling, an adventure, dialogue, the merchant) or the target
## leaving the map (a dev toggle) ends the walk where it began, and a zone
## change the map did not make (a save reset, a dev switch) ends it in the
## real current zone (Review Focus 2).

## Emitted when the player sets off for a zone (on the click; the zone itself
## changes on arrival).
signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)

## Emitted after the map redraws its zones, fog and hex states: on load, on a
## zone change, an unlock, or a dev toggle that changes the map zones.
signal map_rebuilt

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Camera")
## How long the camera takes to glide to a zone: the one the character just
## walked into, or the current zone when its hex is clicked (recentre).
## Higher = slower, more contemplative. Lower = snappier.
@export_range(0.1, 3.0, 0.05) var camera_ease_duration: float = 0.3

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

## A hex tile's size in map space.
const TILE_SIZE: Vector2 = Vector2(164, 190)

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
@onready var _fog_layer: HexagonTileMapLayer = %FogTileMapLayer
@onready var _camera: Camera2D = %Camera2D
@onready var _zoom_controller: CameraZoomController = %CameraZoomController
@onready var _clamp_controller: CameraClampController = %CameraClampController
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
## The zone each route starts from, by the id of the zone it leads into.
var _route_from: Dictionary[String, String] = {}
var _camera_bounds: Rect2 = Rect2()
## The map zones' centres in map space: the camera clamp keeps one of them in
## the free map window.
var _clamp_zone_centres: Array[Vector2] = []
var _frame_tween: Tween = null
## The character's idle motion (the foraging wander or the Aura Well's bob).
var _idle_motion_tween: Tween = null
var _selected_zone: ZoneData = null
## The zone the character is walking to, or null while it stands.
var _travel_target: ZoneData = null
## The zone under the pointer's hex cell ("" over fog or off the map).
var _hovered_cell_zone_id: String = ""

## The zone the character stands in (the current zone). Setting it makes it
## the current zone (ZoneManager.set_current_zone).
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

	# The zone layer holds the map zones and the fog layer every other cell, so
	# each press or move on the map reaches exactly one of them. The fog
	# layer's own "unhovered" is left out: it fires when the pointer moves onto
	# a zone cell, after the zone layer has reported that cell.
	tile_map.tile_clicked.connect(_on_zone_tile_clicked)
	tile_map.tile_hovered.connect(_on_zone_tile_hovered)
	tile_map.tile_unhovered.connect(_on_zone_tile_unhovered)
	_fog_layer.tile_clicked.connect(_on_fog_tile_clicked)
	_fog_layer.tile_hovered.connect(_on_fog_tile_hovered)
	_map_markers.plate_pressed.connect(click_zone)
	_map_markers.marker_hover_changed.connect(_refresh_hover)
	_map_markers.interaction_changed.connect(_apply_interaction)
	_map_markers.pointer_left_map.connect(_on_pointer_left_map)
	_zoom_controller.zoom_changed.connect(_on_zoom_changed)

	character_body.movement_completed.connect(_on_character_movement_completed)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)
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

## The zoom the player left the camera at (the zoom controller's target),
## which the camera is back at once ZoneTransition's adventure zoom eases out.
func get_resting_zoom() -> Vector2:
	return _zoom_controller.target_zoom

## The rect around every place the camera's centre may be at the zoom the
## player left it at (get_camera_bounds_at_zoom), in map space.
func get_camera_bounds() -> Rect2:
	return _camera_bounds

## The rect around every place the camera's centre may be at the zoom: the
## camera windows of all map zones (ZoneMapMath.camera_window_for), each
## keeping that zone's centre in the free map window. The clamp keeps the
## camera in one of the windows, not just in this rect, so a corner of the
## rect that no window covers is out of reach.
func get_camera_bounds_at_zoom(zoom: float) -> Rect2:
	var windows: Array[Rect2] = _camera_windows(zoom)
	var bounds: Rect2 = windows[0]
	for window: Rect2 in windows:
		bounds = bounds.merge(window)
	return bounds

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

## The dotted route that leads into the zone (from the current zone or the
## charted zone next to it on the way, or for an uncharted zone from the
## nearest charted one), or null when none does.
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

## Does what a click on the zone's hex does (null = fog): an open zone walks
## there, a locked or uncharted one pins its popover, the current zone
## recentres the camera (and turns a walk back home), fog closes the popover.
func click_zone(zone_data: ZoneData) -> void:
	var zone_id: String = zone_data.zone_id if zone_data != null else ""
	match _map_markers.click_zone(zone_id):
		MapPopoverState.ClickResult.TRAVEL:
			_travel_to(zone_data)
		MapPopoverState.ClickResult.RECENTRE:
			if is_travelling():
				_travel_to(_selected_zone)
			frame_zone(_selected_zone, camera_ease_duration)

## True while the character walks to a zone (the current zone changes on
## arrival).
func is_travelling() -> bool:
	return _travel_target != null

## The zone the character is walking to, or null while it stands.
func get_travel_target() -> ZoneData:
	return _travel_target

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

## The camera clamp follows the map zones: the camera's centre stays in one
## of their camera windows at the zoom the player left it at.
func _update_camera_bounds(map_zones: Array[ZoneData]) -> void:
	_clamp_zone_centres.clear()
	for zone_data: ZoneData in map_zones:
		_clamp_zone_centres.append(get_zone_world_centre(zone_data))
	_apply_camera_clamp(_zoom_controller.target_zoom.x)

## Sets the clamp for the zoom (the windows shrink as the map zooms in) and
## pulls the camera into it.
func _apply_camera_clamp(zoom: float) -> void:
	_camera_bounds = get_camera_bounds_at_zoom(zoom)
	_clamp_controller.boundary_min = _camera_bounds.position
	_clamp_controller.boundary_max = _camera_bounds.end
	_clamp_controller.clamp_regions = _camera_windows(zoom)
	_clamp_controller.clamp_now()

## One camera window per map zone at the zoom (the world origin's when the map
## has no zones).
func _camera_windows(zoom: float) -> Array[Rect2]:
	var windows: Array[Rect2] = []
	for centre: Vector2 in _clamp_zone_centres:
		windows.append(ZoneMapMath.camera_window_for(centre, zoom))
	if windows.is_empty():
		windows.append(ZoneMapMath.camera_window_for(Vector2.ZERO, zoom))
	return windows

## Fills every cell that reaches into the clamp bounds at the lowest zoom
## (the widest) plus half a viewport at that zoom, so the screen is covered
## wherever the camera is clamped at any zoom (Review Focus 3). Map-zone cells
## are skipped; the uncharted zone charts nothing, so fog tiers count only
## from charted zones.
func _draw_fog(map_zones: Array[ZoneData]) -> void:
	_fog_layer.clear()
	var zone_cells: Dictionary[Vector2i, bool] = {}
	var charted_cubes: Array[Vector3i] = []
	for zone_data: ZoneData in map_zones:
		zone_cells[zone_data.tilemap_location] = true
		if ZoneManager.is_zone_charted(zone_data):
			charted_cubes.append(ZoneMapMath.cell_to_cube(zone_data.tilemap_location))

	var half_view: Vector2 = ZoneMapMath.VIEWPORT_SIZE / (2.0 * _zoom_controller.zoom_min)
	var fog_rect: Rect2 = get_camera_bounds_at_zoom(_zoom_controller.zoom_min).grow_individual(half_view.x, half_view.y, half_view.x, half_view.y)
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

## Lays the dotted routes (kit §0, the road ahead). Each one joins two
## neighbouring hexes and crosses only their shared rim: the charted map zones,
## nearest the current zone first, each from the nearest zone already reached
## (the current zone on a tie); then each uncharted zone from the charted zone
## nearest it (the first in map order on a tie).
func _draw_routes(map_zones: Array[ZoneData]) -> void:
	for child: Node in _route_container.get_children():
		_route_container.remove_child(child)
		child.free()
	_routes.clear()
	_route_from.clear()

	var current: ZoneData = ZoneManager.get_current_zone()
	var current_id: String = current.zone_id if current != null else ""
	var charted: Array[ZoneData] = []
	var current_on_map: ZoneData = null
	for zone_data: ZoneData in map_zones:
		if ZoneManager.is_zone_charted(zone_data):
			charted.append(zone_data)
			if zone_data.zone_id == current_id:
				current_on_map = zone_data

	# With the current zone off the map, no charted zone gets a route.
	var reached: Array[ZoneData] = []
	if current_on_map != null:
		reached.append(current_on_map)
		for zone_data: ZoneData in _by_distance_from(current_on_map, charted):
			if zone_data == current_on_map:
				continue
			_add_route(_nearest_zone(zone_data, reached), zone_data)
			reached.append(zone_data)
	for zone_data: ZoneData in map_zones:
		if not charted.has(zone_data):
			_add_route(_nearest_zone(zone_data, charted), zone_data)

## Lays the dotted route from one zone into another.
func _add_route(from_zone: ZoneData, to_zone: ZoneData) -> void:
	if from_zone == null:
		return
	var route: ZoneRoute = ZoneRouteScene.instantiate() as ZoneRoute
	_route_container.add_child(route)
	route.set_points(get_zone_world_centre(from_zone), get_zone_world_centre(to_zone))
	_routes[to_zone.zone_id] = route
	_route_from[to_zone.zone_id] = from_zone.zone_id

## The zones sorted by hex distance from origin, nearest first, keeping map
## order on a tie.
func _by_distance_from(origin: ZoneData, zones: Array[ZoneData]) -> Array[ZoneData]:
	var origin_cube: Vector3i = ZoneMapMath.cell_to_cube(origin.tilemap_location)
	var buckets: Dictionary[int, Array] = {}
	for zone_data: ZoneData in zones:
		var distance: int = HexagonTileMap.cube_distance(origin_cube, ZoneMapMath.cell_to_cube(zone_data.tilemap_location))
		if not buckets.has(distance):
			buckets[distance] = []
		buckets[distance].append(zone_data)
	var distances: Array[int] = []
	distances.assign(buckets.keys())
	distances.sort()
	var sorted: Array[ZoneData] = []
	for distance: int in distances:
		sorted.append_array(buckets[distance])
	return sorted

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

## Walks the character to the zone's stand (a new target retargets a walk
## under way). The running action keeps running; the zone changes on arrival.
func _travel_to(zone_data: ZoneData) -> void:
	if zone_data == null:
		return
	_travel_target = zone_data
	zone_selected.emit(zone_data, zone_data.tilemap_location)
	_stop_idle_motion()
	character_body.move_to_position(_get_stand_position(zone_data), CHARACTER_MOVE_SPEED)

## Ends a walk where it began: the character stands in the current zone again
## and the camera frames it. Nothing arrives later.
func _cancel_travel() -> void:
	if _travel_target == null:
		return
	_snap_to_zone(_selected_zone)

## Ends any walk and puts the map in the zone at once: the character on its
## stand, the camera framing it, its idle motion running. Nothing arrives
## later.
func _snap_to_zone(zone_data: ZoneData) -> void:
	# Cleared first: stop_moving() reports the walk as completed.
	_travel_target = null
	character_body.stop_moving()
	# The backing field: ZoneManager already holds this zone, no re-emit.
	_selected_zone = zone_data
	_place_character(zone_data)
	frame_zone(zone_data)
	_start_idle_motion()

## A walk whose target left the map (a dev toggle hid it) or can no longer be
## travelled to ends where it began.
func _cancel_travel_to_lost_target() -> void:
	if is_travelling() and not _is_on_map_and_travelable(_travel_target):
		_cancel_travel()

## True when the zone is on the map and open (or the current zone).
func _is_on_map_and_travelable(zone_data: ZoneData) -> bool:
	var state: ZoneManager.ZoneMapState = ZoneManager.get_zone_map_state(zone_data)
	if state != ZoneManager.ZoneMapState.OPEN and state != ZoneManager.ZoneMapState.CURRENT:
		return false
	for map_zone: ZoneData in ZoneManager.get_map_zones():
		if map_zone.zone_id == zone_data.zone_id:
			return true
	return false

## The walk reached its stand. A new zone becomes the current zone (which
## stops the old action and resumes the new zone's idle action) and the
## camera glides to it; a walk back home changes nothing.
func _arrive(destination: ZoneData) -> void:
	if destination != _selected_zone:
		# The backing field first: the zone change stops the old idle action,
		# whose handler puts the character on the selected zone's stand.
		_selected_zone = destination
		ZoneManager.set_current_zone(destination)
		frame_zone(destination, camera_ease_duration)
	_start_idle_motion()

func _is_idle(action: ZoneActionData) -> bool:
	return action is ForageActionData or action is TrainingActionData

## The character's idle motion for the running action, around its stand, one
## world px (two screen px) a step: foraging wanders west and back over one
## haul, in phase with the haul timer (restarted each haul), the Aura Well
## bobs it up and down. Nothing while it walks to a zone or while any other
## action runs.
func _start_idle_motion() -> void:
	_stop_idle_motion()
	if character_body.is_moving or selected_zone == null:
		return
	var action: ZoneActionData = ActionManager.get_current_action()
	if action is ForageActionData:
		_start_forage_wander(action as ForageActionData)
	elif action is TrainingActionData:
		_idle_motion_tween = create_tween().set_loops()
		_idle_motion_tween.tween_method(_apply_training_bob, 0.0, ZoneMapMath.TRAINING_BOB_SECONDS, ZoneMapMath.TRAINING_BOB_SECONDS)

## Runs the wander from where the haul timer is to the haul's end, so a map
## opened (or a walk ended) partway through a haul joins in step, from its
## first frame, and the haul never makes the character jump. Before the
## timer starts, from the top.
func _start_forage_wander(forage: ForageActionData) -> void:
	var haul_seconds: float = forage.foraging_interval_in_sec
	var elapsed: float = 0.0
	var timer: Timer = ActionManager.action_timer
	if not timer.is_stopped():
		haul_seconds = timer.wait_time
		elapsed = clampf(timer.wait_time - timer.time_left, 0.0, haul_seconds)
	var wander_from: float = elapsed / haul_seconds * ZoneMapMath.FORAGE_WANDER_SECONDS if haul_seconds > 0.0 else 0.0
	_apply_forage_wander(wander_from)
	_idle_motion_tween = create_tween()
	_idle_motion_tween.tween_method(_apply_forage_wander, wander_from, ZoneMapMath.FORAGE_WANDER_SECONDS, maxf(haul_seconds - elapsed, 0.0))

func _apply_forage_wander(elapsed: float) -> void:
	character_body.position = _get_stand_position(selected_zone) + Vector2(ZoneMapMath.forage_wander_x(elapsed), 0.0)

func _apply_training_bob(elapsed: float) -> void:
	character_body.position = _get_stand_position(selected_zone) + Vector2(0.0, ZoneMapMath.training_bob_y(elapsed))

func _stop_idle_motion() -> void:
	if _idle_motion_tween and _idle_motion_tween.is_valid():
		_idle_motion_tween.kill()
	_idle_motion_tween = null

#-----------------------------------------------------------------------------
# MAP INTERACTION
#-----------------------------------------------------------------------------

## Tells MapMarkers what the pointer is over: a plate's zone, nothing on the
## popover, else the zone of the hex cell under it ("" over fog); nothing at
## all while the pointer is off the map.
func _refresh_hover() -> void:
	if not _map_markers.is_pointer_on_map():
		_map_markers.hover_zone("")
		return
	var point: Vector2 = get_viewport().get_mouse_position()
	var zone_id: String = _map_markers.get_plate_zone_id_at(point)
	if zone_id == "" and not _map_markers.is_point_on_popover(point):
		zone_id = _hovered_cell_zone_id
	_map_markers.hover_zone(zone_id)

## Swaps the hex rims for the hovered and pinned zones (a travelable open hex
## gets the brighter rim, a veiled hex the thin or heavy inner rim) and lights
## the route from the current zone to a hovered zone you can travel to: each
## segment back along the way while both its ends are open (or the current
## zone), never one into or out of a locked or uncharted zone.
func _apply_interaction() -> void:
	var state: MapPopoverState = _map_markers.get_popover_state()
	var hovered_id: String = state.get_hovered_zone_id()
	var pinned_id: String = state.get_pinned_zone_id()
	for zone_id: String in _hex_overlays:
		var marker := _hex_overlays[zone_id] as ZoneHexMarker
		var veil := _hex_overlays[zone_id] as LockedZoneOverlay
		if marker != null:
			marker.set_hovered(zone_id == hovered_id and state.is_hovered_travelable())
		elif veil != null:
			veil.set_hovered(zone_id == hovered_id)
			veil.set_pinned(zone_id == pinned_id)
	var lit_ids: Dictionary[String, bool] = {}
	if state.is_hovered_travelable():
		var zone_id: String = hovered_id
		while _route_from.has(zone_id) and not lit_ids.has(zone_id) and _is_travelable_id(_route_from[zone_id]):
			lit_ids[zone_id] = true
			zone_id = _route_from[zone_id]
	for zone_id: String in _routes:
		_routes[zone_id].set_lit(lit_ids.has(zone_id))

## True when the map zone is open or the current zone (its hex has a rim, not
## a veil): a route may brighten up to it.
func _is_travelable_id(zone_id: String) -> bool:
	return _hex_overlays.get(zone_id, null) is ZoneHexMarker

## True when the pointer's press lands on a plate or the popover: those take
## the click themselves, so the hex under them must not.
func _is_press_on_marker() -> bool:
	return _map_markers.is_point_on_marker(get_viewport().get_mouse_position())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A press on a map zone's cell: the zone's click (travel, pin, recentre).
func _on_zone_tile_clicked(tile_coord: Vector2i) -> void:
	if _is_press_on_marker():
		return
	click_zone(get_zone_at_tile(tile_coord))

## A press on fog closes the popover.
func _on_fog_tile_clicked(_tile_coord: Vector2i) -> void:
	if _is_press_on_marker():
		return
	click_zone(null)

func _on_zone_tile_hovered(tile_coord: Vector2i) -> void:
	var zone_data: ZoneData = get_zone_at_tile(tile_coord)
	_hovered_cell_zone_id = zone_data.zone_id if zone_data != null else ""
	_refresh_hover()

func _on_zone_tile_unhovered() -> void:
	_hovered_cell_zone_id = ""
	_refresh_hover()

func _on_fog_tile_hovered(_tile_coord: Vector2i) -> void:
	_hovered_cell_zone_id = ""
	_refresh_hover()

## The pointer left the map: no cell is under it, and the hex layers forget
## the last one, so coming straight back onto it hovers it again.
func _on_pointer_left_map() -> void:
	_hovered_cell_zone_id = ""
	tile_map.forget_hovered_cell()
	_fog_layer.forget_hovered_cell()

## The player zoomed: the clamp follows the zoom the camera is easing to.
func _on_zoom_changed(new_zoom: Vector2) -> void:
	_apply_camera_clamp(new_zoom.x)

func _on_condition_unlocked(_condition_id: String) -> void:
	_rebuild_map()
	_cancel_travel_to_lost_target()

func _on_map_zones_changed() -> void:
	_rebuild_map()
	_cancel_travel_to_lost_target()

## The current zone moved: its rim and the open hairlines follow. The map's
## own change comes on arrival, after the walk is over; any other (a save
## reset, a dev switch) ends a walk and takes the character, the camera and
## the map's zone to the real current zone, even the zone the walk began in.
func _on_zone_changed(zone_data: ZoneData) -> void:
	_rebuild_map()
	if zone_data == null or (zone_data == _selected_zone and not is_travelling()):
		return
	_snap_to_zone(zone_data)

## The walk ended at its stand: arrive (a stop that cancelled the walk has
## already cleared the target), then the running idle action's motion starts.
func _on_character_movement_completed() -> void:
	var destination: ZoneData = _travel_target
	_travel_target = null
	if destination != null:
		_arrive(destination)
		return
	_start_idle_motion()

## A session action (cycling, an adventure, dialogue, the merchant) started
## while the character walks: it belongs to the zone the walk began in, so
## the walk ends there.
func _on_current_action_changed(action: ZoneActionData) -> void:
	if is_travelling() and action != null and not _is_idle(action):
		_cancel_travel()

## A save reset ends any walk where it began.
func _on_save_data_reset() -> void:
	_cancel_travel()

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
