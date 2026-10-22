class_name MapMarkers
extends CanvasLayer

## MapMarkers
## The zone map's screen-space markers (kit §0, §6.3-6.5), drawn over the map
## on canvas layer 1 inside the zone view's SubViewport:
## - a plate (ZoneMapLabel) under every map zone;
## - the padlock and "?" glyphs (MapGlyph) over the locked and uncharted hexes;
## - the action ring (MapActionRing) and the floater (MapFloater) that repeat
##   the running idle action beside the character.
## Draw order, back to front: ring, floater, glyphs, plates (kit §6.1).
## Every frame each marker follows its hex through the map's canvas transform:
## at zoom 2 it sits at the kit's offset from the hex centre at file size, and
## at any other zoom both the offset and the marker scale by zoom / 2, so it
## stays on its hex (Review Focus 3). The layer hides while the camera zooms
## into an adventure and shows again when the zone view comes back and the
## camera has eased back to its resting zoom.
## Instanced by ZoneTilemap, which it reads through map; it rebuilds on the
## map's map_rebuilt.

## Emitted when the player clicks a zone's plate (it does what a click on the
## zone's hex does; the map interaction layer decides what that is).
signal plate_pressed(zone_data: ZoneData)

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
## The floater token is centred on the hex centre + 50 (snapped to even px),
## with its top 28 above the centre before it rises.
const FLOATER_CENTRE_X: float = 50.0
const FLOATER_TOP: float = -28.0

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

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	ActionManager.training_tick_processed.connect(_on_training_tick_processed)
	ActionManager.foraging_completed.connect(_on_foraging_completed)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)
	ZoneManager.action_completed.connect(_on_zone_action_completed)
	_view_host = _find_view_host()
	if _view_host != null:
		_view_host.visibility_changed.connect(_on_view_host_visibility_changed)
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
	for child: Node in _plate_container.get_children():
		var plate := child as ZoneMapLabel
		if plate != null and not plate.is_queued_for_deletion() and plate.get_zone_data() != null:
			ids.append(plate.get_zone_data().zone_id)
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

#-----------------------------------------------------------------------------
# BUILDING
#-----------------------------------------------------------------------------

## Lays a plate under every map zone and a glyph over every veiled one. A hover
## or pin whose zone left the map goes with it (Review Focus 5). The old
## plates and glyphs hide and stay in the layer until they are freed at the
## end of the frame, so none is ever an orphan.
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
		_plates[zone_data.zone_id] = plate
		if _is_veiled(state):
			var glyph: MapGlyph = MapGlyphScene.instantiate() as MapGlyph
			_glyph_container.add_child(glyph)
			glyph.setup(state)
			_glyphs[zone_data.zone_id] = glyph

	if not _plates.has(_hovered_zone_id):
		_hovered_zone_id = ""
	if not _plates.has(_pinned_zone_id):
		_pinned_zone_id = ""
	_apply_hover_and_pin()
	_show_idle_action(ActionManager.get_current_action())
	_place_markers()

func _apply_hover_and_pin() -> void:
	for zone_id: String in _plates:
		var plate: ZoneMapLabel = _plates[zone_id]
		plate.set_hovered(zone_id == _hovered_zone_id)
		plate.set_pinned(zone_id == _pinned_zone_id)

#-----------------------------------------------------------------------------
# PLACEMENT
#-----------------------------------------------------------------------------

## Puts every marker at its kit offset from its hex's screen centre, both
## scaled by zoom / 2, in whole px.
func _place_markers() -> void:
	if map == null or not map.is_inside_tree():
		return
	var canvas: Transform2D = map.get_global_transform_with_canvas()
	var marker_scale: float = canvas.get_scale().x / KIT_ZOOM
	var scale_vector: Vector2 = Vector2(marker_scale, marker_scale)

	for zone_id: String in _plates:
		var plate: ZoneMapLabel = _plates[zone_id]
		plate.position = (canvas * _zone_centres[zone_id] + _plate_offset(plate.get_state()) * marker_scale).round()
		plate.scale = scale_vector
	for zone_id: String in _glyphs:
		var glyph: MapGlyph = _glyphs[zone_id]
		glyph.position = (canvas * _zone_centres[zone_id] + _glyph_offset(glyph.get_state()) * marker_scale).round()
		glyph.scale = scale_vector

	var current_id: String = _current_map_zone_id()
	if current_id == "":
		return
	var centre: Vector2 = canvas * _zone_centres[current_id]
	_ring.position = (centre + RING_OFFSET * marker_scale).round()
	_ring.scale = scale_vector
	var floater_offset: Vector2 = Vector2(
		snappedf(FLOATER_CENTRE_X - _floater.get_token_width() / 2.0, 2.0),
		FLOATER_TOP - _floater.get_rise())
	_floater.position = (centre + floater_offset * marker_scale).round()
	_floater.scale = scale_vector

func _plate_offset(state: ZoneManager.ZoneMapState) -> Vector2:
	match state:
		ZoneManager.ZoneMapState.LOCKED:
			return PLATE_OFFSET_LOCKED
		ZoneManager.ZoneMapState.UNCHARTED:
			return PLATE_OFFSET_UNCHARTED
	return PLATE_OFFSET_OPEN

func _glyph_offset(state: ZoneManager.ZoneMapState) -> Vector2:
	return GLYPH_OFFSET_UNCHARTED if state == ZoneManager.ZoneMapState.UNCHARTED else GLYPH_OFFSET_LOCKED

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
## the ring and the floater hide outright.
func _show_idle_action(action: ZoneActionData) -> void:
	var idle: ZoneActionData = action if _is_idle(action) and _current_map_zone_id() != "" else null
	_ring.show_action(idle)
	if idle == null:
		_floater.stop()

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

## ZoneTransition zooms the camera into the zone before an adventure: the
## plates and glyphs would swell with it, so the layer hides.
func _on_adventure_start_requested(_action_data: AdventureActionData) -> void:
	_waiting_for_camera = false
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
