extends GutTest

## How the zone map follows the game (Task 11 of the map-first zone view): the
## fog tiers counted from the charted zones and covering every cell the camera
## can show (Review Focus 3), the hex states of shown, hidden and demo zones,
## the character's idle motion as actions start, stop and travel, the map
## following zone changes it did not make, and the camera clamp keeping a zone
## in the free map window.

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"
const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const FORAGING_UNLOCK_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"
## One 60 FPS frame, for the tests that step the idle motion by hand.
const FRAME: float = 1.0 / 60.0

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
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
	_map.tile_map.tile_set.emit_changed()
	await get_tree().process_frame

func after_each() -> void:
	# A test that held the action timer lets it go, or no later haul or tick
	# would ever come.
	ActionManager.action_timer.paused = false
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

## Where the character stands in the zone, in the map's world space.
func _stand(zone_id: String) -> Vector2:
	return _map.get_zone_world_centre(_zone(zone_id)) + ZoneTilemap.CHARACTER_STAND_OFFSET

## The clip the character is playing.
func _animation() -> StringName:
	return (_map.character_body.get_node("AnimationPlayer") as AnimationPlayer).current_animation

## Holds the action timer (the haul, the Aura Well's ticks), so an idle motion
## test is its own clock: it steps the motion by hand.
func _hold_action_timer() -> void:
	ActionManager.action_timer.paused = true

## Steps the map's idle motion (its tween, paused so only the test moves it)
## by one frame. Looked up each frame: a haul starts a new one.
func _step_frame(map: ZoneTilemap) -> void:
	var motion: Tween = map._idle_motion_tween
	motion.pause()
	motion.custom_step(FRAME)

## Steps 60 FPS frames of the map's idle motion until `done` returns true or
## `limit` seconds pass. Returns whether `done` is true.
func _step_until(map: ZoneTilemap, done: Callable, limit: float) -> bool:
	for _frame: int in roundi(limit / FRAME):
		if done.call():
			return true
		_step_frame(map)
	return done.call()

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
# FOG
#-----------------------------------------------------------------------------

func test_fog_tiers_around_spirit_valley() -> void:
	assert_eq(_map.get_fog_tier_at(Vector2i(1, 0)), 1, "a neighbour of Spirit Valley is tier 1")
	assert_eq(_map.get_fog_tier_at(Vector2i(2, 0)), 2, "two away is tier 2")
	assert_eq(_map.get_fog_tier_at(Vector2i(3, 0)), 3, "three away is tier 3")
	assert_eq(_map.get_fog_tier_at(Vector2i(0, 0)), -1, "a zone cell has no fog")

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

#-----------------------------------------------------------------------------
# ZONES AND HEX STATES
#-----------------------------------------------------------------------------

func test_hidden_test_zone_not_drawn() -> void:
	var cell: Vector2i = ZoneManager.get_zone_by_id(TEST_ZONE_ID).tilemap_location
	assert_null(_map.get_zone_at_tile(cell), "the hidden Test Zone has no cell on the zone layer")
	assert_null(_map.get_hex_overlay(TEST_ZONE_ID), "and no rim or veil")
	assert_eq(_map.get_fog_tier_at(cell), 1, "its cell is fog, one away from Spirit Valley")

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

func test_zone_change_moves_the_current_rim() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq((_map.get_hex_overlay(TEST_ZONE_ID) as ZoneHexMarker).get_state(), ZoneManager.ZoneMapState.CURRENT)
	assert_eq((_map.get_hex_overlay(SPIRIT_VALLEY_ID) as ZoneHexMarker).get_state(), ZoneManager.ZoneMapState.OPEN)

#-----------------------------------------------------------------------------
# CHARACTER
#-----------------------------------------------------------------------------

func test_foraging_wanders_west_of_the_stand() -> void:
	var stand: Vector2 = _map.character_body.position
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging starts on unlock")
	await wait_seconds(0.5)
	var position: Vector2 = _map.character_body.position
	assert_lt(position.x, stand.x, "the character walks west while foraging")
	assert_eq(_animation(), &"walk_left", "on its west walk cycle")
	ActionManager.stop_action()
	assert_eq(_map.character_body.position, stand, "stopping returns the character to its stand")
	assert_eq(_animation(), &"RESET", "standing still")

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

func test_stopping_the_aura_well_while_gone_shows_the_character() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	_hold_action_timer()
	var gone: bool = _step_until(_map, func() -> bool: return not _map.character_body.visible, 9.0)
	assert_true(gone, "precondition: the character dissolved")
	ActionManager.stop_action()
	assert_true(_map.character_body.visible, "it stands on its stand again, in sight")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID))

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
	await wait_seconds(0.1)
	assert_eq(_animation(), &"meditate", "the Aura Well's meditation starts once the walk ends")

#-----------------------------------------------------------------------------
# ZONE CHANGES THE MAP DID NOT MAKE
#-----------------------------------------------------------------------------

func test_zone_change_from_outside_moves_the_character() -> void:
	_open_test_zone()
	# A dev switch sets the zone without a click on the map.
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_eq(_map.character_body.position, _stand(TEST_ZONE_ID), "the character stands in the new zone")

func test_save_reset_after_travel_brings_the_map_home() -> void:
	_open_test_zone()
	_click_zone(TEST_ZONE_ID)
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_eq(_map.character_body.position, _stand(TEST_ZONE_ID), "precondition: arrived in Test Zone")
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "precondition: a fresh save starts in Spirit Valley")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "the character goes back with the save")

#-----------------------------------------------------------------------------
# CAMERA CLAMP (centre mode)
#-----------------------------------------------------------------------------

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

func test_zooming_in_at_the_edge_pulls_the_camera_back() -> void:
	var camera: Camera2D = _map.get_camera()
	_zoom_controller().set_zoom_level(1.0)
	camera.position = Vector2(5000.0, 5000.0)
	_clamp_controller().clamp_now()
	_zoom_controller().set_zoom_level(2.0)
	assert_true(_in_free_window(_zone_on_screen(SPIRIT_VALLEY_ID)), "back at zoom 2 the valley is still in the free window")
