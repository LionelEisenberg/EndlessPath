class_name ZoneActionButton
extends Control
## An activity card in the zone chest: a lacquer drawer with the action's icon,
## title, NEW seal, mode tag and one detail line (lacquer kit §5.5 › Card
## internals, positions local to the card). The card is a fixed 392 x 72, or
## 96 when tall, so long text never widens it.
## The detail line has two columns: what the action gives on the left (the
## detail slot), and at most one figure in the right column, right-aligned
## under the tag ("+1 Spirit / level"). A card names what you get, never a
## sentence joined with " · ": the timings, ranges and levels of a running
## action are the Now strip's (the user's review, 2026-10-24).
##
## The card owns the drawer, the tag, the running state (an idle action that
## runs is pulled out to (-2, -2) on the running drawer and tagged RUNNING),
## hover, flash, the steady ready frame and click routing. A presenter scene
## picked by the action type (PRESENTER_SCENES) fills the detail slot and the
## footer slot, and may change the tag (the adventure's ENTER), the height and
## the ready frame.

## Emitted when the player clicks the card of the idle action that is running.
## The activity list uses it to flash the Now strip.
signal card_pressed_while_running

## How the mode tag is drawn: a carved recess with tan text (IDLE, ACTIVE, SHOP,
## STORY), the same recess with cream text (RUNNING), or the brass plate with
## ink text (ENTER).
enum TagStyle { CARVED, RUNNING, ENTER }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const CARD_WIDTH: float = 392.0
const SHORT_HEIGHT: float = 72.0
const TALL_HEIGHT: float = 96.0
## Where the running drawer is drawn, pulled out of the list.
const RUNNING_OFFSET: Vector2 = Vector2(-2, -2)

## The title row: the title's left edge, its top, and the width the title and
## NEW seal share before the tag.
const TITLE_X: float = 64.0
const TITLE_TOP: float = 14.0
const TITLE_ROW_WIDTH: float = 232.0
const SEAL_GAP: float = 10.0
## The tag's left edge; the tag and seal sit 1 px above the title's top.
const TAG_X: float = 304.0
const TAG_RAISE: float = 1.0

## The detail line's width, and how many lines a long detail wraps onto.
const DETAIL_WIDTH: float = 316.0
const DETAIL_WRAP_LINES: int = 2
## The right column takes at most half the line; a longer figure ends in an
## ellipsis.
const DETAIL_RIGHT_MAX_WIDTH: float = DETAIL_WIDTH / 2.0
## What a cut detail line ends in, and the joins it must not end on before it
## (the " · " separator, "/ s", a range dash).
const ELLIPSIS: String = "…"
const TRAILING_JOINS: String = " ·/–-,"

const FLASH_TIMES: int = 2
const RUNNING_TAG_TEXT: String = "RUNNING"

const DRAWER_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer_ai.png")
const DRAWER_RUN_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer_run_ai.png")
const DRAWER_TALL_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer_tall_ai.png")
const TAG_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_tag_ai.png")
const TAG_ENTER_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_tag_enter_ai.png")

## Maps ActionType to presenter scene. Types not listed here (NPC_DIALOGUE,
## ZONE_EVENT) use DEFAULT_PRESENTER_SCENE, which shows the description.
const DEFAULT_PRESENTER_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn")
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
	ZoneActionData.ActionType.ADVENTURE: preload("res://scenes/zones/zone_action_button/presenters/adventure_presenter.tscn"),
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/cycling_presenter.tscn"),
	ZoneActionData.ActionType.TRAIN_STATS: preload("res://scenes/zones/zone_action_button/presenters/training_presenter.tscn"),
	ZoneActionData.ActionType.MERCHANT: preload("res://scenes/zones/zone_action_button/presenters/merchant_presenter.tscn"),
}

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

@export var action_data: ZoneActionData

@onready var _drawer: Control = %Drawer
@onready var _face: TextureRect = %Face
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _new_seal: TextureRect = %NewSeal
@onready var _tag: TextureRect = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _detail_row: HBoxContainer = %DetailRow
@onready var _detail_slot: HBoxContainer = %DetailSlot
@onready var _detail_right: RichTextLabel = %DetailRight
@onready var _footer_slot: Control = %FooterSlot
@onready var _ready_frame: LacquerFrameOverlay = %ReadyFrame
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

var _presenter: ZoneActionPresenter = null
var _is_running: bool = false
var _is_tall: bool = false
var _shows_ready_frame: bool = false
## Keeps the ready frame hidden while a flash runs (both are the brass frame,
## so the flash would not show over it). Null when no flash holds it.
var _ready_frame_hold: Tween = null
## The tag shown while the action is not running (set_mode_tag).
var _tag_text: String = ""
var _tag_style: TagStyle = TagStyle.CARVED
## The width the right column's text takes, 0 while it is hidden.
var _detail_right_width: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	_apply_height()
	if action_data:
		_apply_action()

func _exit_tree() -> void:
	if ActionManager.current_action_changed.is_connected(_on_current_action_changed):
		ActionManager.current_action_changed.disconnect(_on_current_action_changed)
	if _presenter:
		_presenter.teardown()

## Shows the action on the card. Before the card is ready it is applied in
## _ready.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_node_ready() and action_data:
		_apply_action()

#-----------------------------------------------------------------------------
# PUBLIC API (presenters, the activity list and the technique drawer)
#-----------------------------------------------------------------------------

## Sets the tag shown while the action is not running. While an idle action
## runs the tag reads RUNNING; this tag shows again when it stops.
func set_mode_tag(text: String, style: TagStyle) -> void:
	_tag_text = text
	_tag_style = style
	_apply_tag()

## The HBoxContainer at the detail line (x+64, y+38, 316 wide less the right
## column and its 12 px gap): presenters put the left part of their detail
## line here.
func get_detail_slot() -> HBoxContainer:
	return _detail_slot

## Shows text in the detail line's right column, right-aligned at the tag's
## right edge (x+380), in tan or in color; "" hides it. The column takes at most
## half the line (a longer text ends in an ellipsis), and the left part keeps
## what it leaves (get_detail_room): call this before fitting the left part.
func set_detail_right(text: String, color: Color = ThemeConstants.LACQUER_TAN) -> void:
	_detail_right.visible = text != ""
	_detail_right.add_theme_color_override(&"default_color", color)
	_detail_right_width = 0.0
	if text != "":
		_detail_right_width = ceilf(fit_detail_rich_text(_detail_right, text, DETAIL_RIGHT_MAX_WIDTH))

## The right column's text, "" while it is hidden.
func get_detail_right_text() -> String:
	return _detail_right.get_parsed_text() if _detail_right.visible else ""

## The width the left part of the detail line has: the whole 316 px, or what
## the right column and its gap leave.
func get_detail_room() -> float:
	if not _detail_right.visible:
		return DETAIL_WIDTH
	return DETAIL_WIDTH - _detail_right_width - _detail_row.get_theme_constant(&"separation")

## A Control covering the drawer: presenters put pieces here at the kit's card
## positions (the adventure's Madra line, rod and hint).
func get_footer_slot() -> Control:
	return _footer_slot

## Uses the tall drawer (96) instead of the short one (72).
func set_tall(tall: bool) -> void:
	_is_tall = tall
	_apply_height()
	_apply_face()

## Shows the brass frame over the card, steadily, while shown is true (the
## adventure at its Madra threshold). A flash hides it until the flash ends.
func set_ready_frame(shown: bool) -> void:
	_shows_ready_frame = shown
	_apply_ready_frame()

## Fits a one-line detail Label into the left part of the detail line (316 px
## less the right column, kit §0). On a card whose action is not idle, a line
## wider than that wraps onto two lines in the tall drawer; otherwise the line
## ellipsizes and the card stays short.
func fit_detail_label(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var wraps: bool = not _is_idle_action() and width > get_detail_room()
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF
	label.max_lines_visible = DETAIL_WRAP_LINES if wraps else -1
	set_tall(wraps)

## Sets a RichTextLacquer detail line (the lines that may hold a decimal
## point): text with its decimal points in Yatra One, cut at a word with an
## ellipsis when it is wider than max_width, by default the left part's room
## (get_detail_room; kit §5.5: ellipsis), since RichTextLabel has no
## text_overrun_behavior. Returns the width the shown line takes, measured
## with the label's own font.
func fit_detail_rich_text(rich: RichTextLabel, text: String, max_width: float = -1.0) -> float:
	if max_width < 0.0:
		max_width = get_detail_room()
	var font: Font = rich.get_theme_font(&"normal_font")
	var font_size: int = rich.get_theme_font_size(&"normal_font_size")
	var shown: String = ellipsize_words(text, font, font_size, max_width)
	rich.text = LacquerText.decimal_bbcode(shown)
	return _text_width(shown, font, font_size)

## Returns text when it fits max_width at font_size. Otherwise returns its
## longest run of whole words that fits with an ellipsis after it, with no
## separator left before the ellipsis ("2–6 · every 12.25 s…"); a first word
## too long on its own is cut letter by letter.
static func ellipsize_words(text: String, font: Font, font_size: int, max_width: float) -> String:
	if _text_width(text, font, font_size) <= max_width:
		return text
	var words: PackedStringArray = text.split(" ", false)
	for count: int in range(words.size() - 1, 0, -1):
		var head: String = " ".join(words.slice(0, count)).rstrip(TRAILING_JOINS)
		if head != "" and _text_width(head + ELLIPSIS, font, font_size) <= max_width:
			return head + ELLIPSIS
	var letters: String = words[0] if not words.is_empty() else ""
	while letters != "":
		letters = letters.left(-1).rstrip(TRAILING_JOINS)
		if letters != "" and _text_width(letters + ELLIPSIS, font, font_size) <= max_width:
			return letters + ELLIPSIS
	return ELLIPSIS if _text_width(ELLIPSIS, font, font_size) <= max_width else ""

## Places a drawer's title, the NEW seal right after it and the tag. The title
## hugs its text (rounded to even px) up to where the seal or the tag would
## start, and the activity cards ellipsize it there. With wraps (the technique
## drawers) it wraps there instead and hugs its widest line, the seal stays
## beside its first line, and with the tag hidden the row runs on to the
## detail line's width. The activity cards and the technique drawers share it,
## so their title rows line up.
static func layout_title_row(title: Label, new_seal: Control, tag: Control, wraps: bool = false) -> void:
	var font: Font = title.get_theme_font(&"font")
	var font_size: int = title.get_theme_font_size(&"font_size")
	var max_width: float = DETAIL_WIDTH if wraps and not tag.visible else TITLE_ROW_WIDTH
	if new_seal.visible:
		max_width -= SEAL_GAP + new_seal.size.x
	var text_width: float
	if wraps:
		text_width = font.get_multiline_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size).x
	else:
		text_width = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var title_width: float = minf(2.0 * ceilf(text_width / 2.0), max_width)
	title.position = Vector2(TITLE_X, TITLE_TOP)
	# The width first: a wrapping title's height depends on it.
	title.size = Vector2(title_width, title.size.y)
	title.size = Vector2(title_width, title.get_minimum_size().y)
	new_seal.position = Vector2(TITLE_X + title_width + SEAL_GAP, TITLE_TOP - TAG_RAISE)
	tag.position = Vector2(TAG_X, TITLE_TOP - TAG_RAISE)

## Flashes the brass frame over the card twice (300 ms on, 300 ms off). A
## steady ready frame steps aside for the flash and returns after it.
func flash() -> void:
	_flash_frame.flash(FLASH_TIMES)
	_end_ready_frame_hold()
	if _shows_ready_frame and is_inside_tree():
		_ready_frame_hold = create_tween()
		_ready_frame_hold.tween_interval(FLASH_TIMES * 2.0 * LacquerFrameOverlay.FLASH_PHASE_SECONDS)
		_ready_frame_hold.tween_callback(_end_ready_frame_hold)
		_apply_ready_frame()

## Returns true while the NEW seal shows (the action has not been seen).
func is_new_shown() -> bool:
	return _new_seal.visible

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _apply_action() -> void:
	_title.text = action_data.action_name
	_icon.texture = action_data.icon
	_tag_text = ZoneActionGroups.mode_tag(action_data)
	_tag_style = TagStyle.CARVED
	_is_tall = false
	_shows_ready_frame = false
	_apply_ready_frame()
	_spawn_presenter()
	_is_running = _is_running_idle_action()
	if _presenter:
		_presenter.set_is_current(_is_running)
	_apply_height()
	_apply_face()
	_apply_tag()
	_refresh_new_seal()

func _spawn_presenter() -> void:
	if _presenter:
		_presenter.teardown()
		remove_child(_presenter)
		_presenter.queue_free()
		_presenter = null
	_clear_slot(_detail_slot)
	_clear_slot(_footer_slot)
	set_detail_right("")

	var scene: PackedScene = PRESENTER_SCENES.get(action_data.action_type, DEFAULT_PRESENTER_SCENE) as PackedScene
	_presenter = scene.instantiate() as ZoneActionPresenter
	if _presenter == null:
		Log.error("ZoneActionButton: presenter scene for action_type %s has no ZoneActionPresenter root" % action_data.action_type)
		return
	add_child(_presenter)
	_presenter.setup(action_data, self)

func _clear_slot(slot: Control) -> void:
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

func _apply_height() -> void:
	var card_size := Vector2(CARD_WIDTH, TALL_HEIGHT if _is_tall else SHORT_HEIGHT)
	custom_minimum_size = card_size
	size = card_size
	_drawer.size = card_size

## Picks the drawer face and centres the icon on its height, where each face
## draws its carved socket (y+20 in the 72 px drawers, y+32 in the tall one).
func _apply_face() -> void:
	_drawer.position = RUNNING_OFFSET if _is_running else Vector2.ZERO
	var face_height: float = SHORT_HEIGHT
	if _is_running:
		_face.texture = DRAWER_RUN_TEXTURE
	elif _is_tall:
		_face.texture = DRAWER_TALL_TEXTURE
		face_height = TALL_HEIGHT
	else:
		_face.texture = DRAWER_TEXTURE
	_face.size = _face.texture.get_size()
	_icon.position.y = (face_height - _icon.size.y) / 2.0

func _apply_ready_frame() -> void:
	_ready_frame.visible = _shows_ready_frame and _ready_frame_hold == null

func _end_ready_frame_hold() -> void:
	if _ready_frame_hold != null and _ready_frame_hold.is_valid():
		_ready_frame_hold.kill()
	_ready_frame_hold = null
	_apply_ready_frame()

func _apply_tag() -> void:
	var text: String = RUNNING_TAG_TEXT if _is_running else _tag_text
	var style: TagStyle = TagStyle.RUNNING if _is_running else _tag_style
	_tag_label.text = text
	_tag.texture = TAG_ENTER_TEXTURE if style == TagStyle.ENTER else TAG_TEXTURE
	match style:
		TagStyle.RUNNING:
			_tag_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM)
		TagStyle.ENTER:
			_tag_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_INK)
		_:
			_tag_label.remove_theme_color_override(&"font_color")

func _layout_title_row() -> void:
	layout_title_row(_title, _new_seal, _tag)

func _refresh_new_seal() -> void:
	_new_seal.visible = action_data != null and not ZoneManager.is_action_seen(action_data.action_id)
	_layout_title_row()

func _mark_seen() -> void:
	if action_data == null:
		return
	ZoneManager.mark_action_seen(action_data.action_id)
	_refresh_new_seal()

static func _text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _is_idle_action() -> bool:
	if action_data == null:
		return false
	match action_data.action_type:
		ZoneActionData.ActionType.FORAGE, ZoneActionData.ActionType.TRAIN_STATS:
			return true
	return false

func _is_running_idle_action() -> bool:
	return _is_idle_action() and ActionManager.get_current_action() == action_data

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or action_data == null:
		return
	_mark_seen()
	if _is_running:
		card_pressed_while_running.emit()
		return
	if ActionManager.get_current_action() == action_data:
		return
	if _presenter and not _presenter.can_activate():
		_presenter.on_activation_rejected()
		return
	ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	_hover_frame.show()
	_mark_seen()

func _on_mouse_exited() -> void:
	_hover_frame.hide()

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	if action_data == null:
		return
	var running: bool = _is_running_idle_action()
	if running != _is_running:
		_is_running = running
		if _presenter:
			_presenter.set_is_current(_is_running)
		_apply_face()
		_apply_tag()
	_refresh_new_seal()
