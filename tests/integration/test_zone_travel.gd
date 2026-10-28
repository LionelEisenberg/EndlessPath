extends GutTest

## Map interaction (Task 13 of the map-first zone view; spec: Behaviour › Map
## interaction; kit §0, §6.4, §6.6): hovering hexes swaps their rims and
## lights the route to a zone you can travel to; a locked or uncharted hex
## shows a preview popover after 150 ms and pins it on a click; an open hex
## walks the character there with the old action running, and the zone only
## changes on arrival (Review Focus 2). One popover at a time; ×, Esc, a click
## outside, another hex, travel, or its zone leaving the map closes it
## (Review Focus 5).

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")
const ZoneMapPopoverScene: PackedScene = preload("res://scenes/zones/map_markers/zone_map_popover/zone_map_popover.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"
const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const FIXTURE_ZONE_ID: String = "TravelRetargetFixtureZone"
const AURA_WELL_EVENT: String = "aura_well_discovered"
## Completing the first quest unlocks foraging and The Shallow Woods.
const SHALLOW_WOODS_UNLOCK_EVENT: String = "q_fill_core_completed"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const CYCLING_ID: String = "wilderness_cycling_action"

## One 60 FPS frame, for stepping the walk and the tweens by hand.
const FRAME: float = 1.0 / 60.0
## Longer than any walk between neighbouring zones.
const WALK_LIMIT: float = 3.0

## GUT's output window's canvas layer.
const GUT_OUTPUT_LAYER: int = 128

var _map: ZoneTilemap
var _fixture_zone: ZoneData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	# The map sets the current zone on load and travel writes to the save: run
	# on a fresh one, never the developer's save.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_map = ZoneTilemapScene.instantiate()
	add_child_autofree(_map)
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
	_map.tile_map.tile_set.emit_changed()
	await _settle()

func after_each() -> void:
	# test_esc_closes_pinned_popover parses a ui_cancel press; leave the action
	# released for the tests that run after this file.
	Input.action_release(&"ui_cancel")
	_remove_fixture_zone()
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	await get_tree().process_frame

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The markers place themselves every frame: let two frames run.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _markers() -> MapMarkers:
	return _map.get_map_markers()

func _popover() -> ZoneMapPopover:
	return _markers().get_popover()

func _state() -> MapPopoverState:
	return _markers().get_popover_state()

func _zone(zone_id: String) -> ZoneData:
	for zone: ZoneData in ZoneManager.get_map_zones():
		if zone.zone_id == zone_id:
			return zone
	return ZoneManager.get_zone_by_id(zone_id)

## Where the character stands in the zone, in the map's world space.
func _stand(zone_id: String) -> Vector2:
	return _map.get_zone_world_centre(_zone(zone_id)) + ZoneTilemap.CHARACTER_STAND_OFFSET

## The screen point a world point lands on with the map camera as it is now.
func _to_screen(world: Vector2) -> Vector2:
	var camera: Camera2D = _map.get_camera()
	return ZoneMapMath.world_to_screen(world, camera.position, camera.zoom.x)

## Shows the hidden Test Zone and unlocks it, so it is an open hex.
func _open_test_zone() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)

## A third open zone, in memory only (east of Spirit Valley unless told
## otherwise), so a walk can be sent somewhere new halfway (Review Focus 2).
## Shown on the next map rebuild.
func _add_fixture_zone(cell: Vector2i = Vector2i(1, 0)) -> void:
	_fixture_zone = ZoneData.new()
	_fixture_zone.zone_id = FIXTURE_ZONE_ID
	_fixture_zone.zone_name = "Fixture Ridge"
	_fixture_zone.tilemap_location = cell
	ZoneManager.get_all_zones().append(_fixture_zone)

func _remove_fixture_zone() -> void:
	if _fixture_zone == null:
		return
	if ZoneManager.get_current_zone() != null and ZoneManager.get_current_zone().zone_id == FIXTURE_ZONE_ID:
		ZoneManager.set_current_zone_by_id(SPIRIT_VALLEY_ID)
	ZoneManager.get_all_zones().erase(_fixture_zone)
	_fixture_zone = null

func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press

func _escape_event() -> InputEventAction:
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	return escape

func _hover_cell_of(zone_id: String) -> void:
	_map.tile_map.tile_hovered.emit(_zone(zone_id).tilemap_location)

## Moves every running tween in the tree on by `delta`, as a frame does: the
## camera's glide, the lock's shake, the idle motion.
func _step_tweens(delta: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			tween.custom_step(delta)

## One 60 FPS frame stepped by hand, in the tree's order: the walk's physics
## step, then the tweens. The walk is taken off the physics clock, so only the
## test moves it.
func _step_frame(map: ZoneTilemap) -> void:
	map.character_body.set_physics_process(false)
	simulate(map.character_body, 1, FRAME)
	_step_tweens(FRAME)

## Steps `seconds` of 60 FPS frames.
func _run(map: ZoneTilemap, seconds: float) -> void:
	for _frame: int in roundi(seconds / FRAME):
		_step_frame(map)

## Steps 60 FPS frames until the walk ends, for at most WALK_LIMIT seconds.
func _walk_until_arrival(map: ZoneTilemap) -> void:
	for _frame: int in roundi(WALK_LIMIT / FRAME):
		if not map.character_body.is_moving:
			return
		_step_frame(map)

## Lets the hover preview's 150 ms run out: the markers' one-shot preview
## timer times out now if it is running.
func _run_out_preview_delay(markers: MapMarkers) -> void:
	var timer: Timer = markers._preview_timer
	if not timer.is_stopped():
		timer.stop()
		timer.timeout.emit()

## A second map shown, as in the game, through a full-size SubViewport. Its
## host sits on a canvas layer of its own, out of reach of the first map's
## camera and above GUT's output window (layer 128, full screen), so the
## pointer finds it where it is drawn.
func _hosted_map() -> ZoneTilemap:
	var layer := CanvasLayer.new()
	layer.layer = GUT_OUTPUT_LAYER + 1
	var host := SubViewportContainer.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ZoneMapMath.VIEWPORT_SIZE)
	host.add_child(viewport)
	layer.add_child(host)
	add_child_autofree(layer)
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	viewport.add_child(map)
	map.tile_map.tile_set.emit_changed()
	await _settle()
	return map

## Where the zone's hex centre lands in the hosted map's SubViewport.
func _hosted_screen_point(map: ZoneTilemap, zone_id: String) -> Vector2:
	return map.get_global_transform_with_canvas() * map.get_zone_world_centre(_zone(zone_id))

## Moves the pointer, through the window as the player would, to a point in
## the hosted map's SubViewport (headless, the window is not 1920x1080).
func _move_pointer_to(map: ZoneTilemap, point: Vector2) -> void:
	await _move_pointer_to_window_point(map.get_viewport().get_screen_transform() * point)

func _move_pointer_to_window_point(window_point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame

#-----------------------------------------------------------------------------
# TRAVEL (Review Focus 2)
#-----------------------------------------------------------------------------

func test_travel_changes_zone_on_arrival_only() -> void:
	_open_test_zone()
	watch_signals(ZoneManager)
	_map.click_zone(_zone(TEST_ZONE_ID))
	assert_true(_map.is_travelling(), "the click starts a walk")
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "the zone does not change on the click")
	assert_signal_not_emitted(ZoneManager, "zone_changed")
	_walk_until_arrival(_map)
	assert_eq(ZoneManager.get_current_zone().zone_id, TEST_ZONE_ID, "it changes on arrival")
	assert_signal_emit_count(ZoneManager, "zone_changed", 1)
	assert_false(_map.is_travelling())
	assert_eq(_map.character_body.position, _stand(TEST_ZONE_ID), "the character stands in Test Zone")

func test_tile_click_travels() -> void:
	_open_test_zone()
	_map.tile_map.tile_clicked.emit(_zone(TEST_ZONE_ID).tilemap_location)
	assert_true(_map.is_travelling(), "a click on the open hex's cell walks there")

func test_arrival_frames_the_new_zone() -> void:
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_walk_until_arrival(_map)
	_run(_map, _map.camera_ease_duration + 0.1)
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(TEST_ZONE_ID)))
	assert_almost_eq(screen.x, 960.0, 0.5, "after a short ease the new zone sits at x 960")
	assert_almost_eq(screen.y, 702.0, 0.5, "and y 702")

func test_old_action_runs_during_walk() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_true(ActionManager.get_current_action() is TrainingActionData, "precondition: the Aura Well runs")
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.3)
	assert_true(_map.is_travelling(), "still walking 0.3 s in")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "the Aura Well keeps running mid-walk")
	_walk_until_arrival(_map)
	assert_null(ActionManager.get_current_action(), "Test Zone has no idle action to resume")

func test_second_click_during_walk_retargets() -> void:
	_add_fixture_zone()
	_open_test_zone()
	EventManager.trigger_event(AURA_WELL_EVENT)
	watch_signals(ZoneManager)
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	_map.click_zone(_zone(FIXTURE_ZONE_ID))
	assert_true(_map.is_travelling(), "the walk turns toward the second zone")
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "the zone still has not changed")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "one action runs: the Aura Well")
	_walk_until_arrival(_map)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "the walk ends in the second zone")
	assert_signal_emit_count(ZoneManager, "zone_changed", 1, "one zone change, on the final arrival")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID))
	assert_null(ActionManager.get_current_action(), "the fixture zone has no idle action")

func test_click_current_during_walk_walks_home() -> void:
	_open_test_zone()
	EventManager.trigger_event(AURA_WELL_EVENT)
	watch_signals(ZoneManager)
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	_map.click_zone(_zone(SPIRIT_VALLEY_ID))
	_walk_until_arrival(_map)
	assert_false(_map.is_travelling())
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID)
	assert_signal_not_emitted(ZoneManager, "zone_changed", "turning back never changes the zone")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back at the valley's stand")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "the Aura Well never stopped")

func test_session_action_during_walk_cancels_travel() -> void:
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_false(_map.is_travelling(), "cycling here stops the walk")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "the character is back in the valley")
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "no arrival in Test Zone")
	assert_eq(ActionManager.get_current_action().action_id, CYCLING_ID, "cycling still runs")

func test_save_reset_during_walk_cancels_travel() -> void:
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_false(_map.is_travelling(), "a save reset ends the walk")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID))
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "and nothing arrives later")

func test_outside_zone_change_during_walk_snaps_there() -> void:
	# A zone change the map did not make (a dev switch, a save reset) ends the
	# walk at once: the character, the camera and the map's own zone follow
	# the real current zone, and nothing arrives later.
	_add_fixture_zone()
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	ZoneManager.set_current_zone_by_id(FIXTURE_ZONE_ID)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.selected_zone, _zone(FIXTURE_ZONE_ID), "the map stands in the new zone")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID), "and so does the character")
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(FIXTURE_ZONE_ID)))
	assert_almost_eq(screen.x, 960.0, 0.5, "framed at once")
	assert_almost_eq(screen.y, 702.0, 0.5)
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "nothing arrives in Test Zone later")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID))

func test_outside_change_to_the_zone_you_left_ends_the_walk() -> void:
	# Even a zone change that names the zone the walk began in comes from
	# outside the map: the walk ends there.
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	ZoneManager.set_current_zone_by_id(SPIRIT_VALLEY_ID)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back on the valley's stand")
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "nothing arrives in Test Zone later")

func test_save_reset_during_walk_ends_in_the_new_zone() -> void:
	_add_fixture_zone()
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	var save := SaveGameData.new()
	save.current_selected_zone_id = FIXTURE_ZONE_ID
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.selected_zone, ZoneManager.get_current_zone(), "the map follows the new save's zone")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID), "the character stands there")
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "nothing arrives in Test Zone later")

func test_walk_ends_when_its_zone_leaves_the_map() -> void:
	# The dev toggle hides Test Zone mid-walk: the character goes back to the
	# valley instead of arriving in a zone the map no longer shows.
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	_run(_map, 0.2)
	ZoneManager.set_hidden_zones_visible(false)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back on the valley's stand")
	_run(_map, 0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "nothing arrives off the map")

func test_travel_closes_popover() -> void:
	_open_test_zone()
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_true(_popover().visible, "precondition: pinned")
	_map.click_zone(_zone(TEST_ZONE_ID))
	assert_false(_popover().visible, "travelling closes the popover")
	assert_eq(_state().get_pinned_zone_id(), "")

#-----------------------------------------------------------------------------
# CLICKS ON VEILED HEXES, THE CURRENT ZONE AND FOG
#-----------------------------------------------------------------------------

func test_click_locked_pins_popover_and_shakes_lock() -> void:
	ZoneManager.set_demo_zones_visible(true)
	await _settle()
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_false(_map.is_travelling(), "a locked zone never travels")
	assert_eq(_state().get_pinned_zone_id(), ADVANCEMENT_DEMO_ID)
	var popover: ZoneMapPopover = _popover()
	assert_true(popover.visible)
	assert_true(popover.is_pinned())
	assert_eq(popover.get_zone_data().zone_id, ADVANCEMENT_DEMO_ID)
	assert_eq(popover.get_title_text(), "Advancement Zone")
	assert_eq(popover.get_body_text(), "Defeat the Tribulation Guardian in The Shallow Woods")
	assert_string_contains(popover.get_card_texture().resource_path, "lacquer_pop_locked_ai")
	var glyph: MapGlyph = _markers().get_glyph(ADVANCEMENT_DEMO_ID) as MapGlyph
	assert_true(glyph.is_shaking(), "the lock shakes")
	var overlay: LockedZoneOverlay = _map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay
	assert_string_contains(overlay.get_rim_texture().resource_path, "lacquer_hex_pinned_in_ai", "the heavy rim inside the veil")
	assert_true(_markers().get_plate(ADVANCEMENT_DEMO_ID).is_pinned_frame_shown(), "and the brass frame on its plate")

func test_lock_shake_steps() -> void:
	assert_eq(MapGlyph.shake_offset_at(0.0), 0)
	assert_eq(MapGlyph.shake_offset_at(0.1), -8)
	assert_eq(MapGlyph.shake_offset_at(0.2), 8)
	assert_eq(MapGlyph.shake_offset_at(0.3), -6)
	assert_eq(MapGlyph.shake_offset_at(0.4), 4)
	assert_eq(MapGlyph.shake_offset_at(0.44), 0, "back home after 0.44 s")
	assert_eq(MapGlyph.shake_offset_at(1.0), 0)

func test_lock_shake_moves_only_the_icon() -> void:
	ZoneManager.set_demo_zones_visible(true)
	await _settle()
	var glyph: MapGlyph = _markers().get_glyph(ADVANCEMENT_DEMO_ID) as MapGlyph
	var glyph_position: Vector2 = glyph.position
	var icon: Control = glyph.get_node("%Icon") as Control
	glyph.shake()
	# The real shake, sampled halfway through each 0.088 s step, follows the
	# keyframe table test_lock_shake_steps reads.
	var offsets: Array[float] = []
	var elapsed: float = 0.0
	for sample_at: float in [0.132, 0.22, 0.308, 0.396]:
		_step_tweens(sample_at - elapsed)
		elapsed = sample_at
		offsets.append(icon.position.x)
	assert_eq(offsets, [-8.0, 8.0, -6.0, 4.0] as Array[float], "the padlock steps -8, 8, -6, 4 px")
	assert_eq(glyph.position, glyph_position, "the glyph stays on its hex")
	_step_tweens(MapGlyph.SHAKE_SECONDS)
	assert_false(glyph.is_shaking())
	assert_eq(icon.position.x, 0.0, "and settles back")

func test_click_uncharted_pins_never_travels() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	assert_false(_map.is_travelling())
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID)
	var popover: ZoneMapPopover = _popover()
	assert_true(popover.visible)
	assert_true(popover.is_pinned())
	assert_eq(popover.get_title_text(), "Uncharted")
	assert_eq(popover.get_body_text(), "Revealed after the Tribulation.")
	assert_string_contains(popover.get_card_texture().resource_path, "lacquer_pop_uncharted_ai")
	assert_false(popover.is_show_me_shown(), "an uncharted popover has no Show me")
	assert_false((_markers().get_glyph(UNCHARTED_DEMO_ID) as MapGlyph).is_shaking(), "only the lock shakes")

func test_only_one_popover_pinned() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	assert_eq(_popover().get_zone_data().zone_id, UNCHARTED_DEMO_ID, "the second hex takes the popover")
	var locked: LockedZoneOverlay = _map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay
	assert_null(locked.get_rim_texture(), "the first hex loses its pinned rim")
	assert_false(_markers().get_plate(ADVANCEMENT_DEMO_ID).is_pinned_frame_shown())

func test_click_current_recentres_and_closes() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	var camera: Camera2D = _map.get_camera()
	camera.position += Vector2(60, 40)
	_map.click_zone(_zone(SPIRIT_VALLEY_ID))
	assert_false(_popover().visible, "recentring closes the popover")
	assert_false(_map.is_travelling(), "and never walks")
	_run(_map, _map.camera_ease_duration + 0.1)
	var screen: Vector2 = _to_screen(Vector2.ZERO)
	assert_almost_eq(screen.x, 960.0, 0.5, "the valley is framed again")
	assert_almost_eq(screen.y, 702.0, 0.5)

func test_click_fog_closes() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	var fog: TileMapLayer = _map.get_node("%FogTileMapLayer") as TileMapLayer
	fog.emit_signal("tile_clicked", Vector2i(2, 0))
	assert_false(_popover().visible, "a click on fog closes the popover")
	assert_eq(_state().get_pinned_zone_id(), "")
	assert_false(_map.is_travelling())

func test_plate_press_does_what_its_hex_does() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_open_test_zone()
	_markers().get_plate(ADVANCEMENT_DEMO_ID).gui_input.emit(_left_press())
	assert_eq(_state().get_pinned_zone_id(), ADVANCEMENT_DEMO_ID, "the locked plate pins its popover")
	_markers().get_plate(TEST_ZONE_ID).gui_input.emit(_left_press())
	assert_true(_map.is_travelling(), "the open plate walks there")
	assert_false(_popover().visible)

#-----------------------------------------------------------------------------
# HOVER
#-----------------------------------------------------------------------------

func test_hover_open_zone_brightens_rim_route_and_plate() -> void:
	_open_test_zone()
	var marker: ZoneHexMarker = _map.get_hex_overlay(TEST_ZONE_ID) as ZoneHexMarker
	var route: ZoneRoute = _map.get_route_to(TEST_ZONE_ID)
	_hover_cell_of(TEST_ZONE_ID)
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_hover_ai", "the brighter rim")
	assert_true(route.is_lit(), "the route to it turns cream")
	assert_eq(_markers().get_plate(TEST_ZONE_ID).get_line_text(), "Click to travel")
	_map.tile_map.tile_unhovered.emit()
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_open_ai")
	assert_false(route.is_lit())
	assert_ne(_markers().get_plate(TEST_ZONE_ID).get_line_text(), "Click to travel")

func test_route_lights_every_open_segment_on_the_way() -> void:
	# An open zone two hexes west, reached through Test Zone: hovering it
	# lights both segments, the valley to Test Zone and Test Zone to it.
	_add_fixture_zone(Vector2i(-2, 0))
	_open_test_zone()
	_hover_cell_of(FIXTURE_ZONE_ID)
	assert_true(_map.get_route_to(FIXTURE_ZONE_ID).is_lit(), "the segment into the hovered zone")
	assert_true(_map.get_route_to(TEST_ZONE_ID).is_lit(), "and the open zone on the way")

func test_route_never_lights_into_or_out_of_a_locked_zone() -> void:
	# Spec: a route brightens only toward a zone you can travel to, never
	# toward a locked or uncharted one. An open zone whose route runs on from
	# the locked demo zone lights neither segment.
	_add_fixture_zone(Vector2i(1, -1))
	ZoneManager.set_demo_zones_visible(true)
	var route: ZoneRoute = _map.get_route_to(FIXTURE_ZONE_ID)
	var locked_centre: Vector2 = _map.get_zone_world_centre(_zone(ADVANCEMENT_DEMO_ID)) - route.position
	var fixture_centre: Vector2 = _map.get_zone_world_centre(_zone(FIXTURE_ZONE_ID)) - route.position
	assert_eq(route.get_dot_positions(), ZoneRoute.dot_positions(locked_centre, fixture_centre), "precondition: its route runs on from the locked zone")
	_hover_cell_of(FIXTURE_ZONE_ID)
	var marker: ZoneHexMarker = _map.get_hex_overlay(FIXTURE_ZONE_ID) as ZoneHexMarker
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_hover_ai", "precondition: hovered and travelable")
	assert_false(route.is_lit(), "no segment out of the locked zone")
	assert_false(_map.get_route_to(ADVANCEMENT_DEMO_ID).is_lit(), "and none into it")
	assert_false(_map.get_route_to(UNCHARTED_DEMO_ID).is_lit())

func test_hover_current_zone_brightens_its_plate_only() -> void:
	_hover_cell_of(SPIRIT_VALLEY_ID)
	assert_eq(_markers().get_plate(SPIRIT_VALLEY_ID).get_name_color(), ThemeConstants.LACQUER_CREAM, "the plate text brightens")
	var marker: ZoneHexMarker = _map.get_hex_overlay(SPIRIT_VALLEY_ID) as ZoneHexMarker
	assert_string_contains(marker.get_rim_texture().resource_path, "lacquer_hex_current_ai", "the rim stays")

func test_fog_hover_clears_the_hover() -> void:
	_open_test_zone()
	_hover_cell_of(TEST_ZONE_ID)
	var fog: TileMapLayer = _map.get_node("%FogTileMapLayer") as TileMapLayer
	fog.emit_signal("tile_hovered", Vector2i(2, 0))
	assert_eq(_state().get_hovered_zone_id(), "")
	assert_false(_map.get_route_to(TEST_ZONE_ID).is_lit())

func test_hover_locked_shows_preview_after_delay() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_hover_cell_of(ADVANCEMENT_DEMO_ID)
	var overlay: LockedZoneOverlay = _map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay
	assert_string_contains(overlay.get_rim_texture().resource_path, "lacquer_hex_hover_in_ai", "a thin brass rim inside the veil")
	assert_string_contains(overlay.get_tile_texture().resource_path, "lacquer_tile_locked_hover_ai")
	assert_false(_map.get_route_to(ADVANCEMENT_DEMO_ID).is_lit(), "routes never brighten toward a locked zone")
	assert_false(_popover().visible, "no preview before 150 ms")
	assert_almost_eq(_markers()._preview_timer.wait_time, 0.15, 0.0001, "the preview waits 150 ms")
	_run_out_preview_delay(_markers())
	assert_true(_popover().visible, "the preview shows")
	assert_false(_popover().is_pinned())
	assert_string_contains(_popover().get_card_texture().resource_path, "lacquer_pop_locked_preview_ai")
	assert_false(_popover().is_close_shown(), "a preview has no ×")
	assert_false(_popover().is_show_me_shown(), "nor Show me")
	_map.tile_map.tile_unhovered.emit()
	assert_false(_popover().visible, "leaving the hex hides it outright")
	assert_null(overlay.get_rim_texture())

func test_passing_pointer_opens_no_preview() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_hover_cell_of(ADVANCEMENT_DEMO_ID)
	# Off the hex again before its 150 ms run out.
	_map.tile_map.tile_unhovered.emit()
	_run_out_preview_delay(_markers())
	assert_false(_popover().visible)

func test_leaving_the_map_clears_the_hover() -> void:
	# In the game the map sits in a SubViewport; a pointer that leaves it for a
	# panel leaves every hex, even when it skips the fog between.
	var host := SubViewportContainer.new()
	var viewport := SubViewport.new()
	host.add_child(viewport)
	add_child_autofree(host)
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	viewport.add_child(map)
	await _settle()
	ZoneManager.set_demo_zones_visible(true)
	map.tile_map.tile_hovered.emit(_zone(ADVANCEMENT_DEMO_ID).tilemap_location)
	var markers: MapMarkers = map.get_map_markers()
	_run_out_preview_delay(markers)
	assert_true(markers.get_popover().visible, "precondition: the preview shows")
	host.mouse_exited.emit()
	assert_eq(markers.get_popover_state().get_hovered_zone_id(), "")
	assert_false(markers.get_popover().visible, "the preview goes with the pointer")
	assert_null((map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay).get_rim_texture())

func test_coming_back_onto_the_same_cell_hovers_again() -> void:
	# The hex layers report a cell only when the pointer moves onto a new one:
	# leaving the map must make them forget the last, or a pointer coming
	# straight back onto it hovers nothing.
	var map: ZoneTilemap = await _hosted_map()
	var host: SubViewportContainer = map.get_viewport().get_parent() as SubViewportContainer
	_open_test_zone()
	var point: Vector2 = _hosted_screen_point(map, TEST_ZONE_ID)
	await _move_pointer_to(map, point)
	var state: MapPopoverState = map.get_map_markers().get_popover_state()
	assert_eq(state.get_hovered_zone_id(), TEST_ZONE_ID, "precondition: the pointer hovers Test Zone")
	host.mouse_exited.emit()
	assert_eq(state.get_hovered_zone_id(), "", "precondition: leaving the map clears it")
	host.mouse_entered.emit()
	await _move_pointer_to(map, point + Vector2(2, 2))
	assert_eq(state.get_hovered_zone_id(), TEST_ZONE_ID, "back on the same cell, it hovers again")
	assert_true(map.get_route_to(TEST_ZONE_ID).is_lit())
	await _move_pointer_to_window_point(Vector2.ZERO)

func test_late_marker_exit_brings_back_no_hover() -> void:
	# Leaving the map from a plate or the popover, their own mouse_exited can
	# come after the map's: it must not hover the hex the pointer left.
	var map: ZoneTilemap = await _hosted_map()
	var host: SubViewportContainer = map.get_viewport().get_parent() as SubViewportContainer
	_open_test_zone()
	ZoneManager.set_demo_zones_visible(true)
	var markers: MapMarkers = map.get_map_markers()
	await _move_pointer_to(map, _hosted_screen_point(map, TEST_ZONE_ID))
	assert_eq(markers.get_popover_state().get_hovered_zone_id(), TEST_ZONE_ID, "precondition: hovered")
	host.mouse_exited.emit()
	markers.get_plate(TEST_ZONE_ID).mouse_exited.emit()
	assert_eq(markers.get_popover_state().get_hovered_zone_id(), "", "a plate's late exit hovers nothing")
	assert_false(map.get_route_to(TEST_ZONE_ID).is_lit())
	(markers.get_popover().get_node("%LockedCard") as Control).mouse_exited.emit()
	assert_eq(markers.get_popover_state().get_hovered_zone_id(), "", "nor does the popover's")
	await _move_pointer_to_window_point(Vector2.ZERO)

func test_arrival_glide_hovers_what_ends_up_under_the_still_pointer() -> void:
	# The arrival glide moves Test Zone from under the pointer to the screen's
	# centre; the pointer stays put, over the open fixture zone west of it by
	# the end. Without a mouse move, the hover must follow the camera.
	var map: ZoneTilemap = await _hosted_map()
	_open_test_zone()
	_add_fixture_zone(Vector2i(-2, 0))
	map._rebuild_map()
	await _settle()
	var state: MapPopoverState = map.get_map_markers().get_popover_state()
	await _move_pointer_to(map, _hosted_screen_point(map, TEST_ZONE_ID))
	assert_eq(state.get_hovered_zone_id(), TEST_ZONE_ID, "precondition: the pointer hovers Test Zone")
	map.click_zone(_zone(TEST_ZONE_ID))
	_walk_until_arrival(map)
	_run(map, map.camera_ease_duration + 0.1)
	await _settle()
	assert_eq(ZoneManager.get_current_zone().zone_id, TEST_ZONE_ID, "precondition: arrived")
	assert_eq(state.get_hovered_zone_id(), FIXTURE_ZONE_ID, "the zone now under the pointer is hovered")
	assert_true(state.is_hovered_travelable(), "and reads as a zone you can travel to")
	assert_true(map.get_route_to(FIXTURE_ZONE_ID).is_lit(), "its route lights")
	await _move_pointer_to_window_point(Vector2.ZERO)

func test_camera_move_under_a_still_pointer_clears_a_hover_left_behind() -> void:
	# A wheel zoom or a recentre moves the cells under a still pointer; a hex
	# the camera took away is no longer hovered.
	var map: ZoneTilemap = await _hosted_map()
	_open_test_zone()
	await _settle()
	var state: MapPopoverState = map.get_map_markers().get_popover_state()
	await _move_pointer_to(map, _hosted_screen_point(map, TEST_ZONE_ID))
	assert_eq(state.get_hovered_zone_id(), TEST_ZONE_ID, "precondition: the pointer hovers Test Zone")
	map.get_camera().position += Vector2(-400, 0)
	await _settle()
	await _settle()
	assert_eq(state.get_hovered_zone_id(), "", "fog is under the pointer now")
	assert_false(map.get_route_to(TEST_ZONE_ID).is_lit(), "the route goes out")
	await _move_pointer_to_window_point(Vector2.ZERO)

func test_no_preview_while_pinned() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	_hover_cell_of(ADVANCEMENT_DEMO_ID)
	_run_out_preview_delay(_markers())
	assert_eq(_popover().get_zone_data().zone_id, UNCHARTED_DEMO_ID, "the pinned popover stays the only one")
	assert_true(_popover().is_pinned())

#-----------------------------------------------------------------------------
# POPOVER PLACEMENT AND CONTENTS
#-----------------------------------------------------------------------------

func test_popovers_sit_at_kit_positions() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	await _settle()
	assert_eq(_popover().position, Vector2(684, 331), "kit §6.6: the pinned locked popover, left of its hex")
	assert_eq(_popover().get_close_button().get_global_rect().position, Vector2(904, 343), "× at X+220, Y+12")
	assert_eq(_popover().get_show_me_button().get_global_rect().position, Vector2(700, 455), "Show me at X+16, Y+124")
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	await _settle()
	assert_eq(_popover().position, Vector2(1128, 76), "kit §6.6: the uncharted popover, right of its hex")
	assert_eq(_popover().get_close_button().get_global_rect().position, Vector2(1356, 88), "× at X+228, Y+12")
	_markers().close_popover()
	_hover_cell_of(ADVANCEMENT_DEMO_ID)
	_run_out_preview_delay(_markers())
	await _settle()
	assert_eq(_popover().position, Vector2(684, 351), "kit §6.6: the locked preview")

func test_popover_follows_hex_at_zoom_one() -> void:
	# Review Focus 3: away from zoom 2 the popover keeps to its hex.
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	var centre: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(ADVANCEMENT_DEMO_ID)))
	assert_eq(_popover().scale, Vector2.ONE, "the popover keeps its size: its text never drops under 13 px")
	# At zoom 2 the card's right edge is 168 px left of the hex centre, 4 px
	# clear of the rim; at zoom 1 it is 84 px left, centred on the hex height.
	assert_eq(_popover().position, (centre + Vector2(-84 - 272, -86)).round(), "beside its hex")

func test_show_me_only_for_action_in_current_zone() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_false(_popover().is_show_me_shown(), "a fresh save has no Shallow Woods card to show")
	EventManager.trigger_event(SHALLOW_WOODS_UNLOCK_EVENT)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_true(_popover().is_show_me_shown(), "the card is in Spirit Valley's list")
	assert_true(_popover().is_close_shown(), "a pinned popover has its ×")
	_open_test_zone()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_true(_popover().visible)
	assert_false(_popover().is_show_me_shown(), "from Test Zone the card is not in the list")

func test_show_me_requests_focus() -> void:
	ZoneManager.set_demo_zones_visible(true)
	EventManager.trigger_event(SHALLOW_WOODS_UNLOCK_EVENT)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	watch_signals(ZoneManager)
	_popover().get_show_me_button().pressed.emit()
	assert_signal_emitted_with_parameters(ZoneManager, "action_focus_requested", [ADVENTURE_ID])

func test_long_text_stays_inside_the_popover() -> void:
	# Review Focus 4: a long zone name ellipsizes, a long requirement keeps
	# to two lines, and the card never grows.
	var popover: ZoneMapPopover = ZoneMapPopoverScene.instantiate()
	add_child_autofree(popover)
	var zone := ZoneData.new()
	zone.zone_id = "LongZone"
	zone.zone_name = "The Exceedingly Long and Winding Valley of a Thousand Whispering Names"
	zone.requirement_text = "Defeat the Tribulation Guardian and every one of its seven sworn sisters in the deepest reaches of The Shallow Woods at midnight"
	popover.setup(zone, ZoneManager.ZoneMapState.LOCKED, true, true)
	await _settle()
	var title: Label = popover.get_node("%LockedTitle") as Label
	var body: Label = popover.get_node("%LockedBody") as Label
	assert_eq(title.size.x, 232.0, "the title keeps its 232 px slot")
	assert_ne(title.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "and ellipsizes")
	assert_eq(body.size, Vector2(232, 40), "the body keeps its two 20 px lines")
	assert_eq(body.max_lines_visible, 2)
	assert_eq(popover.get_card_rect().size, Vector2(276, 176), "the card keeps its size")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

func test_close_button_closes() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	_popover().get_close_button().pressed.emit()
	assert_false(_popover().visible)
	assert_eq(_state().get_pinned_zone_id(), "")
	assert_null((_map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay).get_rim_texture())
	assert_false(_markers().get_plate(ADVANCEMENT_DEMO_ID).is_pinned_frame_shown())

func test_esc_closes_pinned_popover() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	Input.parse_input_event(_escape_event())
	await _settle()
	assert_false(_popover().visible, "Esc closes the pinned popover")
	assert_eq(_state().get_pinned_zone_id(), "")

## A MainView with the zone view as its base state, not in the tree, as
## test_zone_panel.gd builds one.
func _main_view_on_the_zone_view() -> MainView:
	var main_view: MainView = autofree(MainView.new())
	main_view.zone_view_state = autofree(ZoneViewState.new())
	main_view.base_current_state = main_view.zone_view_state
	main_view.state_stack = [] as Array[MainViewState]
	return main_view

## A LogWindow with its full log open, placed before the map in the tree so
## the map hears Esc first. (In the game the log sits after the zone view and
## hears it first anyway; this pins that the map leaves Esc to a full log
## whatever the order.)
func _log_with_full_log_open() -> LogWindow:
	var screen := Control.new()
	screen.size = ZoneMapMath.VIEWPORT_SIZE
	add_child_autofree(screen)
	move_child(screen, 0)
	var log_window: LogWindow = (load("res://scenes/ui/log_window/log_window.tscn") as PackedScene).instantiate()
	screen.add_child(log_window)
	log_window.toggle_full_log()
	return log_window

func test_esc_reaches_an_overlay_over_the_zone_view_first() -> void:
	# The map's SubViewport hears Esc before MainView, its ancestor, does. With
	# the Character view pushed over the zone view (opened with C), Esc belongs
	# to it, not to a popover pinned under it.
	ZoneManager.set_demo_zones_visible(true)
	var main_view: MainView = _main_view_on_the_zone_view()
	_markers().main_view = main_view
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	main_view.state_stack.append(autofree(MainViewState.new()))
	Input.parse_input_event(_escape_event())
	await _settle()
	assert_eq(_state().get_pinned_zone_id(), ADVANCEMENT_DEMO_ID, "the overlay gets Esc; the pin stays")
	main_view.state_stack.clear()
	Input.parse_input_event(_escape_event())
	await _settle()
	assert_eq(_state().get_pinned_zone_id(), "", "with the overlay gone, Esc closes the popover")

func test_esc_leaves_the_popover_while_another_base_view_shows() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var main_view: MainView = _main_view_on_the_zone_view()
	main_view.base_current_state = autofree(MainViewState.new())
	_markers().main_view = main_view
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	Input.parse_input_event(_escape_event())
	await _settle()
	assert_eq(_state().get_pinned_zone_id(), ADVANCEMENT_DEMO_ID, "the zone view is not the active state")

func test_esc_closes_the_full_log_before_the_popover() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var main_view: MainView = _main_view_on_the_zone_view()
	var log_window: LogWindow = _log_with_full_log_open()
	main_view.log_window = log_window
	_markers().main_view = main_view
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	assert_true(log_window.is_full_log_open())
	Input.parse_input_event(_escape_event())
	await _settle()
	assert_false(log_window.is_full_log_open(), "the full log over the map closes first")
	assert_eq(_state().get_pinned_zone_id(), ADVANCEMENT_DEMO_ID, "the pin waits for the next Esc")

func test_click_outside_closes_pinned_popover() -> void:
	# A press anywhere in the window that the map does not take (a panel, the
	# dock) closes the popover at the end of the frame.
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	get_tree().root.window_input.emit(_left_press())
	assert_true(_popover().visible, "the press lands first")
	await _settle()
	assert_false(_popover().visible, "then the popover closes")

func test_click_inside_popover_keeps_it() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	get_tree().root.window_input.emit(_left_press())
	(_popover().get_node("%LockedCard") as Control).gui_input.emit(_left_press())
	await _settle()
	assert_true(_popover().visible, "a press on the popover keeps it open")

func test_click_on_another_hex_keeps_its_new_popover() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	get_tree().root.window_input.emit(_left_press())
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	await _settle()
	assert_true(_popover().visible, "the map took the press: the new popover stays")
	assert_eq(_popover().get_zone_data().zone_id, UNCHARTED_DEMO_ID)

func test_hiding_demo_zones_closes_their_popover() -> void:
	# Review Focus 5: no orphan popover, pin, hover or preview timer.
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	_map.click_zone(null)
	_hover_cell_of(UNCHARTED_DEMO_ID)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	ZoneManager.set_demo_zones_visible(false)
	assert_false(_popover().visible, "the popover closes with its zone")
	assert_eq(_state().get_pinned_zone_id(), "")
	assert_eq(_state().get_hovered_zone_id(), "", "the hover goes too")
	_run_out_preview_delay(_markers())
	assert_false(_popover().visible, "and no preview timer opens one later")

func test_save_reset_closes_popover() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_false(_popover().visible)
	assert_eq(_state().get_pinned_zone_id(), "")
