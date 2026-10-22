class_name MapPopoverState
extends RefCounted

## MapPopoverState
## What the zone map's popovers show, as pure state (spec: Behaviour › Map
## interaction; kit §6.6). It tracks three zone ids:
## - the hovered zone, with its map state;
## - the preview: the hovered locked or uncharted zone, set only once
##   MapMarkers' 150 ms timer calls show_preview(), so a passing pointer opens
##   nothing;
## - the pinned zone, whose popover a click opened.
## Only one popover is open at a time: while one is pinned no preview shows.
## click() says what a click on a hex does; the map carries it out (travel,
## recentre) and MapMarkers draws the popover.
##
## An enum-and-ids record rather than a node-based state machine: the
## "states" (nothing, preview, pinned) have no enter or exit logic of their
## own, and the map and the markers both read the ids.

## What a click on the map does.
enum ClickResult {
	## An open zone you are not in: walk there. Closes any popover.
	TRAVEL,
	## A locked or uncharted zone: pin its popover (the lock shakes).
	PIN,
	## The zone you are in: recentre the camera. Closes any popover.
	RECENTRE,
	## Fog: close any popover.
	CLOSE,
}

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _hovered_zone_id: String = ""
var _hovered_state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.OPEN
var _preview_zone_id: String = ""
var _pinned_zone_id: String = ""

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The pointer is over the zone's hex or plate. A new zone drops the preview
## (it waits for its own timer); the same zone keeps it, so moving from a
## hex to its own plate is one hover.
func hover(zone_id: String, state: ZoneManager.ZoneMapState) -> void:
	if zone_id == "":
		unhover()
		return
	if zone_id != _hovered_zone_id or not _is_veiled(state):
		_preview_zone_id = ""
	_hovered_zone_id = zone_id
	_hovered_state = state

## The pointer left every hex and plate: the preview goes, a pinned popover
## stays.
func unhover() -> void:
	_hovered_zone_id = ""
	_preview_zone_id = ""

## The hover delay ran out: the hovered zone shows its preview popover when
## it is locked or uncharted.
func show_preview() -> void:
	if _hovered_zone_id != "" and _is_veiled(_hovered_state):
		_preview_zone_id = _hovered_zone_id

## What a click on the zone's hex (or its plate) does. "" is fog.
func click(zone_id: String, state: ZoneManager.ZoneMapState) -> ClickResult:
	if zone_id == "":
		close()
		return ClickResult.CLOSE
	match state:
		ZoneManager.ZoneMapState.LOCKED, ZoneManager.ZoneMapState.UNCHARTED:
			_pinned_zone_id = zone_id
			return ClickResult.PIN
		ZoneManager.ZoneMapState.CURRENT:
			close()
			return ClickResult.RECENTRE
	close()
	return ClickResult.TRAVEL

## Closes the pinned popover (its ×, Esc, a click outside, travel).
func close() -> void:
	_pinned_zone_id = ""

## The zone whose popover is pinned, or "".
func get_pinned_zone_id() -> String:
	return _pinned_zone_id

## The zone whose preview popover shows, or "": none until show_preview(),
## and none while a popover is pinned.
func get_preview_zone_id() -> String:
	if _pinned_zone_id != "":
		return ""
	return _preview_zone_id

## The zone under the pointer, or "".
func get_hovered_zone_id() -> String:
	return _hovered_zone_id

## True when the hovered zone is an open zone you could walk to: its rim
## brightens and the route to it turns cream.
func is_hovered_travelable() -> bool:
	return _hovered_zone_id != "" and _hovered_state == ZoneManager.ZoneMapState.OPEN

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _is_veiled(state: ZoneManager.ZoneMapState) -> bool:
	return state == ZoneManager.ZoneMapState.LOCKED or state == ZoneManager.ZoneMapState.UNCHARTED
