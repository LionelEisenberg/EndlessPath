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
## Falling Leaf's test leaves (_ready_leaves()): each drops at its rep's start from
## LEAF_START, without sway, and is half way down, at LEAF_HALF, 1.8 s later.
const LEAF_START: Vector2 = Vector2(200, 64)
const LEAF_HALF: Vector2 = Vector2(200, 460)

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

## The left mouse button going down or up at `point`, in the stage's px.
func _click(down: bool, point: Vector2) -> InputEventMouseButton:
	var event := _mouse(down)
	event.global_position = _play.get_stage().get_global_transform() * point
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

## Readies Horse Stance, its sets' arc held at `band_centre` all set long.
func _ready_stance(band_centre: float) -> void:
	_play.run_for = func(drill: DrillData, _seed: int) -> DrillRun:
		return HorseStanceRun.new(drill, PackedInt64Array([0, 40_000_000]), PackedFloat64Array([band_centre, band_centre]))
	_play.setup(BodyRefiningManager.get_drill("horse_stance"))

## Readies Falling Leaf, its sets' leaves the test's: one a rep from LEAF_START.
func _ready_leaves() -> void:
	_play.run_for = func(drill: DrillData, _seed: int) -> DrillRun:
		var leaves: Array[FallingLeafRun.Leaf] = []
		for rep: int in drill.reps_per_set:
			leaves.append(FallingLeafRun.Leaf.new(rep * 2_000_000, LEAF_START.x, LEAF_START.y, 0.0, 1_600_000, 0.0))
		return FallingLeafRun.new(drill, leaves)
	_play.setup(BodyRefiningManager.get_drill("falling_leaf"))

## The stage's leaf `index`.
func _leaf_node(index: int) -> CanvasItem:
	return _play.get_stage().get_node("%Leaves").get_child(index) as CanvasItem

## The `progress` a stage's piece's shader shows.
func _progress(unique_name: String) -> float:
	return ((_play.get_stage().get_node("%" + unique_name) as CanvasItem).material as ShaderMaterial).get_shader_parameter(&"progress")

#-----------------------------------------------------------------------------
# THE STAGE
#-----------------------------------------------------------------------------

## Each drill plays on the scene of its input, and only that scene shows.
func test_each_drill_shows_its_own_stage() -> void:
	var cases: Array[Dictionary] = [
		{"drill": "stone_lifting", "stage": "StoneLiftingStage"},
		{"drill": "horse_stance", "stage": "HorseStanceStage"},
		{"drill": "falling_leaf", "stage": "FallingLeafStage"},
		{"drill": "waterfall_tempering", "stage": "WaterfallStage"},
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
# HORSE STANCE
#-----------------------------------------------------------------------------

## A sink into an arc at the top of the gauge, and a rise to stand in it for the
## rest of the rep: Perfect, which trains Body beside Strength.
func test_a_horse_stance_rep_pays_strength_body_and_health() -> void:
	ResourceManager.set_health(50.0)
	_ready_stance(0.1)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_clock_to(0.2)
	_play.handle_press_event(_press(false))
	_at(4.0)
	assert_eq(_bead_frames()[0], 1, "a Perfect rep")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 8.0, "Horse Stance's Strength XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 4.0, "and its Body XP")
	assert_eq(ResourceManager.get_health(), 54.0, "and its Health")

## The needle and the arc stand where the run has them, and the brass gauge shows
## exactly while the needle is in the arc.
func test_the_gauge_follows_the_run() -> void:
	_ready_stance(0.5)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	var gauge_lit: CanvasItem = _play.get_stage().get_node("%GaugeLit") as CanvasItem
	var gauge_dim: CanvasItem = _play.get_stage().get_node("%GaugeDim") as CanvasItem
	var cases: Array[Dictionary] = [
		{"at": 0.5, "depth": 0.25, "inside": false},
		{"at": 1.0, "depth": 0.5, "inside": true},
		{"at": 1.5, "depth": 0.75, "inside": false},
	]
	for case: Dictionary in cases:
		_at(case["at"])
		assert_almost_eq(_progress("Needle"), case["depth"], 0.0001, "%.1f s: the needle" % case["at"])
		assert_almost_eq(_progress("GaugeLit"), 0.5, 0.0001, "%.1f s: the arc" % case["at"])
		assert_eq(gauge_lit.visible, case["inside"], "%.1f s: the brass gauge" % case["at"])
		assert_eq(gauge_dim.visible, not case["inside"], "%.1f s: the tan gauge" % case["at"])

## The incense counts the set's seconds down, and is whole again for the next set.
func test_the_incense_burns_down_with_the_set() -> void:
	_ready_stance(0.5)
	var seconds: Label = _play.get_stage().get_node("%Seconds") as Label
	assert_eq(seconds.text, HorseStanceStage.SECONDS_FORMAT % 40, "a whole set before it starts")
	_clock_to(0.0)
	_play.handle_press_event(_press())
	for case: Array in [[0.0, 40], [10.0, 30], [39.5, 1]]:
		_at(case[0])
		assert_eq(seconds.text, HorseStanceStage.SECONDS_FORMAT % case[1], "%.1f s into the set" % case[0])
	_play.stop_set()
	assert_eq(seconds.text, HorseStanceStage.SECONDS_FORMAT % 40, "whole again once it stops")

#-----------------------------------------------------------------------------
# FALLING LEAF
#-----------------------------------------------------------------------------

## A click on a leaf's middle half way down: Perfect, which trains Agility beside
## Strength. The leaf turns into its pellets and the ring snaps where the click came.
func test_a_falling_leaf_catch_pays_agility() -> void:
	ResourceManager.set_health(50.0)
	_ready_leaves()
	_clock_to(0.0)
	_play.handle_press_event(_click(true, LEAF_START))
	_play.handle_press_event(_click(false, LEAF_START))
	_clock_to(1.8)
	_play.handle_press_event(_click(true, LEAF_HALF))
	_at(1.8)
	assert_eq(_bead_frames()[0], 1, "a Perfect catch")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 4.0, "Falling Leaf's Strength XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.AGILITY), 2.0, "and its Agility XP")
	assert_eq(ResourceManager.get_health(), 52.0, "and its Health")
	var ring: Control = _play.get_stage().get_node("%CatchRing") as Control
	assert_true(ring.visible, "the ring shows")
	assert_eq(ring.position + ring.size / 2.0, LEAF_HALF, "where the click came")
	assert_false(_leaf_node(0).visible, "the leaf is gone")
	_at(2.4)
	assert_false(ring.visible, "the ring goes")

## A leaf nobody catches is a Miss as it lands, and lies there until the set ends.
func test_a_landed_leaf_stays_on_the_ground() -> void:
	_ready_leaves()
	_clock_to(0.0)
	_play.handle_press_event(_click(true, LEAF_START))
	_at(3.6)
	assert_eq(_bead_frames()[0], 4, "a Miss")
	assert_eq(_floater("LineFloater").get_text(), DrillPlay.MISS_REASONS[DrillRun.Miss.LANDED])
	for seconds: float in [3.6, 10.0, 20.0]:
		_at(seconds)
		assert_true(_leaf_node(0).visible, "%.1f s: the leaf lies on the ground" % seconds)
	_at(21.6)
	assert_false(_play.is_set_running(), "precondition: the last leaf landed and the set ended")
	assert_false(_leaf_node(0).visible, "the ground is cleared for the next set")

## Review Focus 5: on Falling Leaf the press that starts a set shakes the branch
## and on Waterfall Tempering it opens the falls: it judges no rep, even aimed at
## the first leaf. The next press is judged.
func test_the_starting_press_starts_without_a_rep_on_the_press_drills() -> void:
	var cases: Array[Dictionary] = [
		{"drill": "falling_leaf", "start_aim": LEAF_START, "next_at": 1.8, "next_aim": LEAF_HALF},
		{"drill": "waterfall_tempering", "start_aim": Vector2.ZERO, "next_at": 1.5, "next_aim": Vector2.ZERO},
	]
	for case: Dictionary in cases:
		if case["drill"] == "falling_leaf":
			_ready_leaves()
		else:
			_play.run_for = DrillRun.for_drill
			_play.setup(BodyRefiningManager.get_drill(case["drill"]))
		var judged: Array[DrillRun.Judgement] = []
		var note := func(judgement: DrillRun.Judgement, _health: float, _stat_xp: Dictionary) -> void:
			judged.append(judgement)
		_play.rep_judged.connect(note)
		_clock_to(0.0)
		_play.handle_press_event(_click(true, case["start_aim"]))
		_play.handle_press_event(_click(false, case["start_aim"]))
		assert_true(_play.is_set_running(), "%s: the press starts a set" % case["drill"])
		assert_eq(judged.size(), 0, "%s: and judges no rep" % case["drill"])
		_clock_to(case["next_at"])
		_play.handle_press_event(_click(true, case["next_aim"]))
		assert_eq(judged.size(), 1, "%s: the next press is judged" % case["drill"])
		if judged.size() == 1:
			assert_eq(judged[0].tier, Tier.PERFECT, "%s: Perfect" % case["drill"])
		_play.rep_judged.disconnect(note)

#-----------------------------------------------------------------------------
# WATERFALL TEMPERING
#-----------------------------------------------------------------------------

## A press as the first surge lands on the line: Perfect, which trains Body beside
## Strength.
func test_a_waterfall_landing_pays_body() -> void:
	ResourceManager.set_health(50.0)
	_play.setup(BodyRefiningManager.get_drill("waterfall_tempering"))
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_clock_to(1.5)
	_play.handle_press_event(_press())
	assert_eq(_bead_frames()[0], 1, "a Perfect brace")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 6.0, "Waterfall Tempering's Strength XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 3.0, "and its Body XP")
	assert_eq(ResourceManager.get_health(), 53.0, "and its Health")

## Each surge rides down from the top of the falls as its rep starts and lands on
## the line exactly when a press is Perfect; a braced surge is gone, and one
## nobody braced against crashes through the line.
func test_the_surge_rides_down_to_the_line() -> void:
	_play.setup(BodyRefiningManager.get_drill("waterfall_tempering"))
	var surge: Control = _play.get_stage().get_node("%Surge") as Control
	var middle := func() -> float: return surge.position.y + surge.size.y / 2.0
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_at(0.0)
	assert_eq(middle.call(), WaterfallStage.LINE_Y - WaterfallStage.LEAD_PX, "at the top as the rep starts")
	_at(0.75)
	assert_eq(middle.call(), WaterfallStage.LINE_Y - WaterfallStage.LEAD_PX / 2.0, "half way down half way through its lead")
	_at(1.5)
	assert_eq(middle.call(), WaterfallStage.LINE_Y, "on the line as it lands")
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_at(1.5)
	assert_false(surge.visible, "braced, it is gone")
	_at(4.6)
	assert_true(surge.visible, "the next surge, unbraced")
	assert_gt(middle.call(), WaterfallStage.LINE_Y, "crashes through the line")

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

## A drill's other stat at the cap reads "capped" as Strength does, takes no XP,
## and the rep still restores Health.
func test_a_capped_minor_stat_pops_capped() -> void:
	CharacterManager.set_stat_level(AttributeType.BODY, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(50.0)
	var body_xp: float = CharacterManager.get_stat_xp(AttributeType.BODY)
	_ready_stance(0.1)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_clock_to(0.2)
	_play.handle_press_event(_press(false))
	_at(4.0)
	assert_eq(_floater("WordFloater").get_text(), "Perfect")
	assert_eq(_floater("LineFloater").get_icons(), [StatDisplay.mini_icon_of(AttributeType.BODY)] as Array[Texture2D], "Body's icon")
	assert_eq(_floater("LineFloater").get_text(), " capped")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), body_xp, "Body takes no XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 8.0, "Strength still does")
	assert_eq(ResourceManager.get_health(), 54.0, "and Health still refills")

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

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Turns Auto on for the drill on the play, unlocking its Auto first when `unlock`.
func _auto_on(unlock: bool = true) -> void:
	if unlock:
		BodyRefiningManager.unlock_auto(STARTING_DRILL_ID)
	_play.set_auto_play(true)

## Runs frames every half second from 0 to `seconds` after the set's start.
func _frames_to(seconds: float) -> void:
	var t: float = 0.0
	while t <= seconds:
		_at(t)
		t += 0.5

## With Auto on and unlocked the play starts a set by itself and plays it: each rep
## lands at the drill's pace and pays 0.4 of a Perfect rep's Strength XP and
## Health (#110).
func test_auto_plays_reps_at_the_auto_rate() -> void:
	ResourceManager.set_health(20.0)
	watch_signals(_play)
	_auto_on()
	_frames_to(4.0)
	assert_true(_play.is_set_running(), "Auto started a set by itself")
	assert_true(_play.is_auto_set())
	assert_signal_emit_count(_play, "rep_judged", 1, "one rep in its first 4 s slot")
	var params: Array = get_signal_parameters(_play, "rep_judged")
	if params.size() == 3:
		assert_eq((params[0] as DrillRun.Judgement).tier, Tier.AUTO, "an Auto rep")
	assert_almost_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 2.4, 0.0001, "0.4 of 6 Strength XP")
	assert_almost_eq(ResourceManager.get_health(), 21.6, 0.0001, "0.4 of 4 Health")
	assert_eq(_bead_frames()[0], 1, "its bead lights Perfect's frame")
	assert_eq(_play._beads[0].self_modulate, DrillPlay.AUTO_BEAD_TINT, "dimmed")
	_frames_to(38.5)
	assert_signal_emit_count(_play, "rep_judged", 10, "ten reps a set, the last stone down by 38.5 s")
	assert_almost_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 24.0, 0.0001, "a set pays 24 Strength XP")
	assert_signal_emit_count(_play, "set_completed", 1, "the set is reported")
	var completed: Array = get_signal_parameters(_play, "set_completed")
	if not completed.is_empty():
		assert_true((completed[0] as DrillSetResult).is_auto(), "as an Auto set")
		assert_false((completed[0] as DrillSetResult).is_perfect(), "never perfect")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "and counted")
	_at(39.0)
	assert_true(_play.is_set_running(), "the next set starts by itself on the next frame")

## Before the drill's Auto unlocks, Auto plays nothing, even switched on.
func test_locked_auto_plays_nothing() -> void:
	_auto_on(false)
	_frames_to(10.0)
	assert_false(_play.is_auto_running())
	assert_false(_play.is_set_running(), "no set starts")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "no rep lands")

## A press while Auto runs is taken and plays nothing.
func test_a_press_under_auto_plays_nothing() -> void:
	_auto_on()
	_clock_to(0.0)
	assert_true(_play.handle_press_event(_press()), "the press is taken")
	assert_false(_play.is_set_running(), "but starts no set")
	_at(0.0)
	assert_true(_play.is_auto_set(), "Auto's set starts on the next frame")

## Turning Auto off drops Auto's set: its reps stay paid, it is neither counted nor
## reported, and the next set waits for a press.
func test_turning_auto_off_drops_its_set() -> void:
	watch_signals(_play)
	_auto_on()
	_frames_to(9.0)
	_play.set_auto_play(false)
	assert_false(_play.is_set_running())
	assert_almost_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 4.8, 0.0001, "two reps stay paid")
	assert_signal_emit_count(_play, "set_completed", 0, "the set is not reported")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "nor counted")
	_at(10.0)
	assert_false(_play.is_set_running(), "no set until a press")
