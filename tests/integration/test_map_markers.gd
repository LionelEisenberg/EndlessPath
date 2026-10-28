extends GutTest

## The zone map's markers (Task 12 of the map-first zone view): a plate under
## each map zone with its name and status line, the action ring on the current
## zone's plate (the user's review, 2026-10-24), the lock and "?" glyphs over
## the veiled hexes, the dotted routes between zones, and the floater that
## repeats the running idle action's ticks and hauls. Positions are the
## lacquer kit's screen px at zoom 2 (kit §0, §6.3-6.5, §6.7); away from zoom
## 2 the markers keep to their hexes (Review Focus 3), and a dev toggle or a
## save reset leaves no orphan plate behind (Review Focus 5).

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")
const ZoneRouteScene: PackedScene = preload("res://scenes/zones/zone_route/zone_route.tscn")
const ZoneMapLabelScene: PackedScene = preload("res://scenes/zones/map_markers/zone_map_label/zone_map_label.tscn")

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

## The plate's status line slot, in the plate's own px (kit §6.5), 4 px in
## from the side rivets at x 6 and 242.
const LINE_LEFT: float = 10.0
const LINE_RIGHT: float = 238.0

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
## 60 FPS frames. The markers place it each frame before it moves on, so on the
## frame clock the rise it reports can be a 2 px step past the one it was
## placed with. Holds the action timer too: no real tick or haul pops it again.
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

## The screen top-left of each dot of the route into the zone, with the map
## camera as it is now.
func _route_screen_dots(zone_id: String) -> Array[Vector2]:
	var camera: Camera2D = _map.get_camera()
	var route: ZoneRoute = _map.get_route_to(zone_id)
	var dots: Array[Vector2] = []
	for dot: Vector2 in route.get_dot_positions():
		dots.append(ZoneMapMath.world_to_screen(route.position + dot, camera.position, camera.zoom.x))
	return dots

## The control's rect in the plate's own px (the plate is at scale 1).
func _rect_in_plate(plate: ZoneMapLabel, control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	rect.position -= plate.global_position
	return rect

## The width the label's whole text needs, untrimmed.
func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x

## The width of a plate that hugs its name: the name plus `padding`, on the
## 2 px grid.
func _hug_width(plate: ZoneMapLabel, padding: float) -> float:
	var width: float = ceilf(_text_width(plate.get_node("%NameLabel") as Label)) + padding
	return width + fposmod(width, 2.0)

## Asserts the floater rises from the left of the zone's plate: its token
## ends 8 px left of the ring (of the plate while no ring shows), centred on
## the plate's 52 px height before its rise.
func _assert_floater_beside_plate(zone_id: String, context: String) -> void:
	var plate: ZoneMapLabel = _markers().get_plate(zone_id)
	var ring: MapActionRing = plate.get_action_ring()
	var floater: LacquerFloater = _markers().get_floater()
	var plate_left: float = plate.position.x + (ring.position.x if ring.visible else 0.0)
	assert_eq(floater.position.x + floater.get_token_width(), plate_left - 8.0, "%s: the token ends 8 px left of the plate's ring" % context)
	assert_eq(floater.position.y + floater.get_rise(), plate.position.y + 12.0, "%s: centred on the plate's height, then rising" % context)

## The screen centre of the zone's hex with the map camera as it is now.
func _hex_centre(zone_id: String) -> Vector2:
	var camera: Camera2D = _map.get_camera()
	return ZoneMapMath.world_to_screen(_map.get_zone_world_centre(_zone(zone_id)), camera.position, camera.zoom.x)

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

func test_current_plate_sits_under_its_hex() -> void:
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(plate.size, Vector2(_hug_width(plate, 32.0), 52), "no status line: the plate hugs its name, 16 px a side")
	assert_eq(plate.position.x + plate.size.x / 2.0, 960.0, "kit §6.5: centred under the valley's hex")
	assert_eq(plate.position.y, 800.0, "its top 98 px under the hex centre")
	assert_eq(plate.scale, Vector2.ONE, "shown at file size at zoom 2")
	assert_string_contains(plate.get_plate_texture().resource_path, "lacquer_plate_current_ai")

func test_current_plate_has_no_status_line() -> void:
	# The user's review (2026-10-24): the ring is the running action on the
	# map; its "Aura Well · +1.5 Madra / s" line went (the cabinet and the Now
	# strip show the rate).
	assert_eq(_markers().get_plate(SPIRIT_VALLEY_ID).get_line_text(), "", "nothing runs on a fresh save")
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_true(ActionManager.get_current_action() is TrainingActionData, "precondition: the Aura Well runs")
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(plate.get_line_text(), "", "the Aura Well adds no line")
	assert_false(plate.is_line_shown())
	assert_false((plate.get_node("%LineArea") as Control).visible)

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

func test_ring_sits_on_the_plates_left_end() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _settle()
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	var ring: MapActionRing = plate.get_action_ring()
	var name_label: Label = plate.get_node("%NameLabel") as Label
	var ring_rect: Rect2 = _rect_in_plate(plate, ring)
	assert_eq(ring_rect, Rect2(-22, -6, 64, 64), "hanging off the left end, centred on the plate's 52 px height")
	assert_eq(plate.size, Vector2(_hug_width(plate, 48.0 + 24.0), 52), "the ring's room, the name and 24 px")
	assert_eq(plate.position.x + plate.size.x / 2.0, 960.0, "still centred under its hex")
	var name_rect: Rect2 = _rect_in_plate(plate, name_label)
	var name_left: float = name_rect.position.x + (name_rect.size.x - _text_width(name_label)) / 2.0
	assert_almost_eq(name_left, 48.0, 1.0, "the name starts 6 px past the ring")
	assert_almost_eq(name_left + _text_width(name_label), plate.size.x - 24.0, 1.0, "and ends 24 px before the right edge, well clear of the rivet")
	assert_false(plate.get_line_text().contains("·"), "no status line beside it")

func test_ring_stays_on_a_name_only_plate() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_true(plate.get_action_ring().is_visible_in_tree(), "zoomed out, the ring stays")
	assert_eq(plate.size, Vector2(_hug_width(plate, 48.0 + 24.0), 52), "with the same room")

func test_current_plate_name_brightens_on_hover() -> void:
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(plate.get_name_color(), ThemeConstants.LACQUER_BRASS, "the current zone's name is brass")
	_markers().set_hovered_zone(SPIRIT_VALLEY_ID)
	assert_eq(plate.get_name_color(), ThemeConstants.LACQUER_CREAM, "hovering turns it cream")
	assert_string_contains(plate.get_plate_texture().resource_path, "lacquer_plate_current_hover_ai")
	_markers().set_hovered_zone("")
	assert_eq(plate.get_name_color(), ThemeConstants.LACQUER_BRASS)

func test_open_line_counts_activities() -> void:
	assert_eq(ZoneMapLabel.open_line(0), "Open · nothing to do yet")
	assert_eq(ZoneMapLabel.open_line(1), "Open · 1 activity")
	assert_eq(ZoneMapLabel.open_line(5), "Open · 5 activities")

func test_open_plate_counts_activities() -> void:
	_open_test_zone()
	var test_plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	assert_not_null(test_plate, "an unlocked, shown Test Zone gets a plate")
	assert_eq(test_plate.get_state(), ZoneManager.ZoneMapState.OPEN)
	assert_eq(test_plate.get_line_text(), "Open · nothing to do yet", "Test Zone has no activities (kit §6.5)")
	assert_eq(test_plate.position, Vector2(508, 800), "kit §6.5: Test Zone's plate top-left")

	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	var valley: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	assert_eq(valley.get_state(), ZoneManager.ZoneMapState.OPEN, "seen from Test Zone, the valley is open")
	var count: int = ZoneManager.get_available_actions(SPIRIT_VALLEY_ID).size()
	assert_eq(valley.get_line_text(), ZoneMapLabel.open_line(count))
	assert_eq(valley.get_line_color(), ThemeConstants.LACQUER_TAN)

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

func test_open_plate_reads_click_to_travel_on_hover() -> void:
	_open_test_zone()
	var plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	_markers().set_hovered_zone(TEST_ZONE_ID)
	assert_eq(plate.get_line_text(), "Click to travel")
	assert_eq(plate.get_line_color(), ThemeConstants.LACQUER_BRASS, "in brass")
	var name_part: Label = plate.get_node_or_null("%LineName") as Label
	assert_not_null(name_part, "the line's text is a Label of its own")
	if name_part != null:
		assert_eq(name_part.get_theme_color("font_color"), ThemeConstants.LACQUER_BRASS, "drawn in brass")
	assert_string_contains(plate.get_plate_texture().resource_path, "lacquer_plate_open_hover_ai")
	_markers().set_hovered_zone("")
	assert_eq(plate.get_line_text(), "Open · nothing to do yet")

func test_plate_press_emits_plate_pressed() -> void:
	var markers: MapMarkers = _markers()
	watch_signals(markers)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	markers.get_plate(SPIRIT_VALLEY_ID).gui_input.emit(click)
	assert_signal_emitted_with_parameters(markers, "plate_pressed", [_zone(SPIRIT_VALLEY_ID)])

func test_long_zone_name_stays_on_the_plate() -> void:
	# Review Focus 4: a long name ellipsizes inside the plate.
	var plate: ZoneMapLabel = ZoneMapLabelScene.instantiate()
	add_child_autofree(plate)
	var zone := ZoneData.new()
	zone.zone_id = "LongZone"
	zone.zone_name = "The Exceedingly Long and Winding Valley of a Thousand Whispering Names"
	zone.blocker_short_text = "Defeat every guardian of every peak of every mountain in the far north"
	plate.setup(zone, ZoneManager.ZoneMapState.LOCKED)
	await _settle()
	assert_eq(plate.size, Vector2(248, 52), "the plate never widens")
	var name_label: Label = plate.get_node("%NameLabel") as Label
	assert_lte(name_label.position.x + name_label.size.x, 248.0, "the name stays inside the plate")
	assert_ne(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "and ellipsizes")

func test_long_zone_name_beside_the_ring_stays_on_the_plate() -> void:
	# Review Focus 4: beside the ring a long name ellipsizes, and the plate
	# stops at the kit's 248 px.
	EventManager.trigger_event(AURA_WELL_EVENT)
	var plate: ZoneMapLabel = ZoneMapLabelScene.instantiate()
	add_child_autofree(plate)
	var zone := ZoneData.new()
	zone.zone_id = "LongCurrentZone"
	zone.zone_name = "The Exceedingly Long and Winding Valley of a Thousand Whispering Names"
	plate.setup(zone, ZoneManager.ZoneMapState.CURRENT)
	await _settle()
	var name_label: Label = plate.get_node("%NameLabel") as Label
	assert_true(plate.get_action_ring().visible, "precondition: the ring shows")
	assert_eq(plate.size, Vector2(248, 52), "the plate never widens past the kit's")
	assert_gte(name_label.position.x, 48.0, "the name starts past the ring")
	assert_lte(name_label.position.x + name_label.size.x, 248.0 - 6.0, "and stays inside the plate")
	assert_ne(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "and ellipsizes")

func test_long_blocker_ellipsizes_inside_the_plate() -> void:
	# Review Focus 4: a locked plate's long blocker ellipsizes after its icon.
	var plate: ZoneMapLabel = ZoneMapLabelScene.instantiate()
	add_child_autofree(plate)
	var zone := ZoneData.new()
	zone.zone_id = "LongBlocker"
	zone.zone_name = "Far North"
	zone.blocker_short_text = "Tribulation Guardian of the Far North and of Every Peak Beyond"
	plate.setup(zone, ZoneManager.ZoneMapState.LOCKED)
	await _settle()
	var name_part: Label = plate.get_node("%LineName") as Label
	var icon: Control = plate.get_node("%LineIcon") as Control
	assert_eq(name_part.text, zone.blocker_short_text, "the Label holds the whole blocker and trims it")
	assert_lt(_rect_in_plate(plate, name_part).size.x, _text_width(name_part), "cut short")
	assert_lte(_rect_in_plate(plate, name_part).end.x, LINE_RIGHT, "inside the slot")
	assert_true(icon.is_visible_in_tree(), "the swords stay")
	assert_gte(_rect_in_plate(plate, icon).position.x, LINE_LEFT)

func test_status_line_is_centred_as_a_group() -> void:
	# Kit §6.5: icon and text centred together; a short blocker is not cut.
	ZoneManager.set_demo_zones_visible(true)
	await _settle()
	var plate: ZoneMapLabel = _markers().get_plate(ADVANCEMENT_DEMO_ID)
	var name_part: Label = plate.get_node("%LineName") as Label
	var icon: Control = plate.get_node("%LineIcon") as Control
	assert_eq(name_part.text, "Tribulation Guardian")
	assert_gte(_rect_in_plate(plate, name_part).size.x, _text_width(name_part), "a short line is whole")
	var left_gap: float = _rect_in_plate(plate, icon).position.x - LINE_LEFT
	var right_gap: float = LINE_RIGHT - _rect_in_plate(plate, name_part).end.x
	assert_almost_eq(left_gap, right_gap, 1.0, "centred as a group")
	assert_eq(_rect_in_plate(plate, name_part).position.x - _rect_in_plate(plate, icon).end.x, 6.0, "the icon 6 px before the text")
	assert_eq(name_part.get_theme_color("font_color"), ThemeConstants.LACQUER_CREAM, "the line is cream")

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
	assert_string_contains(locked.get_plate_texture().resource_path, "lacquer_plate_locked_ai")
	assert_eq(uncharted.get_state(), ZoneManager.ZoneMapState.UNCHARTED)
	assert_eq(uncharted.get_line_text(), "After the Tribulation")
	assert_eq(uncharted.get_name_color(), ThemeConstants.LACQUER_TAN, "the uncharted name is tan")

	var lock_glyph: MapGlyph = markers.get_glyph(ADVANCEMENT_DEMO_ID) as MapGlyph
	var unknown_glyph: MapGlyph = markers.get_glyph(UNCHARTED_DEMO_ID) as MapGlyph
	assert_string_contains(lock_glyph.get_texture().resource_path, "lacquer_glyph_lock_ai")
	assert_false(lock_glyph.has_twinkle())
	assert_string_contains(unknown_glyph.get_texture().resource_path, "lacquer_glyph_unknown_ai")
	assert_true(unknown_glyph.has_twinkle(), "the ? twinkles")
	assert_null(markers.get_glyph(SPIRIT_VALLEY_ID), "a current or open zone has no glyph")

func test_demo_markers_sit_at_kit_positions() -> void:
	ZoneManager.set_demo_zones_visible(true)
	await _settle()
	var markers: MapMarkers = _markers()
	assert_eq(markers.get_plate(ADVANCEMENT_DEMO_ID).position, Vector2(1000, 428), "kit §6.5")
	assert_eq(markers.get_plate(UNCHARTED_DEMO_ID).position, Vector2(836, 150), "kit §6.5")
	assert_eq(markers.get_glyph(ADVANCEMENT_DEMO_ID).position, Vector2(1102, 356), "kit §6.4")
	assert_eq(markers.get_glyph(UNCHARTED_DEMO_ID).position, Vector2(946, 92), "kit §6.4")
	var twinkle: Control = markers.get_glyph(UNCHARTED_DEMO_ID).get_node("%Twinkle") as Control
	assert_eq(twinkle.global_position, Vector2(972, 84), "kit §0: the twinkle beside the ?")

func test_veiled_plates_hover_and_pin() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var markers: MapMarkers = _markers()
	var locked: ZoneMapLabel = markers.get_plate(ADVANCEMENT_DEMO_ID)
	var uncharted: ZoneMapLabel = markers.get_plate(UNCHARTED_DEMO_ID)
	markers.set_hovered_zone(ADVANCEMENT_DEMO_ID)
	assert_string_contains(locked.get_plate_texture().resource_path, "lacquer_plate_locked_hover_ai")
	markers.set_hovered_zone(UNCHARTED_DEMO_ID)
	assert_string_contains(locked.get_plate_texture().resource_path, "lacquer_plate_locked_ai", "one hover at a time")
	assert_string_contains(uncharted.get_plate_texture().resource_path, "lacquer_plate_uncharted_hover_ai")
	assert_eq(uncharted.get_name_color(), ThemeConstants.LACQUER_CREAM, "the uncharted name brightens on hover")
	assert_eq(markers.get_hovered_zone_id(), UNCHARTED_DEMO_ID)

	assert_false(locked.is_pinned_frame_shown())
	markers.set_pinned_zone(ADVANCEMENT_DEMO_ID)
	assert_true(locked.is_pinned_frame_shown(), "a pinned plate gets the brass frame")
	markers.set_pinned_zone(UNCHARTED_DEMO_ID)
	assert_false(locked.is_pinned_frame_shown(), "one pin at a time")
	assert_true(uncharted.is_pinned_frame_shown())
	markers.set_pinned_zone("")
	assert_false(uncharted.is_pinned_frame_shown())

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

func test_plate_keeps_its_size_at_zoom_one() -> void:
	# The 13 px text floor: a plate is drawn at its kit size at every zoom;
	# only where it hangs follows the hex.
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	var centre: Vector2 = ZoneMapMath.world_to_screen(Vector2.ZERO, camera.position, 1.0)
	assert_eq(plate.scale, Vector2.ONE, "the plate never shrinks")
	assert_eq(plate.position.y, roundf(centre.y + 49.0), "its top 98 px under the hex centre at zoom 2, 49 at zoom 1")
	assert_eq(plate.position.x + plate.size.x / 2.0, roundf(centre.x), "centred under its hex")

func test_glyphs_follow_hexes_when_panned_to_the_clamp_edge() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2(1.5, 1.5)
	camera.position = _map.get_camera_bounds().position
	await _settle()
	var lock_centre: Vector2 = ZoneMapMath.world_to_screen(_map.get_zone_world_centre(_zone(ADVANCEMENT_DEMO_ID)), camera.position, 1.5)
	var glyph: Control = _markers().get_glyph(ADVANCEMENT_DEMO_ID)
	assert_eq(glyph.scale, Vector2.ONE, "the glyph keeps its size")
	# The 44x52 padlock's centre sits 35 px above the hex centre at zoom 2.
	assert_almost_eq(glyph.position.x, lock_centre.x - 22.0, 1.0, "centred on its hex")
	assert_almost_eq(glyph.position.y, lock_centre.y - 35.0 * 0.75 - 26.0, 1.0, "its centre's height above the hex scales with the hex")

func test_floater_keeps_its_size_at_zoom_one() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	ActionManager.training_tick_processed.emit(ActionManager.get_current_action() as TrainingActionData, 1)
	_advance_floater(0.5)
	await _settle()
	var floater: LacquerFloater = _markers().get_floater()
	assert_eq(floater.get_rise(), 20, "precondition: halfway up its 40 px rise")
	assert_eq(floater.scale, Vector2.ONE, "the floater keeps its size")
	_assert_floater_beside_plate(SPIRIT_VALLEY_ID, "zoom 1")
	assert_eq(_markers().get_plate(SPIRIT_VALLEY_ID).get_action_ring().scale, Vector2.ONE, "the ring on the plate keeps its size")

func test_floater_rises_beside_the_current_plate_at_every_zoom() -> void:
	# The user's review (2026-10-24): the gain rises from the left of the
	# plate whose ring just ticked, at every zoom.
	EventManager.trigger_event(AURA_WELL_EVENT)
	var camera: Camera2D = _map.get_camera()
	var floater: LacquerFloater = _markers().get_floater()
	ActionManager.training_tick_processed.emit(ActionManager.get_current_action() as TrainingActionData, 1)
	_advance_floater(0.5)
	for zoom: float in [1.0, 1.1, 1.25, 1.5, 2.0]:
		camera.zoom = Vector2(zoom, zoom)
		_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
		await _settle()
		_assert_floater_beside_plate(SPIRIT_VALLEY_ID, "zoom %s" % zoom)
		var plate: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
		var plate_rect := Rect2(plate.position + plate.get_action_ring().position, plate.size - plate.get_action_ring().position)
		assert_false(floater.get_rect().intersects(plate_rect), "zoom %s: the token never covers the plate or its ring" % zoom)

func test_current_plate_draws_above_its_neighbours() -> void:
	# Kit-size plates overlap their row neighbours below zoom 1.5 (164 px
	# apart at zoom 1, 248 wide): the zone you stand in always reads whole.
	_open_test_zone()
	var valley: ZoneMapLabel = _markers().get_plate(SPIRIT_VALLEY_ID)
	var test_plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	assert_gt(valley.get_index(), test_plate.get_index(), "Spirit Valley's plate is drawn over Test Zone's")
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	valley = _markers().get_plate(SPIRIT_VALLEY_ID)
	test_plate = _markers().get_plate(TEST_ZONE_ID)
	assert_gt(test_plate.get_index(), valley.get_index(), "standing in Test Zone, its plate is on top")
	assert_eq(_markers().get_plate_zone_ids(), [SPIRIT_VALLEY_ID, TEST_ZONE_ID] as Array[String], "still listed in map order")

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

func test_plate_shows_name_only_below_zoom_1_25() -> void:
	# Spec, Open / deferred: plates are reduced to the name below zoom 1.25.
	_open_test_zone()
	var camera: Camera2D = _map.get_camera()
	var plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	var line_area: Control = plate.get_node("%LineArea") as Control
	camera.zoom = Vector2(1.25, 1.25)
	await _settle()
	assert_true(plate.is_line_shown(), "at 1.25 the status line still shows")
	assert_true(line_area.visible)
	camera.zoom = Vector2(1.2, 1.2)
	await _settle()
	assert_false(plate.is_line_shown(), "below 1.25 the plate shows its name only")
	assert_false(line_area.visible)
	assert_eq(plate.get_line_text(), "Open · nothing to do yet", "the status is kept for when the map zooms back in")
	camera.zoom = Vector2(2.0, 2.0)
	await _settle()
	assert_true(plate.is_line_shown(), "zoomed back in, the line returns")
	assert_true(line_area.visible)

func test_name_only_plate_hugs_its_name() -> void:
	# Below zoom 1.25 a plate is the name plus 16 px a side (even), centred on
	# its hex, so row neighbours 164 px apart at zoom 1 no longer overlap.
	_open_test_zone()
	var camera: Camera2D = _map.get_camera()
	var plate: ZoneMapLabel = _markers().get_plate(TEST_ZONE_ID)
	var name_label: Label = plate.get_node("%NameLabel") as Label
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	assert_eq(plate.size.x, _hug_width(plate, 32.0), "the name plus 32, on the 2 px grid")
	assert_eq(plate.position.x + plate.size.x / 2.0, roundf(_hex_centre(TEST_ZONE_ID).x), "centred on its hex")
	var name_rect: Rect2 = _rect_in_plate(plate, name_label)
	assert_gte(name_rect.position.x, 6.0, "the name clears the left rivet")
	assert_lte(name_rect.end.x, plate.size.x - 6.0, "and the right one")
	assert_eq(plate.get_node("%PlateTexture").size, plate.size + Vector2(2, 2), "the plate texture follows, with its 2 px shadow")
	camera.zoom = Vector2(2.0, 2.0)
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	assert_eq(plate.size, Vector2(248, 52), "back at kit size with the status line")
	assert_eq(plate.position, Vector2(508, 800), "kit §6.5")

func test_row_neighbour_plates_do_not_overlap_at_zoom_one() -> void:
	_open_test_zone()
	var camera: Camera2D = _map.get_camera()
	camera.zoom = Vector2.ONE
	_map.frame_zone(_zone(SPIRIT_VALLEY_ID))
	await _settle()
	var valley_rect: Rect2 = _markers().get_plate(SPIRIT_VALLEY_ID).get_global_rect()
	var test_rect: Rect2 = _markers().get_plate(TEST_ZONE_ID).get_global_rect()
	assert_false(valley_rect.intersects(test_rect), "Test Zone's plate %s clears Spirit Valley's %s" % [test_rect, valley_rect])

#-----------------------------------------------------------------------------
# ROUTES
#-----------------------------------------------------------------------------

func test_route_lit_toggles() -> void:
	var route: ZoneRoute = ZoneRouteScene.instantiate()
	add_child_autofree(route)
	route.set_points(Vector2.ZERO, Vector2(-164, 0))
	assert_eq(route.get_dot_positions().size(), 6, "six dots across the shared rim")
	assert_false(route.is_lit())
	assert_string_contains(route.get_dot_texture().resource_path, "lacquer_route_dot_ai")
	route.set_lit(true)
	assert_true(route.is_lit())
	assert_string_contains(route.get_dot_texture().resource_path, "lacquer_route_dot_lit_ai")
	route.set_lit(false)
	assert_string_contains(route.get_dot_texture().resource_path, "lacquer_route_dot_ai")

func test_no_route_without_other_zones() -> void:
	assert_null(_map.get_route_to(SPIRIT_VALLEY_ID), "no route into the zone you stand in")
	assert_eq(_map.get_routes().size(), 0)

func test_west_route_matches_the_kit() -> void:
	_open_test_zone()
	var expected: Array[Vector2] = [Vector2(852, 698), Vector2(828, 698), Vector2(804, 698), Vector2(780, 698), Vector2(756, 698), Vector2(732, 698)]
	assert_eq(_route_screen_dots(TEST_ZONE_ID), expected, "kit §0: six dots from the valley toward Test Zone")

func test_north_route_matches_the_kit() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var to_locked: Array[Vector2] = [Vector2(1008, 608), Vector2(1020, 586), Vector2(1032, 566), Vector2(1044, 546), Vector2(1056, 524), Vector2(1068, 504)]
	var to_uncharted: Array[Vector2] = [Vector2(1068, 322), Vector2(1056, 302), Vector2(1044, 280), Vector2(1032, 260), Vector2(1020, 240), Vector2(1008, 218)]
	assert_eq(_route_screen_dots(ADVANCEMENT_DEMO_ID), to_locked, "kit §0: the valley to the locked zone")
	assert_eq(_route_screen_dots(UNCHARTED_DEMO_ID), to_uncharted, "and on to the uncharted hex beyond it")
	assert_false(_map.get_route_to(ADVANCEMENT_DEMO_ID).is_lit(), "routes start unlit")

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

func test_ring_frame_steps() -> void:
	assert_eq(MapActionRing.frame_for(0.0), 0)
	assert_eq(MapActionRing.frame_for(0.5), 6)
	assert_eq(MapActionRing.frame_for(0.99), 12)
	assert_eq(MapActionRing.frame_for(1.0), 12, "never past the last frame")

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
	assert_eq(floater.get_color(), ThemeConstants.LACQUER_MADRA, "in Madra blue")
	assert_gt(floater.get_token_width(), 28 + 40, "the token is as wide as its text plus 28")
	assert_eq(floater.get_token_width() % 2, 0, "on the 2 px grid")
	_assert_floater_beside_plate(SPIRIT_VALLEY_ID, "zoom 2")

func test_floater_rises_in_two_px_steps() -> void:
	assert_eq(LacquerFloater.rise_at(0.0), 0)
	assert_eq(LacquerFloater.rise_at(0.05), 2)
	assert_eq(LacquerFloater.rise_at(0.51), 20)
	assert_eq(LacquerFloater.rise_at(0.99), 38)
	assert_eq(LacquerFloater.rise_at(1.0), 40)

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
	assert_eq(floater.get_color(), ThemeConstants.LACQUER_CREAM, "in cream")
	_assert_floater_beside_plate(SPIRIT_VALLEY_ID, "a haul")
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
# GLYPH TWINKLE
#-----------------------------------------------------------------------------

func test_twinkle_frames() -> void:
	assert_eq(MapGlyph.twinkle_frame(0.0), 0, "frame 0 is empty")
	assert_eq(MapGlyph.twinkle_frame(3.5), 0)
	assert_eq(MapGlyph.twinkle_frame(3.65), 1, "every 4 s: frame 1 for 0.1 s")
	assert_eq(MapGlyph.twinkle_frame(3.8), 2, "frame 2 for 0.2 s")
	assert_eq(MapGlyph.twinkle_frame(3.95), 1, "frame 1 for 0.1 s")
	assert_eq(MapGlyph.twinkle_frame(4.0), 0)
	assert_eq(MapGlyph.twinkle_frame(7.65), 1, "and again")

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
