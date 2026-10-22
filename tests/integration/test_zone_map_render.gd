extends GutTest

## How the zone map draws itself (Task 11 of the map-first zone view): the
## camera framed at zoom 2, the fog tiers counted from the charted zones, the
## hex states (current rim, open hairline, locked and uncharted veils), the
## character's stand, and the clamp bounds the fog has to cover (Review Focus 3).

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"
const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const FORAGING_UNLOCK_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"

var _map: ZoneTilemap

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	# The map sets the current zone on load, which resumes idle actions and
	# writes to the save: run on a fresh one, never the developer's save.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_map = ZoneTilemapScene.instantiate()
	add_child_autofree(_map)
	# The project's hex layer overrides _ready() without super(), so the addon
	# sets up its conversions only when the shared TileSet emits `changed`.
	_map.tile_map.tile_set.emit_changed()
	await get_tree().process_frame

func after_each() -> void:
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _zone(zone_id: String) -> ZoneData:
	for zone: ZoneData in ZoneManager.get_map_zones():
		if zone.zone_id == zone_id:
			return zone
	return ZoneManager.get_zone_by_id(zone_id)

## The screen point a world point lands on with the map camera as it is now.
func _to_screen(world: Vector2) -> Vector2:
	var camera: Camera2D = _map.get_camera()
	return ZoneMapMath.world_to_screen(world, camera.position, camera.zoom.x)

## Where the character stands in the zone, in the map's world space.
func _stand(zone_id: String) -> Vector2:
	return _map.get_zone_world_centre(_zone(zone_id)) + ZoneTilemap.CHARACTER_STAND_OFFSET

## Clicks the zone's cell on the map's zone layer.
func _click_zone(zone_id: String) -> void:
	_map.tile_map.tile_clicked.emit(_zone(zone_id).tilemap_location)

## Shows the hidden Test Zone and unlocks it, so it is an open hex.
func _open_test_zone() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)

## The map camera's zoom controller.
func _zoom_controller() -> CameraZoomController:
	for child: Node in _map.get_camera().get_children():
		if child is CameraZoomController:
			return child
	return null

## The map camera's clamp controller.
func _clamp_controller() -> CameraClampController:
	for child: Node in _map.get_camera().get_children():
		if child is CameraClampController:
			return child
	return null

## Where the zone's centre lands on screen with the camera where it is now, at
## the zoom the camera is easing to.
func _zone_on_screen(zone_id: String) -> Vector2:
	var zoom: float = _zoom_controller().target_zoom.x
	return ZoneMapMath.world_to_screen(_map.get_zone_world_centre(_zone(zone_id)), _map.get_camera().position, zoom)

## True when the screen point lies in the free map window (its edges count).
func _in_free_window(screen: Vector2) -> bool:
	return ZoneMapMath.FREE_MAP_WINDOW.grow(0.01).has_point(screen)

## A cell's tile rect in the map's world space.
func _cell_rect(cell: Vector2i) -> Rect2:
	var centre: Vector2 = _map.tile_map.map_to_local(cell) + _map.tile_map.position
	return Rect2(centre - Vector2(82.0, 95.0), Vector2(164.0, 190.0))

#-----------------------------------------------------------------------------
# CAMERA
#-----------------------------------------------------------------------------

func test_default_zoom_is_two() -> void:
	var camera: Camera2D = _map.get_camera()
	assert_eq(camera.zoom, Vector2(2.0, 2.0), "the map opens at zoom 2: one art pixel is two screen px")
	assert_eq(camera.offset, Vector2.ZERO, "no camera offset, so framing is exact")

func test_spirit_valley_framed() -> void:
	var centre: Vector2 = _map.get_zone_world_centre(_zone(SPIRIT_VALLEY_ID))
	assert_eq(centre, Vector2.ZERO, "Spirit Valley's cell (0, 0) centres on world (0, 0)")
	var screen: Vector2 = _to_screen(centre)
	assert_almost_eq(screen.x, 960.0, 0.001, "the current zone's centre is at screen x 960")
	assert_almost_eq(screen.y, 702.0, 0.001, "and at screen y 702, so the map grows north")

func test_frame_zone_centres_another_zone() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	var test_zone: ZoneData = _zone(TEST_ZONE_ID)
	_map.frame_zone(test_zone)
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(test_zone))
	assert_almost_eq(screen.x, 960.0, 0.001)
	assert_almost_eq(screen.y, 702.0, 0.001)

func test_frame_zone_at_zoom_one() -> void:
	_map.get_camera().zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	var screen: Vector2 = _to_screen(Vector2.ZERO)
	assert_almost_eq(screen.x, 960.0, 0.001)
	assert_almost_eq(screen.y, 702.0, 0.001)

func test_camera_bounds_keep_spirit_valley_in_the_free_window() -> void:
	# At zoom 2 the camera may sit 207 world px either side of Spirit Valley,
	# 170.5 above it and 222.5 below it: its centre stays in the free map
	# window (x 546-1374, y 95-881).
	assert_eq(_map.get_camera_bounds(), Rect2(-207.0, -170.5, 414.0, 393.0))

func test_camera_bounds_grow_with_the_demo_zones() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var bounds: Rect2 = _map.get_camera_bounds()
	var uncharted_centre: Vector2 = _map.get_zone_world_centre(_zone(UNCHARTED_DEMO_ID))
	assert_true(bounds.has_point(uncharted_centre), "the uncharted demo hex is inside the clamp bounds")
	assert_almost_eq(bounds.position.y, uncharted_centre.y - 170.5, 0.001)

func test_camera_bounds_follow_the_zoom() -> void:
	_zoom_controller().set_zoom_level(1.0)
	assert_eq(_map.get_camera_bounds(), Rect2(-414.0, -341.0, 828.0, 786.0), "twice as far at zoom 1")
	assert_eq(_map.get_camera_bounds_at_zoom(2.0), Rect2(-207.0, -170.5, 414.0, 393.0))

#-----------------------------------------------------------------------------
# FOG
#-----------------------------------------------------------------------------

func test_fog_tiers_around_spirit_valley() -> void:
	assert_eq(_map.get_fog_tier_at(Vector2i(1, 0)), 1, "a neighbour of Spirit Valley is tier 1")
	assert_eq(_map.get_fog_tier_at(Vector2i(2, 0)), 2, "two away is tier 2")
	assert_eq(_map.get_fog_tier_at(Vector2i(3, 0)), 3, "three away is tier 3")
	assert_eq(_map.get_fog_tier_at(Vector2i(0, 0)), -1, "a zone cell has no fog")

func test_fog_draws_the_kit_art_around_spirit_valley() -> void:
	# Kit §6.2: the ring round the valley is quiet Basic but for Ravine east
	# and Lake2 south; the art index is the cell's place in the fog pool.
	assert_eq(_map.get_fog_art_at(Vector2i(-1, -1)), 0, "north-west: Basic")
	assert_eq(_map.get_fog_art_at(Vector2i(0, -1)), 0, "north-east: Basic")
	assert_eq(_map.get_fog_art_at(Vector2i(1, 0)), 7, "east: Ravine")
	assert_eq(_map.get_fog_art_at(Vector2i(-1, 1)), 0, "south-west: Basic")
	assert_eq(_map.get_fog_art_at(Vector2i(0, 1)), 4, "south-east: Lake2")
	assert_eq(_map.get_fog_art_at(Vector2i(-1, 0)), 3, "west (the hidden Test Zone's cell): Lake1")
	assert_eq(_map.get_fog_art_at(Vector2i(0, 0)), -1, "a zone cell has no fog art")

func test_fog_covers_screen_at_zoom_one() -> void:
	# Review Focus 3: the camera's centre is clamped to the bounds, so at the
	# lowest zoom (1.0), where they are widest, the screen reaches half a
	# viewport past them.
	var fog_rect: Rect2 = _map.get_camera_bounds_at_zoom(1.0).grow_individual(960.0, 540.0, 960.0, 540.0)
	var zone_cells: Dictionary[Vector2i, bool] = {}
	for zone: ZoneData in ZoneManager.get_map_zones():
		zone_cells[zone.tilemap_location] = true
	var checked: int = 0
	for row: int in range(-20, 21):
		for col: int in range(-20, 21):
			var cell := Vector2i(col, row)
			if not _cell_rect(cell).intersects(fog_rect):
				continue
			checked += 1
			assert_true(zone_cells.has(cell) or _map.get_fog_tier_at(cell) != -1, "cell %s on screen has neither fog nor a zone" % cell)
	assert_gt(checked, 100, "the check walked the whole screen area")

func test_fog_covers_screen_with_demo_zones() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var fog_rect: Rect2 = _map.get_camera_bounds_at_zoom(1.0).grow_individual(960.0, 540.0, 960.0, 540.0)
	for row: int in range(-20, 21):
		for col: int in range(-20, 21):
			var cell := Vector2i(col, row)
			if not _cell_rect(cell).intersects(fog_rect):
				continue
			assert_true(_map.get_zone_at_tile(cell) != null or _map.get_fog_tier_at(cell) != -1, "cell %s uncovered" % cell)

#-----------------------------------------------------------------------------
# ZONES AND HEX STATES
#-----------------------------------------------------------------------------

func test_hidden_test_zone_not_drawn() -> void:
	var cell: Vector2i = ZoneManager.get_zone_by_id(TEST_ZONE_ID).tilemap_location
	assert_null(_map.get_zone_at_tile(cell), "the hidden Test Zone has no cell on the zone layer")
	assert_null(_map.get_hex_overlay(TEST_ZONE_ID), "and no rim or veil")
	assert_eq(_map.get_fog_tier_at(cell), 1, "its cell is fog, one away from Spirit Valley")

func test_current_zone_gets_the_current_rim() -> void:
	var marker: ZoneHexMarker = _map.get_hex_overlay(SPIRIT_VALLEY_ID) as ZoneHexMarker
	assert_not_null(marker, "the current zone carries a hex marker")
	assert_eq(marker.get_state(), ZoneManager.ZoneMapState.CURRENT)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_current_ai")
	assert_eq(marker.position, Vector2.ZERO, "laid on its cell")

func test_open_zone_gets_the_hairline_and_hover_rim() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)
	var marker: ZoneHexMarker = _map.get_hex_overlay(TEST_ZONE_ID) as ZoneHexMarker
	assert_not_null(marker, "an unlocked Test Zone is an open hex")
	assert_eq(marker.get_state(), ZoneManager.ZoneMapState.OPEN)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_open_ai")
	marker.set_hovered(true)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_hover_ai", "hovering swaps in the brighter rim")
	marker.set_hovered(false)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_open_ai")

func test_current_rim_ignores_hover() -> void:
	var marker: ZoneHexMarker = _map.get_hex_overlay(SPIRIT_VALLEY_ID) as ZoneHexMarker
	marker.set_hovered(true)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_current_ai")

func test_demo_zones_add_overlays_and_retier_fog() -> void:
	assert_eq(_map.get_fog_tier_at(Vector2i(1, -2)), 2, "precondition: two away from Spirit Valley")
	watch_signals(_map)
	ZoneManager.set_demo_zones_visible(true)
	assert_signal_emitted(_map, "map_rebuilt")
	var locked: LockedZoneOverlay = _map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay
	var uncharted: LockedZoneOverlay = _map.get_hex_overlay(UNCHARTED_DEMO_ID) as LockedZoneOverlay
	assert_not_null(locked, "the Advancement demo gets a veiled overlay")
	assert_not_null(uncharted, "the Uncharted demo gets a veiled overlay")
	assert_eq(locked.get_state(), ZoneManager.ZoneMapState.LOCKED)
	assert_eq(uncharted.get_state(), ZoneManager.ZoneMapState.UNCHARTED)
	assert_string_contains(locked.get_tile_texture().resource_path, "lacquer_tile_locked_ai")
	assert_string_contains(uncharted.get_tile_texture().resource_path, "lacquer_tile_uncharted_ai")
	assert_eq(locked.position, _map.get_zone_world_centre(_zone(ADVANCEMENT_DEMO_ID)), "laid on its own cell")
	assert_eq(_map.get_fog_tier_at(Vector2i(1, -2)), 1, "fog next to the charted Advancement Zone is tier 1")
	assert_eq(_map.get_fog_tier_at(Vector2i(0, -1)), -1, "the demo zone's cell is no longer fog")
	assert_eq(_map.get_zone_at_tile(Vector2i(0, -1)), _zone(ADVANCEMENT_DEMO_ID), "the veiled cell is still a clickable zone cell")

func test_uncharted_zone_charts_nothing() -> void:
	ZoneManager.set_demo_zones_visible(true)
	# (1, -3) is one from the uncharted hex (0, -2) but two from the Advancement Zone.
	assert_eq(_map.get_fog_tier_at(Vector2i(1, -3)), 2)

func test_hiding_demo_zones_removes_their_overlays() -> void:
	ZoneManager.set_demo_zones_visible(true)
	ZoneManager.set_demo_zones_visible(false)
	assert_null(_map.get_hex_overlay(ADVANCEMENT_DEMO_ID))
	assert_null(_map.get_hex_overlay(UNCHARTED_DEMO_ID))
	assert_eq(_map.get_fog_tier_at(Vector2i(0, -1)), 1, "the cell is fog again")
	assert_null(_map.get_zone_at_tile(Vector2i(0, -1)))

func test_veiled_overlay_hover_and_pin() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var locked: LockedZoneOverlay = _map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay
	assert_null(locked.get_rim_texture(), "no inner rim at rest")
	locked.set_hovered(true)
	assert_string_contains(locked.get_tile_texture().resource_path, "lacquer_tile_locked_hover_ai", "hover lightens the veil")
	assert_string_contains(locked.get_rim_texture().resource_path, "lacquer_hex_hover_in_ai", "and lays the thin brass rim inside it")
	locked.set_pinned(true)
	assert_string_contains(locked.get_rim_texture().resource_path, "lacquer_hex_pinned_in_ai", "a pinned hex shows the heavy rim, even hovered")
	locked.set_hovered(false)
	assert_string_contains(locked.get_tile_texture().resource_path, "lacquer_tile_locked_ai")
	assert_string_contains(locked.get_rim_texture().resource_path, "lacquer_hex_pinned_in_ai")
	locked.set_pinned(false)
	assert_null(locked.get_rim_texture())

func test_zone_change_moves_the_current_rim() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq((_map.get_hex_overlay(TEST_ZONE_ID) as ZoneHexMarker).get_state(), ZoneManager.ZoneMapState.CURRENT)
	assert_eq((_map.get_hex_overlay(SPIRIT_VALLEY_ID) as ZoneHexMarker).get_state(), ZoneManager.ZoneMapState.OPEN)

#-----------------------------------------------------------------------------
# CHARACTER
#-----------------------------------------------------------------------------

func test_character_stands_below_the_zone_centre() -> void:
	var character: Node2D = _map.character_body
	assert_eq(character.scale, Vector2.ONE, "the 16x24 frame draws at 2x through the camera's zoom")
	var sprite: Sprite2D = character.get_node("Sprite2D") as Sprite2D
	var top_left: Vector2 = _to_screen(character.position + sprite.get_rect().position)
	assert_almost_eq(top_left.x, 960.0, 0.001, "kit §0: the character's 32x48 rect starts at x 960")
	assert_almost_eq(top_left.y, 740.0, 0.001, "and at y 740, below the river")

func test_foraging_wanders_west_of_the_stand() -> void:
	var stand: Vector2 = _map.character_body.position
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging starts on unlock")
	await wait_seconds(0.5)
	var position: Vector2 = _map.character_body.position
	assert_lt(position.x, stand.x, "the character walks west while foraging")
	assert_gte(position.x, stand.x - 24.0, "no further than 24 world px")
	assert_eq(position.y, stand.y, "only west, never up or down")
	assert_eq(position.x, roundf(position.x), "in whole world px (2 screen px steps)")
	ActionManager.stop_action()
	assert_eq(_map.character_body.position, stand, "stopping returns the character to its stand")

func test_foraging_running_at_load_wanders_at_once() -> void:
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging runs")
	# A map opened while foraging already runs (a save whose idle action is
	# foraging) hears no start_foraging, yet wanders from the first haul.
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	add_child_autofree(map)
	var stand: Vector2 = map.get_zone_world_centre(_zone(SPIRIT_VALLEY_ID)) + ZoneTilemap.CHARACTER_STAND_OFFSET
	await wait_seconds(0.5)
	assert_lt(map.character_body.position.x, stand.x, "the character wanders west before the first haul ends")

func test_foraging_wander_is_phase_locked_to_the_haul() -> void:
	# A map opened partway through a haul (a load, the zone view coming back)
	# picks the wander up where the haul timer is, so the next haul never
	# makes the character jump back to its stand.
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging runs")
	await wait_seconds(2.0)
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	add_child_autofree(map)
	var stand_x: float = map.get_zone_world_centre(_zone(SPIRIT_VALLEY_ID)).x + ZoneTilemap.CHARACTER_STAND_OFFSET.x
	await get_tree().process_frame
	assert_lt(map.character_body.position.x, stand_x - 8.0, "2 s into a 5 s haul the character is already well west")
	# The frames either side of the haul: the wander ends at the stand just as
	# the next one starts there.
	watch_signals(ActionManager)
	var x_before_haul: float = map.character_body.position.x
	var x_after_haul: float = x_before_haul
	var started_usec: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started_usec < 6_000_000:
		await get_tree().process_frame
		x_after_haul = map.character_body.position.x
		if get_signal_emit_count(ActionManager, "foraging_completed") > 0:
			break
		x_before_haul = x_after_haul
	assert_signal_emitted(ActionManager, "foraging_completed", "precondition: a haul came in")
	assert_almost_eq(x_after_haul, x_before_haul, 1.0, "the haul never snaps the character back: one world px (two screen px) at most")

func test_aura_well_bobs_the_character() -> void:
	var stand: Vector2 = _map.character_body.position
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_true(ActionManager.get_current_action() is TrainingActionData, "precondition: the Aura Well runs")
	await wait_seconds(1.3)
	var position: Vector2 = _map.character_body.position
	assert_eq(position.x, stand.x, "the bob never moves sideways")
	assert_lt(position.y, stand.y, "the character rises while it trains")
	assert_gte(position.y, stand.y - 2.0, "by at most 2 world px (4 screen px)")
	assert_eq(position.y, roundf(position.y), "in whole world px (2 screen px steps)")
	ActionManager.stop_action()
	assert_eq(_map.character_body.position, stand, "stopping returns the character to its stand")

func test_travel_while_foraging_walks_to_the_new_zone() -> void:
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging runs")
	_open_test_zone()
	var from_x: float = _stand(SPIRIT_VALLEY_ID).x
	var to_x: float = _stand(TEST_ZONE_ID).x
	_click_zone(TEST_ZONE_ID)
	assert_true(_map.character_body.is_moving, "the click starts a walk, even though the zone change stops foraging")
	await wait_seconds(0.1)
	var x: float = _map.character_body.position.x
	assert_true(_map.character_body.is_moving, "still walking 0.1 s in (an adjacent zone takes ~0.6 s)")
	assert_true(x > to_x and x < from_x, "mid-walk the character is between the two stands, not snapped to one (x = %s)" % x)

func test_idle_motion_starts_on_arrival() -> void:
	_open_test_zone()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	EventManager.trigger_event(AURA_WELL_EVENT)
	_click_zone(SPIRIT_VALLEY_ID)
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_true(ActionManager.get_current_action() is TrainingActionData, "precondition: the Aura Well runs in Spirit Valley")
	var stand: Vector2 = _stand(SPIRIT_VALLEY_ID)
	assert_eq(_map.character_body.position, stand, "precondition: arrived at the stand")
	await wait_seconds(1.3)
	assert_lt(_map.character_body.position.y, stand.y, "the Aura Well's bob starts once the walk ends")

#-----------------------------------------------------------------------------
# ZONE CHANGES THE MAP DID NOT MAKE
#-----------------------------------------------------------------------------

func test_zone_change_from_outside_moves_the_character_and_camera() -> void:
	_open_test_zone()
	# A dev switch sets the zone without a click on the map.
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq(_map.character_body.position, _stand(TEST_ZONE_ID), "the character stands in the new zone")
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(TEST_ZONE_ID)))
	assert_almost_eq(screen.x, 960.0, 0.001, "and the camera frames it")
	assert_almost_eq(screen.y, 702.0, 0.001)

func test_save_reset_after_travel_brings_the_map_home() -> void:
	_open_test_zone()
	_click_zone(TEST_ZONE_ID)
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_eq(_map.character_body.position, _stand(TEST_ZONE_ID), "precondition: arrived in Test Zone")
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "precondition: a fresh save starts in Spirit Valley")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "the character goes back with the save")
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(SPIRIT_VALLEY_ID)))
	assert_almost_eq(screen.x, 960.0, 0.001, "and the camera frames Spirit Valley again")
	assert_almost_eq(screen.y, 702.0, 0.001)

#-----------------------------------------------------------------------------
# CAMERA CLAMP (centre mode)
#-----------------------------------------------------------------------------

func test_clamp_now_keeps_the_camera_centre_inside_the_bounds() -> void:
	var camera: Camera2D = _map.get_camera()
	var clamp: CameraClampController = null
	for child: Node in camera.get_children():
		if child is CameraClampController:
			clamp = child
	camera.position = Vector2(5000.0, -5000.0)
	clamp.clamp_now()
	var bounds: Rect2 = _map.get_camera_bounds()
	assert_eq(camera.position, Vector2(bounds.end.x, bounds.position.y), "pulled back to the nearest bounds corner")

## Panned as far as it goes in each of the eight directions.
const FAR_PANS: Array[Vector2] = [
	Vector2(-5000.0, -5000.0), Vector2(0.0, -5000.0), Vector2(5000.0, -5000.0),
	Vector2(-5000.0, 0.0), Vector2(5000.0, 0.0),
	Vector2(-5000.0, 5000.0), Vector2(0.0, 5000.0), Vector2(5000.0, 5000.0),
]

func test_clamp_keeps_spirit_valley_in_the_free_window_at_every_zoom() -> void:
	var camera: Camera2D = _map.get_camera()
	for zoom: float in [2.0, 1.5, 1.0]:
		_zoom_controller().set_zoom_level(zoom)
		for pan: Vector2 in FAR_PANS:
			camera.position = pan
			_clamp_controller().clamp_now()
			var screen: Vector2 = _zone_on_screen(SPIRIT_VALLEY_ID)
			assert_true(_in_free_window(screen), "zoom %s, panned %s: Spirit Valley at %s is out of the free window" % [zoom, pan, screen])
		# Panned down and right as far as it goes, the valley sits on the free
		# window's top-left corner: the clamp is no tighter than it has to be.
		camera.position = Vector2(5000.0, 5000.0)
		_clamp_controller().clamp_now()
		var corner: Vector2 = _zone_on_screen(SPIRIT_VALLEY_ID)
		assert_almost_eq(corner.x, 546.0, 0.01, "zoom %s: on the window's left edge" % zoom)
		assert_almost_eq(corner.y, 95.0, 0.01, "zoom %s: on the window's top edge" % zoom)

func test_clamp_keeps_a_zone_in_the_free_window_with_every_demo_zone() -> void:
	_open_test_zone()
	ZoneManager.set_demo_zones_visible(true)
	var camera: Camera2D = _map.get_camera()
	for zoom: float in [2.0, 1.5, 1.0]:
		_zoom_controller().set_zoom_level(zoom)
		for pan: Vector2 in FAR_PANS:
			camera.position = pan
			_clamp_controller().clamp_now()
			var shown: Array[String] = []
			for zone: ZoneData in ZoneManager.get_map_zones():
				if _in_free_window(_zone_on_screen(zone.zone_id)):
					shown.append(zone.zone_id)
			assert_false(shown.is_empty(), "zoom %s, panned %s: no zone in the free window" % [zoom, pan])

func test_zooming_in_at_the_edge_pulls_the_camera_back() -> void:
	var camera: Camera2D = _map.get_camera()
	_zoom_controller().set_zoom_level(1.0)
	camera.position = Vector2(5000.0, 5000.0)
	_clamp_controller().clamp_now()
	_zoom_controller().set_zoom_level(2.0)
	assert_true(_in_free_window(_zone_on_screen(SPIRIT_VALLEY_ID)), "back at zoom 2 the valley is still in the free window")
