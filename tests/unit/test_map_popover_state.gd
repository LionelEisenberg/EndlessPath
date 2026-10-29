extends GutTest

## The map popover's state (Task 13 of the map-first zone view, spec: Map
## interaction): what a click on a hex does, which zone's popover is pinned,
## and the hover preview that waits for MapMarkers' 150 ms timer. Only one
## popover is open at a time.

const VALLEY_ID: String = "SpiritValley"
const OPEN_ID: String = "TestZone"
const LOCKED_ID: String = "AdvancementZoneDemo"
const UNCHARTED_ID: String = "UnchartedZoneDemo"

var _state: MapPopoverState

func before_each() -> void:
	_state = MapPopoverState.new()

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

## What a click does and which popover is pinned after it, from nothing pinned
## or with the locked zone's popover pinned: an open zone you are not in
## travels and the zone you are in recentres, both closing any popover; a
## locked or uncharted zone pins its own (never travels), replacing any other,
## and a second click keeps it pinned (the lock shakes again); fog ("") closes.
func test_click_results() -> void:
	var cases: Array[Dictionary] = [
		{"name": "open", "zone_id": OPEN_ID, "state": ZoneManager.ZoneMapState.OPEN, "pinned_first": false,
			"result": MapPopoverState.ClickResult.TRAVEL, "pinned": ""},
		{"name": "open, over a pinned popover", "zone_id": OPEN_ID, "state": ZoneManager.ZoneMapState.OPEN, "pinned_first": true,
			"result": MapPopoverState.ClickResult.TRAVEL, "pinned": ""},
		{"name": "locked", "zone_id": LOCKED_ID, "state": ZoneManager.ZoneMapState.LOCKED, "pinned_first": false,
			"result": MapPopoverState.ClickResult.PIN, "pinned": LOCKED_ID},
		{"name": "locked, already pinned", "zone_id": LOCKED_ID, "state": ZoneManager.ZoneMapState.LOCKED, "pinned_first": true,
			"result": MapPopoverState.ClickResult.PIN, "pinned": LOCKED_ID},
		{"name": "uncharted", "zone_id": UNCHARTED_ID, "state": ZoneManager.ZoneMapState.UNCHARTED, "pinned_first": false,
			"result": MapPopoverState.ClickResult.PIN, "pinned": UNCHARTED_ID},
		{"name": "uncharted, over another pinned popover", "zone_id": UNCHARTED_ID, "state": ZoneManager.ZoneMapState.UNCHARTED, "pinned_first": true,
			"result": MapPopoverState.ClickResult.PIN, "pinned": UNCHARTED_ID},
		{"name": "current, over a pinned popover", "zone_id": VALLEY_ID, "state": ZoneManager.ZoneMapState.CURRENT, "pinned_first": true,
			"result": MapPopoverState.ClickResult.RECENTRE, "pinned": ""},
		{"name": "fog, over a pinned popover", "zone_id": "", "state": ZoneManager.ZoneMapState.OPEN, "pinned_first": true,
			"result": MapPopoverState.ClickResult.CLOSE, "pinned": ""},
	]
	for case: Dictionary in cases:
		var state := MapPopoverState.new()
		if case.pinned_first:
			state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
		assert_eq(state.click(case.zone_id, case.state), case.result, "%s: result" % case.name)
		assert_eq(state.get_pinned_zone_id(), case.pinned, "%s: pinned" % case.name)

func test_close_unpins() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.close()
	assert_eq(_state.get_pinned_zone_id(), "")

#-----------------------------------------------------------------------------
# HOVER AND PREVIEW
#-----------------------------------------------------------------------------

func test_hover_tracks_the_zone() -> void:
	_state.hover(OPEN_ID, ZoneManager.ZoneMapState.OPEN)
	assert_eq(_state.get_hovered_zone_id(), OPEN_ID)
	_state.unhover()
	assert_eq(_state.get_hovered_zone_id(), "")

func test_preview_requires_show_preview() -> void:
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_eq(_state.get_preview_zone_id(), "", "no preview until the 150 ms timer calls show_preview()")
	_state.show_preview()
	assert_eq(_state.get_preview_zone_id(), LOCKED_ID)

func test_preview_only_for_veiled_zones() -> void:
	_state.hover(OPEN_ID, ZoneManager.ZoneMapState.OPEN)
	_state.show_preview()
	assert_eq(_state.get_preview_zone_id(), "", "an open zone has no popover")
	_state.hover(VALLEY_ID, ZoneManager.ZoneMapState.CURRENT)
	_state.show_preview()
	assert_eq(_state.get_preview_zone_id(), "", "nor does the current zone")
	_state.hover(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	_state.show_preview()
	assert_eq(_state.get_preview_zone_id(), UNCHARTED_ID, "an uncharted zone previews like a locked one")

func test_hovering_another_zone_drops_the_preview() -> void:
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.show_preview()
	_state.hover(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	assert_eq(_state.get_preview_zone_id(), "", "the new hover waits for its own timer")

func test_hovering_the_same_zone_keeps_the_preview() -> void:
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.show_preview()
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_eq(_state.get_preview_zone_id(), LOCKED_ID, "moving from the hex to its plate is one hover")

func test_unhover_clears_preview_not_pin() -> void:
	_state.click(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.show_preview()
	_state.unhover()
	assert_eq(_state.get_preview_zone_id(), "", "leaving the hex drops its preview")
	assert_eq(_state.get_pinned_zone_id(), UNCHARTED_ID, "but the pinned popover stays")

func test_no_preview_while_a_popover_is_pinned() -> void:
	_state.click(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.show_preview()
	assert_eq(_state.get_preview_zone_id(), "", "one popover at a time: the pinned one")
	_state.close()
	assert_eq(_state.get_preview_zone_id(), LOCKED_ID, "the preview shows once the pin closes")

func test_pinning_the_hovered_zone_replaces_its_preview() -> void:
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.show_preview()
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_eq(_state.get_pinned_zone_id(), LOCKED_ID)
	assert_eq(_state.get_preview_zone_id(), "", "the pinned popover takes the preview's place")

func test_open_zone_is_travelable_on_hover() -> void:
	_state.hover(OPEN_ID, ZoneManager.ZoneMapState.OPEN)
	assert_true(_state.is_hovered_travelable(), "an open zone you are not in")
	_state.hover(VALLEY_ID, ZoneManager.ZoneMapState.CURRENT)
	assert_false(_state.is_hovered_travelable(), "not the zone you stand in")
	_state.hover(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_false(_state.is_hovered_travelable(), "nor a locked one")
