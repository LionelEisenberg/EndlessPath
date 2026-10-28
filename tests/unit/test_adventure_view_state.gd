extends GutTest

## Unit tests for AdventureViewState's dither dissolve: the zone view gives way
## to an adventure, and the adventure back to the zone view, through MainView's
## ViewDissolve, which takes its still of the old view before the views change.
## The MainView is never added to the tree: each test fills in the views and
## states it needs with plain Controls and stand-ins, as
## test_view_state_hud_positions.gd does.

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stands in for the AdventureView, which AdventureViewState only shows,
## hides and listens to for the end of the adventure.
class FakeAdventureView:
	extends Control

	signal adventure_completed(result_data: AdventureResultData)

## Stands in for MainView's ViewDissolve: counts its plays and notes which view
## showed when each still was taken.
class FakeViewDissolve:
	extends ViewDissolve

	var main_view: MainView = null
	var plays: int = 0
	var zone_view_showed: Array[bool] = []
	var adventure_view_showed: Array[bool] = []

	func play() -> void:
		plays += 1
		zone_view_showed.append(main_view.zone_view.visible)
		adventure_view_showed.append(main_view.adventure_view.visible)

var _main_view: MainView
var _dissolve: FakeViewDissolve
var _adventure_state: AdventureViewState

func before_each() -> void:
	_main_view = autofree(MainView.new())
	_main_view.zone_view = autofree(Control.new())
	_main_view.adventure_view = autofree(FakeAdventureView.new())
	_main_view.adventure_view.visible = false # as in main_game.tscn
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())
	_dissolve = autofree(FakeViewDissolve.new())
	_dissolve.main_view = _main_view
	_main_view.view_dissolve = _dissolve
	_main_view.zone_view_state = _new_state(ZoneViewState.new())
	_adventure_state = _new_state(AdventureViewState.new())
	_main_view.adventure_view_state = _adventure_state
	_main_view.adventure_end_card_state = _new_state(MainViewState.new())
	_main_view.change_state(_main_view.zone_view_state)

func _new_state(state: MainViewState) -> MainViewState:
	state.scene_root = _main_view
	return autofree(state)

#-----------------------------------------------------------------------------
# INTO THE ADVENTURE
#-----------------------------------------------------------------------------

func test_starting_the_adventure_dissolves_the_zone_view_away() -> void:
	_adventure_state._on_start_adventure(null, 100.0)
	assert_eq(_dissolve.plays, 1, "one dissolve into the adventure")
	assert_eq(_main_view.base_current_state, _adventure_state, "the adventure view is up under it")

func test_the_still_is_the_zone_view() -> void:
	_adventure_state._on_start_adventure(null, 100.0)
	assert_eq(_dissolve.zone_view_showed, [true], "taken while the zone view still showed")
	assert_eq(_dissolve.adventure_view_showed, [false], "before the adventure view showed")

#-----------------------------------------------------------------------------
# BACK TO THE ZONE
#-----------------------------------------------------------------------------

func test_returning_from_the_end_card_dissolves_the_adventure_away() -> void:
	_adventure_state._on_start_adventure(null, 100.0)
	_main_view.push_state(_main_view.adventure_end_card_state)
	_adventure_state._on_end_card_return()
	assert_eq(_dissolve.plays, 2, "a second dissolve, back to the zone")
	assert_eq(_main_view.base_current_state, _main_view.zone_view_state, "the zone view is up under it")
	assert_eq(_dissolve.adventure_view_showed, [false, true], "taken while the adventure still showed")
	assert_eq(_dissolve.zone_view_showed, [true, false], "before the zone view showed again")

func test_no_dissolve_without_one() -> void:
	_main_view.view_dissolve = null
	_adventure_state._on_start_adventure(null, 100.0)
	assert_eq(_main_view.base_current_state, _adventure_state, "the views still change")
