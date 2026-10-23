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

func test_click_open_travels() -> void:
	var result: MapPopoverState.ClickResult = _state.click(OPEN_ID, ZoneManager.ZoneMapState.OPEN)
	assert_eq(result, MapPopoverState.ClickResult.TRAVEL, "an open zone you are not in travels")
	assert_eq(_state.get_pinned_zone_id(), "", "and pins nothing")

func test_click_open_closes_a_pinned_popover() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.click(OPEN_ID, ZoneManager.ZoneMapState.OPEN)
	assert_eq(_state.get_pinned_zone_id(), "", "travelling closes the popover")

func test_click_locked_pins() -> void:
	var result: MapPopoverState.ClickResult = _state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_eq(result, MapPopoverState.ClickResult.PIN)
	assert_eq(_state.get_pinned_zone_id(), LOCKED_ID)

func test_click_pinned_locked_again_stays_pinned() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	var result: MapPopoverState.ClickResult = _state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	assert_eq(result, MapPopoverState.ClickResult.PIN, "the lock shakes again")
	assert_eq(_state.get_pinned_zone_id(), LOCKED_ID, "and the popover stays")

func test_click_uncharted_pins_never_travels() -> void:
	var result: MapPopoverState.ClickResult = _state.click(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	assert_eq(result, MapPopoverState.ClickResult.PIN, "an uncharted zone pins its popover")
	assert_ne(result, MapPopoverState.ClickResult.TRAVEL, "and never travels")
	assert_eq(_state.get_pinned_zone_id(), UNCHARTED_ID)

func test_click_current_recentres_and_closes() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	var result: MapPopoverState.ClickResult = _state.click(VALLEY_ID, ZoneManager.ZoneMapState.CURRENT)
	assert_eq(result, MapPopoverState.ClickResult.RECENTRE)
	assert_eq(_state.get_pinned_zone_id(), "", "recentring closes any popover")

func test_click_fog_closes() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	var result: MapPopoverState.ClickResult = _state.click("", ZoneManager.ZoneMapState.OPEN)
	assert_eq(result, MapPopoverState.ClickResult.CLOSE, "\"\" is fog")
	assert_eq(_state.get_pinned_zone_id(), "")

func test_only_one_pinned() -> void:
	_state.click(LOCKED_ID, ZoneManager.ZoneMapState.LOCKED)
	_state.click(UNCHARTED_ID, ZoneManager.ZoneMapState.UNCHARTED)
	assert_eq(_state.get_pinned_zone_id(), UNCHARTED_ID, "pinning another hex replaces the first popover")

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
