extends GutTest

## Unit tests for how MerchantViewState opens and closes the shop on MainView's
## state stack. The MainView is never added to the tree: each test builds its
## state_stack by hand and fills in merchant_view, grey_background and the HUD
## windows directly.

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stands in for MainView's GreyBackground, which only exists inside
## main_game.tscn. Shows and hides at once instead of fading, then emits
## panel_hidden like the real one does when its fade-out ends.
class FakeGreyBackground:
	extends GreyBackground

	func show_with_panel(panel: Control) -> void:
		visible = true
		panel.visible = true

	func hide_with_panel(panel: Control) -> void:
		visible = false
		panel.visible = false
		panel_hidden.emit()

var _main_view: MainView
var _state: MerchantViewState
## Another overlay that can sit above the shop, such as cycling.
var _other: MainViewState

func before_each() -> void:
	_main_view = autofree(MainView.new())
	_main_view.grey_background = autofree(FakeGreyBackground.new())
	_main_view.merchant_view = add_child_autofree(MerchantViewScene.instantiate())
	_main_view.log_window = autofree(Control.new())
	_main_view.quest_window = autofree(Control.new())
	_state = autofree(MerchantViewState.new())
	_state.scene_root = _main_view
	_other = autofree(MainViewState.new())

func _set_stack(states: Array[MainViewState]) -> void:
	_main_view.state_stack = states

func _merchant_action() -> MerchantActionData:
	return load(ACTION_PATH) as MerchantActionData

#-----------------------------------------------------------------------------
# OPENING
#-----------------------------------------------------------------------------

func test_start_pushes_the_shop() -> void:
	_set_stack([])
	_state._on_start_merchant(_merchant_action())
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _state)
	assert_true(_main_view.merchant_view.visible)

func test_start_while_open_does_not_push_again() -> void:
	_set_stack([_state])
	_state._on_start_merchant(_merchant_action())
	assert_eq(_main_view.state_stack.size(), 1, "a second entry would stay on the stack after the shop closes")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

func test_stop_on_top_closes_and_removes_itself() -> void:
	_set_stack([_state])
	_main_view.merchant_view.visible = true
	_state._on_stop_merchant()
	assert_false(_main_view.merchant_view.visible)
	assert_true(_main_view.state_stack.is_empty())

func test_stop_under_another_view_closes_only_the_shop() -> void:
	_set_stack([_state, _other])
	_main_view.merchant_view.visible = true
	_main_view.grey_background.visible = true
	_state._on_stop_merchant()
	assert_false(_main_view.merchant_view.visible, "the shop must not stay open under the other view")
	assert_true(_main_view.grey_background.visible, "the other view keeps its grey backdrop")
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other)

func test_close_finished_removes_only_itself() -> void:
	# A view pushed during the fade-out sits above the shop when the fade ends.
	_set_stack([_state, _other])
	_state._on_close_finished()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other, "the view opened during the fade-out stays open")

func test_close_finished_never_pops_another_state() -> void:
	_set_stack([_other])
	_state._on_close_finished()
	assert_eq(_main_view.state_stack.size(), 1)
	assert_same(_main_view.state_stack.back(), _other)

#-----------------------------------------------------------------------------
# HUD WINDOWS
#-----------------------------------------------------------------------------

func test_open_hides_the_log_and_quest_windows() -> void:
	# The shop covers part of them, so their text would be cut off at its edge.
	_set_stack([])
	_state._on_start_merchant(_merchant_action())
	assert_false(_main_view.log_window.visible, "log window")
	assert_false(_main_view.quest_window.visible, "quest window")

func test_close_shows_the_log_and_quest_windows_again() -> void:
	_set_stack([])
	_state._on_start_merchant(_merchant_action())
	_state._on_stop_merchant()
	assert_true(_main_view.log_window.visible, "log window")
	assert_true(_main_view.quest_window.visible, "quest window")

func test_close_leaves_a_hidden_window_hidden() -> void:
	_main_view.quest_window.visible = false
	_set_stack([])
	_state._on_start_merchant(_merchant_action())
	_state._on_stop_merchant()
	assert_false(_main_view.quest_window.visible, "the shop restores what was there, not more")
	assert_true(_main_view.log_window.visible)
