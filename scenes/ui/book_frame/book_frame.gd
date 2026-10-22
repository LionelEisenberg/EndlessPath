class_name BookFrame
extends Control

## BookFrame
## The book every menu opens in: the book art with its open, close and
## page-turn animations, the close tab on the top edge and the bookmark, all
## recoloured per menu by a BookStyleData. A menu draws its own page content
## over the frame and shows it once the book lies open.
##
## Lives in book units: the 700x450 frame of the book spritesheet. Menus draw
## it at 2x, like the inventory always has.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The open animation finished and the book lies open.
signal opened
## The close animation finished.
signal closed
## The close tab was clicked.
signal close_requested
## A page turn finished.
signal page_turned

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The master book art's cover edge (light, mid, dark) and page border line,
## in BookStyleData.get_book_colors() order.
const BOOK_SOURCE_COLORS: Array[Color] = [
	Color(162 / 255.0, 112 / 255.0, 100 / 255.0),
	Color(128 / 255.0, 72 / 255.0, 69 / 255.0),
	Color(101 / 255.0, 51 / 255.0, 60 / 255.0),
	Color(230 / 255.0, 201 / 255.0, 169 / 255.0),
]

## The master bookmark art's colours (dark, mid, light), in
## BookStyleData.get_bookmark_colors() order.
const BOOKMARK_SOURCE_COLORS: Array[Color] = [
	Color(112 / 255.0, 34 / 255.0, 38 / 255.0),
	Color(160 / 255.0, 50 / 255.0, 50 / 255.0),
	Color(206 / 255.0, 92 / 255.0, 84 / 255.0),
]

## How long the bookmark takes to slide out from between the pages once the
## book lies open.
const BOOKMARK_SLIDE_SECONDS: float = 0.45

## Matches palette_swap.gdshader's MAX_COLORS.
const _PALETTE_SIZE: int = 8
const _CLOSE_ANIMATION: StringName = &"BookClosingAnimation"
const _PAGE_TURN_ANIMATION: StringName = &"PageTurningAnimation"

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## This book's colours. Null keeps the master art's colours.
@export var style: BookStyleData:
	set(value):
		style = value
		_apply_style()

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _book_background: TextureRect = %BookBackground
@onready var _book_animation_player: AnimationPlayer = %BookAnimationPlayer
@onready var _page_turning_rect: TextureRect = %PageTurningRect
@onready var _page_turning_animation_player: AnimationPlayer = %PageTurningAnimationPlayer
@onready var _close_tab: TextureButton = %CloseTab
## Clips the bookmark at the top page's bottom edge, so it slides out from
## between the pages.
@onready var _bookmark_clip: Control = %BookmarkClip
@onready var _bookmark: TextureRect = %Bookmark

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

enum _Motion { NONE, OPENING, CLOSING }

var _motion: _Motion = _Motion.NONE
var _bookmark_tween: Tween = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_close_tab.pressed.connect(close_requested.emit)
	_book_animation_player.animation_finished.connect(_on_book_animation_finished)
	_page_turning_animation_player.animation_finished.connect(_on_page_turning_animation_finished)
	_set_chrome_visible(false)
	_apply_style()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Plays the open animation. Emits opened once the book lies open. Calling it
## while the book closes turns the motion around.
func animate_open() -> void:
	var is_turning_around: bool = is_moving()
	_motion = _Motion.OPENING
	_set_chrome_visible(false)
	_book_animation_player.play_backwards(_CLOSE_ANIMATION)
	if not is_turning_around:
		# Played backwards, the close animation starts on its last key, and its
		# discrete track only applies the keys it crosses. Seek onto that key so
		# the book starts closed instead of on the frame it last showed: the
		# open book, until it has closed once.
		_book_animation_player.seek(_book_animation_player.current_animation_length, true)

## Plays the close animation and emits closed when it ends. Calling it while
## the book opens turns the motion around.
func animate_close() -> void:
	_motion = _Motion.CLOSING
	_set_chrome_visible(false)
	_book_animation_player.play(_CLOSE_ANIMATION)

## Turns a page: forwards when moving to a later section, backwards to an
## earlier one. Emits page_turned when the page has landed.
func turn_page(forward: bool) -> void:
	if forward:
		_page_turning_animation_player.play(_PAGE_TURN_ANIMATION)
	else:
		_page_turning_animation_player.play_backwards(_PAGE_TURN_ANIMATION)

## True while the book opens or closes.
func is_moving() -> bool:
	return _motion != _Motion.NONE

## True while the close tab and bookmark are shown, which is only when the
## book lies open.
func is_chrome_visible() -> bool:
	return _close_tab.visible

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_book_animation_finished(_animation_name: StringName) -> void:
	var finished: _Motion = _motion
	_motion = _Motion.NONE
	match finished:
		_Motion.OPENING:
			_set_chrome_visible(true)
			opened.emit()
		_Motion.CLOSING:
			closed.emit()

func _on_page_turning_animation_finished(_animation_name: StringName) -> void:
	page_turned.emit()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## The close tab and the bookmark only exist on the open book: the closing
## frames have no page edge for them to sit on. The bookmark slides out as it
## appears.
func _set_chrome_visible(is_shown: bool) -> void:
	_close_tab.visible = is_shown
	_bookmark_clip.visible = is_shown
	if _bookmark_tween:
		_bookmark_tween.kill()
		_bookmark_tween = null
	if is_shown:
		_slide_bookmark_out()

func _slide_bookmark_out() -> void:
	_bookmark.position.y = -_bookmark.size.y
	_bookmark_tween = create_tween()
	_bookmark_tween.tween_property(_bookmark, "position:y", 0.0, BOOKMARK_SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _apply_style() -> void:
	if not is_node_ready():
		return
	var book_colors: PackedColorArray = PackedColorArray(BOOK_SOURCE_COLORS)
	var bookmark_colors: PackedColorArray = PackedColorArray(BOOKMARK_SOURCE_COLORS)
	if style:
		book_colors = style.get_book_colors()
		bookmark_colors = style.get_bookmark_colors()
	_set_palette(_book_background.material as ShaderMaterial, BOOK_SOURCE_COLORS, book_colors)
	# The turning page carries the page border line too.
	_set_palette(_page_turning_rect.material as ShaderMaterial, BOOK_SOURCE_COLORS, book_colors)
	_set_palette(_bookmark.material as ShaderMaterial, BOOKMARK_SOURCE_COLORS, bookmark_colors)

func _set_palette(palette_material: ShaderMaterial, sources: Array[Color], targets: PackedColorArray) -> void:
	var padded_sources: PackedColorArray = PackedColorArray(sources)
	var padded_targets: PackedColorArray = targets.duplicate()
	padded_sources.resize(_PALETTE_SIZE)
	padded_targets.resize(_PALETTE_SIZE)
	palette_material.set_shader_parameter("source_colors", padded_sources)
	palette_material.set_shader_parameter("target_colors", padded_targets)
	palette_material.set_shader_parameter("color_count", mini(sources.size(), targets.size()))
