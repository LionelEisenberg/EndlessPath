extends GutTest

## Unit tests for GreyBackground: hide_with_panel ends with its own fade-out,
## or, for a panel with a close_finished signal (the menu books), only once
## that panel's own close has finished too; and a left click on the backdrop
## itself is reported, so a book can close on it.

const FADE_LENGTH: float = 0.05

## A panel that closes on its own schedule, like a menu book.
class ClosingPanel:
	extends Control

	signal close_finished

	var close_calls: int = 0

	func animate_close() -> void:
		close_calls += 1

var _backdrop: GreyBackground

func before_each() -> void:
	_backdrop = GreyBackground.new()
	var player := AnimationPlayer.new()
	player.name = "GreyBackgroundAnimationPlayer"
	var library := AnimationLibrary.new()
	for animation_name: String in ["grey_fade_in", "grey_fade_out"]:
		var animation := Animation.new()
		animation.length = FADE_LENGTH
		library.add_animation(animation_name, animation)
	player.add_animation_library("", library)
	_backdrop.add_child(player)
	player.owner = _backdrop
	player.unique_name_in_owner = true
	add_child_autofree(_backdrop)

#-----------------------------------------------------------------------------
# PANELS WITH THEIR OWN CLOSE
#-----------------------------------------------------------------------------

func test_hide_waits_for_the_panels_close() -> void:
	var panel := ClosingPanel.new()
	add_child_autofree(panel)
	watch_signals(_backdrop)
	_backdrop.hide_with_panel(panel)
	assert_eq(panel.close_calls, 1, "the panel is asked to close")
	await wait_seconds(FADE_LENGTH * 4)
	assert_signal_not_emitted(_backdrop, "panel_hidden", "the fade alone must not cut a book's close short")
	assert_true(panel.visible)
	panel.close_finished.emit()
	assert_signal_emitted(_backdrop, "panel_hidden")
	assert_false(panel.visible)
	assert_false(_backdrop.visible)

func test_panel_closing_first_still_waits_for_the_fade() -> void:
	var panel := ClosingPanel.new()
	add_child_autofree(panel)
	watch_signals(_backdrop)
	_backdrop.hide_with_panel(panel)
	panel.close_finished.emit()
	assert_signal_not_emitted(_backdrop, "panel_hidden")
	await wait_for_signal(_backdrop.panel_hidden, 1.0)
	assert_signal_emitted(_backdrop, "panel_hidden")

#-----------------------------------------------------------------------------
# PANELS WITHOUT ONE
#-----------------------------------------------------------------------------

func test_hide_without_close_signal_ends_with_the_fade() -> void:
	var panel := Control.new()
	add_child_autofree(panel)
	watch_signals(_backdrop)
	_backdrop.hide_with_panel(panel)
	await wait_for_signal(_backdrop.panel_hidden, 1.0)
	assert_signal_emitted(_backdrop, "panel_hidden")
	assert_false(panel.visible)

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func test_left_click_on_the_backdrop_is_reported() -> void:
	watch_signals(_backdrop)
	_backdrop._gui_input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	assert_signal_emit_count(_backdrop, "clicked", 1)

func test_other_buttons_and_releases_are_not_clicks() -> void:
	watch_signals(_backdrop)
	_backdrop._gui_input(_mouse_button(MOUSE_BUTTON_RIGHT, true))
	_backdrop._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP, true))
	_backdrop._gui_input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_signal_not_emitted(_backdrop, "clicked")
