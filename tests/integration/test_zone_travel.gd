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

## The preview waits 150 ms; this is comfortably past it.
const PREVIEW_WAIT: float = 0.25

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
	# The project's hex layer overrides _ready() without super(), so the addon
	# sets up its conversions only when the shared TileSet emits `changed`.
	_map.tile_map.tile_set.emit_changed()
	await _settle()

func after_each() -> void:
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

## A third open zone east of Spirit Valley, in memory only, so a walk can be
## sent somewhere new halfway (Review Focus 2). Shown on the next map rebuild.
func _add_fixture_zone() -> void:
	_fixture_zone = ZoneData.new()
	_fixture_zone.zone_id = FIXTURE_ZONE_ID
	_fixture_zone.zone_name = "Fixture Ridge"
	_fixture_zone.tilemap_location = Vector2i(1, 0)
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
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
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
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	await wait_seconds(_map.camera_ease_duration + 0.1)
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(TEST_ZONE_ID)))
	assert_almost_eq(screen.x, 960.0, 0.5, "after a short ease the new zone sits at x 960")
	assert_almost_eq(screen.y, 702.0, 0.5, "and y 702")

func test_old_action_runs_during_walk() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_true(ActionManager.get_current_action() is TrainingActionData, "precondition: the Aura Well runs")
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.3)
	assert_true(_map.is_travelling(), "still walking 0.3 s in")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "the Aura Well keeps running mid-walk")
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_null(ActionManager.get_current_action(), "Test Zone has no idle action to resume")

func test_second_click_during_walk_retargets() -> void:
	_add_fixture_zone()
	_open_test_zone()
	EventManager.trigger_event(AURA_WELL_EVENT)
	watch_signals(ZoneManager)
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	_map.click_zone(_zone(FIXTURE_ZONE_ID))
	assert_true(_map.is_travelling(), "the walk turns toward the second zone")
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "the zone still has not changed")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "one action runs: the Aura Well")
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "the walk ends in the second zone")
	assert_signal_emit_count(ZoneManager, "zone_changed", 1, "one zone change, on the final arrival")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID))
	assert_null(ActionManager.get_current_action(), "the fixture zone has no idle action")

func test_click_current_during_walk_walks_home() -> void:
	_open_test_zone()
	EventManager.trigger_event(AURA_WELL_EVENT)
	watch_signals(ZoneManager)
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	_map.click_zone(_zone(SPIRIT_VALLEY_ID))
	await wait_for_signal(_map.character_body.movement_completed, 3.0)
	assert_false(_map.is_travelling())
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID)
	assert_signal_not_emitted(ZoneManager, "zone_changed", "turning back never changes the zone")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back at the valley's stand")
	assert_true(ActionManager.get_current_action() is TrainingActionData, "the Aura Well never stopped")

func test_session_action_during_walk_cancels_travel() -> void:
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_false(_map.is_travelling(), "cycling here stops the walk")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "the character is back in the valley")
	await wait_seconds(0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "no arrival in Test Zone")
	assert_eq(ActionManager.get_current_action().action_id, CYCLING_ID, "cycling still runs")

func test_save_reset_during_walk_cancels_travel() -> void:
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_false(_map.is_travelling(), "a save reset ends the walk")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID))
	await wait_seconds(0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "and nothing arrives later")

func test_outside_zone_change_during_walk_snaps_there() -> void:
	# A zone change the map did not make (a dev switch, a save reset) ends the
	# walk at once: the character, the camera and the map's own zone follow
	# the real current zone, and nothing arrives later.
	_add_fixture_zone()
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	ZoneManager.set_current_zone_by_id(FIXTURE_ZONE_ID)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.selected_zone, _zone(FIXTURE_ZONE_ID), "the map stands in the new zone")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID), "and so does the character")
	var screen: Vector2 = _to_screen(_map.get_zone_world_centre(_zone(FIXTURE_ZONE_ID)))
	assert_almost_eq(screen.x, 960.0, 0.5, "framed at once")
	assert_almost_eq(screen.y, 702.0, 0.5)
	await wait_seconds(0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "nothing arrives in Test Zone later")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID))

func test_outside_change_to_the_zone_you_left_ends_the_walk() -> void:
	# Even a zone change that names the zone the walk began in comes from
	# outside the map: the walk ends there.
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	ZoneManager.set_current_zone_by_id(SPIRIT_VALLEY_ID)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back on the valley's stand")
	await wait_seconds(0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, SPIRIT_VALLEY_ID, "nothing arrives in Test Zone later")

func test_save_reset_during_walk_ends_in_the_new_zone() -> void:
	_add_fixture_zone()
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	var save := SaveGameData.new()
	save.current_selected_zone_id = FIXTURE_ZONE_ID
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.selected_zone, ZoneManager.get_current_zone(), "the map follows the new save's zone")
	assert_eq(_map.character_body.position, _stand(FIXTURE_ZONE_ID), "the character stands there")
	await wait_seconds(0.6)
	assert_eq(ZoneManager.get_current_zone().zone_id, FIXTURE_ZONE_ID, "nothing arrives in Test Zone later")

func test_walk_ends_when_its_zone_leaves_the_map() -> void:
	# The dev toggle hides Test Zone mid-walk: the character goes back to the
	# valley instead of arriving in a zone the map no longer shows.
	_open_test_zone()
	_map.click_zone(_zone(TEST_ZONE_ID))
	await wait_seconds(0.2)
	ZoneManager.set_hidden_zones_visible(false)
	assert_false(_map.is_travelling(), "the walk ends")
	assert_eq(_map.character_body.position, _stand(SPIRIT_VALLEY_ID), "back on the valley's stand")
	await wait_seconds(0.6)
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
	glyph.shake()
	await wait_seconds(0.12)
	var icon: Control = glyph.get_node("%Icon") as Control
	assert_eq(icon.position.x, -8.0, "the padlock jumps 8 px left")
	assert_eq(glyph.position, glyph_position, "the glyph stays on its hex")
	await wait_seconds(0.4)
	assert_eq(icon.position.x, 0.0, "and settles back")
	assert_false(glyph.is_shaking())

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
	await wait_seconds(_map.camera_ease_duration + 0.1)
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
	await wait_seconds(PREVIEW_WAIT)
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
	await wait_seconds(0.05)
	_map.tile_map.tile_unhovered.emit()
	await wait_seconds(PREVIEW_WAIT)
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
	await wait_seconds(PREVIEW_WAIT)
	var markers: MapMarkers = map.get_map_markers()
	assert_true(markers.get_popover().visible, "precondition: the preview shows")
	host.mouse_exited.emit()
	assert_eq(markers.get_popover_state().get_hovered_zone_id(), "")
	assert_false(markers.get_popover().visible, "the preview goes with the pointer")
	assert_null((map.get_hex_overlay(ADVANCEMENT_DEMO_ID) as LockedZoneOverlay).get_rim_texture())

func test_no_preview_while_pinned() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(UNCHARTED_DEMO_ID))
	_hover_cell_of(ADVANCEMENT_DEMO_ID)
	await wait_seconds(PREVIEW_WAIT)
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
	await wait_seconds(PREVIEW_WAIT)
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
	await wait_seconds(PREVIEW_WAIT)
	assert_false(_popover().visible, "and no preview timer opens one later")

func test_save_reset_closes_popover() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_map.click_zone(_zone(ADVANCEMENT_DEMO_ID))
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	assert_false(_popover().visible)
	assert_eq(_state().get_pinned_zone_id(), "")
