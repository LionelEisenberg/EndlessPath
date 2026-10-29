extends GutTest

## Integration tests for the Tribulation board (TribulationView), the breathing trial
## a full core faces in the zone view's map gap. The board opens on its intro, and a
## press (Space, or a click on the board) begins the run; a click anywhere else on the
## intro does nothing, though the board still takes it. The press is judged against the
## board's clock when it arrives, and the frames judge the beats that pass. Each
## judgement shows itself as a floater word; a crack lights a pip, and hits grow the
## core. The last breath ends in a hold, which only the input that started it lets go
## (or a focus loss). The fourth crack fails the trial at once and costs five levels;
## a clean run breaks through to Copper.
##
## Each test runs on a fresh save at level 100 on the real stages, with the original
## put back after it. The board's clock is the test's: _at() sets it and runs a frame,
## so every time below is the trial's own, in seconds from begin(). The shipped
## Foundation Tribulation's beats: 0 at 2.5623 s, 3 at 7.6623 s, the last (24) at
## 35.5389 s, held for 1.2311 s; the run ends at 37.97 s.

const VIEW_SCENE_PATH: String = "res://scenes/tribulation/tribulation_view.tscn"
const DATA_PATH: String = "res://resources/tribulation/foundation_tribulation.tres"

const Mode := TribulationView.Mode
const Stage := CultivationManager.AdvancementStage

const ZONE_NAME: String = "Spirit Valley"
## Long enough to wrap at the board's 900 px.
const LONG_ZONE_NAME: String = "The Valley of the Thousand Whispering Springs, Where the Old Cultivators Breathed Beneath the Silver Moon and Listened to the Aura Pour Down the Mountain for Ten Thousand Years"

## The board's clock when a run begins: _at(seconds) sets it to this plus `seconds`.
const START_USEC: int = 1_000_000

## A detail line's height (15 / 18, padded): what each wrapped line adds to the board.
const DETAIL_LINE: float = 18.0

## How far past the end of the hold, or of the run, a test steps. The clock is whole
## microseconds, so a time written exactly can round a hair short of it.
const PAST: float = 0.01

var _view: TribulationView = null
var _data: TribulationData = null
var _now_usec: int = START_USEC
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_use_full_core_save()
	_now_usec = START_USEC
	_data = load(DATA_PATH) as TribulationData
	_view = (load(VIEW_SCENE_PATH) as PackedScene).instantiate() as TribulationView
	add_child_autofree(_view)
	_view.clock_usec = func() -> int: return _now_usec
	_view.setup(_data, ZONE_NAME)

func after_each() -> void:
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the managers back to the original save resumes the idle action it
	# left off with: stop that one too, so no timer runs on into the next file.
	_stop_everything()
	_view = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A fresh save whose core is full: Foundation, level 100.
func _use_full_core_save() -> void:
	var save := SaveGameData.new()
	save.core_density_level = 100.0
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## Never leave an action running for the next test.
func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _node(unique_name: String) -> Node:
	return _view.get_node("%" + unique_name)

## Sets the board's clock to `seconds` into the run and runs one frame.
func _at(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)
	_view._process(0.0)

## Sets the board's clock to `seconds` into the run, without a frame.
func _clock_to(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)

## A press of the trial's input (`down`), or its release.
func _press(down: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"tribulation_press"
	event.pressed = down
	return event

## A left mouse button going down, or coming up, at `at`. The view fills the screen from
## (0, 0), so its own space is the screen's, and the event's position is the same in both.
func _mouse(down: bool, at: Vector2 = Vector2.ZERO) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	return event

## The time of beat `index` of the running trial.
func _beat(index: int) -> float:
	return _view.get_run().get_beat_times()[index]

## The last beat of the running trial.
func _last_beat() -> int:
	return _view.get_run().get_beat_times().size() - 1

## Steps to each beat from `from` to `to` and presses on it.
func _hit_beats(from: int, to: int) -> void:
	for index: int in range(from, to + 1):
		_at(_beat(index))
		_view.handle_press_event(_press())

## Steps to the end of the run.
func _at_the_end() -> void:
	_at(_view.get_run().get_duration() + PAST)

## Begins a run, presses every beat on time, holds the last breath into the core and
## steps to the end.
func _play_clean_run() -> void:
	_now_usec = START_USEC
	_view.begin()
	_hit_beats(0, _last_beat())
	_at(_beat(_last_beat()) + _view.get_run().get_hold_seconds() + PAST)
	_view.handle_press_event(_press(false))
	_at_the_end()

## The four floaters on the stage.
func _floaters() -> Array[LacquerFloater]:
	var floaters: Array[LacquerFloater] = []
	for child: Node in _node("Floaters").get_children():
		if child is LacquerFloater:
			floaters.append(child as LacquerFloater)
	return floaters

## The floater showing `text`, or null when none shows it.
func _shown_floater(text: String) -> LacquerFloater:
	for floater: LacquerFloater in _floaters():
		if floater.visible and floater.get_text() == text:
			return floater
	return null

## The texts of the floaters that show.
func _shown_texts() -> Array[String]:
	var texts: Array[String] = []
	for floater: LacquerFloater in _floaters():
		if floater.visible:
			texts.append(floater.get_text())
	return texts

## The six crack pips, in order.
func _pips() -> Array[LacquerStripRect]:
	var pips: Array[LacquerStripRect] = []
	for child: Node in _node("CrackPips").get_children():
		pips.append(child as LacquerStripRect)
	return pips

func _core_frame() -> Vector2i:
	return (_node("Core") as LacquerStripRect).get_frame()

func _text_of(unique_name: String) -> String:
	return (_node(unique_name) as Label).text

#-----------------------------------------------------------------------------
# THE INTRO
#-----------------------------------------------------------------------------

func test_setup_shows_the_intro_with_the_rules() -> void:
	assert_true(_view.visible, "the board shows")
	assert_eq(_view.get_mode(), Mode.INTRO)
	assert_true((_node("IntroPanel") as Control).visible, "the intro shows")
	assert_false((_node("ResultPanel") as Control).visible, "the result does not")
	assert_eq(_text_of("RulesLabel"), "4 cracks end the trial and cost 5 levels of Core Density.")
	assert_eq(_text_of("ActionLabel"), ZONE_NAME)
	var pips: Array[LacquerStripRect] = _pips()
	assert_eq(pips.size(), 6, "six pip sockets")
	for index: int in pips.size():
		assert_eq(pips[index].visible, index < 4, "pip %d shows only for one of the 4 cracks that fail" % index)
		assert_eq(pips[index].get_frame(), Vector2i(0, 0), "pip %d is unlit" % index)
	assert_eq((_node("ProgressRod") as LacquerRod).get_step(), 0, "the rod is empty")
	assert_eq(_core_frame(), Vector2i(0, 0), "the smallest whole core")
	assert_null(_view.get_run(), "no run before Begin")

## Review Focus 5: a click on the zone chest during the trial never reaches a card.
func test_the_view_stops_every_click_beneath_it() -> void:
	assert_eq(_view.mouse_filter, Control.MOUSE_FILTER_STOP, "the full-screen root stops every click")
	assert_eq([_view.anchor_left, _view.anchor_top, _view.anchor_right, _view.anchor_bottom], [0.0, 0.0, 1.0, 1.0], "and covers the screen")
	var board := _node("Board") as Control
	assert_eq(board.mouse_filter, Control.MOUSE_FILTER_PASS, "the board passes its clicks on to the root")
	var buttons: Array[Node] = [_node("BeginButton"), _node("NotYetButton"), _node("ContinueButton")]
	var takers: Array[String] = []
	# The scene's own nodes and those of the scenes it instances. The engine's internal
	# children (a RichTextLabel's hidden scroll bar) belong to no scene and are left out.
	for node: Node in _view.find_children("*", "Control", true, true):
		if node == board or buttons.has(node):
			continue
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append(String(node.name))
	assert_eq(takers.size(), 0, "every node but the board and the buttons lets a click through to the root, not %s" % [takers])

## Ruling S: on the intro only a click on the board begins the trial. The second click of a
## double click on the card that opened it lands outside the board, and a run cannot be left
## once it starts, so a click there must skip neither the rules nor Not yet.
func test_a_click_outside_the_board_on_the_intro_does_nothing() -> void:
	await wait_process_frames(2)
	var board_rect: Rect2 = (_node("Board") as Control).get_global_rect()
	var around: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(board_rect.position.x - 24.0, board_rect.get_center().y),
		Vector2(board_rect.end.x + 24.0, board_rect.get_center().y),
		Vector2(board_rect.get_center().x, board_rect.end.y + 24.0),
	]
	for point: Vector2 in around:
		assert_false(board_rect.has_point(point), "precondition: %s is off the board %s" % [point, board_rect])
		_view._gui_input(_mouse(true, point))
		_view._gui_input(_mouse(false, point))
		assert_eq(_view.get_mode(), Mode.INTRO, "a click at %s leaves the intro up" % point)
	assert_null(_view.get_run(), "no run began")
	assert_true((_node("IntroPanel") as Control).visible, "and the rules still show")

func test_a_click_on_the_board_on_the_intro_begins_the_run() -> void:
	await wait_process_frames(2)
	var board_rect: Rect2 = (_node("Board") as Control).get_global_rect()
	var on_the_board: Array[Vector2] = [
		board_rect.get_center(),
		board_rect.position + Vector2(2.0, 2.0),
		board_rect.end - Vector2(2.0, 2.0),
	]
	for point: Vector2 in on_the_board:
		_view.setup(_data, ZONE_NAME)
		assert_true(board_rect.has_point(point), "precondition: %s is on the board %s" % [point, board_rect])
		_view._gui_input(_mouse(true, point))
		assert_eq(_view.get_mode(), Mode.RUNNING, "a click at %s begins the run" % point)
		assert_not_null(_view.get_run(), "a run has begun")

## Space begins the run wherever the pointer is: a key has no position to be off the board.
func test_space_begins_the_run_wherever_the_pointer_is() -> void:
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	assert_true(_view.handle_press_event(space), "the board takes the key")
	assert_eq(_view.get_mode(), Mode.RUNNING, "Space begins the run")

## Once the run goes on, nothing changes: a click anywhere is a press, as the brief says.
func test_a_click_anywhere_is_still_a_press_while_the_run_goes_on() -> void:
	_view.begin()
	_at(_beat(0))
	_view._gui_input(_mouse(true, Vector2.ZERO))
	assert_eq(_view.get_run().perfect_count, 1, "a click at the screen's corner hits the beat")

func test_buttons_take_no_focus() -> void:
	for button_name: String in ["BeginButton", "NotYetButton", "ContinueButton"]:
		assert_eq((_node(button_name) as Control).focus_mode, Control.FOCUS_NONE, "%s takes no focus, so Space never presses it" % button_name)

func test_a_press_on_the_intro_begins() -> void:
	assert_true(_view.handle_press_event(_press()), "the board takes the press")
	assert_eq(_view.get_mode(), Mode.RUNNING)
	assert_false((_node("IntroPanel") as Control).visible, "the intro hides")
	assert_not_null(_view.get_run(), "a run has begun")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_A
	other.pressed = true
	assert_false(_view.handle_press_event(other), "another input is not the board's")

func test_cancel_mid_run_does_nothing() -> void:
	watch_signals(_view)
	_view.begin()
	_view.cancel()
	assert_signal_not_emitted(_view, "finished", "a run once begun has no way out")
	assert_eq(_view.get_mode(), Mode.RUNNING)

func test_not_yet_finishes_without_a_run() -> void:
	watch_signals(_view)
	(_node("NotYetButton") as TextureButton).pressed.emit()
	assert_signal_emitted_with_parameters(_view, "finished", [false])
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "nothing is lost")
	assert_null(_view.get_run(), "no run began")

#-----------------------------------------------------------------------------
# JUDGING AND FEEDBACK
#-----------------------------------------------------------------------------

func test_press_is_judged_at_its_arrival_time() -> void:
	_view.begin()
	# No frame has run since the begin: the press reads the clock itself.
	_clock_to(_beat(0))
	_view.handle_press_event(_press())
	assert_eq(_view.get_run().perfect_count, 1)

## A press long after the last beat: the miss it left behind is judged first, so the
## press's own word is the one that stays up.
func test_a_hit_shows_after_the_miss_it_left_behind() -> void:
	_view.begin()
	_clock_to(_beat(1))
	_view.handle_press_event(_press())
	_at(_beat(1))
	assert_eq(_view.get_run().cracks, 1, "beat 0 was missed")
	assert_eq(_pips()[0].get_frame(), Vector2i(1, 0), "and its pip lit")
	assert_eq(_shown_texts(), ["Perfect"] as Array[String], "the hit on beat 1 shows, not the miss before it")

func test_late_miss_lights_a_pip() -> void:
	_view.begin()
	_at(_beat(0) + 0.2)
	var pips: Array[LacquerStripRect] = _pips()
	assert_eq(pips[0].get_frame(), Vector2i(1, 0), "the first pip lights")
	assert_eq(pips[1].get_frame(), Vector2i(0, 0), "the second does not")
	assert_not_null(_shown_floater("Miss"), "a floater reads Miss, among %s" % [_shown_texts()])
	assert_not_null(_shown_floater("Too late"), "and one under it reads Too late")

func test_core_grows_with_hits() -> void:
	_view.begin()
	_hit_beats(0, 6)
	assert_eq(_core_frame().x, 1, "seven hits grow the core a size")
	assert_eq(_core_frame().y, 0, "and it is whole")

func test_phase_labels_follow_the_run() -> void:
	_view.begin()
	_at(1.0)
	assert_eq(_text_of("PhaseNameLabel"), "Steady breath")
	_hit_beats(0, 5)
	_at(11.5)
	assert_eq(_text_of("PhaseNameLabel"), "Heartbeat")
	assert_eq(_text_of("PhaseTipLabel"), "The rhythm breaks. Follow it.")

#-----------------------------------------------------------------------------
# THE HOLD
#-----------------------------------------------------------------------------

func test_the_held_breath_counts_as_a_hit() -> void:
	# Five beats and the last: six hits leave the core at its first size, and the
	# hold is the seventh.
	var phase := TribulationPhaseData.new()
	phase.phase_name = "Five breaths"
	phase.breath_periods = PackedFloat32Array([1.7, 1.7, 1.7, 1.7, 1.7])
	var data := TribulationData.new()
	data.phases.append(phase)
	_view.setup(data, ZONE_NAME)
	_view.begin()
	_hit_beats(0, _last_beat())
	assert_true(_view.get_run().is_holding(), "the last beat's hit holds")
	assert_not_null(_shown_floater("Perfect · hold"), "the last beat's hit says to hold, among %s" % [_shown_texts()])
	assert_eq(_core_frame().x, 0, "six hits")
	_at(_beat(_last_beat()) + _view.get_run().get_hold_seconds() + PAST)
	assert_not_null(_shown_floater("Held"), "the hold runs into the core, among %s" % [_shown_texts()])
	assert_eq(_core_frame().x, 1, "the hold counts as a hit")

## Review Focus 1: the Space key's repeats during the hold are not presses.
func test_key_repeat_does_not_press_again() -> void:
	_view.begin()
	_hit_beats(0, 24)
	var run: TribulationRun = _view.get_run()
	assert_true(run.is_holding(), "precondition: the hold is on")
	_clock_to(_beat(24) + 0.3)
	var repeat := InputEventKey.new()
	repeat.physical_keycode = KEY_SPACE
	repeat.pressed = true
	repeat.echo = true
	assert_true(_view.handle_press_event(repeat), "the board takes the repeat")
	assert_true(run.is_holding(), "the hold goes on")
	assert_eq(run.cracks, 0)

## A held key repeats on a beat too: the repeat is no press, so holding Space down
## never hits a beat for the player.
func test_a_key_repeat_on_a_beat_is_no_hit() -> void:
	_view.begin()
	_clock_to(_beat(0))
	var repeat := InputEventKey.new()
	repeat.physical_keycode = KEY_SPACE
	repeat.pressed = true
	repeat.echo = true
	assert_true(_view.handle_press_event(repeat), "the board takes the repeat")
	var run: TribulationRun = _view.get_run()
	assert_eq(run.perfect_count + run.good_count, 0, "it hits nothing")
	_at(_beat(0) + 0.2)
	assert_eq(run.cracks, 1, "and the beat passes unpressed")

func test_a_mouse_release_leaves_a_key_hold() -> void:
	_view.begin()
	_hit_beats(0, 24)
	var run: TribulationRun = _view.get_run()
	_clock_to(_beat(24) + 0.3)
	_view._gui_input(_mouse(false))
	assert_true(run.is_holding(), "the mouse did not start the hold")
	assert_eq(run.cracks, 0)
	_view.handle_press_event(_press(false))
	assert_false(run.is_holding(), "the key that started it lets it go")
	assert_eq(run.cracks, 1, "too early")

func test_a_key_release_leaves_a_mouse_hold() -> void:
	_view.begin()
	_hit_beats(0, 23)
	_at(_beat(24))
	_view._gui_input(_mouse(true))
	var run: TribulationRun = _view.get_run()
	assert_true(run.is_holding(), "a click holds the last beat")
	_clock_to(_beat(24) + 0.3)
	_view.handle_press_event(_press(false))
	assert_true(run.is_holding(), "the key did not start the hold")
	_view._gui_input(_mouse(false))
	assert_false(run.is_holding(), "the mouse button lets it go")
	assert_eq(run.cracks, 1)

func test_focus_loss_during_the_hold_releases_it() -> void:
	_view.begin()
	_hit_beats(0, 24)
	var run: TribulationRun = _view.get_run()
	_clock_to(_beat(24) + 0.3)
	_view.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(run.is_holding(), "a key-up lost to another window cannot keep the hold")
	assert_eq(run.cracks, 1, "released too early")
	_at_the_end()
	assert_eq(_view.get_mode(), Mode.RESULT, "the clock kept going to the end")
	assert_eq(_text_of("GradeLabel"), "Clean")

func test_focus_loss_outside_the_hold_changes_nothing() -> void:
	_view.begin()
	_at(1.0)
	_view.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var run: TribulationRun = _view.get_run()
	assert_eq(run.cracks, 0)
	assert_false(run.is_holding())
	assert_eq(_view.get_mode(), Mode.RUNNING)

#-----------------------------------------------------------------------------
# THE END
#-----------------------------------------------------------------------------

func test_fail_applies_the_penalty_at_once() -> void:
	watch_signals(_view)
	_view.begin()
	_at(_beat(3) + 0.15)
	assert_eq(_view.get_mode(), Mode.RESULT, "the fourth crack ends the trial")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "five levels are gone before Continue")
	assert_true((_node("ResultPanel") as Control).visible)
	assert_eq(_text_of("ResultText"), "Core Density falls from 100 to 95.")
	assert_eq(_text_of("GradeLabel"), "Failed")
	assert_eq(_text_of("StatsLabel"), "0 perfect · 0 good · 4 missed")
	assert_eq(_core_frame().y, 4, "the spent core")
	for pip: LacquerStripRect in _pips().slice(0, 4):
		assert_eq(pip.get_frame(), Vector2i(1, 0), "every pip is lit")
	assert_signal_not_emitted(_view, "finished")

## Ruling F: a long frame that runs past the end, across a last beat nobody pressed,
## judges that beat before it asks whether the run is over.
func test_a_long_frame_judges_the_last_beat_before_the_end() -> void:
	_view.begin()
	_hit_beats(0, 23)
	_at_the_end()
	assert_eq(_view.get_mode(), Mode.RESULT)
	assert_eq(_view.get_run().cracks, 1, "the last beat was missed")
	assert_eq(_text_of("GradeLabel"), "Clean", "so the run is not flawless")

## A press after a stall can find the run failed by the beats it left behind: their
## misses show, and the run ends on them.
func test_a_press_after_a_stall_fails_on_the_beats_it_left_behind() -> void:
	_view.begin()
	_clock_to(_beat(3) + 0.15)
	_view.handle_press_event(_press())
	assert_eq(_view.get_mode(), Mode.RESULT, "four beats were missed")
	assert_eq(CultivationManager.get_core_density_level(), 95.0)
	assert_eq(_view.get_run().perfect_count + _view.get_run().good_count, 0, "the press scored nothing")
	assert_not_null(_shown_floater("Too late"), "the misses show, among %s" % [_shown_texts()])
	for pip: LacquerStripRect in _pips().slice(0, 4):
		assert_eq(pip.get_frame(), Vector2i(1, 0), "every pip is lit")

func test_pass_breaks_through() -> void:
	_play_clean_run()
	assert_eq(_view.get_mode(), Mode.RESULT)
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER)
	assert_eq(CultivationManager.get_core_density_level(), 0.0)
	assert_eq(_text_of("GradeLabel"), "Flawless")
	assert_eq(_text_of("StatsLabel"), "25 perfect · 0 good · 0 missed")
	assert_eq(_core_frame(), Vector2i(3, 5), "the biggest core, in brass")
	assert_eq((_node("ProgressRod") as LacquerRod).get_step(), 138, "the rod is full")

## A listener of the manager's signals can stop the action while the result is applied
## (Copper's systems will hook advancement_stage_changed), and the stop closes the board and
## drops the run. The end reads what the panel shows from the run before it calls the
## manager, so a pass still finishes: the stage moves on and the panel is filled in. One crack
## keeps the grade and the counts apart from the scene's own placeholder texts.
func test_a_listener_that_closes_the_board_does_not_cut_a_pass_short() -> void:
	var close_board := func(_new_stage: Stage) -> void: _view.close()
	CultivationManager.advancement_stage_changed.connect(close_board, CONNECT_ONE_SHOT)
	_view.begin()
	_hit_beats(1, _last_beat())
	_at(_beat(_last_beat()) + _view.get_run().get_hold_seconds() + PAST)
	_view.handle_press_event(_press(false))
	_at_the_end()
	if CultivationManager.advancement_stage_changed.is_connected(close_board):
		CultivationManager.advancement_stage_changed.disconnect(close_board)
	assert_eq(_view.get_mode(), Mode.CLOSED, "precondition: the listener closed the board as the stage changed")
	assert_null(_view.get_run(), "and dropped the run")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER, "the breakthrough was applied")
	assert_eq(_text_of("GradeLabel"), "Clean", "the grade came from the run, not from nothing")
	assert_eq(_text_of("StatsLabel"), "24 perfect · 0 good · 1 missed")
	assert_eq(_core_frame(), Vector2i(3, 5), "the core turned brass")
	# close() queued the pellets in flight to be freed: let that happen before GUT counts orphans.
	await wait_process_frames(2)

## The same for a failure, stopped from the level update the penalty sends.
func test_a_listener_that_closes_the_board_does_not_cut_a_fail_short() -> void:
	var close_board := func(_xp: float, _level: float) -> void: _view.close()
	CultivationManager.core_density_level_updated.connect(close_board, CONNECT_ONE_SHOT)
	_view.begin()
	_at(_beat(3) + 0.15)
	if CultivationManager.core_density_level_updated.is_connected(close_board):
		CultivationManager.core_density_level_updated.disconnect(close_board)
	assert_eq(_view.get_mode(), Mode.CLOSED, "precondition: the listener closed the board as the levels fell")
	assert_null(_view.get_run(), "and dropped the run")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the penalty was applied")
	assert_eq(_text_of("ResultText"), "Core Density falls from 100 to 95.")
	assert_eq(_text_of("GradeLabel"), "Failed", "the grade came from the run")
	assert_eq(_text_of("StatsLabel"), "0 perfect · 0 good · 4 missed")
	assert_eq(_core_frame(), Vector2i(0, 4), "the spent core")

func test_continue_finishes_with_the_result() -> void:
	watch_signals(_view)
	_view.begin()
	_at(_beat(3) + 0.15)
	(_node("ContinueButton") as TextureButton).pressed.emit()
	assert_signal_emitted_with_parameters(_view, "finished", [false])
	_use_full_core_save()
	_view.setup(_data, ZONE_NAME)
	_play_clean_run()
	(_node("ContinueButton") as TextureButton).pressed.emit()
	assert_signal_emit_count(_view, "finished", 2)
	assert_signal_emitted_with_parameters(_view, "finished", [true])

## Review Focus 4: mashing Space through the end keeps the result up.
func test_presses_on_the_result_panel_do_nothing() -> void:
	_view.begin()
	_at(_beat(3) + 0.15)
	var run: TribulationRun = _view.get_run()
	watch_signals(_view)
	assert_true(_view.handle_press_event(_press()), "the board takes the press")
	_view.handle_press_event(_press(false))
	_view._gui_input(_mouse(true))
	_view._gui_input(_mouse(false))
	_view.begin()
	_at(_beat(3) + 1.0)
	assert_eq(_view.get_mode(), Mode.RESULT, "the result stays up")
	assert_same(_view.get_run(), run, "and no new run begins")
	assert_signal_not_emitted(_view, "finished")
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the penalty is taken once")

func test_close_mid_run_applies_nothing() -> void:
	_view.begin()
	_at(3.0)
	_view.close()
	assert_false(_view.visible, "the board hides")
	assert_eq(_view.get_mode(), Mode.CLOSED)
	assert_null(_view.get_run(), "the run is dropped")
	assert_eq(CultivationManager.get_core_density_level(), 100.0)
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION)

## A stop plays the board shrinking away, so the board must stay drawn while nothing of the
## run is applied. The clock is stepped past the run's end: a run still going would have
## failed on the beats nobody pressed, and cost five levels.
func test_halt_mid_run_applies_nothing_and_keeps_the_board_up() -> void:
	_view.begin()
	_at(3.0)
	var duration: float = _view.get_run().get_duration()
	_view.halt()
	_at(duration + PAST)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "no level is lost")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and no breakthrough")
	assert_eq(_view.get_mode(), Mode.CLOSED)
	assert_null(_view.get_run(), "the run is dropped")
	assert_true(_view.visible, "the board is still showing")

#-----------------------------------------------------------------------------
# DRAWING AND LAYOUT
#-----------------------------------------------------------------------------

## Ruling A: the stage's draw handlers run only in the deferred draw phase, so the
## board must draw frames for them to run. GUT fails the test on an engine error. The
## board's first draw is done before the count starts, so what is counted are the
## redraws the run's frames ask for.
func test_the_stage_draws_without_errors() -> void:
	_view.begin()
	_hit_beats(0, 24)
	await wait_process_frames(2)
	var drawn: Dictionary[String, int] = {"SphereLayer": 0, "ArcLayer": 0}
	for layer_name: String in drawn:
		(_node(layer_name) as Control).draw.connect(func() -> void: drawn[layer_name] += 1)
	var t: float = _beat(24) + 0.5
	_at(t)
	var run: TribulationRun = _view.get_run()
	assert_gt(run.spheres_at(t).size(), 0, "precondition: a sphere breathes")
	assert_gt(run.hold_progress(t), 0.0, "precondition: the arc shows")
	await wait_process_frames(2)
	assert_gt(drawn["SphereLayer"], 0, "the spheres were drawn")
	assert_gt(drawn["ArcLayer"], 0, "the arc was drawn")

## A transition scales the view out of the cultivator into the board, so it asks the view
## where the board stands. The transition reads the rect as the board opens, before a frame has run with the view
## shown, and a board that has not laid out yet measures 2318 px tall, so the camera aimed
## below the screen and the board grew out of its bottom edge. The rect it reports then is
## the one the board settles to.
func test_board_rect_before_the_first_frame_is_the_settled_board() -> void:
	var first: Rect2 = _view.get_board_rect()
	await wait_process_frames(3)
	assert_eq(first, (_node("Board") as Control).get_global_rect(), "the same rect as once the board has laid out")

## Text is never cut off: a name too long for its line wraps, and the board grows
## by the lines it adds.
func test_a_long_name_wraps_and_the_board_grows() -> void:
	await wait_process_frames(2)
	var board := _node("Board") as Control
	var height: float = board.size.y
	_view.setup(_data, LONG_ZONE_NAME)
	await wait_process_frames(2)
	var label := _node("ActionLabel") as Label
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the name wraps by word")
	var added: int = label.get_line_count() - 1
	assert_gt(added, 0, "the name needs more than one line")
	assert_eq(board.size.y, height + DETAIL_LINE * added, "the board grows by the lines")
