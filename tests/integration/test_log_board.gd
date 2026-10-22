extends GutTest

## Integration tests for the lacquer Log board (LogWindow, lacquer kit §5.3 and
## §0): up to five lines, newest at the bottom, BBCode stripped, fading by
## colour steps with age; the board grows upward from the bottom line; and the
## full log that L, Escape and LogManager.toggle_window() open and close.

const LOG_SCENE_PATH: String = "res://scenes/ui/log_window/log_window.tscn"
const BOARD_TEXTURE_PATH: String = "res://assets/ui/lacquer/lacquer_log%d_ai.png"
const BULLET_TEXTURE_PATH: String = "res://assets/ui/lacquer/lacquer_bullet_%s_ai.png"

const SCREEN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
## The line the board sits on in the zone view (kit §5.3: 852 + 204).
const BOTTOM_LINE: float = 1056.0
## Where the adventure view puts the log (AdventureViewState).
const ADVENTURE_SPOT: Vector2 = Vector2(24.0, 24.0)
## The log's slot in the zone view (kit §5.3).
const ZONE_SPOT: Vector2 = Vector2(24.0, 852.0)
const BOARD_WIDTH: float = 440.0
const MAX_TEXT_WIDTH: float = 384.0

## Kit §2 palette, written out so the tests do not read the colours they check.
const BRASS: Color = Color("#D4A84A")
const CREAM: Color = Color("#F0E8D8")
const TAN: Color = Color("#A89070")
const DIM: Color = Color("#94806A")
const MADRA: Color = Color("#BBD5E7")

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

func _line_bullet(age: int) -> TextureRect:
	return _node("LineBullet%d" % age) as TextureRect

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

func _bullet(name: String) -> Texture2D:
	return load(BULLET_TEXTURE_PATH % name)

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

func test_long_line_ellipsizes() -> void:
	_add_log()
	LogManager.log_message("Travelled to " + "a very long zone name ".repeat(14))
	var label: Label = _line_label(0)
	assert_lte(label.size.x, MAX_TEXT_WIDTH, "the line ellipsizes in its 384 px slot")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(_board().size.x, BOARD_WIDTH, "the board keeps its width")

#-----------------------------------------------------------------------------
# BOARD SIZE AND PLACEMENT
#-----------------------------------------------------------------------------

func test_board_grows_upward() -> void:
	_add_log()
	_log_lines(["One", "Two"])
	assert_eq(_board().size.y, 126.0, "74 + 26 × 2")
	assert_eq(_board().get_global_rect().end.y, BOTTOM_LINE, "the bottom stays on the line")
	assert_eq((_node("BoardTexture") as TextureRect).texture, load(BOARD_TEXTURE_PATH % 2))
	_log_lines(["Three", "Four", "Five"])
	assert_eq(_board().size.y, 204.0, "74 + 26 × 5")
	assert_eq(_board().get_global_rect().end.y, BOTTOM_LINE)
	assert_eq((_node("BoardTexture") as TextureRect).texture, load(BOARD_TEXTURE_PATH % 5))

func test_empty_log_shows_the_one_line_board() -> void:
	_add_log()
	assert_eq(_visible_line_count(), 0)
	assert_eq(_board().size.y, 100.0, "the one-line board, empty")
	assert_eq(_board().get_global_rect().end.y, BOTTOM_LINE)
	assert_eq((_node("BoardTexture") as TextureRect).texture, load(BOARD_TEXTURE_PATH % 1))

func test_board_hangs_from_the_top_when_placed_high() -> void:
	_add_log()
	_log_lines(["One", "Two"])
	_log.position = ADVENTURE_SPOT
	assert_eq(_board().get_global_rect().position.y, ADVENTURE_SPOT.y, "in the upper half the top stays put")
	_log_lines(["Three"])
	assert_eq(_board().get_global_rect().position.y, ADVENTURE_SPOT.y, "and the board grows down")
	assert_eq(_board().size.y, 152.0)
	_log.position = ZONE_SPOT
	assert_eq(_board().get_global_rect().end.y, BOTTOM_LINE, "back in the zone slot it sits on the line again")

func test_boards_keep_their_width_in_a_resized_slot() -> void:
	_add_log()
	_log.toggle_full_log()
	_log.size = Vector2(400.0, 217.0) # main_game.tscn's old LogWindow size
	assert_eq(_board().size.x, BOARD_WIDTH)
	assert_eq((_node("FullBoard") as Control).size.x, BOARD_WIDTH)

#-----------------------------------------------------------------------------
# TONES
#-----------------------------------------------------------------------------

func test_tone_for_mapping() -> void:
	assert_eq(LogWindow.tone_for("[color=cyan]Gained 5 Madra[/color]"), LogWindow.Tone.MADRA)
	assert_eq(LogWindow.tone_for("[color=gold]Gained 5 Gold[/color]"), LogWindow.Tone.BRASS)
	assert_eq(LogWindow.tone_for("[color=green]Combat Victory![/color]"), LogWindow.Tone.CREAM)
	assert_eq(LogWindow.tone_for("[color=red]Not enough Madra![/color]"), LogWindow.Tone.TAN)
	assert_eq(LogWindow.tone_for("Resumed Aura Well"), LogWindow.Tone.TAN)

func test_tone_for_reads_hex_and_other_names() -> void:
	assert_eq(LogWindow.tone_for("[color=#D4A84A]+34 gold[/color]"), LogWindow.Tone.BRASS)
	assert_eq(LogWindow.tone_for("[color=yellow]Obtained 1x Fern[/color]"), LogWindow.Tone.BRASS)
	assert_eq(LogWindow.tone_for("[color=orange]Encounter: Rat[/color]"), LogWindow.Tone.BRASS)
	assert_eq(LogWindow.tone_for("[color=#849BE4]Level up[/color]"), LogWindow.Tone.MADRA)
	assert_eq(LogWindow.tone_for("[color=blue]x[/color]"), LogWindow.Tone.MADRA)
	assert_eq(LogWindow.tone_for("[color=white]x[/color]"), LogWindow.Tone.CREAM)
	assert_eq(LogWindow.tone_for("[color=lime]x[/color]"), LogWindow.Tone.CREAM)
	assert_eq(LogWindow.tone_for("[color=light_gray]Looted 1x Fern[/color]"), LogWindow.Tone.TAN)
	assert_eq(LogWindow.tone_for("[color=magenta][DEV][/color] Set Madra"), LogWindow.Tone.TAN)
	assert_eq(LogWindow.tone_for("[color=not_a_colour]x[/color]"), LogWindow.Tone.TAN)
	assert_eq(LogWindow.tone_for("[b]Rat[/b] took [color=red]3 Damage[/color]"), LogWindow.Tone.TAN,
		"the first colour tag decides")

func test_tones_fade_with_age() -> void:
	_add_log()
	for i: int in range(5):
		LogManager.log_message("[color=gold]Gained %d Gold[/color]" % i)
	var expected_colours: Array[Color] = [BRASS, BRASS, TAN, DIM, DIM]
	var expected_bullets: Array[String] = ["brass", "brass", "tan", "dim", "dim"]
	for age: int in range(5):
		assert_eq(_line_label(age).get_theme_color("font_color"), expected_colours[age], "colour at age %d" % age)
		assert_eq(_line_bullet(age).texture, _bullet(expected_bullets[age]), "bullet at age %d" % age)

func test_newest_lines_keep_their_tone() -> void:
	_add_log()
	_log_lines(["[color=green]Found 2 Spirit Fern[/color]", "[color=cyan]Aura Well reached level 2[/color]"])
	assert_eq(_line_label(0).get_theme_color("font_color"), MADRA)
	assert_eq(_line_bullet(0).texture, _bullet("madra"))
	assert_eq(_line_label(1).get_theme_color("font_color"), CREAM)
	assert_eq(_line_bullet(1).texture, _bullet("cream"))

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

func test_full_log_sits_on_the_bottom_line() -> void:
	_add_log()
	_log.toggle_full_log()
	var full_board: Control = _node("FullBoard") as Control
	assert_eq(full_board.get_global_rect().end.y, BOTTOM_LINE)
	assert_eq(full_board.size.x, BOARD_WIDTH)
	assert_gt(full_board.size.y, 204.0, "larger than the five-line board")

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
