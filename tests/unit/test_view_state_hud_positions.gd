extends GutTest

## Unit tests for where each view state puts the HUD boards MainView shares
## between views (spec: Goals › Placement; plan Task 14). The zone view puts
## Goals under the cultivator cabinet and the log at the bottom left; the
## adventure view moves Goals to the free top right and the log to the top
## left, and puts both back when it ends; the merchant hides both.
## The MainView is never added to the tree: each test fills in the views and
## boards it needs with plain Controls, as test_merchant_view_state.gd does.

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const MERCHANT_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

## Kit §5.2, §5.3 and the spec's adventure placement, written out so the
## tests do not read the constants they check.
const ZONE_GOALS_POSITION: Vector2 = Vector2(24.0, 272.0)
const ZONE_LOG_POSITION: Vector2 = Vector2(24.0, 852.0)
const ADVENTURE_GOALS_POSITION: Vector2 = Vector2(1456.0, 24.0)
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
