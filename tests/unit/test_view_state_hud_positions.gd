extends GutTest

## Unit tests for where each view state puts the HUD boards MainView shares
## between views (spec: Goals › Placement; plan Task 14). The zone view puts
## Goals under the cultivator cabinet and the log at the bottom left; the
## adventure view moves Goals to the free top right and the log to the top
## left, and puts both back when it ends; the merchant and cycling hide both
## and give them back their visibility when they close. The menu books
## (inventory, abilities, character, path tree) leave both boards showing.
## The MainView is never added to the tree: each test fills in the views and
## boards it needs with plain Controls, as test_merchant_view_state.gd does.

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const GoalsPanelScene := preload("res://scenes/ui/goals_panel/goals_panel.tscn")
const MERCHANT_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

## Kit §5.2, §5.3 and the spec's adventure placement, written out so the
## tests do not read the constants they check.
const ZONE_GOALS_POSITION: Vector2 = Vector2(24.0, 272.0)
const ZONE_LOG_POSITION: Vector2 = Vector2(24.0, 852.0)
## The Goals board's root: its top 20 px are the cords, hidden in an
## adventure, so the board's body starts at y 24, level with the log.
const ADVENTURE_GOALS_POSITION: Vector2 = Vector2(1456.0, 4.0)
const ADVENTURE_GOALS_BODY_POSITION: Vector2 = Vector2(1456.0, 24.0)
const ADVENTURE_LOG_POSITION: Vector2 = Vector2(24.0, 24.0)

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

func test_adventure_moves_goals_and_restores() -> void:
	_main_view.goals_panel.position = ZONE_GOALS_POSITION
	var state: MainViewState = _new_state(AdventureViewState.new())
	state.enter()
	assert_eq(_main_view.goals_panel.position, ADVENTURE_GOALS_POSITION, "Goals sit at the free top right")
	state.exit()
	assert_eq(_main_view.goals_panel.position, ZONE_GOALS_POSITION, "Goals go back where they were")

func test_adventure_moves_the_log_and_restores() -> void:
	_main_view.log_window.position = ZONE_LOG_POSITION
	var state: MainViewState = _new_state(AdventureViewState.new())
	state.enter()
	assert_eq(_main_view.log_window.position, ADVENTURE_LOG_POSITION)
	state.exit()
	assert_eq(_main_view.log_window.position, ZONE_LOG_POSITION)

## At the top right the cords would hang from nothing: the adventure hides
## them and shows them again when it ends.
func test_adventure_hides_the_goals_cords_and_restores() -> void:
	var goals: GoalsPanel = add_child_autofree(GoalsPanelScene.instantiate())
	_main_view.goals_panel = goals
	var cords: Control = goals.get_node("%Cords")
	var state: MainViewState = _new_state(AdventureViewState.new())
	state.enter()
	assert_false(cords.visible, "no cords at the top right")
	state.exit()
	assert_true(cords.visible, "the cords hang again under the cabinet")

## With the cords hidden, the board's body (not its root, whose top 20 px are
## the cords' strip) is what sits at 1456, 24, level with the log's top.
func test_adventure_lines_the_goals_board_up_with_the_log() -> void:
	var goals: GoalsPanel = add_child_autofree(GoalsPanelScene.instantiate())
	_main_view.goals_panel = goals
	_new_state(AdventureViewState.new()).enter()
	await wait_process_frames(1)
	var board_top: Control = goals.get_node("%BoardTop")
	assert_eq(board_top.global_position, ADVENTURE_GOALS_BODY_POSITION, "the board's body starts at the top right")
	assert_eq(board_top.global_position.y, ADVENTURE_LOG_POSITION.y, "level with the log")

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
# OVERLAYS (cycling and the shop hide the HUD boards; the books leave them be)
#-----------------------------------------------------------------------------

## Fills in the views the overlay states open, with plain stand-ins.
func _add_overlay_views() -> void:
	_main_view.grey_background = autofree(FakeGreyBackground.new())
	_main_view.cycling_view = autofree(Control.new())
	_main_view.inventory_view = autofree(MenuBookView.new())
	_main_view.abilities_view = autofree(MenuBookView.new())
	_main_view.character_view = autofree(CharacterView.new())
	_main_view.path_tree_view = autofree(PathTreeView.new())

## Enters the overlay, checks both boards hide, exits it, checks both show.
func _assert_overlay_hides_boards(state: MainViewState, overlay_name: String) -> void:
	_add_overlay_views()
	_main_view.goals_panel.visible = true
	_main_view.log_window.visible = true
	state.enter()
	assert_false(_main_view.goals_panel.visible, "%s hides the Goals board" % overlay_name)
	assert_false(_main_view.log_window.visible, "%s hides the log" % overlay_name)
	state.exit()
	assert_true(_main_view.goals_panel.visible, "the Goals board is back after %s" % overlay_name)
	assert_true(_main_view.log_window.visible, "the log is back after %s" % overlay_name)

## Opens the book, checks both boards still show, closes it, checks again.
func _assert_book_keeps_boards(state: MainViewState, book_name: String) -> void:
	_add_overlay_views()
	_main_view.goals_panel.visible = true
	_main_view.log_window.visible = true
	state.enter()
	assert_true(_main_view.goals_panel.visible, "the Goals board stays beside %s" % book_name)
	assert_true(_main_view.log_window.visible, "the log stays beside %s" % book_name)
	state.exit()
	assert_true(_main_view.goals_panel.visible, "the Goals board still shows after %s" % book_name)
	assert_true(_main_view.log_window.visible, "the log still shows after %s" % book_name)

func test_cycling_hides_the_boards() -> void:
	_assert_overlay_hides_boards(_new_state(CyclingViewState.new()), "cycling")

func test_inventory_keeps_the_boards() -> void:
	_assert_book_keeps_boards(_new_state(InventoryViewState.new()), "the inventory")

func test_abilities_keep_the_boards() -> void:
	_assert_book_keeps_boards(_new_state(AbilitiesViewState.new()), "the abilities book")

func test_character_keeps_the_boards() -> void:
	_assert_book_keeps_boards(_new_state(CharacterViewState.new()), "the character book")

func test_path_tree_keeps_the_boards() -> void:
	_assert_book_keeps_boards(_new_state(PathTreeViewState.new()), "the path book")

func test_overlay_restores_a_board_that_was_hidden() -> void:
	_add_overlay_views()
	_main_view.log_window.visible = false
	var state: MainViewState = _new_state(CyclingViewState.new())
	state.enter()
	state.exit()
	assert_false(_main_view.log_window.visible, "a log hidden before the overlay stays hidden")
	assert_true(_main_view.goals_panel.visible)

## The shop can leave while cycling still covers it (MerchantViewState removes
## itself from under another view). The boards stay hidden until the last
## overlay closes, and then come back as they were before the first.
func test_boards_stay_hidden_until_the_last_overlay_closes() -> void:
	_add_overlay_views()
	_main_view.merchant_view = add_child_autofree(MerchantViewScene.instantiate())
	var merchant: MerchantViewState = _new_state(MerchantViewState.new())
	var cycling: MainViewState = _new_state(CyclingViewState.new())
	_main_view.state_stack = []
	merchant._on_start_merchant(load(MERCHANT_ACTION_PATH) as MerchantActionData)
	_main_view.push_state(cycling)
	merchant._on_stop_merchant()
	assert_false(_main_view.state_stack.has(merchant), "precondition: the shop left from under cycling")
	assert_false(_main_view.goals_panel.visible, "cycling still covers the Goals board")
	assert_false(_main_view.log_window.visible, "cycling still covers the log")
	_main_view.pop_state()
	assert_true(_main_view.goals_panel.visible, "back once the last overlay closed")
	assert_true(_main_view.log_window.visible)
