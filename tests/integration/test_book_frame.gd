extends GutTest

## Integration tests for BookFrame: its open, close and page-turn signals, the
## chrome that only shows on the open book, the close tab, and the book and
## bookmark catching the clicks that land on them.

const BookFrameScene: PackedScene = preload("res://scenes/ui/book_frame/book_frame.tscn")

## Longer than the 0.3 s open and close and the 0.54 s page turn.
const ANIMATION_TIMEOUT: float = 2.0
## The book art's frames on the spritesheet: the open book is the first, the
## closed book the last.
const OPEN_FRAME_X: float = 0.0
const CLOSED_FRAME_X: float = 2800.0

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

func test_the_book_only_shows_open_once_it_has_opened() -> void:
	# A book that has never closed still holds the open frame. Showing it while
	# the book opens draws an open book that snaps shut and opens again.
	var frames_while_opening: Array[float] = []
	var deadline: int = Time.get_ticks_msec() + int(ANIMATION_TIMEOUT * 1000.0)
	_frame.animate_open()
	while _frame.is_moving() and Time.get_ticks_msec() < deadline:
		frames_while_opening.append(_book_frame_x())
		await get_tree().process_frame
	assert_false(_frame.is_moving(), "the book finished opening")
	assert_eq(frames_while_opening.front(), CLOSED_FRAME_X, "the open starts on the closed book")
	assert_does_not_have(frames_while_opening, OPEN_FRAME_X, "the open book showed before the pages folded open")
	assert_eq(_book_frame_x(), OPEN_FRAME_X, "and it ends open")

func test_opening_while_closing_turns_around_where_the_close_got_to() -> void:
	_frame.animate_open()
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	_frame.animate_close()
	await wait_seconds(0.1)
	assert_true(_frame.is_moving(), "still closing")
	var frame_x: float = _book_frame_x()
	_frame.animate_open()
	assert_eq(_book_frame_x(), frame_x, "no jump to the closed book mid-turn")
	watch_signals(_frame)
	await wait_for_signal(_frame.opened, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "opened")

#-----------------------------------------------------------------------------
# PAGE TURN AND CLOSE TAB
#-----------------------------------------------------------------------------

func test_turning_a_page_emits_page_turned() -> void:
	watch_signals(_frame)
	_frame.turn_page(true)
	await wait_for_signal(_frame.page_turned, ANIMATION_TIMEOUT)
	assert_signal_emitted(_frame, "page_turned")

## A page landing on the left page passes over the side tabs on the book's left
## edge (2026-10-28 review: the tabs, drawn after the book, cut it off). The
## strip's first and last frames are empty, so at rest it covers nothing.
func test_the_turning_page_draws_over_the_side_tabs() -> void:
	var page: CanvasItem = _frame.find_child("PageTurningRect", true, false) as CanvasItem
	assert_gt(page.z_index, 0, "over the books' content, the side tabs included")

func test_close_tab_requests_a_close() -> void:
	watch_signals(_frame)
	var close_tab: TextureButton = _frame.find_child("CloseTab", true, false)
	close_tab.pressed.emit()
	assert_signal_emitted(_frame, "close_requested")

func test_the_open_books_art_catches_clicks() -> void:
	# A click on the backdrop closes the book, so clicks on the book itself
	# (even on bare page) must stop here.
	var hit_area: Control = _frame.find_child("BookHitArea", true, false)
	assert_eq(hit_area.mouse_filter, Control.MOUSE_FILTER_STOP)

func test_the_bookmark_catches_clicks_too() -> void:
	var clip: Control = _frame.find_child("BookmarkClip", true, false)
	assert_eq(clip.mouse_filter, Control.MOUSE_FILTER_STOP)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Which spritesheet frame the book art shows.
func _book_frame_x() -> float:
	var background: TextureRect = _frame.find_child("BookBackground", true, false) as TextureRect
	return (background.texture as AtlasTexture).region.position.x
