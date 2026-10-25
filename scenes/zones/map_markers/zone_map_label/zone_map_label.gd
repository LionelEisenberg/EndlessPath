class_name ZoneMapLabel
extends Control

## ZoneMapLabel
## A zone's plate on the zone map (kit §6.5): a 52 px lacquer plate under the
## hex with the zone's name and, on most plates, one status line.
## - Current zone: the name in brass (cream on hover) and no status line. While
##   an idle action runs there, its action ring (MapActionRing: the action's
##   icon and the beads that light over each tick or haul) sits on the plate's
##   left end, overlapping it, and the name stands beside it. The ring and the
##   plate were two things on the hex until the user's review of 2026-10-24,
##   which moved the ring onto the plate and dropped the "Aura Well · +1.5
##   Madra / s" line: the cabinet and the Now strip show the rate.
## - Open zone: "Open · N activities" in tan, "Click to travel" in brass while
##   hovered.
## - Locked zone: the blocker in short ("Tribulation Guardian") after a swords
##   icon. Uncharted zone: the blocker in tan, its name tan until hovered.
## The status line is the icon and a Label, centred as a group in a slot kept
## 4 px clear of the plate's side rivets. A long blocker ellipsizes in the
## Label, so the icon stays whole and the plate never widens (Review Focus 4).
## A plate with a status line is the kit's 248 px. A plate without one (the
## current zone's, or any plate while the map is zoomed out below 1.25,
## set_name_only) hugs its name: 16 px a side, or the ring's room on the left
## and 24 px on the right while the ring shows, so row neighbours (164 px apart at zoom 1) stop
## overlapping. The texture is a 9-slice whose middle tiles, so its grain is
## cut short, never squeezed.
## Hovered plates show their hover texture; a pinned plate (its popover is
## pinned) gets the brass frame. MapMarkers places the plate under its hex
## every frame, at its kit size. Pressing the plate emits pressed (MapMarkers
## turns that into plate_pressed).

## Emitted when the player clicks the plate.
signal pressed

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Plates")
@export var current_texture: Texture2D
@export var current_hover_texture: Texture2D
@export var open_texture: Texture2D
@export var open_hover_texture: Texture2D
@export var locked_texture: Texture2D
@export var locked_hover_texture: Texture2D
@export var uncharted_texture: Texture2D
@export var uncharted_hover_texture: Texture2D

@export_group("Line icons")
## Before a locked zone's blocker.
@export var blocker_icon: Texture2D

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The name's top with a status line under it, and centred alone (kit §6.5).
const NAME_TOP: float = 6.0
const NAME_ONLY_TOP: float = 17.0

## The plate's kit width, and how much wider than its name a plate that hugs
## its name is (16 px a side, clear of the rivets).
const PLATE_WIDTH: float = 248.0
const NAME_ONLY_PADDING: float = 32.0
## The name's slot runs 6 px in from each side of the plate.
const NAME_EDGE: float = 6.0

## The ring's top-left on the plate: its 64 px hang off the plate's left end
## and stand 6 px over the plate's 52 px top and bottom, centred on its height.
const RING_POSITION: Vector2 = Vector2(-22, -6)
## Beside the ring the name starts 6 px past the ring's right edge (x 42),
## and ends 24 px short of the plate's right edge. With the left rivet under the
## ring, the right one (6 px in) would read as a dot after the name at the
## 16 px a plate that hugs its name leaves.
const RING_NAME_LEFT: float = 48.0
const RING_NAME_RIGHT: float = 24.0

const SEPARATOR: String = " · "
const CLICK_TO_TRAVEL: String = "Click to travel"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _plate_texture: NinePatchRect = %PlateTexture
@onready var _pinned_frame: LacquerFrameOverlay = %PinnedFrame
@onready var _name_label: Label = %NameLabel
@onready var _line_area: Control = %LineArea
@onready var _icon_margin: MarginContainer = %IconMargin
@onready var _line_icon: TextureRect = %LineIcon
@onready var _line_name: Label = %LineName
@onready var _action_ring: MapActionRing = %ActionRing

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _zone_data: ZoneData = null
var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.OPEN
var _hovered: bool = false
var _pinned: bool = false
## True while the map is zoomed out too far for the status line.
var _name_only: bool = false

## What the plate shows, worked out by _compute() and drawn by _apply().
var _line: String = ""
var _line_icon_texture: Texture2D = null
var _line_color: Color = ThemeConstants.LACQUER_CREAM
var _name_color: Color = ThemeConstants.LACQUER_CREAM
## The idle action the ring shows, or null for no ring.
var _ring_action: ZoneActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_action_ring.position = RING_POSITION
	_apply()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the zone's plate for its map state.
func setup(zone_data: ZoneData, state: ZoneManager.ZoneMapState) -> void:
	_zone_data = zone_data
	_state = state
	refresh()

## Re-reads what the plate shows: the ring for the idle action running in the
## current zone, the activity count on an open zone's status line.
func refresh() -> void:
	_compute()
	_apply()

## Hovered: the hover texture, a cream name, and "Click to travel" on an open
## zone's plate.
func set_hovered(hovered: bool) -> void:
	if hovered == _hovered:
		return
	_hovered = hovered
	refresh()

## Pinned (its popover is pinned): the brass frame over the plate.
func set_pinned(pinned: bool) -> void:
	if pinned == _pinned:
		return
	_pinned = pinned
	_apply()

## Name only (the map is zoomed out below 1.25): the status line hides, the
## plate narrows to the name and the name centres on it; the line and the kit
## width come back with false. The ring stays.
func set_name_only(name_only: bool) -> void:
	if name_only == _name_only:
		return
	_name_only = name_only
	_apply()

## The zone the plate names.
func get_zone_data() -> ZoneData:
	return _zone_data

## The map state the plate was set up with.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## The status line as plain text, or "" when the plate has none (the current
## zone's plate never has one). Kept while the plate shows its name only.
func get_line_text() -> String:
	return _line

## True when the plate shows a status line under the name: it has one and
## the map is not zoomed out to names only.
func is_line_shown() -> bool:
	return _line != "" and not _name_only

## The ring on the plate's left end. It shows only on the current zone's
## plate while an idle action runs there.
func get_action_ring() -> MapActionRing:
	return _action_ring

## The colour the zone's name is drawn in now.
func get_name_color() -> Color:
	return _name_color

## The colour the status line is drawn in now.
func get_line_color() -> Color:
	return _line_color

## The plate texture drawn now.
func get_plate_texture() -> Texture2D:
	return _pick_plate_texture()

## True while the brass frame of a pinned plate shows.
func is_pinned_frame_shown() -> bool:
	return _pinned

## An open zone's status line: "Open · 5 activities", "Open · 1 activity", or
## "Open · nothing to do yet" for a zone with none (kit §6.5).
static func open_line(count: int) -> String:
	if count <= 0:
		return "Open" + SEPARATOR + "nothing to do yet"
	if count == 1:
		return "Open" + SEPARATOR + "1 activity"
	return "Open" + SEPARATOR + "%d activities" % count

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Works out the line, its icon, the ring and the colours for the state and
## hover.
func _compute() -> void:
	_line = ""
	_line_icon_texture = null
	_ring_action = null
	_line_color = ThemeConstants.LACQUER_CREAM
	_name_color = ThemeConstants.LACQUER_CREAM
	if _zone_data != null:
		_compute_for_state()

## The line, icon, ring and colours for the plate's map state.
func _compute_for_state() -> void:
	match _state:
		ZoneManager.ZoneMapState.CURRENT:
			_name_color = ThemeConstants.LACQUER_CREAM if _hovered else ThemeConstants.LACQUER_BRASS
			_ring_action = _running_idle_action()
		ZoneManager.ZoneMapState.OPEN:
			if _hovered:
				_line = CLICK_TO_TRAVEL
				_line_color = ThemeConstants.LACQUER_BRASS
			else:
				_line = open_line(ZoneManager.get_available_actions(_zone_data.zone_id).size())
				_line_color = ThemeConstants.LACQUER_TAN
		ZoneManager.ZoneMapState.LOCKED:
			_line = _zone_data.blocker_short_text
			_line_icon_texture = blocker_icon if _line != "" else null
		ZoneManager.ZoneMapState.UNCHARTED:
			_name_color = ThemeConstants.LACQUER_CREAM if _hovered else ThemeConstants.LACQUER_TAN
			_line = _zone_data.blocker_short_text
			_line_color = ThemeConstants.LACQUER_TAN

## The idle action running (the zone's training or foraging), or null.
func _running_idle_action() -> ZoneActionData:
	var action: ZoneActionData = ActionManager.get_current_action()
	if action is TrainingActionData or action is ForageActionData:
		return action
	return null

func _pick_plate_texture() -> Texture2D:
	match _state:
		ZoneManager.ZoneMapState.CURRENT:
			return current_hover_texture if _hovered else current_texture
		ZoneManager.ZoneMapState.LOCKED:
			return locked_hover_texture if _hovered else locked_texture
		ZoneManager.ZoneMapState.UNCHARTED:
			return uncharted_hover_texture if _hovered else uncharted_texture
	return open_hover_texture if _hovered else open_texture

## Draws what _compute() worked out.
func _apply() -> void:
	if not is_node_ready():
		return
	_plate_texture.texture = _pick_plate_texture()
	_pinned_frame.visible = _pinned
	_action_ring.show_action(_ring_action)
	_name_label.text = _zone_data.zone_name if _zone_data != null else ""
	_name_label.add_theme_color_override("font_color", _name_color)
	_name_label.position.y = NAME_TOP if is_line_shown() else NAME_ONLY_TOP
	# Beside the ring the name's slot is its width exactly (_plate_width), so
	# the centred name starts at RING_NAME_LEFT.
	_name_label.offset_left = RING_NAME_LEFT if _ring_action != null else NAME_EDGE
	_name_label.offset_right = -(RING_NAME_RIGHT if _ring_action != null else NAME_EDGE)
	size.x = _plate_width()
	_line_area.visible = is_line_shown()
	_line_icon.texture = _line_icon_texture
	_icon_margin.visible = _line_icon_texture != null
	_line_name.text = _line
	_line_name.visible = _line != ""
	_line_name.add_theme_color_override("font_color", _line_color)
	_fit_line()

## The kit's 248 px with a status line; without one, the name plus
## NAME_ONLY_PADDING, or plus RING_NAME_LEFT and RING_NAME_RIGHT while the ring
## shows, on the 2 px grid (never wider than the kit's plate).
func _plate_width() -> float:
	if is_line_shown():
		return PLATE_WIDTH
	var font: Font = _name_label.get_theme_font("font")
	var font_size: int = _name_label.get_theme_font_size("font_size")
	var width: float = ceilf(font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	width += RING_NAME_LEFT + RING_NAME_RIGHT if _ring_action != null else NAME_ONLY_PADDING
	width += fposmod(width, 2.0)
	return minf(width, PLATE_WIDTH)

## Sizes the text part: its whole text, or what the slot leaves beside the
## icon, where it ellipsizes.
func _fit_line() -> void:
	var room: float = _line_area.size.x
	if _icon_margin.visible:
		room -= _icon_margin.get_combined_minimum_size().x
	_line_name.custom_minimum_size.x = clampf(_line_text_width(), 0.0, maxf(room, 0.0))

## The width the text part's whole text needs, in whole px.
func _line_text_width() -> float:
	var font: Font = _line_name.get_theme_font("font")
	var font_size: int = _line_name.get_theme_font_size("font_size")
	return ceilf(font.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
