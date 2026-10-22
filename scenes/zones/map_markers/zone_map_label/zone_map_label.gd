class_name ZoneMapLabel
extends Control

## ZoneMapLabel
## A zone's plate on the zone map (kit §6.5): a 248x52 lacquer plate under the
## hex with the zone's name and one status line.
## - Current zone: the name in brass (cream on hover) and the running idle
##   action ("Aura Well · +1.5 Madra / s", "Foraging · a haul every 5 s"), or
##   the name alone, centred, when nothing idle runs.
## - Open zone: "Open · N activities" in tan, "Click to travel" in brass while
##   hovered.
## - Locked zone: the blocker in short ("Tribulation Guardian") after a swords
##   icon. Uncharted zone: the blocker in tan, its name tan until hovered.
## Hovered plates show their hover texture; a pinned plate (its popover is
## pinned) gets the brass frame. MapMarkers places and scales the plate under
## its hex every frame; pressing it emits pressed (MapMarkers turns that into
## plate_pressed).

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
## Before the line of a running training action (the Aura Well).
@export var training_icon: Texture2D
## Before the line of a running foraging action.
@export var forage_icon: Texture2D
## Before a locked zone's blocker.
@export var blocker_icon: Texture2D

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The name's top with a status line under it, and centred alone (kit §6.5).
const NAME_TOP: float = 6.0
const NAME_ONLY_TOP: float = 17.0

const SEPARATOR: String = " · "
const CLICK_TO_TRAVEL: String = "Click to travel"
## What foraging reads as on the plate, whatever the action's own name.
const FORAGING_WORD: String = "Foraging"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _plate_texture: TextureRect = %PlateTexture
@onready var _pinned_frame: LacquerFrameOverlay = %PinnedFrame
@onready var _name_label: Label = %NameLabel
@onready var _line_area: Control = %LineArea
@onready var _icon_margin: MarginContainer = %IconMargin
@onready var _line_icon: TextureRect = %LineIcon
@onready var _line_text: RichTextLabel = %LineText

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _zone_data: ZoneData = null
var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.OPEN
var _hovered: bool = false
var _pinned: bool = false

## What the plate shows, worked out by _compute() and drawn by _apply().
var _line: String = ""
var _line_icon_texture: Texture2D = null
var _line_color: Color = ThemeConstants.LACQUER_CREAM
var _name_color: Color = ThemeConstants.LACQUER_CREAM

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_apply()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the zone's plate for its map state.
func setup(zone_data: ZoneData, state: ZoneManager.ZoneMapState) -> void:
	_zone_data = zone_data
	_state = state
	refresh()

## Re-reads what the status line shows: the running idle action on the
## current zone's plate, the activity count on an open zone's.
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

## The zone the plate names.
func get_zone_data() -> ZoneData:
	return _zone_data

## The map state the plate was set up with.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## The status line as plain text, or "" when the plate shows the name alone.
func get_line_text() -> String:
	return _line

## True when the plate shows a status line under the name.
func is_line_shown() -> bool:
	return _line != ""

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

## Works out the line, its icon and the colours for the state and hover.
func _compute() -> void:
	_line = ""
	_line_icon_texture = null
	_line_color = ThemeConstants.LACQUER_CREAM
	_name_color = ThemeConstants.LACQUER_CREAM
	if _zone_data == null:
		return
	match _state:
		ZoneManager.ZoneMapState.CURRENT:
			_name_color = ThemeConstants.LACQUER_CREAM if _hovered else ThemeConstants.LACQUER_BRASS
			_compute_current_line()
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

## The current zone's line: the running idle action, or nothing.
func _compute_current_line() -> void:
	var action: ZoneActionData = ActionManager.get_current_action()
	var training := action as TrainingActionData
	var forage := action as ForageActionData
	if training != null:
		_line = training.action_name
		var madra_per_second: float = training.get_madra_per_second()
		if madra_per_second > 0.0:
			_line += SEPARATOR + "%s Madra / s" % LacquerText.rate(madra_per_second)
		_line_icon_texture = training_icon
	elif forage != null:
		_line = FORAGING_WORD + SEPARATOR + "a haul every %s s" % _seconds_text(forage.foraging_interval_in_sec)
		_line_icon_texture = forage_icon

## "5" for 5.0 s, "2.5" for 2.5 s.
func _seconds_text(seconds: float) -> String:
	if is_equal_approx(seconds, roundf(seconds)):
		return str(roundi(seconds))
	return String.num(seconds, 1)

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
	_name_label.text = _zone_data.zone_name if _zone_data != null else ""
	_name_label.add_theme_color_override("font_color", _name_color)
	_name_label.position.y = NAME_TOP if is_line_shown() else NAME_ONLY_TOP
	_line_area.visible = is_line_shown()
	_line_text.text = LacquerText.decimal_bbcode(_line)
	_line_text.add_theme_color_override("default_color", _line_color)
	_line_icon.texture = _line_icon_texture
	_icon_margin.visible = _line_icon_texture != null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
