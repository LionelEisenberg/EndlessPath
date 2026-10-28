extends GutTest

## Unit tests for where each view state puts the HUD boards MainView shares
## between views (spec: Goals › Placement; plan Task 14). The zone view puts
## Goals under the cultivator cabinet and the log at the bottom left; the
## adventure view leaves both there, the Goals cords on, since its own cabinet
## stands where the zone view's does (adventure spec: The left column); the
## merchant hides both and gives them back their visibility when it closes.
## Cycling, whose board sits in the map gap beside them, and the menu books
## (inventory, abilities, character, path tree) leave both boards showing.
## MainView's hold-and-release counting of the boards is tested with a
## stand-in covering state, since the shop is the only real state left that
## hides them.
## The MainView is never added to the tree: each test fills in the views and
## boards it needs with plain Controls, as test_merchant_view_state.gd does.

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const GoalsPanelScene := preload("res://scenes/ui/goals_panel/goals_panel.tscn")
const MERCHANT_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

## Kit §5.2 and §5.3, written out so the tests do not read the constants they
## check. Goals hangs 4 px under the kit's 272, giving the cords that link it
## to the cabinet more room (user review, 2026-10-22).
const ZONE_GOALS_POSITION: Vector2 = Vector2(24.0, 276.0)
const ZONE_LOG_POSITION: Vector2 = Vector2(24.0, 852.0)

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stands in for the AdventureView, which AdventureViewState only shows,
## hides and listens to for the end of the adventure.
class FakeAdventureView:
	extends Control

	signal adventure_completed(result_data: AdventureResultData)

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
	_main_view.zone_view = autofree(Control.new())
	_main_view.adventure_view = autofree(FakeAdventureView.new())
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())
	_main_view.log_window.position = Vector2(300.0, 300.0)
	_main_view.goals_panel.position = Vector2(500.0, 500.0)

func _new_state(state: MainViewState) -> MainViewState:
	state.scene_root = _main_view
	return autofree(state)

#-----------------------------------------------------------------------------
# ZONE VIEW
#-----------------------------------------------------------------------------

func test_zone_view_places_goals_under_the_cabinet() -> void:
	_new_state(ZoneViewState.new()).enter()
	assert_eq(_main_view.goals_panel.position, ZONE_GOALS_POSITION)

func test_zone_view_places_the_log_at_the_bottom_left() -> void:
	_new_state(ZoneViewState.new()).enter()
	assert_eq(_main_view.log_window.position, ZONE_LOG_POSITION)

#-----------------------------------------------------------------------------
# ADVENTURE VIEW
#-----------------------------------------------------------------------------

## The adventure's cabinet stands where the zone view's does, so Goals stays
## hung under it and the log stays at the bottom left, through the run and
## after it.
func test_adventure_leaves_goals_and_the_log_in_place() -> void:
	_main_view.goals_panel.position = ZONE_GOALS_POSITION
	_main_view.log_window.position = ZONE_LOG_POSITION
	var state: MainViewState = _new_state(AdventureViewState.new())
	state.enter()
	assert_eq(_main_view.goals_panel.position, ZONE_GOALS_POSITION, "Goals stay under the cabinet in the adventure")
	assert_eq(_main_view.log_window.position, ZONE_LOG_POSITION, "the log stays at the bottom left in the adventure")
	state.exit()
	assert_eq(_main_view.goals_panel.position, ZONE_GOALS_POSITION, "and after it")
	assert_eq(_main_view.log_window.position, ZONE_LOG_POSITION, "and after it")

## The board still hangs from the cabinet's rings, so its cords (and the hooks
## on its top slice) stay on. It has a goal to hang, as it does by the time
## adventures open: a board with none hides its cords.
func test_adventure_keeps_the_goals_cords() -> void:
	var save := SaveGameData.new()
	save.unlock_progression.unlocked_condition_ids.append("celestial_intervener_dialogue_4")
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	var goals: GoalsPanel = add_child_autofree(GoalsPanelScene.instantiate())
	_main_view.goals_panel = goals
	var cords: Control = goals.get_node("%Cords")
	var board_top: TextureRect = goals.get_node("%BoardTop")
	var hooked_top: Texture2D = board_top.texture
	var state: MainViewState = _new_state(AdventureViewState.new())
	state.enter()
	assert_true(cords.visible, "the cords hang in the adventure")
	assert_eq(board_top.texture, hooked_top, "the top slice keeps the hooks they end in")
	state.exit()
	assert_true(cords.visible, "and after it")

func test_back_from_an_adventure_the_zone_view_places_both_boards() -> void:
	var zone_state: MainViewState = _new_state(ZoneViewState.new())
	var adventure_state: MainViewState = _new_state(AdventureViewState.new())
	zone_state.enter()
	zone_state.exit()
	adventure_state.enter()
	adventure_state.exit()
	zone_state.enter()
	assert_eq(_main_view.goals_panel.position, ZONE_GOALS_POSITION, "goals")
	assert_eq(_main_view.log_window.position, ZONE_LOG_POSITION, "log")

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

func test_cycling_keeps_the_boards() -> void:
	_assert_overlay_keeps_boards(_new_state(CyclingViewState.new()), "cycling")

func test_inventory_keeps_the_boards() -> void:
	_assert_overlay_keeps_boards(_new_state(InventoryViewState.new()), "the inventory")

func test_abilities_keep_the_boards() -> void:
	_assert_overlay_keeps_boards(_new_state(AbilitiesViewState.new()), "the abilities book")

func test_character_keeps_the_boards() -> void:
	_assert_overlay_keeps_boards(_new_state(CharacterViewState.new()), "the character book")

func test_path_tree_keeps_the_boards() -> void:
	_assert_overlay_keeps_boards(_new_state(PathTreeViewState.new()), "the path book")

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
