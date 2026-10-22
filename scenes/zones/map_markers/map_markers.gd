class_name MapMarkers
extends CanvasLayer

## MapMarkers
## The zone map's screen-space markers (kit §0, §6.3-6.5), drawn over the map
## on canvas layer 1 inside the zone view's SubViewport:
## - a plate (ZoneMapLabel) under every map zone;
## - the padlock and "?" glyphs (MapGlyph) over the locked and uncharted hexes;
## - the action ring (MapActionRing) and the floater (MapFloater) that repeat
##   the running idle action beside the character;
## - the one map popover (ZoneMapPopover) for a locked or uncharted zone.
## Draw order, back to front: ring, floater, glyphs, plates, popover (kit §6.1).
## Every frame each marker follows its hex through the map's canvas transform:
## at zoom 2 it sits at the kit's offset from the hex centre. Markers keep
## their kit size at every zoom, so no text drops under the 13 px floor; at
## another zoom only the point each one hangs from (its anchor: a plate's top
## centre, a glyph's centre, the ring's top-left, the floater's foot, the
## popover's edge beside the hex) moves with the hex, by zoom / 2 (Review
## Focus 3). Below zoom 1.25 the plates show their names only (spec, Open /
## deferred), so their lines do not crowd. The layer hides while the camera zooms
## into an adventure and shows again when the zone view comes back and the
## camera has eased back to its resting zoom.
## Instanced by ZoneTilemap, which it reads through map; it rebuilds on the
## map's map_rebuilt.
##
## Map interaction (spec: Behaviour › Map interaction; kit §6.6). The map
## reports what the pointer is over (hover_zone) and what was clicked
## (click_zone); a MapPopoverState decides, and this layer draws it: the
## plates' hover and pinned looks, the lock shake, and the popover (a
## preview 150 ms after a locked or uncharted hex is hovered, pinned on a
## click). One popover at a time; its ×, Esc, a press anywhere the map and
## the popover do not take, another hex, travel, a save reset or its zone
## leaving the map closes it. interaction_changed tells the map to swap the
## hex rims and light the route.

## Emitted when the player clicks a zone's plate (it does what a click on the
## zone's hex does; the map interaction layer decides what that is).
signal plate_pressed(zone_data: ZoneData)

## Emitted when the hovered or pinned zone changes, so the map can swap the
## hexes' rims and light the route toward a zone you can travel to.
signal interaction_changed

## Emitted when the pointer enters or leaves a plate or the popover: what the
## pointer is over may have changed without it crossing a hex cell.
signal marker_hover_changed

## Emitted when the pointer leaves the map for a panel or the dock, after the
## hover is cleared: the map forgets the hex cell it was over.
signal pointer_left_map

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The zone map the markers follow.
@export var map: ZoneTilemap

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The map zoom the kit's offsets and sizes are drawn for.
const KIT_ZOOM: float = 2.0

## Offsets from a hex's screen centre at zoom 2 (kit §6.4, §6.5, §0).
const PLATE_OFFSET_OPEN: Vector2 = Vector2(-124, 98)
const PLATE_OFFSET_LOCKED: Vector2 = Vector2(-124, 11)
const PLATE_OFFSET_UNCHARTED: Vector2 = Vector2(-124, 18)
const GLYPH_OFFSET_LOCKED: Vector2 = Vector2(-22, -61)
const GLYPH_OFFSET_UNCHARTED: Vector2 = Vector2(-14, -40)
const RING_OFFSET: Vector2 = Vector2(38, 4)
## Popover top-left offsets from its hex's centre at zoom 2 (kit §6.6): the
## locked card left of the hex (the right side runs into the zone chest), the
## uncharted card right of it, each centred on the hex's height.
const POPOVER_OFFSET_LOCKED_PINNED: Vector2 = Vector2(-440, -86)
const POPOVER_OFFSET_LOCKED_PREVIEW: Vector2 = Vector2(-440, -66)
const POPOVER_OFFSET_UNCHARTED: Vector2 = Vector2(168, -56)
## The floater token is centred on the hex centre + 50 (snapped to even px),
## with its top 28 above the centre before it rises.
const FLOATER_CENTRE_X: float = 50.0
const FLOATER_TOP: float = -28.0

## Where a marker hangs from its hex at zoom 2, from the hex centre: the point
## that moves with the hex at other zooms while the marker keeps its size. The
## ring hangs from its top-left, the floater from the foot of its token, a
## popover from its edge beside the hex (4 px clear of the rim); a plate from
## its top centre and a glyph from its own centre (_plate_anchor,
## _glyph_anchor).
const RING_ANCHOR: Vector2 = RING_OFFSET
const FLOATER_ANCHOR: Vector2 = Vector2(FLOATER_CENTRE_X, 0)
const POPOVER_ANCHOR_LOCKED: Vector2 = Vector2(-168, 0)
const POPOVER_ANCHOR_UNCHARTED: Vector2 = Vector2(168, 0)

## Below this map zoom the plates show their names only (spec, Open / deferred).
const PLATE_NAME_ONLY_BELOW_ZOOM: float = 1.25

## Between the items of a foraging haul on the floater.
const HAUL_SEPARATOR: String = "  "

const ZoneMapLabelScene: PackedScene = preload("res://scenes/zones/map_markers/zone_map_label/zone_map_label.tscn")
const MapGlyphScene: PackedScene = preload("res://scenes/zones/map_markers/map_glyph/map_glyph.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _ring: MapActionRing = %ActionRing
@onready var _floater: MapFloater = %Floater
@onready var _glyph_container: Control = %GlyphContainer
@onready var _plate_container: Control = %PlateContainer
@onready var _popover: ZoneMapPopover = %Popover
@onready var _preview_timer: Timer = %PreviewTimer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _plates: Dictionary[String, ZoneMapLabel] = {}
var _glyphs: Dictionary[String, MapGlyph] = {}
## Each map zone's hex centre in the map's own space.
var _zone_centres: Dictionary[String, Vector2] = {}
var _hovered_zone_id: String = ""
var _pinned_zone_id: String = ""
## The Control that shows the SubViewport the map draws in (the zone view's
## SubViewportContainer), or null outside one.
var _view_host: Control = null
## True from the zone view's return after an adventure until the camera is
## back at its resting zoom, when the layer shows again.
var _waiting_for_camera: bool = false
## Which zone is hovered, previewed and pinned.
var _popover_state: MapPopoverState = MapPopoverState.new()
## False from a left press anywhere in the window until the map or the popover
## takes it; a press nothing takes closes the pinned popover.
var _press_claimed: bool = true
## False while the pointer is off the map (over a panel or the dock): nothing
## on the map is hovered then, whatever a late mouse_exited reports.
var _pointer_on_map: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	ActionManager.training_tick_processed.connect(_on_training_tick_processed)
	ActionManager.foraging_completed.connect(_on_foraging_completed)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)
	ZoneManager.action_completed.connect(_on_zone_action_completed)
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	get_tree().root.window_input.connect(_on_window_input)
	_preview_timer.timeout.connect(_on_preview_timer_timeout)
	_popover.close_pressed.connect(close_popover)
	_popover.show_me_pressed.connect(_on_show_me_pressed)
	_popover.pressed_inside.connect(_claim_press)
	for card: Control in _popover.get_cards():
		card.mouse_entered.connect(marker_hover_changed.emit)
		card.mouse_exited.connect(marker_hover_changed.emit)
	_popover.hide()
	_view_host = _find_view_host()
	if _view_host != null:
		_view_host.visibility_changed.connect(_on_view_host_visibility_changed)
		_view_host.mouse_entered.connect(_on_view_host_mouse_entered)
		_view_host.mouse_exited.connect(_on_view_host_mouse_exited)
	if map != null:
		map.map_rebuilt.connect(_rebuild)
		if map.is_node_ready():
			_rebuild()
	_show_idle_action(ActionManager.get_current_action())

func _process(_delta: float) -> void:
	if _waiting_for_camera and _is_camera_at_rest():
		_waiting_for_camera = false
		show()
	_place_markers()

## Esc closes the pinned popover before anything else hears it.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _popover_state.get_pinned_zone_id() == "":
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_popover()
		get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The plate under the zone's hex, or null when the zone is not on the map.
func get_plate(zone_id: String) -> ZoneMapLabel:
	return _plates.get(zone_id, null) as ZoneMapLabel

## The padlock or "?" glyph over the zone's hex, or null when the zone is not
## veiled (or not on the map).
func get_glyph(zone_id: String) -> Control:
	return _glyphs.get(zone_id, null) as Control

## The ids of the zones whose plates are in the layer, in map order.
func get_plate_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_plates.keys())
	return ids

## The ring that shows the running idle action.
func get_action_ring() -> MapActionRing:
	return _ring

## The floater that rises on each Aura Well tick or foraging haul.
func get_floater() -> MapFloater:
	return _floater

## Shows the zone's plate as hovered ("" for none); one zone at a time.
func set_hovered_zone(zone_id: String) -> void:
	_hovered_zone_id = zone_id if _plates.has(zone_id) else ""
	_apply_hover_and_pin()

## The zone whose plate shows as hovered, or "".
func get_hovered_zone_id() -> String:
	return _hovered_zone_id

## Shows the brass frame on the zone's plate ("" for none); one zone at a time.
func set_pinned_zone(zone_id: String) -> void:
	_pinned_zone_id = zone_id if _plates.has(zone_id) else ""
	_apply_hover_and_pin()

## The zone whose plate shows as pinned, or "".
func get_pinned_zone_id() -> String:
	return _pinned_zone_id

## The map popover (hidden while no zone is previewed or pinned).
func get_popover() -> ZoneMapPopover:
	return _popover

## Which zone is hovered, previewed and pinned.
func get_popover_state() -> MapPopoverState:
	return _popover_state

## True unless the pointer has left the map for a panel or the dock.
func is_pointer_on_map() -> bool:
	return _pointer_on_map

## The pointer is over the zone's hex or plate ("" for none; always none while
## the pointer is off the map). Hovering a locked or uncharted zone starts the
## 150 ms preview timer; a new hover drops the old preview at once.
func hover_zone(zone_id: String) -> void:
	var plate: ZoneMapLabel = get_plate(zone_id)
	if plate == null or not _pointer_on_map:
		zone_id = ""
	var previous_id: String = _popover_state.get_hovered_zone_id()
	if zone_id == "":
		_popover_state.unhover()
	else:
		_popover_state.hover(zone_id, ZoneManager.get_zone_map_state(plate.get_zone_data()))
	if zone_id != previous_id:
		_preview_timer.stop()
		if zone_id != "" and _is_veiled(ZoneManager.get_zone_map_state(plate.get_zone_data())):
			_preview_timer.start()
	set_hovered_zone(zone_id)
	_refresh_popover()
	interaction_changed.emit()

## A click on the zone's hex or plate ("" for fog): returns what the map has
## to do (travel, recentre). Pinning shakes a locked zone's padlock.
func click_zone(zone_id: String) -> MapPopoverState.ClickResult:
	_claim_press()
	var plate: ZoneMapLabel = get_plate(zone_id)
	var state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.OPEN
	if plate == null:
		zone_id = ""
	else:
		state = ZoneManager.get_zone_map_state(plate.get_zone_data())
	var result: MapPopoverState.ClickResult = _popover_state.click(zone_id, state)
	if result == MapPopoverState.ClickResult.PIN and state == ZoneManager.ZoneMapState.LOCKED:
		var glyph: MapGlyph = _glyphs.get(zone_id, null) as MapGlyph
		if glyph != null:
			glyph.shake()
	_apply_pin()
	return result

## Closes the pinned popover.
func close_popover() -> void:
	_popover_state.close()
	_apply_pin()

## The zone whose plate is under the canvas point, or "": where plates
## overlap, the one drawn on top.
func get_plate_zone_id_at(point: Vector2) -> String:
	var children: Array[Node] = _plate_container.get_children()
	for index: int in range(children.size() - 1, -1, -1):
		var plate := children[index] as ZoneMapLabel
		if plate == null or plate.get_zone_data() == null or get_plate(plate.get_zone_data().zone_id) != plate:
			continue
		if plate.is_visible_in_tree() and plate.get_global_rect().has_point(point):
			return plate.get_zone_data().zone_id
	return ""

## True when the canvas point lies on the shown popover.
func is_point_on_popover(point: Vector2) -> bool:
	return visible and _popover.contains_point(point)

## True when the canvas point lies on a plate or the popover, which take the
## click themselves (the map leaves it to them).
func is_point_on_marker(point: Vector2) -> bool:
	return visible and (is_point_on_popover(point) or get_plate_zone_id_at(point) != "")

#-----------------------------------------------------------------------------
# BUILDING
#-----------------------------------------------------------------------------

## Lays a plate under every map zone and a glyph over every veiled one. The
## current zone's plate is drawn last, over any neighbour's it overlaps (at
## zoom 1 row neighbours are 164 px apart, a plate 248 wide). A hover or pin
## whose zone left the map goes with it (Review Focus 5). The old plates and
## glyphs hide and stay in the layer until they are freed at the end of the
## frame, so none is ever an orphan.
func _rebuild() -> void:
	for container: Control in [_glyph_container, _plate_container]:
		for child: Node in container.get_children():
			if child.is_queued_for_deletion():
				continue
			(child as CanvasItem).hide()
			child.queue_free()
	_plates.clear()
	_glyphs.clear()
	_zone_centres.clear()

	for zone_data: ZoneData in ZoneManager.get_map_zones():
		var state: ZoneManager.ZoneMapState = ZoneManager.get_zone_map_state(zone_data)
		_zone_centres[zone_data.zone_id] = map.get_zone_world_centre(zone_data)
		var plate: ZoneMapLabel = ZoneMapLabelScene.instantiate() as ZoneMapLabel
		_plate_container.add_child(plate)
		plate.setup(zone_data, state)
		plate.pressed.connect(_on_plate_pressed.bind(zone_data))
		plate.mouse_entered.connect(marker_hover_changed.emit)
		plate.mouse_exited.connect(marker_hover_changed.emit)
		_plates[zone_data.zone_id] = plate
		if _is_veiled(state):
			var glyph: MapGlyph = MapGlyphScene.instantiate() as MapGlyph
			_glyph_container.add_child(glyph)
			glyph.setup(state)
			_glyphs[zone_data.zone_id] = glyph
	var current_id: String = _current_map_zone_id()
	if current_id != "":
		_plate_container.move_child(_plates[current_id], -1)

	if not _plates.has(_hovered_zone_id):
		_hovered_zone_id = ""
	if not _plates.has(_pinned_zone_id):
		_pinned_zone_id = ""
	_sync_popover_state()
	_apply_hover_and_pin()
	_show_idle_action(ActionManager.get_current_action())
	_refresh_popover()
	_place_markers()
	interaction_changed.emit()

## After a rebuild: a hover or pin whose zone left the map goes, and so does a
## pin on a zone that is no longer locked or uncharted (with its plate's
## frame). The hovered zone's map state is read again (it may have become the
## current zone).
func _sync_popover_state() -> void:
	var pinned_id: String = _popover_state.get_pinned_zone_id()
	if pinned_id != "" and (not _plates.has(pinned_id) or not _is_veiled(ZoneManager.get_zone_map_state(_plates[pinned_id].get_zone_data()))):
		_popover_state.close()
		if _pinned_zone_id == pinned_id:
			_pinned_zone_id = ""
	var hovered_id: String = _popover_state.get_hovered_zone_id()
	if hovered_id != "" and not _plates.has(hovered_id):
		_popover_state.unhover()
		_preview_timer.stop()
	elif hovered_id != "":
		_popover_state.hover(hovered_id, ZoneManager.get_zone_map_state(_plates[hovered_id].get_zone_data()))

func _apply_hover_and_pin() -> void:
	for zone_id: String in _plates:
		var plate: ZoneMapLabel = _plates[zone_id]
		plate.set_hovered(zone_id == _hovered_zone_id)
		plate.set_pinned(zone_id == _pinned_zone_id)

#-----------------------------------------------------------------------------
# PLACEMENT
#-----------------------------------------------------------------------------

## Where a marker of fixed size goes: at zoom 2 (hex_scale 1) its kit offset
## from the hex's screen centre; at any other zoom its anchor (a point at the
## kit's distance from the hex centre) moves with the hex, by hex_scale =
## zoom / 2, and the marker keeps its size around it. In whole px.
static func marker_position(hex_centre: Vector2, kit_offset: Vector2, anchor: Vector2, hex_scale: float) -> Vector2:
	return (hex_centre + kit_offset + anchor * (hex_scale - 1.0)).round()

## Puts every marker at its kit offset from its hex's screen centre, at its
## kit size, its anchor following the hex (marker_position), in whole px.
## Below zoom 1.25 the plates show their names only.
func _place_markers() -> void:
	if map == null or not map.is_inside_tree():
		return
	var canvas: Transform2D = map.get_global_transform_with_canvas()
	var zoom: float = canvas.get_scale().x
	var hex_scale: float = zoom / KIT_ZOOM
	# The canvas scale comes back a hair off the camera's zoom.
	var name_only: bool = zoom < PLATE_NAME_ONLY_BELOW_ZOOM and not is_equal_approx(zoom, PLATE_NAME_ONLY_BELOW_ZOOM)

	for zone_id: String in _plates:
		var plate: ZoneMapLabel = _plates[zone_id]
		var plate_offset: Vector2 = _plate_offset(plate.get_state())
		plate.position = marker_position(canvas * _zone_centres[zone_id], plate_offset, _plate_anchor(plate_offset), hex_scale)
		plate.set_name_only(name_only)
	for zone_id: String in _glyphs:
		var glyph: MapGlyph = _glyphs[zone_id]
		var glyph_offset: Vector2 = _glyph_offset(glyph.get_state())
		glyph.position = marker_position(canvas * _zone_centres[zone_id], glyph_offset, glyph_offset + glyph.size / 2.0, hex_scale)
	var popover_zone: ZoneData = _popover.get_zone_data()
	if _popover.visible and popover_zone != null and _zone_centres.has(popover_zone.zone_id):
		_popover.position = marker_position(canvas * _zone_centres[popover_zone.zone_id], _popover_offset(), _popover_anchor(), hex_scale)

	var current_id: String = _current_map_zone_id()
	if current_id == "":
		return
	var centre: Vector2 = canvas * _zone_centres[current_id]
	_ring.position = marker_position(centre, RING_OFFSET, RING_ANCHOR, hex_scale)
	var floater_offset: Vector2 = Vector2(
		snappedf(FLOATER_CENTRE_X - _floater.get_token_width() / 2.0, 2.0),
		FLOATER_TOP - _floater.get_rise())
	_floater.position = marker_position(centre, floater_offset, FLOATER_ANCHOR, hex_scale)

## A plate hangs from its top centre: the kit's offsets centre the plate
## under its hex.
func _plate_anchor(plate_offset: Vector2) -> Vector2:
	return Vector2(0.0, plate_offset.y)

func _popover_anchor() -> Vector2:
	if _popover.get_state() == ZoneManager.ZoneMapState.UNCHARTED:
		return POPOVER_ANCHOR_UNCHARTED
	return POPOVER_ANCHOR_LOCKED

func _plate_offset(state: ZoneManager.ZoneMapState) -> Vector2:
	match state:
		ZoneManager.ZoneMapState.LOCKED:
			return PLATE_OFFSET_LOCKED
		ZoneManager.ZoneMapState.UNCHARTED:
			return PLATE_OFFSET_UNCHARTED
	return PLATE_OFFSET_OPEN

func _glyph_offset(state: ZoneManager.ZoneMapState) -> Vector2:
	return GLYPH_OFFSET_UNCHARTED if state == ZoneManager.ZoneMapState.UNCHARTED else GLYPH_OFFSET_LOCKED

func _popover_offset() -> Vector2:
	if _popover.get_state() == ZoneManager.ZoneMapState.UNCHARTED:
		return POPOVER_OFFSET_UNCHARTED
	return POPOVER_OFFSET_LOCKED_PINNED if _popover.is_pinned() else POPOVER_OFFSET_LOCKED_PREVIEW

#-----------------------------------------------------------------------------
# POPOVER
#-----------------------------------------------------------------------------

## Shows the pinned zone's popover, else the previewed zone's, else none.
func _refresh_popover() -> void:
	var pinned_id: String = _popover_state.get_pinned_zone_id()
	var zone_id: String = pinned_id if pinned_id != "" else _popover_state.get_preview_zone_id()
	var plate: ZoneMapLabel = get_plate(zone_id)
	if plate == null:
		_popover.hide()
		return
	var zone_data: ZoneData = plate.get_zone_data()
	var show_me: bool = _is_card_in_current_zone(zone_data.requirement_action_id)
	_popover.setup(zone_data, ZoneManager.get_zone_map_state(zone_data), pinned_id != "", show_me)
	_popover.show()
	_place_markers()

## Draws the pin on the plates and the popover, and tells the map.
func _apply_pin() -> void:
	set_pinned_zone(_popover_state.get_pinned_zone_id())
	_refresh_popover()
	interaction_changed.emit()

## True when the action is a card in the current zone's activity list, so
## "Show me" has something to scroll to.
func _is_card_in_current_zone(action_id: String) -> bool:
	var current: ZoneData = ZoneManager.get_current_zone()
	if action_id == "" or current == null:
		return false
	for action: ZoneActionData in ZoneManager.get_available_actions(current.zone_id):
		if action.action_id == action_id:
			return true
	return false

func _claim_press() -> void:
	_press_claimed = true

## A left press nothing on the map took (a panel, the dock, empty window)
## closes the pinned popover.
func _close_unless_claimed() -> void:
	if not _press_claimed:
		_press_claimed = true
		close_popover()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The current zone's id when its hex is on the map, else "".
func _current_map_zone_id() -> String:
	var current: ZoneData = ZoneManager.get_current_zone()
	if current == null or not _zone_centres.has(current.zone_id):
		return ""
	return current.zone_id

## The ring shows the running idle action of a zone on the map; with none,
## the ring and the floater hide outright. A floater left from another action
## (the Aura Well's last tick when foraging starts) hides with it; the same
## action (a map rebuild) keeps its floater rising.
func _show_idle_action(action: ZoneActionData) -> void:
	var idle: ZoneActionData = action if _is_idle(action) and _current_map_zone_id() != "" else null
	if idle == null or idle != _ring.get_action():
		_floater.stop()
	_ring.show_action(idle)

func _is_idle(action: ZoneActionData) -> bool:
	return action is TrainingActionData or action is ForageActionData

func _is_veiled(state: ZoneManager.ZoneMapState) -> bool:
	return state == ZoneManager.ZoneMapState.LOCKED or state == ZoneManager.ZoneMapState.UNCHARTED

func _refresh_plates() -> void:
	for plate: ZoneMapLabel in _plates.values():
		plate.refresh()

## True when the map's camera is at the zoom the player left it at, not on
## ZoneTransition's adventure zoom or its way back.
func _is_camera_at_rest() -> bool:
	if map == null or not map.is_node_ready():
		return true
	return map.get_camera().zoom.is_equal_approx(map.get_resting_zoom())

## The SubViewportContainer that shows the map, found through the SubViewport
## the layer draws in.
func _find_view_host() -> Control:
	var viewport: Viewport = get_viewport()
	if viewport is SubViewport:
		return viewport.get_parent() as Control
	return null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_current_action_changed(action: ZoneActionData) -> void:
	_show_idle_action(action)
	_refresh_plates()

func _on_zone_action_completed() -> void:
	_refresh_plates()

## "+1.5 Madra" in Madra blue for each tick of the running training action.
func _on_training_tick_processed(training: TrainingActionData, _new_tick_count: int) -> void:
	if not _ring.visible or training != ActionManager.get_current_action():
		return
	var madra_per_tick: float = training.get_madra_per_second() * training.tick_interval_seconds
	if madra_per_tick <= 0.0:
		return
	_floater.pop("%s Madra" % LacquerText.rate(madra_per_tick), ThemeConstants.LACQUER_MADRA)
	_place_markers()

## The haul in cream ("+3 Dewdrop Tear  +4 Spirit Fern"), once per haul.
func _on_foraging_completed(items: Dictionary) -> void:
	if not _ring.visible or not ActionManager.get_current_action() is ForageActionData:
		return
	var parts: Array[String] = []
	for item: ItemDefinitionData in items:
		parts.append("+%d %s" % [items[item], item.item_name])
	if parts.is_empty():
		return
	_floater.pop(HAUL_SEPARATOR.join(parts), ThemeConstants.LACQUER_CREAM)
	_place_markers()

func _on_plate_pressed(zone_data: ZoneData) -> void:
	plate_pressed.emit(zone_data)

func _on_preview_timer_timeout() -> void:
	_popover_state.show_preview()
	_refresh_popover()

func _on_show_me_pressed(action_id: String) -> void:
	if action_id != "":
		ZoneManager.request_action_focus(action_id)

## Every left press in the window, before anything handles it: unless the map
## or the popover takes it this frame, the pinned popover closes at the end
## of the frame (after the press has landed on what the player aimed at).
func _on_window_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if _popover_state.get_pinned_zone_id() == "":
		return
	_press_claimed = false
	_close_unless_claimed.call_deferred()

## The pointer left the map for a panel or the dock: it is over no hex, even
## when it skipped the fog between, until it comes back.
func _on_view_host_mouse_exited() -> void:
	_pointer_on_map = false
	hover_zone("")
	pointer_left_map.emit()

func _on_view_host_mouse_entered() -> void:
	_pointer_on_map = true

## A save reset leaves no popover, hover or preview timer behind.
func _on_save_data_reset() -> void:
	_preview_timer.stop()
	_popover_state.unhover()
	set_hovered_zone("")
	close_popover()

## ZoneTransition zooms the camera into the zone before an adventure: the
## plates and glyphs would slide apart with the hexes, so the layer hides.
func _on_adventure_start_requested(_action_data: AdventureActionData) -> void:
	_waiting_for_camera = false
	close_popover()
	hide()

## The zone view state shows its view again (after the adventure), then eases
## the camera back from the adventure zoom: the layer shows once it is back.
func _on_view_host_visibility_changed() -> void:
	if not _view_host.is_visible_in_tree():
		_waiting_for_camera = false
		return
	if _is_camera_at_rest():
		show()
	else:
		_waiting_for_camera = true
