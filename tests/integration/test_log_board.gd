extends GutTest

## Integration tests for the lacquer Log board (LogWindow, lacquer kit §5.3 and
## §0): up to five lines, newest at the bottom, BBCode stripped; and the full
## log that L, Escape and LogManager.toggle_window() open and close, that keeps
## as many lines as LogManager does, and that stays shut while a menu book is
## open.

const LOG_SCENE_PATH: String = "res://scenes/ui/log_window/log_window.tscn"

const SCREEN_SIZE: Vector2 = Vector2(1920.0, 1080.0)

var _saved_history: Array[String] = []
var _log: LogWindow = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

## LogManager's history is global and other tests log into it: each test
## starts from an empty history and gives the old one back afterwards.
func before_each() -> void:
	_saved_history = LogManager._history.duplicate()
	LogManager._history.clear()

func after_each() -> void:
	LogManager._history = _saved_history

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Adds the log scene inside a 1920x1080 stand-in for MainView.
func _add_log() -> LogWindow:
	var screen: Control = Control.new()
	screen.size = SCREEN_SIZE
	add_child_autofree(screen)
	var scene: PackedScene = load(LOG_SCENE_PATH)
	_log = scene.instantiate()
	screen.add_child(_log)
	return _log

func _node(unique_name: String) -> Node:
	return _log.get_node("%" + unique_name)

func _board() -> Control:
	return _node("Board") as Control

func _line_label(age: int) -> Label:
	return _node("LineLabel%d" % age) as Label

func _line_row(age: int) -> Control:
	return _node("Line%d" % age) as Control

func _visible_line_count() -> int:
	var count: int = 0
	for age: int in range(5):
		if _line_row(age).visible:
			count += 1
	return count

func _log_lines(texts: Array[String]) -> void:
	for text: String in texts:
		LogManager.log_message(text)

func _press_key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	get_viewport().push_input(event)

#-----------------------------------------------------------------------------
# LINES
#-----------------------------------------------------------------------------

func test_shows_last_five_newest_last() -> void:
	_add_log()
	_log_lines(["Line 1", "Line 2", "Line 3", "Line 4", "Line 5", "Line 6", "Line 7"])
	assert_eq(_visible_line_count(), 5)
	assert_eq(_line_label(0).text, "Line 7", "the newest line is at the bottom")
	assert_eq(_line_label(4).text, "Line 3", "the oldest line shown is the fifth newest")

func test_reads_history_on_ready() -> void:
	_log_lines(["Spoke with the Intervener", "Learned Wilderness Cycling", "Started Wilderness Cycling"])
	_add_log()
	assert_eq(_visible_line_count(), 3)
	assert_eq(_line_label(0).text, "Started Wilderness Cycling")
	assert_eq(_line_label(2).text, "Spoke with the Intervener")

func test_strips_bbcode() -> void:
	_add_log()
	_log_lines(["[color=gold]Gained [b]5[/b] Gold[/color]", "[color=magenta][DEV][/color] Set Madra to 50"])
	assert_eq(_line_label(1).text, "Gained 5 Gold")
	assert_eq(_line_label(0).text, "[DEV] Set Madra to 50", "a tag RichTextLabel would not parse stays as text")

#-----------------------------------------------------------------------------
# FULL LOG
#-----------------------------------------------------------------------------

func test_toggle_window_opens_full_log_with_all_lines() -> void:
	_log_lines(["Line 1", "Line 2", "Line 3", "Line 4", "Line 5", "Line 6", "[color=gold]Line [b]7[/b][/color]"])
	_add_log()
	assert_false(_log.is_full_log_open(), "closed by default")
	assert_false((_node("FullBoard") as Control).visible)
	LogManager.toggle_window()
	assert_true(_log.is_full_log_open())
	assert_true((_node("FullBoard") as Control).visible)
	assert_false(_board().visible, "the five-line board steps aside")
	var text: String = (_node("FullLogText") as RichTextLabel).get_parsed_text()
	var previous: int = -1
	for i: int in range(1, 8):
		var at: int = text.find("Line %d" % i)
		assert_gt(at, previous, "line %d is there, after the one before it" % i)
		previous = at
	LogManager.toggle_window()
	assert_false(_log.is_full_log_open())
	assert_true(_board().visible)

func test_full_log_takes_new_lines_while_open() -> void:
	_add_log()
	_log_lines(["Before"])
	_log.toggle_full_log()
	_log_lines(["After"])
	var text: String = (_node("FullLogText") as RichTextLabel).get_parsed_text()
	assert_gt(text.find("After"), text.find("Before"), "the new line lands at the bottom")

func test_l_key_toggles_full_log() -> void:
	_add_log()
	_press_key(KEY_L)
	assert_true(_log.is_full_log_open())
	_press_key(KEY_L)
	assert_false(_log.is_full_log_open())

func test_escape_closes_full_log() -> void:
	_add_log()
	_log.toggle_full_log()
	_press_key(KEY_ESCAPE)
	assert_false(_log.is_full_log_open())

func test_l_does_nothing_while_the_log_is_hidden() -> void:
	_add_log()
	_log.visible = false
	_press_key(KEY_L)
	assert_false(_log.is_full_log_open(), "the merchant hides the log; L must not open it behind the shop")

func test_hiding_the_log_closes_the_full_log() -> void:
	_add_log()
	_log.toggle_full_log()
	_log.visible = false
	assert_false(_log.is_full_log_open(), "a hidden log closes its full log")
	_log.visible = true
	assert_false(_log.is_full_log_open(), "and it stays closed when the log shows again")
	assert_true(_board().visible, "the five-line board is back")

#-----------------------------------------------------------------------------
# FULL LOG UNDER A BOOK
#-----------------------------------------------------------------------------

## Stands in for MainView's GreyBackground: shows and hides at once, then
## emits panel_hidden like the real one at the end of its fade-out.
class FakeGreyBackground:
	extends GreyBackground

	func show_with_panel(panel: Control) -> void:
		visible = true
		panel.visible = true

	func hide_with_panel(panel: Control) -> void:
		visible = false
		panel.visible = false
		panel_hidden.emit()

## An inventory book over a MainView (kept out of the tree) whose log is the
## one _add_log() put in the tree.
func _new_book_over_log() -> BookViewState:
	var main_view: MainView = autofree(MainView.new())
	main_view.grey_background = autofree(FakeGreyBackground.new())
	main_view.inventory_view = autofree(MenuBookView.new())
	main_view.log_window = _log
	var book: BookViewState = autofree(InventoryViewState.new())
	book.scene_root = main_view
	return book

func test_full_log_stays_shut_while_blocked() -> void:
	_add_log()
	_log.set_full_log_blocked(true)
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "toggle_full_log() does not open it")
	_press_key(KEY_L)
	assert_false(_log.is_full_log_open(), "nor does L")
	LogManager.toggle_window()
	assert_false(_log.is_full_log_open(), "nor LogManager.toggle_window()")

## The log stays in sight under a book, but the full log must not: open, it
## would take the first Esc meant for the book (LogWindow gets
## _unhandled_input before MainView hands the key to the book).
func test_opening_a_book_closes_the_full_log() -> void:
	_add_log()
	_log.toggle_full_log()
	_new_book_over_log().enter()
	assert_false(_log.is_full_log_open(), "the book closes the full log, so Esc closes the book")
	assert_true(_log.visible, "the log board itself stays")

func test_full_log_stays_shut_while_a_book_is_open() -> void:
	_add_log()
	_new_book_over_log().enter()
	_press_key(KEY_L)
	assert_false(_log.is_full_log_open(), "L does nothing under a book")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "nor does toggle_full_log()")

func test_full_log_opens_again_after_the_book_closes() -> void:
	_add_log()
	var book: BookViewState = _new_book_over_log()
	book.enter()
	book.exit()
	_log.toggle_full_log()
	assert_true(_log.is_full_log_open())

#-----------------------------------------------------------------------------
# FULL LOG TEXT
#-----------------------------------------------------------------------------

func test_full_log_keeps_only_the_history_limit_while_open() -> void:
	_add_log()
	_log.toggle_full_log()
	for i: int in range(LogManager.HISTORY_LIMIT + 5):
		LogManager.log_message("Entry %03d" % i)
	var text: RichTextLabel = _node("FullLogText") as RichTextLabel
	assert_eq(text.get_paragraph_count(), LogManager.HISTORY_LIMIT, "as many lines as LogManager keeps")
	var parsed: String = text.get_parsed_text()
	assert_false(parsed.contains("Entry 004"), "the oldest lines are dropped")
	assert_true(parsed.contains("Entry 005"), "the oldest kept line is still there")
	assert_true(parsed.contains("Entry %03d" % (LogManager.HISTORY_LIMIT + 4)), "and the newest")
