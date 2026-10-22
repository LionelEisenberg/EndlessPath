extends GutTest

## Unit tests for BookViewState, shared by the four menu books: Esc, the
## menu's own key, the book's close tab and a click on the backdrop outside
## the book all close it the same way, and the state pops exactly once. Uses
## the Character book as the example.

const CharacterViewScene := preload("res://scenes/character/character_view.tscn")

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stands in for MainView's GreyBackground: shows and hides at once, then
## emits panel_hidden like the real one does when its close ends.
class FakeGreyBackground:
	extends GreyBackground

	func show_with_panel(panel: Control) -> void:
		visible = true
		panel.visible = true

	func hide_with_panel(panel: Control) -> void:
		visible = false
		panel.visible = false
		panel_hidden.emit()

## Like FakeGreyBackground, but the close only ends when the test says so.
class SlowGreyBackground:
	extends GreyBackground

	var hide_calls: int = 0

	func show_with_panel(panel: Control) -> void:
		panel.visible = true

	func hide_with_panel(_panel: Control) -> void:
		hide_calls += 1

var _main_view: MainView
var _state: CharacterViewState

func before_each() -> void:
	_main_view = autofree(MainView.new())
	_main_view.grey_background = autofree(FakeGreyBackground.new())
	_main_view.character_view = add_child_autofree(CharacterViewScene.instantiate())
	_state = autofree(CharacterViewState.new())
	_state.scene_root = _main_view
	_main_view.push_state(_state)

func _action(action_name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event

#-----------------------------------------------------------------------------
# OPENING
#-----------------------------------------------------------------------------

func test_enter_shows_the_book() -> void:
	assert_true(_main_view.character_view.visible)

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

func test_close_tab_pops_the_state() -> void:
	_main_view.character_view.close_requested.emit()
	assert_true(_main_view.state_stack.is_empty())

func test_escape_pops_the_state() -> void:
	_state.handle_input(_action("ui_cancel"))
	assert_true(_main_view.state_stack.is_empty())

func test_menu_key_pops_the_state() -> void:
	_state.handle_input(_action("open_character"))
	assert_true(_main_view.state_stack.is_empty())

func test_clicking_the_backdrop_pops_the_state() -> void:
	_main_view.grey_background.clicked.emit()
	assert_true(_main_view.state_stack.is_empty())

func test_exit_stops_listening_to_the_backdrop() -> void:
	# The merchant shows the same backdrop; its clicks must not pop anything.
	_main_view.grey_background.clicked.emit()
	var other: MainViewState = autofree(MainViewState.new())
	_main_view.push_state(other)
	_main_view.grey_background.clicked.emit()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), other)

func test_other_menu_keys_keep_the_book_open() -> void:
	_state.handle_input(_action("open_inventory"))
	assert_eq(_main_view.state_stack.size(), 1)

func test_exit_disconnects_the_close_tab() -> void:
	_main_view.character_view.close_requested.emit()
	var other: MainViewState = autofree(MainViewState.new())
	_main_view.push_state(other)
	_main_view.character_view.close_requested.emit()
	assert_eq(_main_view.state_stack.size(), 1, "a stale close tab must not pop another view")
	assert_same(_main_view.state_stack.back(), other)

func test_second_close_request_pops_once() -> void:
	# Esc pressed again while the book is still closing.
	var below: MainViewState = autofree(MainViewState.new())
	var slow: SlowGreyBackground = autofree(SlowGreyBackground.new())
	_main_view.grey_background = slow
	_main_view.state_stack = [below, _state]
	_state.handle_input(_action("ui_cancel"))
	_state.handle_input(_action("ui_cancel"))
	assert_eq(slow.hide_calls, 2)
	slow.panel_hidden.emit()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), below, "the view underneath stays open")
