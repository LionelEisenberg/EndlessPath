class_name LogWindow
extends Control

## The lacquer Log board (lacquer kit §5.3 and §0) and the full log.
##
## The root is the log's 440x204 slot (the kit's five-line rect); view states
## place it by its top-left, as any Control. Inside it, the board hugs its
## content: lacquer_log<n>_ai for n lines, 74 + 26n px tall, n = 1 to 5 (the
## one-line board, empty, before anything is logged). It sits on the slot's
## bottom edge and grows upward one line at a time, or hangs from the slot's
## top edge when the slot is in the upper half of the screen (the adventure
## view puts it at the top left). Up to five lines, newest at the bottom, with
## their BBCode stripped. Lines fade by colour steps, never by opacity: ages 0
## and 1 keep their tone, age 2 is tan, ages 3 and 4 are dim, and each bullet
## takes the same colour.
##
## The full log is a taller board in the same place with every line LogManager
## keeps (at most LogManager.HISTORY_LIMIT), scrolling, newest at the bottom,
## 26 px apart in a text area of whole lines. Its rail's end caps are lit only
## when the text can scroll that way (kit §4.4). L, Escape while it is open,
## and LogManager.toggle_window() open and close it. It never opens while the
## log is hidden (the merchant hides it), and hiding the log closes it.

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## A line's colour family, read from its first [color] tag.
enum Tone { BRASS, CREAM, MADRA, TAN }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Lines the board shows.
const MAX_LINES: int = 5
## Board height: 74 px of title and margins plus 26 px per line (kit §0).
const BOARD_BASE_HEIGHT: float = 74.0
const LINE_HEIGHT: float = 26.0
## The full log's board: from the bottom line up to just under the Goals board
## in the zone view (1056 − 560 = 496).
const FULL_LOG_HEIGHT: float = 560.0
## Lines from age 2 on lose their tone (kit §5.3).
const TAN_AGE: int = 2
const DIM_AGE: int = 3

## A colour tag and its value.
const _COLOR_TAG_PATTERN: String = r"\[color=([^\]]+)\]"
## Any lowercase BBCode tag, opening or closing, with or without a value. Tags
## RichTextLabel would not parse, such as "[DEV]", stay as text, as it shows
## them.
const _BBCODE_TAG_PATTERN: String = r"\[/?[a-z_]+(?:[= ][^\]]*)?\]"
## What Color.from_string() returns for a value that is neither a colour name
## nor an HTML code: no parsed colour has negative channels.
const _NOT_A_COLOUR: Color = Color(-1.0, -1.0, -1.0, -1.0)
## Below this saturation a colour reads as white or grey, not by its hue.
const _NEUTRAL_SATURATION: float = 0.15
## A neutral colour this bright reads as cream; darker greys read as tan.
const _CREAM_VALUE: float = 0.85
## Hue bands in degrees: orange to yellow is brass, yellow-green to green is
## cream, cyan to blue is Madra. Reds, magentas and purples fall outside.
const _BRASS_HUE_FROM: float = 25.0
const _CREAM_HUE_FROM: float = 70.0
const _MADRA_HUE_FROM: float = 165.0
const _MADRA_HUE_TO: float = 260.0

static var _color_tag_regex: RegEx = null
static var _bbcode_tag_regex: RegEx = null

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## lacquer_log1_ai to lacquer_log5_ai, one per line count.
@export var board_textures: Array[Texture2D] = []
@export var brass_bullet: Texture2D = null
@export var cream_bullet: Texture2D = null
@export var madra_bullet: Texture2D = null
@export var tan_bullet: Texture2D = null
@export var dim_bullet: Texture2D = null
## The full log's rail end caps: lit (brass arrow) when the text can scroll
## that way, carved when it can't.
@export var rail_up_on: Texture2D = null
@export var rail_up_off: Texture2D = null
@export var rail_down_on: Texture2D = null
@export var rail_down_off: Texture2D = null

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _board: Control = %Board
@onready var _board_texture: TextureRect = %BoardTexture
@onready var _full_board: Control = %FullBoard
@onready var _full_log_text: RichTextLabel = %FullLogText
@onready var _line_rows: Array[Control] = [%Line0, %Line1, %Line2, %Line3, %Line4]
@onready var _line_bullets: Array[TextureRect] = [%LineBullet0, %LineBullet1, %LineBullet2, %LineBullet3, %LineBullet4]
@onready var _line_labels: Array[Label] = [%LineLabel0, %LineLabel1, %LineLabel2, %LineLabel3, %LineLabel4]

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _full_log_open: bool = false
## Lines in the full log's text since it was last filled.
var _full_log_line_count: int = 0
## The board's current height, kept so a move can re-hang it.
var _board_height: float = BOARD_BASE_HEIGHT + LINE_HEIGHT
## The full log's scrollbar, styled as the lacquer rail.
var _full_log_bar: VScrollBar = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	LogManager.message_logged.connect(_on_message_logged)
	LogManager.visibility_toggled.connect(toggle_full_log)
	item_rect_changed.connect(_on_item_rect_changed)
	visibility_changed.connect(_on_visibility_changed)
	_full_log_bar = _full_log_text.get_v_scroll_bar()
	_full_log_bar.value_changed.connect(_on_full_log_scrolled)
	_full_log_bar.changed.connect(_refresh_rail_caps)
	_full_board.visible = false
	_refresh_rail_caps()
	_update_board()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_log"):
		toggle_full_log()
		get_viewport().set_input_as_handled()
	elif _full_log_open and event.is_action_pressed("ui_cancel"):
		toggle_full_log()
		get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Opens the full log with every line LogManager keeps, or closes it and shows
## the five-line board again. Does not open it while the log is hidden.
func toggle_full_log() -> void:
	if not _full_log_open and not is_visible_in_tree():
		return
	_full_log_open = not _full_log_open
	if _full_log_open:
		_fill_full_log()
	_full_board.visible = _full_log_open
	_board.visible = not _full_log_open

## True while the full log is open.
func is_full_log_open() -> bool:
	return _full_log_open

## The tone of a logged line, from its first [color] tag: gold, yellow, orange
## and other brass hues are BRASS; cyan, blue and other blues are MADRA; green,
## lime and white are CREAM; anything else, or no colour, is TAN.
static func tone_for(bbcode: String) -> Tone:
	if _color_tag_regex == null:
		_color_tag_regex = RegEx.create_from_string(_COLOR_TAG_PATTERN)
	var found: RegExMatch = _color_tag_regex.search(bbcode)
	if found == null:
		return Tone.TAN
	var colour: Color = Color.from_string(found.get_string(1).strip_edges(), _NOT_A_COLOUR)
	if colour == _NOT_A_COLOUR:
		return Tone.TAN
	if colour.s < _NEUTRAL_SATURATION:
		return Tone.CREAM if colour.v >= _CREAM_VALUE else Tone.TAN
	var hue: float = colour.h * 360.0
	if hue >= _BRASS_HUE_FROM and hue < _CREAM_HUE_FROM:
		return Tone.BRASS
	if hue >= _CREAM_HUE_FROM and hue < _MADRA_HUE_FROM:
		return Tone.CREAM
	if hue >= _MADRA_HUE_FROM and hue < _MADRA_HUE_TO:
		return Tone.MADRA
	return Tone.TAN

## A logged line without its BBCode tags.
static func plain_text(bbcode: String) -> String:
	if _bbcode_tag_regex == null:
		_bbcode_tag_regex = RegEx.create_from_string(_BBCODE_TAG_PATTERN)
	return _bbcode_tag_regex.sub(bbcode, "", true)

#-----------------------------------------------------------------------------
# BOARD
#-----------------------------------------------------------------------------

## Shows the newest MAX_LINES lines, newest at the bottom, and sizes the board.
func _update_board() -> void:
	var history: Array[String] = LogManager.get_history()
	var line_count: int = mini(history.size(), MAX_LINES)
	for age: int in range(MAX_LINES):
		var shown: bool = age < line_count
		_line_rows[age].visible = shown
		if shown:
			_show_line(age, history[history.size() - 1 - age])
	var board_lines: int = maxi(line_count, 1)
	_board_texture.texture = board_textures[board_lines - 1]
	_board_height = BOARD_BASE_HEIGHT + LINE_HEIGHT * board_lines
	_hang_boards()

func _show_line(age: int, bbcode: String) -> void:
	_line_labels[age].text = plain_text(bbcode)
	var tone: Tone = tone_for(bbcode)
	var colour: Color = _tone_colour(tone)
	var bullet: Texture2D = _tone_bullet(tone)
	if age >= DIM_AGE:
		colour = ThemeConstants.LACQUER_DIM
		bullet = dim_bullet
	elif age >= TAN_AGE:
		colour = ThemeConstants.LACQUER_TAN
		bullet = tan_bullet
	_line_labels[age].add_theme_color_override("font_color", colour)
	_line_bullets[age].texture = bullet

## Sets both boards against the slot's bottom edge, or its top edge when the
## slot sits in the upper half of the screen.
func _hang_boards() -> void:
	var from_top: bool = position.y + size.y * 0.5 < get_parent_area_size().y * 0.5
	_hang(_board, _board_height, from_top)
	_hang(_full_board, FULL_LOG_HEIGHT, from_top)

## The given height against one edge of the slot. The width stays the
## board's own 440 px, whatever size a view gives the slot.
func _hang(board: Control, height: float, from_top: bool) -> void:
	var anchor: float = 0.0 if from_top else 1.0
	board.anchor_top = anchor
	board.anchor_bottom = anchor
	board.offset_top = 0.0 if from_top else -height
	board.offset_bottom = height if from_top else 0.0

#-----------------------------------------------------------------------------
# FULL LOG
#-----------------------------------------------------------------------------

func _fill_full_log() -> void:
	_full_log_text.clear()
	_full_log_line_count = 0
	for bbcode: String in LogManager.get_history():
		_add_full_log_line(bbcode)

## One line in its tone with its bullet, under the lines already there, then
## the oldest lines go until no more than LogManager keeps are left. Lines in
## the full log do not fade.
func _add_full_log_line(bbcode: String) -> void:
	if _full_log_line_count > 0:
		_full_log_text.newline()
	_full_log_line_count += 1
	var tone: Tone = tone_for(bbcode)
	_full_log_text.add_image(_tone_bullet(tone), 10, 10)
	_full_log_text.add_text("  ")
	_full_log_text.push_color(_tone_colour(tone))
	_full_log_text.add_text(plain_text(bbcode))
	_full_log_text.pop()
	while _full_log_line_count > LogManager.HISTORY_LIMIT:
		_full_log_text.remove_paragraph(0)
		_full_log_line_count -= 1

## Lights each end cap of the rail when the text can scroll that way (kit
## §4.4), in every button state.
func _refresh_rail_caps() -> void:
	var can_scroll_up: bool = _full_log_bar.value > _full_log_bar.min_value
	var can_scroll_down: bool = _full_log_bar.value + _full_log_bar.page < _full_log_bar.max_value
	_set_cap_icons(&"decrement", rail_up_on if can_scroll_up else rail_up_off)
	_set_cap_icons(&"increment", rail_down_on if can_scroll_down else rail_down_off)

func _set_cap_icons(cap: StringName, texture: Texture2D) -> void:
	for state: String in ["", "_highlight", "_pressed"]:
		_full_log_bar.add_theme_icon_override(StringName(cap + state), texture)

#-----------------------------------------------------------------------------
# TONES
#-----------------------------------------------------------------------------

func _tone_colour(tone: Tone) -> Color:
	match tone:
		Tone.BRASS:
			return ThemeConstants.LACQUER_BRASS
		Tone.CREAM:
			return ThemeConstants.LACQUER_CREAM
		Tone.MADRA:
			return ThemeConstants.LACQUER_MADRA
		_:
			return ThemeConstants.LACQUER_TAN

func _tone_bullet(tone: Tone) -> Texture2D:
	match tone:
		Tone.BRASS:
			return brass_bullet
		Tone.CREAM:
			return cream_bullet
		Tone.MADRA:
			return madra_bullet
		_:
			return tan_bullet

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_message_logged(bbcode: String) -> void:
	_update_board()
	if _full_log_open:
		_add_full_log_line(bbcode)

## A view state moved the slot: hang the boards from the right edge again.
func _on_item_rect_changed() -> void:
	_hang_boards()

## A hidden log closes its full log: the board shows again when the log does.
func _on_visibility_changed() -> void:
	if _full_log_open and not is_visible_in_tree():
		toggle_full_log()

func _on_full_log_scrolled(_value: float) -> void:
	_refresh_rail_caps()
