extends GutTest

## Integration tests for BookFrame: its open, close and page-turn signals, the
## chrome that only shows on the open book, the close tab, and the per-book
## palette it hands the shader.

const BookFrameScene: PackedScene = preload("res://scenes/ui/book_frame/book_frame.tscn")
const ABILITIES_STYLE: BookStyleData = preload("res://resources/ui/book_styles/abilities_book_style.tres")

## Longer than the 0.3 s open and close and the 0.54 s page turn.
const ANIMATION_TIMEOUT: float = 2.0

var _frame: BookFrame

func before_each() -> void:
	_frame = BookFrameScene.instantiate() as BookFrame
	add_child_autofree(_frame)

#-----------------------------------------------------------------------------
# OPENING AND CLOSING
#-----------------------------------------------------------------------------

func test_chrome_is_hidden_before_the_book_opens() -> void:
	assert_false(_frame.is_chrome_visible(), "close tab and bookmark wait for the open book")

func test_open_emits_opened_and_shows_the_chrome() -> void:
	watch_signals(_frame)
	_frame.animate_open()
	assert_true(_frame.is_moving())
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "opened")
	assert_false(_frame.is_moving())
	assert_true(_frame.is_chrome_visible())

func test_close_emits_closed_and_hides_the_chrome() -> void:
	_frame.animate_open()
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	watch_signals(_frame)
	_frame.animate_close()
	assert_false(_frame.is_chrome_visible(), "the chrome leaves before the pages fold")
	await wait_for_signal(_frame.closed, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "closed")

func test_closing_while_opening_turns_the_book_around() -> void:
	watch_signals(_frame)
	_frame.animate_open()
	await wait_frames(2)
	_frame.animate_close()
	await wait_for_signal(_frame.closed, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "closed")
	assert_signal_not_emitted(_frame, "opened", "an interrupted open never reports the book open")

#-----------------------------------------------------------------------------
# PAGE TURN AND CLOSE TAB
#-----------------------------------------------------------------------------

func test_turning_a_page_emits_page_turned() -> void:
	watch_signals(_frame)
	_frame.turn_page(true)
	await wait_for_signal(_frame.page_turned, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "page_turned")

func test_turning_back_emits_page_turned() -> void:
	watch_signals(_frame)
	_frame.turn_page(false)
	await wait_for_signal(_frame.page_turned, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "page_turned")

func test_close_tab_requests_a_close() -> void:
	watch_signals(_frame)
	var close_tab: TextureButton = _frame.find_child("CloseTab", true, false)
	close_tab.pressed.emit()
	assert_signal_emitted(_frame, "close_requested")

func test_close_tab_stays_above_the_page() -> void:
	# The page's top edge is solid from y 32 under the tab. A taller tab would
	# catch clicks meant for the page corner and close the book.
	var close_tab: TextureButton = _frame.find_child("CloseTab", true, false)
	var tab_rect: Rect2 = Rect2(close_tab.position, close_tab.size)
	assert_lte(tab_rect.end.y, 34.0)

func test_close_tab_has_no_hover_state() -> void:
	# Like the side tabs: no hover art, no tooltip, no hand cursor.
	var close_tab: TextureButton = _frame.find_child("CloseTab", true, false)
	assert_null(close_tab.texture_hover)
	assert_null(close_tab.texture_pressed)
	assert_eq(close_tab.tooltip_text, "")
	assert_eq(close_tab.mouse_default_cursor_shape, Control.CURSOR_ARROW)

func test_close_glyph_is_the_game_font_x() -> void:
	# The X is text in the game's font, like the cycling view's "X ESC", not art.
	var glyph: Label = _frame.find_child("CloseGlyph", true, false) as Label
	assert_not_null(glyph)
	assert_eq(glyph.text, "X")

func test_bookmark_hangs_a_short_way_below_the_book() -> void:
	# The page stack ends at y 427; the ribbon hangs about 27 below it.
	var clip: Control = _frame.find_child("BookmarkClip", true, false)
	assert_lte(clip.position.y + clip.size.y, 455.0)

func test_bookmark_sits_between_the_old_spot_and_the_right_edge() -> void:
	# It was centred at x 521; the book's right edge is at about 645.
	var clip: Control = _frame.find_child("BookmarkClip", true, false)
	assert_almost_eq(clip.position.x + clip.size.x / 2.0, 583.0, 2.0)

func test_bookmark_slides_out_once_the_book_is_open() -> void:
	var bookmark: Control = _frame.find_child("Bookmark", true, false)
	_frame.animate_open()
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	assert_lt(bookmark.position.y, 0.0, "starts tucked between the pages")
	await wait_seconds(BookFrame.BOOKMARK_SLIDE_SECONDS + 0.2)
	assert_eq(bookmark.position.y, 0.0, "has slid all the way out")

func test_the_open_books_art_catches_clicks() -> void:
	# A click on the backdrop closes the book, so clicks on the book itself
	# (even on bare page) must stop here. The area is the open book's art.
	var hit_area: Control = _frame.find_child("BookHitArea", true, false)
	assert_eq(hit_area.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(Rect2(hit_area.position, hit_area.size), Rect2(48, 24, 604, 408))

func test_the_bookmark_catches_clicks_too() -> void:
	var clip: Control = _frame.find_child("BookmarkClip", true, false)
	assert_eq(clip.mouse_filter, Control.MOUSE_FILTER_STOP)

func test_closing_hides_the_bookmark_at_once() -> void:
	_frame.animate_open()
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	_frame.animate_close()
	assert_false((_frame.find_child("BookmarkClip", true, false) as Control).visible)

#-----------------------------------------------------------------------------
# PALETTE
#-----------------------------------------------------------------------------

func test_style_reaches_the_book_shader() -> void:
	_frame.style = ABILITIES_STYLE
	var book_material: ShaderMaterial = (_frame.find_child("BookBackground", true, false) as CanvasItem).material
	var targets: PackedColorArray = book_material.get_shader_parameter("target_colors")
	assert_eq(book_material.get_shader_parameter("color_count"), BookFrame.BOOK_SOURCE_COLORS.size())
	assert_eq(targets[0], ABILITIES_STYLE.cover_light)
	assert_eq(targets[3], ABILITIES_STYLE.page_border)

func test_style_reaches_the_turning_page() -> void:
	# The turning page carries the page border line, so it must match the book.
	_frame.style = ABILITIES_STYLE
	var page_material: ShaderMaterial = (_frame.find_child("PageTurningRect", true, false) as CanvasItem).material
	var targets: PackedColorArray = page_material.get_shader_parameter("target_colors")
	assert_eq(targets[3], ABILITIES_STYLE.page_border)

func test_style_reaches_the_bookmark_shader() -> void:
	_frame.style = ABILITIES_STYLE
	var bookmark_material: ShaderMaterial = (_frame.find_child("Bookmark", true, false) as CanvasItem).material
	var targets: PackedColorArray = bookmark_material.get_shader_parameter("target_colors")
	assert_eq(bookmark_material.get_shader_parameter("color_count"), BookFrame.BOOKMARK_SOURCE_COLORS.size())
	assert_eq(targets[1], ABILITIES_STYLE.bookmark_mid)

func test_books_do_not_share_a_palette() -> void:
	# Each instance needs its own material, or every book takes the last colours set.
	var other: BookFrame = BookFrameScene.instantiate() as BookFrame
	add_child_autofree(other)
	_frame.style = ABILITIES_STYLE
	var mine: ShaderMaterial = (_frame.find_child("BookBackground", true, false) as CanvasItem).material
	var theirs: ShaderMaterial = (other.find_child("BookBackground", true, false) as CanvasItem).material
	assert_ne(mine, theirs)
	var their_targets: PackedColorArray = theirs.get_shader_parameter("target_colors")
	assert_eq(their_targets[3], BookFrame.BOOK_SOURCE_COLORS[3], "the other book keeps the master border")
