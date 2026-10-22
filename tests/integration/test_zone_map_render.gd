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

func test_camera_bounds_are_map_zones_plus_one_and_a_half_hexes() -> void:
	# Spirit Valley's tile is (-82, -95) to (82, 95); 1.5 hexes is 246 x 285 more each side.
	assert_eq(_map.get_camera_bounds(), Rect2(-328.0, -380.0, 656.0, 760.0))

func test_camera_bounds_grow_with_the_demo_zones() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var bounds: Rect2 = _map.get_camera_bounds()
	var uncharted_centre: Vector2 = _map.get_zone_world_centre(_zone(UNCHARTED_DEMO_ID))
	assert_true(bounds.has_point(uncharted_centre), "the uncharted demo hex is inside the clamp bounds")
	assert_almost_eq(bounds.position.y, uncharted_centre.y - 95.0 - 285.0, 0.001)

#-----------------------------------------------------------------------------
# FOG
#-----------------------------------------------------------------------------

func test_fog_tiers_around_spirit_valley() -> void:
	assert_eq(_map.get_fog_tier_at(Vector2i(1, 0)), 1, "a neighbour of Spirit Valley is tier 1")
	assert_eq(_map.get_fog_tier_at(Vector2i(2, 0)), 2, "two away is tier 2")
	assert_eq(_map.get_fog_tier_at(Vector2i(3, 0)), 3, "three away is tier 3")
	assert_eq(_map.get_fog_tier_at(Vector2i(0, 0)), -1, "a zone cell has no fog")

func test_fog_covers_screen_at_zoom_one() -> void:
	# Review Focus 3: the camera's centre is clamped to the bounds, so at the
	# lowest zoom (1.0) the screen reaches half a viewport past them.
	var fog_rect: Rect2 = _map.get_camera_bounds().grow_individual(960.0, 540.0, 960.0, 540.0)
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
	var fog_rect: Rect2 = _map.get_camera_bounds().grow_individual(960.0, 540.0, 960.0, 540.0)
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
