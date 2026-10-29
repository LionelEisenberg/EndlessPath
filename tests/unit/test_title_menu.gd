extends GutTest

## Unit tests for TitleMenu: when a launch opens it, when it offers Continue, and
## what Continue and New Game do. A GUT run never opens it on its own
## (should_open()), so each test opens it, and New Game's start is swapped for a
## counter: DevManager.new_game() is refused in a test run, which has no main save.
## Whether the launch wrote the save new is PersistenceManager's flag, set directly.
## Quit is not tested: it quits the runner.

const TITLE_MENU_SCENE: PackedScene = preload("res://scenes/ui/title_menu/title_menu.tscn")

var _menu: TitleMenu
var _original_opened_new_save: bool
var _new_games_started: int = 0

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_opened_new_save = PersistenceManager._opened_new_save
	_new_games_started = 0
	_menu = TITLE_MENU_SCENE.instantiate()
	add_child_autofree(_menu)
	await get_tree().process_frame
	_menu.start_new_game = func() -> void: _new_games_started += 1

func after_each() -> void:
	get_tree().paused = false
	PersistenceManager._opened_new_save = _original_opened_new_save

#-----------------------------------------------------------------------------
# WHEN IT OPENS
#-----------------------------------------------------------------------------

func test_only_the_first_launch_on_your_own_save_opens_it() -> void:
	var cases: Array[Dictionary] = [
		{"name": "your save, first time", "kind": DevManager.SessionKind.YOUR_SAVE, "test_run": false, "opened_before": false, "opens": true},
		{"name": "a preset", "kind": DevManager.SessionKind.PRESET, "test_run": false, "opened_before": false, "opens": false},
		{"name": "a --save file", "kind": DevManager.SessionKind.FILE, "test_run": false, "opened_before": false, "opens": false},
		{"name": "a GUT run", "kind": DevManager.SessionKind.YOUR_SAVE, "test_run": true, "opened_before": false, "opens": false},
		{"name": "the main scene loaded again", "kind": DevManager.SessionKind.YOUR_SAVE, "test_run": false, "opened_before": true, "opens": false},
	]
	for case: Dictionary in cases:
		assert_eq(TitleMenu.should_open(case.kind, case.test_run, case.opened_before), case.opens, case.name)

func test_a_test_run_leaves_it_closed() -> void:
	assert_false(_menu.visible, "the menu stays hidden")
	assert_false(get_tree().paused, "the game runs")

func test_opening_it_pauses_the_game() -> void:
	_menu.open()
	assert_true(_menu.visible, "the menu shows")
	assert_true(get_tree().paused, "the game is paused behind it")

#-----------------------------------------------------------------------------
# CONTINUE
#-----------------------------------------------------------------------------

func test_continue_needs_a_save_that_was_there_and_can_be_written() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a save from an earlier launch", "opened_new": false, "blocked": false, "offered": true},
		{"name": "the save this launch wrote new", "opened_new": true, "blocked": false, "offered": false},
		{"name": "a save this build cannot write", "opened_new": false, "blocked": true, "offered": false},
	]
	for case: Dictionary in cases:
		assert_eq(TitleMenu.can_continue(case.opened_new, case.blocked), case.offered, case.name)

func test_opening_it_offers_continue_by_the_launch_save() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a save from an earlier launch", "opened_new": false, "offered": true},
		{"name": "the save this launch wrote new", "opened_new": true, "offered": false},
	]
	for case: Dictionary in cases:
		PersistenceManager._opened_new_save = case.opened_new
		_menu.open()
		assert_eq(_continue_button().visible, case.offered, case.name)
		_menu.close()

func test_continue_closes_it_and_lets_the_game_run() -> void:
	_menu.open()
	_continue_button().pressed.emit()
	assert_false(_menu.visible, "the menu hides")
	assert_false(get_tree().paused, "the game runs")
	assert_eq(_new_games_started, 0, "no new game starts")

#-----------------------------------------------------------------------------
# NEW GAME
#-----------------------------------------------------------------------------

func test_new_game_on_the_save_this_launch_wrote_only_closes_it() -> void:
	PersistenceManager._opened_new_save = true
	_menu.open()
	_new_game_button().pressed.emit()
	assert_false(_menu.visible, "the menu hides")
	assert_false(get_tree().paused, "the game runs")
	assert_eq(_new_games_started, 0, "the save is new already, so nothing replaces it")

func test_new_game_on_an_earlier_save_waits_for_a_second_click() -> void:
	_menu.open()
	_new_game_button().pressed.emit()
	assert_eq(_new_games_started, 0, "the first click starts nothing")
	assert_true(_menu.visible, "the menu stays open for the second click")
	_new_game_button().pressed.emit()
	assert_eq(_new_games_started, 1, "the second click starts a new game")
	assert_false(_menu.visible, "the menu hides")
	assert_false(get_tree().paused, "the game runs before the new game loads")

func test_new_game_asks_again_once_the_confirm_runs_out() -> void:
	_menu.open()
	_new_game_button().pressed.emit()
	var confirm_timer: Timer = _menu.get_node("%ConfirmTimer")
	confirm_timer.stop()
	confirm_timer.timeout.emit()
	_new_game_button().pressed.emit()
	assert_eq(_new_games_started, 0, "the click after the confirm ran out asks again")

func test_closing_it_forgets_the_first_new_game_click() -> void:
	_menu.open()
	_new_game_button().pressed.emit()
	_continue_button().pressed.emit()
	_menu.open()
	_new_game_button().pressed.emit()
	assert_eq(_new_games_started, 0, "the click after reopening asks again")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _continue_button() -> TitleMenuButton:
	return _menu.get_node("%ContinueButton")

func _new_game_button() -> TitleMenuButton:
	return _menu.get_node("%NewGameButton")
