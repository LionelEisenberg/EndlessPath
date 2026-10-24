class_name ChoiceDrawer
extends Control

## One choice of the encounter the player stands on, as a lacquer drawer in the
## expedition page (spec: The right chest, Encounter section). It is as wide as
## the page's Here tray, 408, so its tag (a fight's or a talk's) and its LOCKED
## seal stand where the tray's tag and BOSS seal do, at x 320 and 308, and its
## detail runs to x 396. Where the zone chest's activity card (ZoneActionButton,
## 392 wide beside its list's rail) puts its pieces, it puts its own: the glyph in
## its carved socket (8 px in, 16 for the glyph), the choice's label at x 64 and
## the detail line under it.
## No text is cut off: the label wraps short of the tag or the seal (6 px, the
## tray's NAME_GAP), the detail wraps to x 396, and the drawer grows to hold them,
## 72 px at least. The face is a 9-slice (lacquer_drawer9_ai.png) and the socket a
## piece of its own, centred on the drawer. Under a detail the text starts 14 px
## down, as the card's does; a drawer with no detail centres its label instead of
## leaving an empty second line, and the tag and the seal stand on the label's
## first line (1 px above it). The height is an even number of px (the label's
## lines are 20 px, the detail's 18 with the 1 px pad of wrap_pad.tres), and the
## socket and glyph keep to the 2 px grid.
## setup() reads the choice and the drawer is then one of three things:
## - available: the label in cream. Hover frames it (the kit's frame_hover) and a
##   left press emits `pressed`.
## - locked (its requirements fail): the label in tan and the LOCKED seal where
##   the tag would be. No press, no hover frame.
## - completed (is_completed()): its completed_label (the label when it has
##   none) in tan. No press, no hover frame.
## Completed outranks locked: a choice that gates itself on the event it fires
## (the Aura Well's "Mark down the location") fails its own requirements the
## moment it is done, and reads as done.
## States are read when setup() runs; the page sets a drawer up again whenever it
## shows a tile.

## Emitted when the player presses the drawer while it is available.
signal pressed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The carved tags: a combat choice is a fight, a dialogue choice a talk.
const TAG_FIGHT: String = "FIGHT"
const TAG_TALK: String = "TALK"

## The drawer is the card's 72 tall at least, with its text 14 under the top and
## 16 above the bottom, so a label of one line and a detail of one line fill it.
const MIN_HEIGHT: float = 72.0
const TEXT_TOP: float = 14.0
const TEXT_BOTTOM: float = 16.0
## The label stops this far short of the tag or seal beside it, as the tray's name
## does (ExpeditionPage.NAME_GAP).
const TITLE_GAP: float = 6.0
## The tag and the seal stand this far above the label's top.
const TAG_RISE: float = 1.0
## The carved socket is 48 square and the glyph sits 8 px inside it.
const SOCKET_SIZE: float = 48.0
const GLYPH_INSET: float = 8.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _socket: Control = %Socket
@onready var _glyph: LacquerStripRect = %Glyph
@onready var _text_column: Control = %TextColumn
@onready var _title: Label = %Title
@onready var _tag: Control = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _locked_seal: Control = %LockedSeal
@onready var _detail: Label = %Detail
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _choice: EncounterChoice = null
var _glyph_texture: Texture2D = null
var _glyph_frame_size: Vector2i = Vector2i.ZERO
var _detail_text: String = ""
var _available: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the choice: its label, `detail` under it, the glyph strip at
## `glyph_frame_size` per frame (frame 0 shows; a null glyph shows none), a tag
## for the kind of choice, and the state its requirements and completion put it
## in. Setting a drawer up again replaces all of it and clears the hover frame.
func setup(choice: EncounterChoice, glyph: Texture2D, glyph_frame_size: Vector2i, detail: String) -> void:
	_choice = choice
	_glyph_texture = glyph
	_glyph_frame_size = glyph_frame_size
	_detail_text = detail
	_apply()

## Returns true when a press on the drawer picks its choice: the choice is
## neither completed nor locked.
func is_available() -> bool:
	return _available

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Puts the choice and its state on the nodes, then sizes the drawer to its text.
func _apply() -> void:
	if not is_node_ready():
		return
	var completed: bool = _choice != null and _choice.is_completed()
	var locked: bool = _choice != null and not completed and not _choice.evaluate_requirements()
	_available = _choice != null and not completed and not locked
	_title.text = _title_text(completed)
	if _available:
		_title.remove_theme_color_override(&"font_color")
	else:
		_title.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_TAN)
	var tag_text: String = _tag_text()
	_tag_label.text = tag_text
	_tag.visible = tag_text != "" and not locked
	_locked_seal.visible = locked
	_detail.text = _detail_text
	_glyph.strip = _glyph_texture
	_glyph.frame_size = _glyph_frame_size
	_glyph.set_frame(0)
	_glyph.visible = _glyph_texture != null
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _available else Control.CURSOR_ARROW
	_hover_frame.hide()
	_fit(locked)

## Wraps the label short of its neighbour (the seal when locked, else the tag) and
## the detail to the drawer's edge, makes the drawer as tall as that text asks (an
## even height, 72 at least) and seats the pieces on it: the text 14 down under a
## detail and centred without one, the tag and seal on the label's first line,
## the socket and glyph centred. (The label's width is set as a minimum and as the
## size, so its lines are counted at the new width at once.)
func _fit(locked: bool) -> void:
	var neighbour: Control = _locked_seal if locked else _tag
	var title_width: float = neighbour.position.x - TITLE_GAP - _text_column.position.x
	_title.custom_minimum_size.x = title_width
	_title.size.x = title_width
	# A change of width leaves the label's last height cached for the boxes above.
	_title.update_minimum_size()
	var has_detail: bool = _detail_text != ""
	_detail.visible = has_detail
	var column_height: float = _text_column.get_combined_minimum_size().y
	var height: float = _even_up(maxf(MIN_HEIGHT, TEXT_TOP + column_height + TEXT_BOTTOM))
	var column_top: float = TEXT_TOP if has_detail else _even_down((height - column_height) / 2.0)
	_text_column.position.y = column_top
	_tag.position.y = column_top - TAG_RISE
	_locked_seal.position.y = column_top - TAG_RISE
	var socket_top: float = _even_down((height - SOCKET_SIZE) / 2.0)
	_socket.position.y = socket_top
	_glyph.position.y = socket_top + GLYPH_INSET
	custom_minimum_size.y = height
	size.y = height

## The choice's label, or its completed label once it is done (the label when
## it has none).
func _title_text(completed: bool) -> String:
	if _choice == null:
		return ""
	if completed and _choice.completed_label != "":
		return _choice.completed_label
	return _choice.label

## The nearest even number of px at or above `value`, and at or below it.
func _even_up(value: float) -> float:
	return ceilf(value / 2.0) * 2.0

func _even_down(value: float) -> float:
	return floorf(value / 2.0) * 2.0

## FIGHT for a combat choice, TALK for a dialogue choice, "" for the rest.
func _tag_text() -> String:
	if _choice is CombatChoice:
		return TAG_FIGHT
	if _choice is DialogueChoice:
		return TAG_TALK
	return ""

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if _available:
		pressed.emit()

func _on_mouse_entered() -> void:
	if _available:
		_hover_frame.show()

func _on_mouse_exited() -> void:
	_hover_frame.hide()
