extends GutTest

## Unit tests for which view states show the HUD boards MainView shares between
## views (spec: Goals › Placement; plan Task 14). The merchant hides both and
## gives them back their visibility when it closes. Cycling, whose board sits in
## the map gap beside them, and the menu books (inventory, abilities, character,
## path tree) leave both boards showing.
## MainView's hold-and-release counting of the boards is tested with a
## stand-in covering state, since the shop is the only real state left that
## hides them.
## The MainView is never added to the tree: each test fills in the views and
## boards it needs with plain Controls, as test_merchant_view_state.gd does.

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const MERCHANT_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

#-----------------------------------------------------------------------------
# FIXTURES
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

## Stands in for an overlay that covers the boards and hides them, as the shop
## does: it holds them hidden from enter() to exit().
class FakeCoveringState:
	extends MainViewState

	func enter() -> void:
		scene_root.hide_hud_boards(self)

	func exit() -> void:
		scene_root.release_hud_boards(self)

var _main_view: MainView

func before_each() -> void:
	_main_view = autofree(MainView.new())
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())

func _new_state(state: MainViewState) -> MainViewState:
	state.scene_root = _main_view
	return autofree(state)

#-----------------------------------------------------------------------------
# MERCHANT
#-----------------------------------------------------------------------------

func test_merchant_hides_goals() -> void:
	_main_view.grey_background = autofree(FakeGreyBackground.new())
	_main_view.merchant_view = add_child_autofree(MerchantViewScene.instantiate())
	var state: MerchantViewState = _new_state(MerchantViewState.new())
	_main_view.state_stack = []
	state._on_start_merchant(load(MERCHANT_ACTION_PATH) as MerchantActionData)
	assert_false(_main_view.goals_panel.visible, "the shop covers part of the Goals board")
	state._on_stop_merchant()
	assert_true(_main_view.goals_panel.visible, "Goals show again when the shop closes")

#-----------------------------------------------------------------------------
# OVERLAYS (the shop hides the HUD boards; cycling and the books leave them be)
#-----------------------------------------------------------------------------

## Fills in the views the overlay states open, with plain stand-ins.
func _add_overlay_views() -> void:
	_main_view.grey_background = autofree(FakeGreyBackground.new())
	_main_view.cycling_view = autofree(Control.new())
	_main_view.inventory_view = autofree(MenuBookView.new())
	_main_view.abilities_view = autofree(MenuBookView.new())
	_main_view.character_view = autofree(CharacterView.new())
	_main_view.path_tree_view = autofree(PathTreeView.new())

## Opens the overlay, checks both boards still show, closes it, checks again.
func _assert_overlay_keeps_boards(state: MainViewState, overlay_name: String) -> void:
	_add_overlay_views()
	_main_view.goals_panel.visible = true
	_main_view.log_window.visible = true
	state.enter()
	assert_true(_main_view.goals_panel.visible, "the Goals board stays beside %s" % overlay_name)
	assert_true(_main_view.log_window.visible, "the log stays beside %s" % overlay_name)
	state.exit()
	assert_true(_main_view.goals_panel.visible, "the Goals board still shows after %s" % overlay_name)
	assert_true(_main_view.log_window.visible, "the log still shows after %s" % overlay_name)

func test_cycling_and_the_books_keep_the_boards() -> void:
	var overlays: Dictionary[String, MainViewState] = {
		"cycling": CyclingViewState.new(),
		"the inventory": InventoryViewState.new(),
		"the abilities book": AbilitiesViewState.new(),
		"the character book": CharacterViewState.new(),
		"the path book": PathTreeViewState.new(),
	}
	for overlay_name: String in overlays:
		_assert_overlay_keeps_boards(_new_state(overlays[overlay_name]), overlay_name)

func test_overlay_restores_a_board_that_was_hidden() -> void:
	_main_view.log_window.visible = false
	var state: MainViewState = _new_state(FakeCoveringState.new())
	state.enter()
	state.exit()
	assert_false(_main_view.log_window.visible, "a log hidden before the overlay stays hidden")
	assert_true(_main_view.goals_panel.visible)

## The shop can leave while another overlay still covers it (MerchantViewState
## removes itself from under another view). The boards stay hidden until the
## last overlay closes, and then come back as they were before the first.
func test_boards_stay_hidden_until_the_last_overlay_closes() -> void:
	_add_overlay_views()
	_main_view.merchant_view = add_child_autofree(MerchantViewScene.instantiate())
	var merchant: MerchantViewState = _new_state(MerchantViewState.new())
	var covering: MainViewState = _new_state(FakeCoveringState.new())
	_main_view.state_stack = []
	merchant._on_start_merchant(load(MERCHANT_ACTION_PATH) as MerchantActionData)
	_main_view.push_state(covering)
	merchant._on_stop_merchant()
	assert_false(_main_view.state_stack.has(merchant), "precondition: the shop left from under the other overlay")
	assert_false(_main_view.goals_panel.visible, "the other overlay still covers the Goals board")
	assert_false(_main_view.log_window.visible, "the other overlay still covers the log")
	_main_view.pop_state()
	assert_true(_main_view.goals_panel.visible, "back once the last overlay closed")
	assert_true(_main_view.log_window.visible)
