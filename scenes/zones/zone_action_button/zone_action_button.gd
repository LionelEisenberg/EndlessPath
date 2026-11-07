class_name ZoneActionButton
extends Control
## An activity card in the zone chest: a lacquer drawer with the action's icon,
## title, NEW seal, mode tag and detail lines (lacquer kit §5.5 › Card internals,
## positions local to the card). No text on it is ever cut off (style guide rule
## 14): the card is 392 wide and as tall as its lines, 72 for one title line and
## one detail line, 20 more for each title line after the first and 18 more for
## each detail line after the first. It grows on a 9-slice face with the carved
## socket as a piece of its own, the socket and the icon staying at the top,
## beside the title's first line.
## The detail row has two columns: what the action gives on the left (the detail
## slot, where a presenter stacks its rows), and at most one figure in the right
## column, right-aligned under the tag ("+1 Spirit / level"). A card names what
## you get, never a sentence joined with " · ": the timings, ranges and levels of
## a running action are the Now strip's (the user's review, 2026-10-24).
## A card that shows what it gives as icons alone (the Cycling and Riverbank
## Training cards: the pool, then the side it trains) puts them in the icon
## column, right-aligned under the tag, and leaves the detail line empty. Its
## title, with the NEW seal beside it, is centred on the card's height (#145).
##
## The card owns the drawer, the tag, the running state (an idle action that
## runs is pulled out to (-2, -2) on the running face and tagged RUNNING, and so
## is body refining while its board is up, since that board leaves the chest in
## view),
## hover, flash, the steady ready frame and click routing. A presenter scene
## picked by the action type (PRESENTER_SCENES) fills the detail slot and may
## change the tag (the adventure's ENTER) and the ready frame. A presenter that
## changes what its rows show calls relayout(), and the card takes the height
## its lines need.

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
## The card's height with one title line and one detail line, the least it is.
const MIN_HEIGHT: float = 72.0
## Where the running drawer is drawn, pulled out of the list.
const RUNNING_OFFSET: Vector2 = Vector2(-2, -2)

## The title row: the title's left edge, its top, and the width the title and
## NEW seal share before the tag.
const TITLE_X: float = 64.0
const TITLE_TOP: float = 14.0
const TITLE_ROW_WIDTH: float = 232.0
const SEAL_GAP: float = 10.0
## The tag's left edge; the tag and seal sit 1 px above the title's first line.
const TAG_X: float = 304.0
const TAG_RAISE: float = 1.0

## The detail row's width, how far under the title's last line it starts, and
## how much of the drawer shows under its last line.
const DETAIL_WIDTH: float = 316.0
const DETAIL_GAP: float = 4.0
const ROOM_UNDER_DETAIL: float = 16.0
## The right column takes at most half the line: a longer figure wraps at that
## width, right-aligned, and the left part keeps the rest.
const DETAIL_RIGHT_MAX_WIDTH: float = DETAIL_WIDTH / 2.0
## The icon column's top, under the tag, and how much of the drawer shows under
## its icons: 32 px icons make an 86 px card.
const ICON_COLUMN_TOP: float = 40.0
const ROOM_UNDER_ICONS: float = 14.0

const FLASH_TIMES: int = 2
const RUNNING_TAG_TEXT: String = "RUNNING"

## The faces, 9-slices drawn larger than the drawer by their baked shadow. The
## resting face is the choice drawer's; the running face keeps its brass caps in
## its corners. Patch margins are left, top, right, bottom.
const FACE_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer9_ai.png")
const FACE_MARGINS: Vector4i = Vector4i(4, 4, 6, 6)
const FACE_SHADOW: float = 2.0
const RUNNING_FACE_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer9_run_ai.png")
const RUNNING_FACE_MARGINS: Vector4i = Vector4i(16, 16, 20, 20)
const RUNNING_FACE_SHADOW: float = 4.0

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
	ZoneActionData.ActionType.TRIBULATION: preload("res://scenes/zones/zone_action_button/presenters/tribulation_presenter.tscn"),
	ZoneActionData.ActionType.BODY_REFINING: preload("res://scenes/zones/zone_action_button/presenters/body_refining_presenter.tscn"),
}

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

@export var action_data: ZoneActionData

@onready var _drawer: Control = %Drawer
@onready var _face: NinePatchRect = %Face
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _new_seal: TextureRect = %NewSeal
@onready var _tag: TextureRect = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _detail_row: HBoxContainer = %DetailRow
@onready var _detail_slot: VBoxContainer = %DetailSlot
@onready var _detail_right: RichTextLabel = %DetailRight
@onready var _icon_column: HBoxContainer = %IconColumn
@onready var _ready_frame: LacquerFrameOverlay = %ReadyFrame
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

var _presenter: ZoneActionPresenter = null
var _is_running: bool = false
var _shows_ready_frame: bool = false
## Keeps the ready frame hidden while a flash runs (both are the brass frame,
## so the flash would not show over it). Null when no flash holds it.
var _ready_frame_hold: Tween = null
## The tag shown while the action is not running (set_mode_tag).
var _tag_text: String = ""
var _tag_style: TagStyle = TagStyle.CARVED
## The width the right column takes, 0 while it is hidden.
var _detail_right_width: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	# A row a presenter changes without telling the card still re-measures it.
	_detail_row.minimum_size_changed.connect(relayout)
	_icon_column.minimum_size_changed.connect(relayout)
	relayout()
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

## The VBoxContainer at the detail line (x+64, 4 px under the title's last line,
## 316 wide less the right column and its 12 px gap): presenters stack the rows
## of their detail here, each as wide as get_detail_room().
func get_detail_slot() -> VBoxContainer:
	return _detail_slot

## Shows text in the detail line's right column, right-aligned at the tag's
## right edge (x+380), in tan or in color; "" hides it. The column hugs its text
## up to half the line and wraps at half the line past that. The left part keeps
## what the column leaves (get_detail_room): call this before fitting the left
## part.
func set_detail_right(text: String, color: Color = ThemeConstants.LACQUER_TAN) -> void:
	_detail_right.visible = text != ""
	_detail_right.add_theme_color_override(&"default_color", color)
	_detail_right_width = 0.0
	if text != "":
		_detail_right.autowrap_mode = TextServer.AUTOWRAP_OFF
		_detail_right.text = LacquerText.decimal_bbcode(text)
		var text_width: float = _detail_right.get_content_width()
		if text_width > DETAIL_RIGHT_MAX_WIDTH:
			_detail_right.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail_right_width = DETAIL_RIGHT_MAX_WIDTH
		else:
			_detail_right_width = 2.0 * ceilf(text_width / 2.0)
		_set_width(_detail_right, _detail_right_width)
	relayout()

## The HBoxContainer under the tag, right-aligned at its right edge (x+380): a
## presenter that shows what its action gives as icons alone reparents them here
## and leaves the detail slot empty. The card grows to hold them and centres its
## title on its height.
func get_icon_column() -> HBoxContainer:
	return _icon_column

## The right column's text, "" while it is hidden.
func get_detail_right_text() -> String:
	return _detail_right.get_parsed_text() if _detail_right.visible else ""

## The width the left part of the detail line has: the whole 316 px, or what
## the right column and its gap leave.
func get_detail_room() -> float:
	if not _detail_right.visible:
		return DETAIL_WIDTH
	return DETAIL_WIDTH - _detail_right_width - _detail_row.get_theme_constant(&"separation")

## Wraps a detail Label by word at the left part's room and lays the card out
## again: the card grows by the label's lines.
func fit_detail_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_width(label, get_detail_room())
	relayout()

## Sets a RichTextLacquer detail line (the lines that may hold a decimal
## point): text with its decimal points in Yatra One, wrapped by word at width,
## by default the left part's room (get_detail_room). Lays the card out again.
func set_detail_rich_text(rich: RichTextLabel, text: String, width: float = -1.0) -> void:
	rich.text = LacquerText.decimal_bbcode(text)
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_width(rich, get_detail_room() if width < 0.0 else width)
	relayout()

## Lays the card out from its text: the title row, the detail row 4 px under the
## title's last line, and the card 16 px under the detail row's last line (72 at
## least, an even height), with the drawer, its face and its frames. Icons in the
## icon column stand under the tag with 14 px of drawer under them, and a card with
## icons there and nothing on its detail line centres its title row on its
## height. Presenters call it after they change what their rows show.
func relayout() -> void:
	if not is_node_ready():
		return
	layout_title_row(_title, _new_seal, _tag)
	_detail_row.position = Vector2(TITLE_X, _title.position.y + _title.size.y + DETAIL_GAP)
	var row_height: float = _detail_row.get_combined_minimum_size().y
	_detail_row.size = Vector2(DETAIL_WIDTH, row_height)
	var bottom: float = _detail_row.position.y + row_height + ROOM_UNDER_DETAIL
	var has_icons: bool = _icon_column.get_child_count() > 0
	if has_icons:
		var icons_size: Vector2 = _icon_column.get_combined_minimum_size()
		_icon_column.position = Vector2(TITLE_X + DETAIL_WIDTH - icons_size.x, ICON_COLUMN_TOP)
		_icon_column.size = icons_size
		bottom = maxf(bottom, ICON_COLUMN_TOP + icons_size.y + ROOM_UNDER_ICONS)
	var height: float = maxf(MIN_HEIGHT, 2.0 * ceilf(bottom / 2.0))
	if has_icons and row_height == 0.0:
		_centre_title_row(height)
	var card_size := Vector2(CARD_WIDTH, height)
	custom_minimum_size = card_size
	size = card_size
	_drawer.size = card_size
	_apply_face()

## Shows the brass frame over the card, steadily, while shown is true (the
## adventure at its Madra threshold). A flash hides it until the flash ends.
func set_ready_frame(shown: bool) -> void:
	_shows_ready_frame = shown
	_apply_ready_frame()

## Places a drawer's title, the NEW seal right after it and the tag. The title
## wraps where the seal or the tag would start and hugs its widest line (rounded
## to even px); the seal stays beside its first line, and with the tag hidden
## the row runs on to the detail line's width. The activity cards and the
## technique drawers share it, so their title rows line up.
static func layout_title_row(title: Label, new_seal: Control, tag: Control) -> void:
	var font: Font = title.get_theme_font(&"font")
	var font_size: int = title.get_theme_font_size(&"font_size")
	var max_width: float = TITLE_ROW_WIDTH if tag.visible else DETAIL_WIDTH
	if new_seal.visible:
		max_width -= SEAL_GAP + new_seal.size.x
	var text_width: float = font.get_multiline_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size).x
	var title_width: float = minf(2.0 * ceilf(text_width / 2.0), max_width)
	title.position = Vector2(TITLE_X, TITLE_TOP)
	# The width first: a wrapping title's height depends on it.
	title.size = Vector2(title_width, title.size.y)
	title.size = Vector2(title_width, title.get_minimum_size().y)
	new_seal.position = Vector2(TITLE_X + title_width + SEAL_GAP, TITLE_TOP - TAG_RAISE)
	tag.position = Vector2(TAG_X, TITLE_TOP - TAG_RAISE)

## Fits a drawer's face to the drawer: the resting or the running 9-slice, drawn
## larger than the drawer by its baked shadow. The activity cards and the
## technique drawers share it.
static func fit_face(face: NinePatchRect, running: bool, drawer_size: Vector2) -> void:
	var margins: Vector4i = RUNNING_FACE_MARGINS if running else FACE_MARGINS
	var shadow: float = RUNNING_FACE_SHADOW if running else FACE_SHADOW
	face.texture = RUNNING_FACE_TEXTURE if running else FACE_TEXTURE
	face.patch_margin_left = margins.x
	face.patch_margin_top = margins.y
	face.patch_margin_right = margins.z
	face.patch_margin_bottom = margins.w
	face.position = Vector2.ZERO
	face.size = drawer_size + Vector2(shadow, shadow)

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
	_shows_ready_frame = false
	_apply_ready_frame()
	_is_running = _is_running_action()
	_spawn_presenter()
	if _presenter:
		_presenter.set_is_current(_is_running)
	_apply_tag()
	_refresh_new_seal()

func _spawn_presenter() -> void:
	if _presenter:
		_presenter.teardown()
		remove_child(_presenter)
		_presenter.queue_free()
		_presenter = null
	for slot: Control in [_detail_slot, _icon_column]:
		for child: Node in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
	set_detail_right("")

	var scene: PackedScene = PRESENTER_SCENES.get(action_data.action_type, DEFAULT_PRESENTER_SCENE) as PackedScene
	_presenter = scene.instantiate() as ZoneActionPresenter
	if _presenter == null:
		Log.error("ZoneActionButton: presenter scene for action_type %s has no ZoneActionPresenter root" % action_data.action_type)
		return
	add_child(_presenter)
	_presenter.setup(action_data, self)

## Moves the title and the NEW seal beside its first line down together, so the
## title stands centred on the card's height, on an even y.
func _centre_title_row(height: float) -> void:
	var shift: float = 2.0 * floorf((height - _title.size.y) / 4.0) - _title.position.y
	_title.position.y += shift
	_new_seal.position.y += shift

## Gives a wrapping label its width as its minimum and as its size, then drops
## the minimum size cached at its old width, so the boxes above it measure its
## lines at the new width at once (style guide, Long text).
static func _set_width(control: Control, width: float) -> void:
	control.custom_minimum_size.x = width
	control.size = Vector2(width, control.size.y)
	control.update_minimum_size()

## Puts the drawer where its state draws it and fits its face.
func _apply_face() -> void:
	_drawer.position = RUNNING_OFFSET if _is_running else Vector2.ZERO
	fit_face(_face, _is_running, _drawer.size)

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

## Shows the NEW seal while the action is unseen and lays the card out around it:
## a title that wrapped only beside the seal takes its room back.
func _refresh_new_seal() -> void:
	_new_seal.visible = action_data != null and not ZoneManager.is_action_seen(action_data.action_id)
	relayout()

func _mark_seen() -> void:
	if action_data == null:
		return
	ZoneManager.mark_action_seen(action_data.action_id)
	_refresh_new_seal()

func _is_idle_action() -> bool:
	if action_data == null:
		return false
	match action_data.action_type:
		ZoneActionData.ActionType.FORAGE, ZoneActionData.ActionType.TRAIN_STATS:
			return true
	return false

## True while the card's action runs and shows on the running face: an idle
## action, or body refining, whose board leaves the chest in view. The other
## session actions cover the chest or swap it while they run.
func _is_running_action() -> bool:
	if action_data == null or ActionManager.get_current_action() != action_data:
		return false
	return _is_idle_action() or action_data.action_type == ZoneActionData.ActionType.BODY_REFINING

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

## Hover shows the frame only. The NEW seal waits for the pointer to leave, so
## a card whose title wrapped beside it never shrinks under the pointer.
func _on_mouse_entered() -> void:
	_hover_frame.show()

func _on_mouse_exited() -> void:
	_hover_frame.hide()
	_mark_seen()

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	if action_data == null:
		return
	var running: bool = _is_running_action()
	if running != _is_running:
		_is_running = running
		if _presenter:
			_presenter.set_is_current(_is_running)
		_apply_face()
		_apply_tag()
	_refresh_new_seal()
