extends GutTest

## Integration tests for the Tribulation as a Spirit Valley action. The card
## appears when Core Density reaches 100. ActionManager refuses the action below
## that and starts it at 100, stopping it hands the zone back to its idle action,
## a pass (the breakthrough) hides the card for good, and a failure (five levels
## lost) keeps the card but leaves it refused until the core is full again.
##
## The first tests drive the flow through ActionManager and CultivationManager
## alone. The last ones open the real board: the real TribulationView on a test
## clock, and the TribulationViewState that opens it, in the tree so that its
## _ready() connects ActionManager's signals, on a MainView that never enters the
## tree. They play a whole trial from the card back to the zone's idle action, pin
## that Continue closes the board at once, and check that a click on the zone chest
## during the trial reaches no card. Every test runs on a fresh save that all the
## managers are re-bound to, with the real Foundation and Copper stages. The
## original save goes back in after_each(), once nothing runs.

const Stage := CultivationManager.AdvancementStage
const Mode := TribulationView.Mode

const VIEW_SCENE_PATH: String = "res://scenes/tribulation/tribulation_view.tscn"
const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")

const ZONE_ID: String = "SpiritValley"
const TRIBULATION_ID: String = "spirit_valley_tribulation"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const MERCHANT_ID: String = "spirit_valley_merchant"

## The condition that reveals the Tribulation's card.
const FULL_CORE_CONDITION: String = "core_density_full"
## The event whose unlock condition opens Spring Forest Foraging.
const FORAGING_EVENT: String = "q_fill_core_completed"

## The board's clock when a run begins: _at(seconds) sets it to this plus `seconds`.
const START_USEC: int = 1_000_000

## How far past the end of the hold, or of the run, a test steps. The clock is whole
## microseconds, so a time written exactly can round a hair short of it.
const PAST: float = 0.01

## GUT's output window's canvas layer: a board that takes the pointer is hosted above it.
const GUT_OUTPUT_LAYER: int = 128

## Where the hosted card stands, in the zone chest's column (x 1456 to 1896).
const CARD_AT: Vector2 = Vector2(1464.0, 232.0)

var _original_save: SaveGameData = null

## The board as the game holds it, built by _build_board().
var _main_view: MainView = null
var _view: TribulationView = null
var _state: TribulationViewState = null
var _now_usec: int = START_USEC

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the managers back to the original save resumes the idle action it
	# left off with: stop that one too, so no timer runs on into the next file.
	_stop_everything()
	_view = null
	_state = null
	_main_view = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Never leave an action running for the next test. Stopping a session action
## can resume the idle one, so stop until nothing is left.
func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## The Spirit Valley action, as the card and the board get it.
func _tribulation() -> TribulationActionData:
	return ZoneManager.get_action_by_id(TRIBULATION_ID) as TribulationActionData

## Fills the core the way play does: the last level is earned with XP, so the
## level-up reaches the cap, announces the full core and runs the unlock check.
func _fill_core() -> void:
	PersistenceManager.save_game_data.core_density_level = 99.0
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())

## Unlocks Spring Forest Foraging. It is the zone's first idle action, so it
## starts at once.
func _run_foraging() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs")

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## The ids of the actions Spirit Valley offers now, in list order.
func _available_ids() -> Array[String]:
	var ids: Array[String] = []
	for action: ZoneActionData in ZoneManager.get_available_actions(ZONE_ID):
		ids.append(action.action_id)
	return ids

## The board as the game holds it: the real view on a test clock, a MainView that never
## enters the tree with plain stand-ins for the furniture, and the state that opens the
## board, in the tree so that its _ready() connects ActionManager's signals. The view goes
## under `host` when one is given (a CanvasLayer, say), otherwise under the test.
func _build_board(host: Node = null) -> void:
	_now_usec = START_USEC
	_view = (load(VIEW_SCENE_PATH) as PackedScene).instantiate() as TribulationView
	if host == null:
		add_child_autofree(_view)
	else:
		host.add_child(_view)
	_view.clock_usec = func() -> int: return _now_usec
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.tribulation_view = _view
	_main_view.log_window = autofree(Control.new())
	_main_view.goals_panel = autofree(Control.new())
	_main_view.dock = autofree(Control.new())
	_main_view.zone_map_viewport = autofree(SubViewport.new())
	_state = TribulationViewState.new()
	_state.scene_root = _main_view
	add_child_autofree(_state)

## A BoardTransition for the board's MainView, built from its scene with its processing off
## so the test drives it with advance() and finish() alone. Goals and the log stand where the
## zone view puts them. Call it after _build_board(), before the trial starts.
func _give_main_view_a_player() -> BoardTransition:
	_main_view.goals_panel.position = Vector2(24.0, 24.0)
	_main_view.goals_panel.size = Vector2(408.0, 360.0)
	_main_view.log_window.position = Vector2(24.0, 640.0)
	_main_view.log_window.size = Vector2(520.0, 416.0)
	var player: BoardTransition = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	player.set_process(false)
	_main_view.board_transition = player
	_main_view._bind_board_transition()
	return player

## Sets the board's clock to `seconds` into the run and runs one frame.
func _at(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)
	_view._process(0.0)

## The Space key going down (`down`), or coming up, as the game's input map binds the
## trial's press to it.
func _space(down: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = down
	return event

## The time of beat `index` of the running trial.
func _beat(index: int) -> float:
	return _view.get_run().get_beat_times()[index]

## The last beat of the running trial.
func _last_beat() -> int:
	return _view.get_run().get_beat_times().size() - 1

## Begins the run with Space, presses every beat on time, holds the last breath into the
## core and steps to the end: Space through the state, as the player's hand sends it.
func _play_clean_run() -> void:
	_now_usec = START_USEC
	_state.handle_input(_space())
	for index: int in _last_beat() + 1:
		_at(_beat(index))
		_state.handle_input(_space())
	_at(_beat(_last_beat()) + _view.get_run().get_hold_seconds() + PAST)
	_state.handle_input(_space(false))
	_at(_view.get_run().get_duration() + PAST)

## Presses Continue on the result panel.
func _continue() -> void:
	(_view.get_node("%ContinueButton") as TextureButton).pressed.emit()

#-----------------------------------------------------------------------------
# THE CARD APPEARS
#-----------------------------------------------------------------------------

func test_reaching_one_hundred_reveals_the_card() -> void:
	assert_does_not_have(_available_ids(), TRIBULATION_ID, "a core short of 100 hides the card")
	_fill_core()
	assert_true(UnlockManager.is_condition_unlocked(FULL_CORE_CONDITION), "the level-up to 100 unlocks the condition")
	assert_has(_available_ids(), TRIBULATION_ID, "and the card shows")

#-----------------------------------------------------------------------------
# STARTING THE TRIAL
#-----------------------------------------------------------------------------

func test_select_refuses_below_one_hundred() -> void:
	# The card stays listed after a failure (its condition is latched), so a click
	# on it with the core short must not stop what runs.
	_run_foraging()
	UnlockManager.force_unlock_condition(FULL_CORE_CONDITION)
	PersistenceManager.save_game_data.core_density_level = 95.0
	watch_signals(ActionManager)
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), FORAGING_ID, "the refused click leaves the current action running")
	assert_signal_not_emitted(ActionManager, "start_tribulation")
	assert_signal_not_emitted(ActionManager, "stop_foraging", "and nothing was stopped")

func test_select_at_one_hundred_starts_the_trial() -> void:
	_fill_core()
	var action: TribulationActionData = _tribulation()
	watch_signals(ActionManager)
	ActionManager.select_action(action)
	assert_signal_emitted_with_parameters(ActionManager, "start_tribulation", [action])
	assert_eq(ActionManager.get_current_action(), action, "the trial stays current until something stops it")

func test_stopping_resumes_the_idle_action() -> void:
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial replaced foraging")
	watch_signals(ActionManager)
	ActionManager.stop_action(false)
	assert_signal_emit_count(ActionManager, "stop_tribulation", 1)
	assert_eq(_current_id(), FORAGING_ID, "leaving the trial resumes foraging, like closing the shop")

#-----------------------------------------------------------------------------
# THE ACTION'S TWO QUESTIONS
#-----------------------------------------------------------------------------

## Copper's core fills at 100 as well, but this trial leads out of Foundation.
func test_a_full_copper_core_cannot_face_the_foundation_trial() -> void:
	_fill_core()
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: Foundation leads to a next stage")
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: Copper's core is full")
	assert_false(_tribulation().can_attempt(), "the stage is past the trial's")
	watch_signals(ActionManager)
	ActionManager.select_action(_tribulation())
	assert_signal_not_emitted(ActionManager, "start_tribulation")
	assert_null(ActionManager.get_current_action())

func test_the_trial_is_passed_from_its_target_stage_on() -> void:
	var action: TribulationActionData = _tribulation()
	assert_false(action.is_passed(), "Foundation has not passed it")
	for stage: Stage in [Stage.COPPER, Stage.IRON]:
		PersistenceManager.save_game_data.current_advancement_stage = stage
		assert_true(action.is_passed(), "stage %s is at or past the trial's target" % Stage.find_key(stage))

func test_an_action_without_a_tribulation_is_never_passed_or_startable() -> void:
	var action := TribulationActionData.new()
	assert_null(action.tribulation, "precondition: nothing to face")
	assert_false(action.is_passed())
	_fill_core()
	assert_false(action.can_attempt(), "a full core is not enough without a trial to face")

#-----------------------------------------------------------------------------
# THE BOARD, END TO END
#-----------------------------------------------------------------------------

## Select the card with the core full, play a trial that fails on its fourth crack, and
## press Continue: five levels are gone, the zone's idle action is back, the state is off
## the stack and the board hidden, and the card is still offered.
func test_a_failed_trial_end_to_end() -> void:
	_build_board()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial replaced foraging")
	assert_true(_main_view.state_stack.has(_state), "the state is pushed")
	assert_true(_view.visible, "and the board shows")
	assert_eq(_view.get_mode(), Mode.INTRO, "on its intro")
	_state.handle_input(_space())
	_at(_beat(3) + 0.15)
	assert_eq(_view.get_mode(), Mode.RESULT, "precondition: the fourth crack ended the trial")
	_continue()
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the failure cost five levels")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and the stage stays")
	assert_eq(_current_id(), FORAGING_ID, "foraging is current again")
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_false(_view.visible, "the board is hidden")
	assert_has(_available_ids(), TRIBULATION_ID, "the card is still offered")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "and the map takes input again")

## The same with a clean run: the breakthrough, the card gone for good, and foraging back.
func test_a_passed_trial_end_to_end() -> void:
	_build_board()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial replaced foraging")
	_play_clean_run()
	assert_eq(_view.get_mode(), Mode.RESULT, "precondition: the run ended")
	_continue()
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER, "the core broke through")
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "Copper starts at level 0")
	assert_eq(_current_id(), FORAGING_ID, "foraging is current again")
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_false(_view.visible, "the board is hidden")
	assert_does_not_have(_available_ids(), TRIBULATION_ID, "a passed Tribulation is not offered again")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "and the map takes input again")

## Not yet turns the trial down from the intro: nothing is lost, and the zone's idle action
## is back with the board closed.
func test_not_yet_end_to_end() -> void:
	_build_board()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	(_view.get_node("%NotYetButton") as TextureButton).pressed.emit()
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "nothing is lost")
	assert_eq(_current_id(), FORAGING_ID, "foraging is current again")
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_false(_view.visible, "the board is hidden")
	assert_has(_available_ids(), TRIBULATION_ID, "the card is still offered")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

## The view leaves its mode as it is when it emits finished, and relies on the synchronous
## stop chain (finished, stop_action, stop_tribulation, remove_state, exit, close): right
## after Continue the board is closed, so a second click finds no result panel and cannot
## emit again.
func test_continue_closes_the_board_at_once() -> void:
	_build_board()
	_fill_core()
	ActionManager.select_action(_tribulation())
	_state.handle_input(_space())
	_at(_beat(3) + 0.15)
	assert_eq(_view.get_mode(), Mode.RESULT, "precondition: the result shows")
	watch_signals(_view)
	_continue()
	assert_eq(_view.get_mode(), Mode.CLOSED, "closed right after the click, with no frame between")
	assert_false(_view.visible, "and hidden")
	_continue()
	assert_signal_emit_count(_view, "finished", 1, "a second click emits nothing")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the penalty is taken once")

## The state stops the Tribulation and only the Tribulation: a finished that arrives while
## another action runs leaves that action alone. Emitting the start signal by hand opens
## the board without making its action current, which stands in for the two drifting apart.
func test_finished_stops_only_the_tribulation() -> void:
	_build_board()
	_run_foraging()
	ActionManager.start_tribulation.emit(_tribulation())
	assert_true(_view.visible, "precondition: the board is up")
	assert_eq(_current_id(), FORAGING_ID, "and foraging runs, not the trial")
	watch_signals(ActionManager)
	_view.cancel()
	assert_eq(_current_id(), FORAGING_ID, "foraging runs on")
	assert_signal_not_emitted(ActionManager, "stop_foraging", "and nothing was stopped")

## Review Focus 3: the action stopped from outside mid-trial (a save reset, the dev panel)
## closes the board, applies nothing and removes the state.
func test_stopping_the_action_mid_trial_closes_the_board_and_applies_nothing() -> void:
	_build_board()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	_state.handle_input(_space())
	_at(3.0)
	ActionManager.stop_action(false)
	assert_eq(_view.get_mode(), Mode.CLOSED, "the board is closed")
	assert_false(_view.visible, "and hidden")
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "no level was lost")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and no breakthrough happened")
	assert_eq(_current_id(), FORAGING_ID, "foraging resumed")

## Review Focus 3, the other way in: a save reset mid-trial stops the action, which was
## started under the old save. The board closes, the state leaves the stack, and the new
## save's core is left as it was.
func test_a_save_reset_mid_trial_closes_the_board() -> void:
	_build_board()
	_fill_core()
	ActionManager.select_action(_tribulation())
	_state.handle_input(_space())
	_at(3.0)
	var fresh_save := SaveGameData.new()
	fresh_save.core_density_level = 100.0
	PersistenceManager.save_game_data = fresh_save
	PersistenceManager.save_data_reset.emit()
	assert_eq(_view.get_mode(), Mode.CLOSED, "the board is closed")
	assert_false(_view.visible, "and hidden")
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "the new save is left alone")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and so is its stage")

#-----------------------------------------------------------------------------
# THE BOARD ON THE TRANSITION
#-----------------------------------------------------------------------------

## The action stopped from outside while the board is still opening (ActionManager.stop_action();
## a dev session switch stops it from outside too). A run the board was handed is dropped, and nothing
## of it is applied however late the clock goes while the board shrinks away; the state
## leaves when the close has finished.
func test_a_stop_while_the_board_opens_applies_nothing_and_closes() -> void:
	_build_board()
	var player: BoardTransition = _give_main_view_a_player()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	player.advance(0.1)
	assert_true(_main_view.is_board_moving(), "precondition: the board is still opening")
	_view.begin()
	assert_eq(_view.get_mode(), Mode.RUNNING, "precondition: a run is under way")
	var late: float = _beat(_last_beat()) + _view.get_run().get_hold_seconds() + _view.get_run().get_duration()
	ActionManager.stop_action(false)
	assert_eq(_view.get_mode(), Mode.CLOSED, "the view is closed at the stop")
	assert_null(_view.get_run(), "and the run dropped")
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_true(_main_view.state_stack.has(_state), "the state waits for the close to end")
	assert_eq(_current_id(), FORAGING_ID, "foraging resumed")
	player.advance(0.1)
	_at(late)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "no level was lost")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and no breakthrough happened")
	player.finish()
	assert_false(_view.visible, "the board is hidden after the close")
	assert_false(_main_view.state_stack.has(_state), "and the state is gone")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "and the map takes input again")

## Escape on the intro while the board opens turns the trial down: the open turns around, and
## the state leaves when the board has closed, with foraging back.
func test_escape_while_the_board_opens_turns_it_around() -> void:
	_build_board()
	var player: BoardTransition = _give_main_view_a_player()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	player.advance(0.1)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	_state.handle_input(escape)
	assert_eq(_current_id(), FORAGING_ID, "foraging is current again")
	assert_true(_main_view.is_board_closing(), "the board turns around")
	assert_true(_main_view.state_stack.has(_state), "and the state waits for the close")
	player.finish()
	assert_false(_main_view.state_stack.has(_state), "the state leaves when the board has closed")
	assert_false(_view.visible, "the board is hidden")
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "nothing is lost")

## A failed trial on the transition: the failure is applied once, at the crack, and Continue
## stops the action. The board then shrinks away with the result still on it, and the state
## leaves when it has.
func test_a_failed_trial_closes_through_the_transition() -> void:
	_build_board()
	var player: BoardTransition = _give_main_view_a_player()
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	player.finish()
	_state.handle_input(_space())
	_at(_beat(3) + 0.15)
	assert_eq(_view.get_mode(), Mode.RESULT, "precondition: the fourth crack ended the trial")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the failure cost five levels at the crack")
	_continue()
	assert_eq(_current_id(), FORAGING_ID, "foraging is current again")
	assert_true(_main_view.is_board_closing(), "the board closes")
	assert_true(_view.visible, "and is still drawn")
	assert_true(_main_view.state_stack.has(_state), "the state waits for the close")
	player.finish()
	assert_false(_main_view.state_stack.has(_state), "the state is off the stack")
	assert_false(_view.visible, "the board is hidden")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the penalty was taken once")
	assert_has(_available_ids(), TRIBULATION_ID, "the card is still offered")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "and the map takes input again")

#-----------------------------------------------------------------------------
# CLICKS ON THE ZONE CHEST (Review Focus 5)
#-----------------------------------------------------------------------------

## A zone action card, as the chest lists it (at `at`: the zone chest's column unless told
## otherwise), and the board over it, both on a CanvasLayer above GUT's own window (which
## would otherwise cover the screen and take the click), the board after the card in the
## tree and at z 3 as main_game.tscn has it. The board is built but not opened.
func _host_card_under_board(at: Vector2 = CARD_AT) -> ZoneActionButton:
	var layer := CanvasLayer.new()
	layer.layer = GUT_OUTPUT_LAYER + 1
	add_child_autofree(layer)
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(ZoneManager.get_action_by_id(MERCHANT_ID))
	card.position = at
	layer.add_child(card)
	_build_board(layer)
	_view.z_index = 3
	return card

## A left press and its release at `point` in the viewport's own 1920x1080 space, as the
## mouse sends them. The headless window is scaled down, so the events go in local
## coordinates.
func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

## The control for the test below: with no board up, the same click on the same spot
## reaches the card and selects its action.
func test_a_click_reaches_a_card_when_no_board_is_up() -> void:
	var card: ZoneActionButton = _host_card_under_board()
	assert_true(card.is_new_shown(), "precondition: the merchant is unseen")
	_click(card.get_global_rect().get_center())
	assert_eq(_current_id(), MERCHANT_ID, "the click selected the card's action")
	assert_false(card.is_new_shown(), "and the card heard it")

## A click on the zone chest while the trial is open never reaches a card, so no other
## action can replace the trial. The board takes the click and, the card being outside its
## own rect, does nothing with it (Ruling S): the intro stays up, as it must for the second
## click of a double click on the Tribulation's own card.
func test_a_click_on_a_card_during_the_trial_selects_nothing() -> void:
	var card: ZoneActionButton = _host_card_under_board()
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial runs")
	assert_true(_view.visible, "and the board is up")
	assert_true(card.is_new_shown(), "precondition: the merchant is unseen")
	watch_signals(ActionManager)
	_click(card.get_global_rect().get_center())
	assert_eq(_current_id(), TRIBULATION_ID, "the trial is still the current action")
	assert_signal_not_emitted(ActionManager, "start_merchant", "the card selected nothing")
	assert_signal_not_emitted(ActionManager, "stop_tribulation", "and the trial was not stopped")
	assert_true(card.is_new_shown(), "the card never heard the click")
	assert_eq(_view.get_mode(), Mode.INTRO, "the board took it and left the intro up: only a click on the board begins the run")

## The same wherever the card stands: under the board's own rect the click does begin the run,
## and the card still hears nothing, so the trial stays the current action either way.
func test_a_click_on_a_card_under_the_board_selects_nothing() -> void:
	var card: ZoneActionButton = _host_card_under_board()
	_fill_core()
	ActionManager.select_action(_tribulation())
	await wait_process_frames(2)
	var board_rect: Rect2 = (_view.get_node("%Board") as Control).get_global_rect()
	var click_at: Vector2 = board_rect.position + Vector2(48.0, 48.0)
	card.position = click_at - Vector2(16.0, 16.0)
	assert_true(board_rect.has_point(click_at), "precondition: the click is on the board")
	assert_true(card.get_global_rect().has_point(click_at), "and the card stands under it")
	assert_true(card.is_new_shown(), "precondition: the merchant is unseen")
	watch_signals(ActionManager)
	_click(click_at)
	assert_eq(_current_id(), TRIBULATION_ID, "the trial is still the current action")
	assert_signal_not_emitted(ActionManager, "start_merchant", "the card selected nothing")
	assert_signal_not_emitted(ActionManager, "stop_tribulation", "and the trial was not stopped")
	assert_true(card.is_new_shown(), "the card never heard the click")
	assert_eq(_view.get_mode(), Mode.RUNNING, "the board took it: a click on the board begins the run")
