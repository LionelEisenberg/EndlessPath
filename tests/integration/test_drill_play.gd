extends GutTest

## Integration tests for DrillPlay, the drill played on the body refining board:
## each drill's input shows its own stage, the first press starts a set, each rep
## is judged at its exact time on an injected clock and paid through
## BodyRefiningManager.pay_rep(), its bead lights in its tier's colour, its tier
## pops where its stage says (with what it could not pay under it, or a Miss's
## reason), and a set played to its last rep is counted and reported. The hold
## belongs to the kind of input that started it. Every test runs on a fresh save
## with the real Stone Lifting (6 Strength XP and 4 Health a Perfect rep, 4 s reps,
## 10 to a set) unless it readies another drill, with the original save put back
## after it.

const PLAY_SCENE: PackedScene = preload("res://scenes/body_refining/drill/drill_play.tscn")
const HEALTH_MINI: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const STARTING_DRILL_ID: String = "stone_lifting"

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

## The clock when a set's first press lands: _at(seconds) sets it to this plus `seconds`.
const START_USEC: int = 1_000_000
## A release this long after a lift stops the stone at the band's centre.
const CENTRE: float = 1.37

var _play: DrillPlay = null
var _now_usec: int = START_USEC
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_now_usec = START_USEC
	_play = PLAY_SCENE.instantiate() as DrillPlay
	add_child_autofree(_play)
	_play.clock_usec = func() -> int: return _now_usec
	_play.setup(BodyRefiningManager.get_drill(STARTING_DRILL_ID))

func after_each() -> void:
	BodyRefiningManager.end_set_session()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	_play = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Sets the clock to `seconds` after the set's first press and runs one frame.
func _at(seconds: float) -> void:
	_clock_to(seconds)
	_play._process(0.0)

## Sets the clock to `seconds` after the set's first press, without a frame.
func _clock_to(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)

## A press of the drill's action, or its release.
func _press(down: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"drill_press"
	event.pressed = down
	return event

## Space going down or up; `echo` for a key repeat.
func _key(down: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = down
	event.echo = echo
	return event

## The left mouse button going down or up.
func _mouse(down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	return event

## Lifts at the start of rep `rep`'s slot and lets go `held` seconds later.
func _lift(rep: int, held: float) -> void:
	_clock_to(rep * 4.0)
	_play.handle_press_event(_press())
	_clock_to(rep * 4.0 + held)
	_play.handle_press_event(_press(false))

func _bead_frames() -> Array[int]:
	var frames: Array[int] = []
	for bead: Node in _play.get_node("%Beads").get_children():
		frames.append((bead as LacquerStripRect).get_frame().x)
	return frames

func _floater(unique_name: String) -> LacquerFloater:
	return _play.get_node("%" + unique_name) as LacquerFloater

## The run of the stone being lifted.
func _stone_run() -> StoneLiftingRun:
	return _play.get_run() as StoneLiftingRun

#-----------------------------------------------------------------------------
# THE STAGE
#-----------------------------------------------------------------------------

## Each drill plays on the scene of its input, and only that scene shows.
func test_each_drill_shows_its_own_stage() -> void:
	var cases: Array[Dictionary] = [
		{"drill": "stone_lifting", "stage": "StoneLiftingStage"},
	]
	for case: Dictionary in cases:
		_play.setup(BodyRefiningManager.get_drill(case["drill"]))
		var stage: DrillStage = _play.get_stage()
		assert_not_null(stage, "%s has a stage" % case["drill"])
		if stage == null:
			continue
		assert_eq(stage.name, case["stage"], "%s's stage" % case["drill"])
		for other: Node in _play.get_node("%Stages").get_children():
			assert_eq((other as Control).visible, other == stage, "%s: %s shows only when it is the drill's" % [case["drill"], other.name])

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

func test_a_press_starts_a_set_and_lifts() -> void:
	watch_signals(_play)
	assert_false(_play.is_set_running(), "precondition: no set before the first press")
	_clock_to(0.0)
	_play.handle_press_event(_press())
	assert_signal_emit_count(_play, "set_started", 1)
	assert_true(_play.is_set_running())
	assert_true(_stone_run().is_lifting(), "the first press lifts the stone")
	assert_true(BodyRefiningManager.is_set_running(), "the set session runs")
	assert_eq(BodyRefiningManager.get_set_rep(), 1, "on its first rep")

func test_a_set_scores_and_pays_each_rep() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(_play)
	for rep: int in 10:
		_lift(rep, CENTRE)
	_at(40.0)
	assert_signal_emit_count(_play, "rep_judged", 10, "ten reps judged")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 60.0, "ten Perfect reps of Strength XP")
	assert_eq(ResourceManager.get_health(), 90.0, "and of Health")
	assert_eq(_bead_frames(), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] as Array[int], "every bead lit brass")
	assert_signal_emit_count(_play, "set_completed", 1, "the set is reported once")
	var completed: Array = get_signal_parameters(_play, "set_completed")
	if not completed.is_empty():
		assert_true((completed[0] as DrillSetResult).is_perfect(), "a perfect set")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "and counted")
	assert_false(_play.is_set_running())
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")

func test_rep_judged_reports_what_was_paid() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(_play)
	_lift(0, CENTRE)
	var params: Array = get_signal_parameters(_play, "rep_judged")
	assert_eq(params.size(), 3, "the judgement, the Health and the stat XP")
	if params.size() != 3:
		return
	assert_eq((params[0] as DrillRun.Judgement).tier, Tier.PERFECT)
	assert_eq(params[1], 4.0, "the Health restored")
	assert_eq(params[2], {AttributeType.STRENGTH: 6.0}, "the XP each stat took")

func test_the_set_session_follows_the_set() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(6.0)
	assert_eq(BodyRefiningManager.get_set_rep(), 2, "the second rep")
	assert_almost_eq(BodyRefiningManager.get_rep_progress(), 0.5, 0.0001, "half through it")

func test_a_new_set_starts_on_the_next_press() -> void:
	watch_signals(_play)
	for rep: int in 10:
		_lift(rep, CENTRE)
	_at(40.0)
	_clock_to(41.0)
	_play.handle_press_event(_press())
	assert_signal_emit_count(_play, "set_started", 2, "a second set")
	assert_eq(_bead_frames(), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int], "its beads start empty")

func test_stop_set_keeps_the_paid_reps_and_counts_nothing() -> void:
	watch_signals(_play)
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	_play.stop_set()
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 12.0, "the two reps' XP stays")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "a stopped set is not counted")
	assert_signal_emit_count(_play, "set_completed", 0, "nor reported")
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")
	assert_false(_play.is_set_running())

#-----------------------------------------------------------------------------
# WHAT A REP SHOWS
#-----------------------------------------------------------------------------

func test_a_miss_lights_its_bead_and_pops_its_reason() -> void:
	_lift(0, 0.6)
	assert_eq(_bead_frames()[0], 4, "the miss bead")
	assert_eq(_floater("WordFloater").get_text(), "Miss")
	assert_eq(_floater("WordFloater").get_color(), ThemeConstants.LACQUER_HEALTH, "a Miss in the warning colour")
	assert_eq(_floater("LineFloater").get_text(), "Too low")

func test_a_rep_at_full_health_pops_full() -> void:
	ResourceManager.set_health(ResourceManager.get_max_health())
	_lift(0, CENTRE)
	assert_eq(_floater("WordFloater").get_text(), "Perfect")
	assert_eq(_floater("WordFloater").get_color(), ThemeConstants.LACQUER_BRASS)
	assert_true(_floater("LineFloater").visible, "a line under the tier")
	assert_eq(_floater("LineFloater").get_icons(), [HEALTH_MINI] as Array[Texture2D], "the Health heart")
	assert_eq(_floater("LineFloater").get_text(), " full")

func test_a_capped_strength_pops_capped() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(50.0)
	_lift(0, CENTRE)
	assert_eq(_floater("LineFloater").get_icons(), [StatDisplay.mini_icon_of(AttributeType.STRENGTH)] as Array[Texture2D], "Strength's icon")
	assert_eq(_floater("LineFloater").get_text(), " capped")

func test_a_rep_that_pays_everything_shows_no_line() -> void:
	ResourceManager.set_health(50.0)
	_lift(0, 0.6)
	_lift(1, CENTRE)
	assert_eq(_floater("WordFloater").get_text(), "Perfect")
	assert_false(_floater("LineFloater").visible, "the miss's reason is gone and nothing replaces it")

func test_the_stone_stands_on_the_jade() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(1.0)
	var stone: TextureRect = _play.get_stage().get_node("%Stone") as TextureRect
	var fill: Control = _play.get_stage().get_node("%Fill") as Control
	assert_eq(stone.position.y + stone.size.y, StoneLiftingStage.REST_BASE_Y - 200.0, "a second of lifting: the stone's base 200 px up")
	assert_eq(fill.position.y, StoneLiftingStage.REST_BASE_Y - 200.0, "the jade reaches the stone's base")
	assert_eq(fill.size.y, 200.0)

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func test_only_the_drill_press_is_taken() -> void:
	var other := InputEventAction.new()
	other.action = &"ui_accept"
	other.pressed = true
	assert_false(_play.handle_press_event(other), "another action is left alone")
	assert_true(_play.handle_press_event(_press()), "the drill's press is taken")

func test_key_repeats_are_not_presses() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_key(true))
	_clock_to(CENTRE)
	_play.handle_press_event(_key(false))
	_clock_to(4.0)
	_play.handle_press_event(_key(true, true))
	_at(4.2)
	assert_false(_stone_run().is_lifting(), "a key repeat lifts nothing")

## Review Focus 1: a lift started by the key is let go only by the key.
func test_a_mouse_release_leaves_a_key_lift() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_key(true))
	_clock_to(1.0)
	_play.handle_press_event(_mouse(false))
	assert_true(_stone_run().is_lifting(), "the mouse coming up leaves the key's lift")
	_clock_to(CENTRE)
	_play.handle_press_event(_key(false))
	assert_eq(_bead_frames()[0], 1, "the key's release judges it Perfect")

## Review Focus 2: alt-tabbing away mid-lift lets the stone go there. A desktop
## build sends the application's focus loss and the window's; the Web build sends
## only the window's.
func test_focus_loss_lets_the_stone_go() -> void:
	for focus_loss: int in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_play.setup(BodyRefiningManager.get_drill(STARTING_DRILL_ID))
		_clock_to(0.0)
		_play.handle_press_event(_press())
		_clock_to(CENTRE)
		_play._notification(focus_loss)
		assert_false(_stone_run().is_lifting(), "notification %d: the lift is over" % focus_loss)
		assert_eq(_bead_frames()[0], 1, "notification %d: judged where it was let go" % focus_loss)
