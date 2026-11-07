extends GutTest

## Integration tests for the "Head out?" board (AdventureConfirmBoard) and its
## state (AdventureConfirmState): ActionManager's question pushes the state and
## the board names each low pool and what refills it; Head out starts the run
## through select_action(); Not yet, Esc and a click outside the board start
## nothing, and the idle action runs on; the menu books' keys do nothing while it
## asks. The MainView is never added to the tree: the test fills in what the
## state needs.

const BOARD_SCENE: PackedScene = preload("res://scenes/zones/adventure_confirm/adventure_confirm_board.tscn")
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const AURA_WELL_ID: String = "aura_well_training"
const AURA_WELL_EVENT: String = "aura_well_discovered"
## Opens Riverbank Training, which the Health lines then name.
const RIVERBANK_EVENT: String = "riverbank_training_opened"

var _original_save: SaveGameData = null
var _board: AdventureConfirmBoard = null
var _main_view: MainView = null
var _state: AdventureConfirmState = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_board = BOARD_SCENE.instantiate() as AdventureConfirmBoard
	add_child_autofree(_board)
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.adventure_confirm_board = _board
	_main_view.log_window = autofree(Control.new())
	_state = AdventureConfirmState.new()
	_state.scene_root = _main_view
	add_child_autofree(_state)
	# The Aura Well's unlock starts it: the idle action a Not yet leaves running.
	EventManager.trigger_event(AURA_WELL_EVENT)

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _adventure() -> AdventureActionData:
	return ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

func _ask(health: float, madra: float) -> void:
	ResourceManager.set_health(health)
	ResourceManager.set_madra(madra)
	ActionManager.ask_to_start_adventure(_adventure())

func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _pool(pool_name: String) -> HBoxContainer:
	return _board.get_node("%" + pool_name) as HBoxContainer

func _pool_text(pool_name: String) -> String:
	return (_pool(pool_name).get_node("%YieldText") as RichTextLabel).get_parsed_text()

func _advice() -> String:
	return (_board.get_node("%Advice") as Label).text

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## The question puts the board up over the zone view, once however often it is
## asked.
func test_the_question_puts_the_board_up_once() -> void:
	_ask(30.0, 100.0)
	_ask(30.0, 100.0)
	assert_eq(_main_view.state_stack, [_state] as Array[MainViewState], "one entry on the stack")
	assert_true(_board.visible, "the board asks")
	assert_eq(_current_id(), AURA_WELL_ID, "nothing has started yet")

## Each low pool shows as its figure, the cabinet's, with what refills it.
func test_the_board_names_each_low_pool() -> void:
	EventManager.trigger_event(RIVERBANK_EVENT)
	var cases: Array[Dictionary] = [
		{"name": "Health", "health": 37.2, "madra": 100.0, "shown": [true, false], "health_text": "38 / 100", "madra_text": "", "advice": AdventureConfirmBoard.HEALTH_ADVICE},
		{"name": "Madra", "health": 100.0, "madra": 40.0, "shown": [false, true], "health_text": "", "madra_text": "40 / 100", "advice": AdventureConfirmBoard.MADRA_ADVICE},
		{"name": "both", "health": 38.0, "madra": 40.0, "shown": [true, true], "health_text": "38 / 100", "madra_text": "40 / 100", "advice": AdventureConfirmBoard.BOTH_ADVICE},
		{"name": "no Health", "health": 0.0, "madra": 40.0, "shown": [true, true], "health_text": "0 / 100", "madra_text": "40 / 100", "advice": AdventureConfirmBoard.NO_HEALTH_ADVICE},
	]
	for case: Dictionary in cases:
		_ask(case.health, case.madra)
		assert_eq([_pool("HealthPool").visible, _pool("MadraPool").visible], case.shown, "%s: the low pools show" % case.name)
		if case.shown[0]:
			assert_eq(_pool_text("HealthPool"), case.health_text, "%s: Health as the cabinet reads it" % case.name)
		if case.shown[1]:
			assert_eq(_pool_text("MadraPool"), case.madra_text, "%s: Madra as the cabinet reads it" % case.name)
		assert_eq(_advice(), case.advice, "%s: what refills it" % case.name)
		_board.dismissed.emit()

## The first adventure can send the player home hurt before First Steps Out's
## end opens Riverbank Training: until then the Health lines don't name it.
func test_the_health_lines_name_the_river_only_once_it_is_open() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Health", "health": 38.0, "madra": 100.0, "advice": AdventureConfirmBoard.HEALTH_ADVICE_BEFORE_RIVER},
		{"name": "both", "health": 38.0, "madra": 40.0, "advice": AdventureConfirmBoard.BOTH_ADVICE_BEFORE_RIVER},
		{"name": "no Health", "health": 0.0, "madra": 100.0, "advice": AdventureConfirmBoard.NO_HEALTH_ADVICE_BEFORE_RIVER},
		{"name": "Madra", "health": 100.0, "madra": 40.0, "advice": AdventureConfirmBoard.MADRA_ADVICE},
	]
	for case: Dictionary in cases:
		_ask(case.health, case.madra)
		assert_eq(_advice(), case.advice, "%s: before the river opens" % case.name)
		_board.dismissed.emit()

## Head out takes the board down and starts the run.
func test_head_out_starts_the_run() -> void:
	_ask(30.0, 100.0)
	(_board.get_node("%GoButton") as TextureButton).pressed.emit()
	assert_eq(_main_view.state_stack, [] as Array[MainViewState], "the board's state is off the stack")
	assert_false(_board.visible, "the board is down")
	assert_eq(_current_id(), ADVENTURE_ID, "the run starts")

## Not yet, Esc and a click outside the board take it down and start nothing.
func test_every_way_out_starts_nothing() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var ways: Array[Dictionary] = [
		{"name": "Not yet", "do": func() -> void: (_board.get_node("%StayButton") as TextureButton).pressed.emit()},
		{"name": "Esc", "do": func() -> void: _state.handle_input(_action_event(&"ui_cancel"))},
		{"name": "a click away", "do": func() -> void: (_board.get_node("%ClickAway") as Control).gui_input.emit(press)},
	]
	for way: Dictionary in ways:
		_ask(30.0, 30.0)
		(way.do as Callable).call()
		assert_eq(_main_view.state_stack, [] as Array[MainViewState], "%s: the board's state is off the stack" % way.name)
		assert_false(_board.visible, "%s: the board is down" % way.name)
		assert_eq(_current_id(), AURA_WELL_ID, "%s: the Aura Well runs on" % way.name)

## While it asks, the menu books' keys open nothing.
func test_a_book_key_does_nothing_while_it_asks() -> void:
	_ask(30.0, 100.0)
	for key: StringName in [&"open_inventory", &"open_character", &"open_abilities", &"open_path"]:
		_state.handle_input(_action_event(key))
	assert_eq(_main_view.state_stack, [_state] as Array[MainViewState], "only the question is up")
	assert_true(_board.visible, "and it still asks")
