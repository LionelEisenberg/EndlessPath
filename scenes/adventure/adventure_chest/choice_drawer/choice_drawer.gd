class_name ChoiceDrawer
extends Control

## One choice of the encounter the player stands on, as a lacquer drawer in the
## expedition page (spec: The right chest, Encounter section). It copies the
## zone chest's activity card (ZoneActionButton) at the card's offsets: the
## drawer face, the glyph in its carved socket at (16, 20), the choice's label at
## (64, 14), a carved tag at (304, 13) for a fight or a talk, the LOCKED seal at
## (292, 13) and one detail line at (64, 38). It is a fixed 392 x 72, so a long
## label or detail ellipsizes instead of widening it.
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

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _glyph: LacquerStripRect = %Glyph
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

## Puts the choice and its state on the nodes.
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

## The choice's label, or its completed label once it is done (the label when
## it has none).
func _title_text(completed: bool) -> String:
	if _choice == null:
		return ""
	if completed and _choice.completed_label != "":
		return _choice.completed_label
	return _choice.label

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
