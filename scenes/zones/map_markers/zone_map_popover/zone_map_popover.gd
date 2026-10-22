class_name ZoneMapPopover
extends Control

## ZoneMapPopover
## The zone map's popover for a locked or uncharted zone (kit §6.6), drawn by
## MapMarkers beside the zone's hex. Two cards, one shown at a time:
## - Locked: notch on the right, placed left of the hex. The LOCKED chop, the
##   zone name and the requirement (two lines at most); pinned, a × and,
##   when the requirement names a card in the current zone, "Show me".
## - Uncharted: notch on the left, placed right of the hex. The UNKNOWN tag,
##   the zone name and the requirement; pinned, a ×.
## A preview (hover, after 150 ms) uses the plain board with no buttons; a
## pinned popover uses the board with brass caps. The popover's top-left is
## the card's top-left (the locked card's own, the uncharted card's notch),
## so MapMarkers places it at the kit's offset from the hex centre.

## Emitted when the player presses the ×.
signal close_pressed

## Emitted when the player presses "Show me", with the card's action id.
signal show_me_pressed(action_id: String)

## Emitted on any left press on the popover (its card or a button), so a click
## on it is never taken for a click outside it.
signal pressed_inside

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Cards")
## Pinned locked card with brass caps and room for Show me (276x176 file).
@export var locked_pinned_texture: Texture2D
## Locked hover preview, no caps or buttons (276x136 file).
@export var locked_preview_texture: Texture2D
## Pinned uncharted card with brass caps (276x116 file).
@export var uncharted_pinned_texture: Texture2D
## Uncharted hover preview (276x116 file).
@export var uncharted_preview_texture: Texture2D

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _locked_card: TextureRect = %LockedCard
@onready var _locked_title: Label = %LockedTitle
@onready var _locked_body: Label = %LockedBody
@onready var _locked_close: TextureButton = %LockedClose
@onready var _show_me_button: TextureButton = %ShowMeButton
@onready var _show_me_hover: LacquerFrameOverlay = %ShowMeHover
@onready var _uncharted_card: TextureRect = %UnchartedCard
@onready var _uncharted_title: Label = %UnchartedTitle
@onready var _uncharted_body: Label = %UnchartedBody
@onready var _uncharted_close: TextureButton = %UnchartedClose

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _zone_data: ZoneData = null
var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.LOCKED
var _pinned: bool = false
var _show_me: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_locked_close.pressed.connect(_on_close_pressed)
	_uncharted_close.pressed.connect(_on_close_pressed)
	_show_me_button.pressed.connect(_on_show_me_pressed)
	_show_me_button.mouse_entered.connect(_show_me_hover.show)
	_show_me_button.mouse_exited.connect(_show_me_hover.hide)
	for card: Control in [_locked_card, _uncharted_card]:
		card.gui_input.connect(_on_card_gui_input)
	for button: BaseButton in [_locked_close, _uncharted_close, _show_me_button]:
		button.button_down.connect(pressed_inside.emit)
	_apply()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the zone's popover: the locked or the uncharted card, pinned (× and,
## with show_me, the Show me button) or as a hover preview.
func setup(zone_data: ZoneData, state: ZoneManager.ZoneMapState, pinned: bool, show_me: bool) -> void:
	_zone_data = zone_data
	_state = state
	_pinned = pinned
	_show_me = show_me
	_apply()

## The zone the popover describes, or null before setup().
func get_zone_data() -> ZoneData:
	return _zone_data

## The map state the popover was set up with: LOCKED or UNCHARTED.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## Both cards (the locked and the uncharted one), which take the pointer.
func get_cards() -> Array[Control]:
	return [_locked_card, _uncharted_card]

## True for a pinned popover, false for a hover preview.
func is_pinned() -> bool:
	return _pinned

## True when the × shows (pinned popovers only).
func is_close_shown() -> bool:
	return _pinned

## True when the "Show me" button shows: a pinned locked popover whose
## requirement names a card in the current zone.
func is_show_me_shown() -> bool:
	return _pinned and _show_me and not _is_uncharted()

## The zone name the card shows.
func get_title_text() -> String:
	return _zone_data.zone_name if _zone_data != null else ""

## The requirement sentence the card shows.
func get_body_text() -> String:
	return _zone_data.requirement_text if _zone_data != null else ""

## The card texture drawn now (its board, preview or pinned).
func get_card_texture() -> Texture2D:
	return _active_card().texture

## The shown card's rect in canvas px, its baked shadow included.
func get_card_rect() -> Rect2:
	return _active_card().get_global_rect()

## True when the canvas point lies on the shown card.
func contains_point(point: Vector2) -> bool:
	return visible and get_card_rect().has_point(point)

## The × of the shown card.
func get_close_button() -> BaseButton:
	return _uncharted_close if _is_uncharted() else _locked_close

## The locked card's "Show me" button.
func get_show_me_button() -> BaseButton:
	return _show_me_button

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _is_uncharted() -> bool:
	return _state == ZoneManager.ZoneMapState.UNCHARTED

func _active_card() -> TextureRect:
	return _uncharted_card if _is_uncharted() else _locked_card

func _apply() -> void:
	if not is_node_ready():
		return
	var uncharted: bool = _is_uncharted()
	_locked_card.visible = not uncharted
	_uncharted_card.visible = uncharted
	if uncharted:
		_uncharted_card.texture = uncharted_pinned_texture if _pinned else uncharted_preview_texture
		_uncharted_card.reset_size()
		_uncharted_title.text = get_title_text()
		_uncharted_body.text = get_body_text()
		_uncharted_close.visible = _pinned
	else:
		_locked_card.texture = locked_pinned_texture if _pinned else locked_preview_texture
		# The preview board is shorter: shrink the card back to its texture.
		_locked_card.reset_size()
		_locked_title.text = get_title_text()
		_locked_body.text = get_body_text()
		_locked_close.visible = _pinned
		_show_me_button.visible = is_show_me_shown()
	_show_me_hover.hide()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_card_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		pressed_inside.emit()

func _on_close_pressed() -> void:
	close_pressed.emit()

func _on_show_me_pressed() -> void:
	if _zone_data != null:
		show_me_pressed.emit(_zone_data.requirement_action_id)
