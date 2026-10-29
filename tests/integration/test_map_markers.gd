extends GutTest

## The zone map's markers (Task 12 of the map-first zone view): a plate under
## each map zone with its state and status line, the action ring on the current
## zone's plate (the user's review, 2026-10-24), the lock and "?" glyphs over
## the veiled hexes, the routes between neighbouring zones, the floater that
## repeats the running idle action's ticks and hauls, and the layer hiding for
## the adventure's zoom. A dev toggle or a save reset leaves no orphan plate
## behind (Review Focus 5).

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"
const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const FORAGING_UNLOCK_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const CYCLING_ID: String = "wilderness_cycling_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
## One 60 FPS frame, for running the floater by hand.
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
	await _settle()

func after_each() -> void:
	# A test that held the action timer lets it go, or no later tick or haul
	# would ever come.
	ActionManager.action_timer.paused = false
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# Rebuilds queue the old plates and glyphs for deletion: let them go
	# before GUT counts orphans.
	await get_tree().process_frame

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The markers place themselves every frame: let two frames run.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## Takes the floater off the frame clock and runs `seconds` of it by hand in
## 60 FPS frames. Holds the action timer too: no real tick or haul pops it
## again.
func _advance_floater(seconds: float) -> void:
	ActionManager.action_timer.paused = true
	var floater: LacquerFloater = _markers().get_floater()
	floater.set_process(false)
	simulate(floater, roundi(seconds / FRAME), FRAME)

func _markers() -> MapMarkers:
	return _map.get_map_markers()

func _zone(zone_id: String) -> ZoneData:
	for zone: ZoneData in ZoneManager.get_map_zones():
		if zone.zone_id == zone_id:
			return zone
	return ZoneManager.get_zone_by_id(zone_id)

## Shows the hidden Test Zone and unlocks it, so it is an open hex.
func _open_test_zone() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)

#-----------------------------------------------------------------------------
# PLATES
#-----------------------------------------------------------------------------

func test_plate_per_map_zone() -> void:
	var ids: Array[String] = _markers().get_plate_zone_ids()
	assert_eq(ids.size(), 1, "one plate: Spirit Valley is the only map zone on a fresh save")
	assert_eq(ids[0], SPIRIT_VALLEY_ID)
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(plate.get_zone_data().zone_id, SPIRIT_VALLEY_ID)
	assert_eq(plate.get_state(), ZoneManager.ZoneMapState.CURRENT)
	assert_null(_markers().get_plate(TEST_ZONE_ID), "the hidden Test Zone has no plate")

func test_current_plate_ring_follows_action() -> void:
	var ring: MapActionRing = _markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring()
	assert_false(ring.visible, "nothing idle runs on a fresh save")
	EventManager.trigger_event(AURA_WELL_EVENT)
	ring = _markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring()
	assert_true(ring.visible, "the Aura Well shows the ring")
	assert_eq(ring.get_action().action_id, AURA_WELL_ID)
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	ring = _markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring()
	assert_eq(ring.get_action().action_id, FORAGING_ID, "foraging takes the ring over")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_false(_markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring().visible, "cycling is not an idle action")
	ActionManager.stop_action()

func test_open_plate_counts_activities() -> void:
	_open_test_zone()
	var test_plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	assert_not_null(test_plate, "an unlocked, shown Test Zone gets a plate")
	assert_eq(test_plate.get_state(), ZoneManager.ZoneMapState.OPEN)

	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	var valley: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(valley.get_state(), ZoneManager.ZoneMapState.OPEN, "seen from Test Zone, the valley is open")
	var count: int = ZoneManager.get_available_actions(SPIRIT_VALLEY_ID).size()
	assert_eq(valley.get_line_text(), ZoneMapLabel.open_line(count))

func test_plates_refresh_when_a_limited_action_completes() -> void:
	# ZoneManager.action_completed carries the action id. The dialogue's
	# completion count is bumped silently, so only that signal can update the
	# valley's activity count on its plate.
	_open_test_zone()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await _settle()
	var valley: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	var count_before: int = ZoneManager.get_available_actions(SPIRIT_VALLEY_ID).size()
	assert_eq(valley.get_line_text(), ZoneMapLabel.open_line(count_before))
	PersistenceManager.save_game_data.increment_zone_progression_for_action(TEST_ZONE_UNLOCK_ID, SPIRIT_VALLEY_ID, 1)
	var count_after: int = ZoneManager.get_available_actions(SPIRIT_VALLEY_ID).size()
	assert_eq(count_after, count_before - 1, "the completed dialogue leaves the valley's list")
	ZoneManager.action_completed.emit(TEST_ZONE_UNLOCK_ID)
	assert_eq(valley.get_line_text(), ZoneMapLabel.open_line(count_after), "the plate re-counts on action_completed")

func test_plate_press_emits_plate_pressed() -> void:
	var markers: MapMarkers = _markers()
	watch_signals(markers)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	markers.get_plate(SPIRIT_VALLEY_ID).gui_input.emit(click)
	assert_signal_emitted_with_parameters(markers, "plate_pressed", [_zone(SPIRIT_VALLEY_ID)])

#-----------------------------------------------------------------------------
# DEMO ZONES: PLATES AND GLYPHS
#-----------------------------------------------------------------------------

func test_demo_plates_and_glyphs() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var markers: MapMarkers = _markers()
	var locked: ZoneMapLabel = markers.get_plate(ADVANCEMENT_DEMO_ID)
	var uncharted: ZoneMapLabel = markers.get_plate(UNCHARTED_DEMO_ID)
	assert_eq(locked.get_state(), ZoneManager.ZoneMapState.LOCKED)
	assert_eq(locked.get_line_text(), "Tribulation Guardian")
	assert_eq(uncharted.get_state(), ZoneManager.ZoneMapState.UNCHARTED)
	assert_eq(uncharted.get_line_text(), "After the Tribulation")

	var lock_glyph: MapGlyph = markers.get_glyph(ADVANCEMENT_DEMO_ID) as MapGlyph
	var unknown_glyph: MapGlyph = markers.get_glyph(UNCHARTED_DEMO_ID) as MapGlyph
	assert_false(lock_glyph.has_twinkle())
	assert_true(unknown_glyph.has_twinkle(), "the ? twinkles")
	assert_null(markers.get_glyph(SPIRIT_VALLEY_ID), "a current or open zone has no glyph")

func test_hover_and_pin_survive_a_rebuild() -> void:
	ZoneManager.set_demo_zones_visible(true)
	_markers().set_pinned_zone(ADVANCEMENT_DEMO_ID)
	# Any unlock rebuilds the map and its plates.
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	assert_true(_markers().get_plate(ADVANCEMENT_DEMO_ID).is_pinned_frame_shown(), "the new plate keeps the pin")

func test_hiding_demo_zones_removes_their_plates() -> void:
	# Review Focus 5: the dev toggle leaves no orphan plate, glyph, route or pin.
	ZoneManager.set_demo_zones_visible(true)
	var markers: MapMarkers = _markers()
	markers.set_hovered_zone(UNCHARTED_DEMO_ID)
	markers.set_pinned_zone(ADVANCEMENT_DEMO_ID)
	ZoneManager.set_demo_zones_visible(false)
	assert_null(markers.get_plate(ADVANCEMENT_DEMO_ID))
	assert_null(markers.get_plate(UNCHARTED_DEMO_ID))
	assert_null(markers.get_glyph(ADVANCEMENT_DEMO_ID))
	assert_null(markers.get_glyph(UNCHARTED_DEMO_ID))
	assert_eq(markers.get_plate_zone_ids().size(), 1, "only Spirit Valley's plate is left in the layer")
	assert_eq(markers.get_pinned_zone_id(), "", "the pin goes with its zone")
	assert_eq(markers.get_hovered_zone_id(), "", "and so does the hover")
	assert_null(_map.get_route_to(ADVANCEMENT_DEMO_ID))
	assert_null(_map.get_route_to(UNCHARTED_DEMO_ID))

func test_rebuild_leaves_no_orphans() -> void:
	# The old plates and glyphs wait, hidden, in the layer until they are
	# freed at the end of the frame: none is ever an orphan, so tests that do
	# not await a frame count none (Review Focus 5).
	ZoneManager.set_demo_zones_visible(true)
	await _settle()
	var old_plate: ZoneMapLabel = _markers().get_plate(ADVANCEMENT_DEMO_ID)
	var orphans_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ZoneManager.set_demo_zones_visible(false)
	var orphans_after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "no plate or glyph left outside the tree")
	assert_false(old_plate.visible, "the old plate is hidden at once")
	assert_eq(_markers().get_plate_zone_ids(), [SPIRIT_VALLEY_ID] as Array[String], "and not counted")

func test_save_reset_rebuilds_plates_once() -> void:
	ZoneManager.set_demo_zones_visible(true)
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	await _settle()
	assert_eq(_markers().get_plate_zone_ids().size(), 3, "Spirit Valley and the two demo zones, no duplicates")

#-----------------------------------------------------------------------------
# ZOOM (Review Focus 3)
#-----------------------------------------------------------------------------

func test_overlapping_plates_hover_the_one_on_top() -> void:
	# Standing in Test Zone, its plate is drawn over the valley's, which
	# comes first in map order.
	_open_test_zone()
	# In memory only, put back before any assert: the current plate hugs its
	# name, so a long one makes it meet the valley's 248 px plate.
	var test_zone: ZoneData = _zone(TEST_ZONE_ID)
	var original_name: String = test_zone.zone_name
	test_zone.zone_name = "The Test Zone of the Long and Winding Name"
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	# At zoom 1.25 the hexes are 205 px apart.
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2(1.25, 1.25)
	_map.frame_zone(test_zone)
	await _settle()
	var valley_rect: Rect2 = _markers().get_plate(SPIRIT_VALLEY_ID).get_global_rect()
	var test_rect: Rect2 = _markers().get_plate(TEST_ZONE_ID).get_global_rect()
	var overlap: Rect2 = valley_rect.intersection(test_rect)
	var owner_id: String = _markers().get_plate_zone_id_at(overlap.get_center())
	test_zone.zone_name = original_name
	assert_true(overlap.has_area(), "precondition: at zoom 1.25 the two plates overlap")
	assert_eq(owner_id, TEST_ZONE_ID, "the point belongs to the plate drawn on top")

#-----------------------------------------------------------------------------
# ROUTES
#-----------------------------------------------------------------------------

func test_no_route_without_other_zones() -> void:
	assert_null(_map.get_route_to(SPIRIT_VALLEY_ID), "no route into the zone you stand in")
	assert_eq(_map.get_routes().size(), 0)

func test_routes_only_join_neighbours() -> void:
	# Kit §0: a route crosses one shared rim. From Test Zone the way to the
	# locked zone runs on from the valley instead of across it.
	_open_test_zone()
	ZoneManager.set_demo_zones_visible(true)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	var route: ZoneRoute = _map.get_route_to(ADVANCEMENT_DEMO_ID)
	assert_not_null(route)
	var valley_centre: Vector2 = _map.get_zone_world_centre(_zone(SPIRIT_VALLEY_ID)) - route.position
	var locked_centre: Vector2 = _map.get_zone_world_centre(_zone(ADVANCEMENT_DEMO_ID)) - route.position
	assert_eq(route.get_dot_positions(), ZoneRoute.dot_positions(valley_centre, locked_centre), "from the valley to the locked zone")
	assert_eq(_map.get_routes().size(), 3, "Test Zone - valley - locked - uncharted")
	for each_route: ZoneRoute in _map.get_routes():
		assert_eq(each_route.get_dot_positions().size(), 6, "six dots across one shared rim")

func test_routes_start_from_the_current_zone() -> void:
	_open_test_zone()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_null(_map.get_route_to(TEST_ZONE_ID), "no route into the zone you stand in")
	assert_not_null(_map.get_route_to(SPIRIT_VALLEY_ID), "a route back to the valley")

#-----------------------------------------------------------------------------
# ACTION RING AND FLOATERS
#-----------------------------------------------------------------------------

func test_only_the_current_plate_shows_a_ring() -> void:
	_open_test_zone()
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_true(_markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring().visible, "precondition: the valley's ring shows")
	assert_false(_markers().get_plate(TEST_ZONE_ID).get_action_ring().visible, "an open zone's plate has none")

func test_floater_on_training_tick() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var training: TrainingActionData = ActionManager.get_current_action() as TrainingActionData
	var floater: LacquerFloater = _markers().get_floater()
	assert_false(floater.visible, "no floater before the first tick")
	ActionManager.training_tick_processed.emit(training, 1)
	_advance_floater(0.5)
	await _settle()
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "+1.5 Madra")

func test_haul_floater_once_per_haul() -> void:
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	var forage: ForageActionData = ActionManager.get_current_action() as ForageActionData
	assert_not_null(forage, "precondition: foraging starts on unlock")
	var haul: Dictionary = {}
	var icons: Array[Texture2D] = []
	var quantity: int = 3
	for entry: LootTableEntry in forage.loot_table.entries:
		haul[entry.item] = quantity
		icons.append(entry.item.get_mini_icon())
		quantity += 1
	ActionManager.foraging_completed.emit(haul)
	var floater: LacquerFloater = _markers().get_floater()
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "+3  +4", "the counts, two spaces between items")
	assert_eq(floater.get_icons(), icons, "each count with its item's icon, not its name (the user's review, 2026-10-24)")
	_advance_floater(1.1)
	assert_false(floater.visible, "hidden outright after its 1 s rise")

func test_floater_stops_when_the_idle_action_changes() -> void:
	# The Aura Well's last "+1.5 Madra" must not rise over the foraging ring.
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	EventManager.trigger_event(AURA_WELL_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(AURA_WELL_ID))
	var training: TrainingActionData = ActionManager.get_current_action() as TrainingActionData
	assert_not_null(training, "precondition: the Aura Well runs")
	var floater: LacquerFloater = _markers().get_floater()
	ActionManager.training_tick_processed.emit(training, 1)
	assert_true(floater.visible, "precondition: its tick's floater rises")
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	assert_true(ActionManager.get_current_action() is ForageActionData, "precondition: foraging runs now")
	assert_true(_markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring().visible, "the ring shows foraging")
	assert_false(floater.visible, "the Aura Well's floater went with it")

func test_floater_keeps_rising_through_a_map_rebuild() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var floater: LacquerFloater = _markers().get_floater()
	ActionManager.training_tick_processed.emit(ActionManager.get_current_action() as TrainingActionData, 1)
	ZoneManager.set_demo_zones_visible(true)
	assert_true(floater.visible, "the same action still runs: its floater keeps rising")

func test_ring_and_floater_hide_when_the_idle_action_stops() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	ActionManager.training_tick_processed.emit(ActionManager.get_current_action() as TrainingActionData, 1)
	ActionManager.stop_action()
	assert_false(_markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring().visible)
	assert_false(_markers().get_floater().visible)

#-----------------------------------------------------------------------------
# ADVENTURE ZOOM
#-----------------------------------------------------------------------------

func test_layer_hides_for_the_adventure_zoom_and_returns_with_the_view() -> void:
	# The zone view hosts the map in a SubViewport; the view state hides and
	# shows that host when it exits and re-enters.
	var host := Control.new()
	var container := SubViewportContainer.new()
	var viewport := SubViewport.new()
	host.add_child(container)
	container.add_child(viewport)
	add_child_autofree(host)
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	viewport.add_child(map)
	await _settle()
	var markers: MapMarkers = map.get_map_markers()
	assert_true(markers.visible)
	ActionManager.adventure_start_requested.emit(ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData)
	assert_false(markers.visible, "hidden while the camera zooms into the adventure")
	host.hide()
	assert_false(markers.visible)
	host.show()
	assert_true(markers.visible, "shown again when the zone view comes back")

func test_layer_waits_for_the_camera_to_zoom_back_out() -> void:
	# ZoneTransition leaves the camera at zoom 3 and eases it back over 0.3 s
	# once the zone view returns: the markers would shrink with it, so the
	# layer shows only when the camera is back at its resting zoom.
	var host := Control.new()
	var container := SubViewportContainer.new()
	var viewport := SubViewport.new()
	host.add_child(container)
	container.add_child(viewport)
	add_child_autofree(host)
	var map: ZoneTilemap = ZoneTilemapScene.instantiate()
	viewport.add_child(map)
	await _settle()
	var markers: MapMarkers = map.get_map_markers()
	var camera: Camera2D = map.get_camera()
	var resting_zoom: Vector2 = camera.zoom
	ActionManager.adventure_start_requested.emit(ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData)
	camera.zoom = Vector2(3.0, 3.0)
	host.hide()
	host.show()
	await _settle()
	assert_false(markers.visible, "still hidden while the camera is zoomed in")
	camera.zoom = Vector2(2.5, 2.5)
	await _settle()
	assert_false(markers.visible, "and while it eases back")
	camera.zoom = resting_zoom
	await _settle()
	assert_true(markers.visible, "shown once the camera is back")
