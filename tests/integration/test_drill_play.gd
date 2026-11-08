extends GutTest

## Integration tests for DrillPlay, the drill played on the body refining board:
## each drill's input shows its own stage, the first press starts a set, every rep
## starts on the player's press and ends with its own motion (#143), judged at its
## exact time on an injected clock. Each judged rep restores its Health at once
## through BodyRefiningManager.pay_rep() and stores its XP for the set's end, its
## bead lights in its tier's colour, a brass ring marks the rep the player is on,
## its bead pops where its stage says (#149: no word, no reason, nothing unpaid),
## and a set played to its last rep pays its XP, flashes the beads' frame, and is
## counted and reported. The hold belongs to the kind of input that
## started it. Every test runs on a fresh save with the real Stone Lifting (10
## Strength XP and 4 Health a Perfect rep, a 4 s Auto pace, 10 to a set) unless it
## readies another drill, with the original save put back after it.

const PLAY_SCENE: PackedScene = preload("res://scenes/body_refining/drill/drill_play.tscn")
const STARTING_DRILL_ID: String = "stone_lifting"

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

## The clock when a set's first press lands: _at(seconds) sets it to this plus `seconds`.
const START_USEC: int = 1_000_000
## A release this long after a lift stops the stone at the band's centre.
const CENTRE: float = 1.37
## Falling Leaf's test leaves (_ready_leaves()): each hangs at LEAF_START, falls
## without sway, and is half way down, at LEAF_HALF, 1.8 s after it is shaken down.
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

## Lifts `rep` times 4 s into the set and lets go `held` seconds later.
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

## The bead the ring stands on, or -1 while it hides.
func _marked_bead() -> int:
	var mark: Control = _play.get_node("%BeadMark") as Control
	if not mark.visible:
		return -1
	var beads: Array[Node] = _play.get_node("%Beads").get_children()
	for index: int in beads.size():
		var bead: Control = beads[index] as Control
		if bead.get_global_rect().get_center().is_equal_approx(mark.get_global_rect().get_center()):
			return index
	return -2

## The floater a rep's bead pops on.
func _floater() -> LacquerFloater:
	return _play.get_node("%RepFloater") as LacquerFloater

## Asserts the floater shows the bead a rep of `tier` lights and nothing else, in
## `tint`.
func _assert_pops_bead(tier: Tier, tint: Color = Color.WHITE, context: String = "") -> void:
	var floater: LacquerFloater = _floater()
	assert_true(floater.visible, "%s: it pops" % context)
	assert_eq(floater.get_icons(), [DrillPlay.bead_icon(tier)] as Array[Texture2D], "%s: the bead it lit" % context)
	assert_eq(floater.get_text(), "", "%s: no word" % context)
	assert_eq(floater.get_color(), tint, "%s: its tint" % context)

## The run of the stone being lifted.
func _stone_run() -> StoneLiftingRun:
	return _play.get_run() as StoneLiftingRun

## Readies Horse Stance, every rep's arc held at `band_centre`.
func _ready_stance(band_centre: float) -> void:
	_play.run_for = func(drill: DrillData, _seed: int) -> DrillRun:
		return HorseStanceRun.new(drill, [[PackedInt64Array([0]), PackedFloat64Array([band_centre])]])
	_play.setup(BodyRefiningManager.get_drill("horse_stance"))

## Readies Falling Leaf, its sets' leaves the test's: each hangs at LEAF_START.
func _ready_leaves() -> void:
	_play.run_for = func(drill: DrillData, _seed: int) -> DrillRun:
		var leaves: Array[FallingLeafRun.Leaf] = []
		for rep: int in drill.reps_per_set:
			leaves.append(FallingLeafRun.Leaf.new(LEAF_START.x, LEAF_START.y, 0.0, 1_600_000, 0.0))
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

## A sink into the arc at the top of the gauge, standing in it for the rest of the
## rep: Perfect, which restores Health at once and stores Strength and Body XP.
func test_a_horse_stance_rep_restores_health_and_stores_body() -> void:
	ResourceManager.set_health(50.0)
	_ready_stance(HorseStanceRun.BAND_START)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_clock_to(0.2)
	_play.handle_press_event(_press(false))
	_at(2.0)
	assert_eq(_bead_frames()[0], 1, "a Perfect rep after its 2 s in the arc")
	assert_eq(ResourceManager.get_health(), 54.0, "its Health at once")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.STRENGTH), 14.0, "Horse Stance's Strength XP, stored")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.BODY), 7.0, "and its Body XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "paid when the set ends")

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

## The incense counts the set, not seconds: it burns only while the needle is in
## the arc, a tenth of the stick a rep, and is whole again for the next set.
func test_the_incense_burns_only_in_the_arc() -> void:
	_ready_stance(0.88)
	var stick: Control = _play.get_stage().get_node("%IncenseStick") as Control
	var full: float = HorseStanceStage.STICK_FULL_PX
	assert_eq(stick.size.y, full, "whole before a set")
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(1.0)
	assert_eq(stick.size.y, full, "out of the arc until 1.52 s: nothing burns")
	_at(2.52)
	assert_eq(stick.size.y, snappedf(full * 0.95, 2.0), "a second in the arc: half a tenth")
	_at(3.52)
	assert_eq(stick.size.y, snappedf(full * 0.9, 2.0), "the rep landed: a tenth")
	_at(30.0)
	assert_eq(stick.size.y, snappedf(full * 0.9, 2.0), "and nothing burns while the drill waits")
	_play.stop_set()
	assert_eq(stick.size.y, full, "whole again once the set ends")

## No seconds count down on Horse Stance's stage.
func test_horse_stance_shows_no_seconds() -> void:
	_ready_stance(0.5)
	assert_null(_play.get_stage().get_node_or_null("%Seconds"), "the incense has no seconds under it")

#-----------------------------------------------------------------------------
# FALLING LEAF
#-----------------------------------------------------------------------------

## The leaf a shake would drop hangs golden under the branch: the first at the
## branch's middle before a set, then the next while fewer than two fall.
func test_the_next_leaf_hangs_until_shaken() -> void:
	_ready_leaves()
	var hanging_frame := func(index: int) -> int:
		return (_leaf_node(index).get_node("%Leaf") as LacquerStripRect).get_frame().x
	assert_true(_leaf_node(0).visible, "a leaf hangs before the set")
	assert_eq(hanging_frame.call(0), FallingLeaf.HANGING_FRAME, "golden")
	_clock_to(0.0)
	_play.handle_press_event(_click(true, LEAF_START + Vector2(0, -200)))
	_play.handle_press_event(_click(false, LEAF_START + Vector2(0, -200)))
	_at(0.5)
	assert_true(_leaf_node(1).visible, "the next leaf hangs while one falls")
	assert_eq(hanging_frame.call(1), FallingLeaf.HANGING_FRAME)
	_clock_to(0.5)
	_play.handle_press_event(_click(true, LEAF_START + Vector2(0, -200)))
	_play.handle_press_event(_click(false, LEAF_START + Vector2(0, -200)))
	_at(0.6)
	assert_false(_leaf_node(2).visible, "two in the air: no leaf hangs")


## The first click shakes down a leaf; a click on its middle half way down is
## Perfect, which restores Health and stores Agility beside Strength. The leaf turns
## into its pellets and the ring snaps where the click came.
func test_a_falling_leaf_catch_stores_agility() -> void:
	ResourceManager.set_health(50.0)
	_ready_leaves()
	_clock_to(0.0)
	_play.handle_press_event(_click(true, LEAF_START))
	_play.handle_press_event(_click(false, LEAF_START))
	_clock_to(1.8)
	_play.handle_press_event(_click(true, LEAF_HALF))
	_at(1.8)
	assert_eq(_bead_frames()[0], 1, "a Perfect catch")
	assert_eq(ResourceManager.get_health(), 52.0, "its Health at once")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.STRENGTH), 7.0, "Falling Leaf's Strength XP, stored")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.AGILITY), 4.0, "and its Agility XP")
	var ring: Control = _play.get_stage().get_node("%CatchRing") as Control
	assert_true(ring.visible, "the ring shows")
	assert_eq(ring.position + ring.size / 2.0, LEAF_HALF, "where the click came")
	assert_false(_leaf_node(0).visible, "the leaf is gone")
	_at(2.4)
	assert_false(ring.visible, "the ring goes")

## A leaf nobody catches is a Miss as it lands, and lies there while the set runs.
func test_a_landed_leaf_stays_on_the_ground() -> void:
	_ready_leaves()
	_clock_to(0.0)
	_play.handle_press_event(_click(true, LEAF_START))
	_at(3.6)
	assert_eq(_bead_frames()[0], 4, "a Miss")
	_assert_pops_bead(Tier.MISS, Color.WHITE, "a landed leaf")
	for seconds: float in [3.6, 10.0, 20.0]:
		_at(seconds)
		assert_true(_leaf_node(0).visible, "%.1f s: the leaf lies on the ground" % seconds)
	_play.stop_set()
	var frame: int = (_leaf_node(0).get_node("%Leaf") as LacquerStripRect).get_frame().x
	assert_eq(frame, FallingLeaf.HANGING_FRAME, "the ground is cleared once the set ends: the next set's first leaf hangs")
	assert_false(_leaf_node(1).visible)

#-----------------------------------------------------------------------------
# WATERFALL TEMPERING
#-----------------------------------------------------------------------------

## The first press sends the waiting surge; a press as it lands on the line is
## Perfect, which restores Health and stores Body beside Strength.
func test_a_waterfall_brace_stores_body() -> void:
	ResourceManager.set_health(50.0)
	_play.setup(BodyRefiningManager.get_drill("waterfall_tempering"))
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_clock_to(1.5)
	_play.handle_press_event(_press())
	assert_eq(_bead_frames()[0], 1, "a Perfect brace")
	assert_eq(ResourceManager.get_health(), 53.0, "its Health at once")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.STRENGTH), 10.0, "Waterfall Tempering's Strength XP, stored")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.BODY), 5.0, "and its Body XP")

## The next surge waits at the ledge until a press sends it; it rides down to the
## line exactly when a brace is Perfect; a braced surge is gone, one nobody braced
## against crashes through the line, and the next waits at the ledge again.
func test_the_surge_waits_at_the_ledge_until_sent() -> void:
	_play.setup(BodyRefiningManager.get_drill("waterfall_tempering"))
	var surge: Control = _play.get_stage().get_node("%Surge") as Control
	var waiting: Control = _play.get_stage().get_node("%WaitingSurge") as Control
	var middle := func() -> float: return surge.position.y + surge.size.y / 2.0
	assert_true(waiting.visible, "a surge waits at the ledge before the set")
	assert_eq(waiting.position.y + waiting.size.y / 2.0, WaterfallStage.LINE_Y - WaterfallStage.LEAD_PX, "at the top of the falls")
	assert_false(surge.visible)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_at(0.0)
	assert_false(waiting.visible, "sent")
	assert_eq(middle.call(), WaterfallStage.LINE_Y - WaterfallStage.LEAD_PX, "from the top")
	_at(0.75)
	assert_eq(middle.call(), WaterfallStage.LINE_Y - WaterfallStage.LEAD_PX / 2.0, "half way down half way through its ride")
	_at(1.5)
	assert_eq(middle.call(), WaterfallStage.LINE_Y, "on the line as it lands")
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_at(1.5)
	assert_false(surge.visible, "braced, it is gone")
	assert_true(waiting.visible, "and the next waits at the ledge")
	_at(30.0)
	assert_true(waiting.visible, "as long as the player likes")
	_clock_to(30.0)
	_play.handle_press_event(_press())
	_play.handle_press_event(_press(false))
	_at(31.6)
	assert_true(surge.visible, "unbraced")
	assert_gt(middle.call(), WaterfallStage.LINE_Y, "it crashes through the line")

## Review Focus 5: the press that starts a set is its first rep's input on every
## drill: on Falling Leaf it shakes down the first leaf, even aimed where the leaf
## hangs, and on Waterfall Tempering it sends the first surge. It judges no rep;
## the press after it is judged.
func test_the_first_press_drops_a_leaf_and_sends_a_surge() -> void:
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

## Each rep restores its Health at once; the set's XP lands when its tenth rep
## does, and the set is counted and reported once.
func test_reps_pay_health_and_the_set_s_end_pays_xp() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(_play)
	for rep: int in 9:
		_lift(rep, CENTRE)
	assert_eq(ResourceManager.get_health(), 86.0, "nine reps of Health, at once")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "no Strength XP before the set ends")
	_lift(9, CENTRE)
	_at(40.0)
	assert_signal_emit_count(_play, "rep_judged", 10, "ten reps judged")
	# Ten Perfect reps pay 100 Strength XP, all of Lv 2's cost, so paid they read as the level.
	assert_eq(CharacterManager.get_stat_level(AttributeType.STRENGTH), 2, "ten Perfect reps' 100 Strength XP buy Lv 2 at the set's end")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "to the last point")
	assert_eq(ResourceManager.get_health(), 90.0)
	assert_eq(_bead_frames(), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] as Array[int], "every bead lit brass")
	assert_signal_emit_count(_play, "set_completed", 1, "the set is reported once")
	var completed: Array = get_signal_parameters(_play, "set_completed")
	if not completed.is_empty():
		assert_true((completed[0] as DrillSetResult).is_perfect(), "a perfect set")
		assert_eq((completed[0] as DrillSetResult).get_stat_xp(AttributeType.STRENGTH), 100.0, "holding what Strength took")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "and counted")
	assert_false(_play.is_set_running())
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")

func test_rep_judged_reports_what_was_stored() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(_play)
	_lift(0, CENTRE)
	var params: Array = get_signal_parameters(_play, "rep_judged")
	assert_eq(params.size(), 3, "the judgement, the Health and the stat XP")
	if params.size() != 3:
		return
	assert_eq((params[0] as DrillRun.Judgement).tier, Tier.PERFECT)
	assert_eq(params[1], 4.0, "the Health restored")
	assert_eq(params[2], {AttributeType.STRENGTH: 10.0}, "the XP each stat stored")

## Review Focus 2: no clock. Two reps, then a minute's wait judges nothing, and the
## next press plays the third rep.
func test_a_pause_judges_nothing_and_the_next_press_plays_on() -> void:
	watch_signals(_play)
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	_at(64.0)
	assert_signal_emit_count(_play, "rep_judged", 2, "nothing judged while the player waits")
	assert_eq(_bead_frames(), [1, 1, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int])
	assert_true(_play.is_set_running(), "the set waits")
	_lift(16, CENTRE)
	assert_eq(_bead_frames()[2], 1, "the next press plays rep 3, Perfect")

## The Now strip's snapshot: the rep the player is on (the reps landed, plus one),
## and the rep in play's own motion, 0 while the drill waits.
func test_the_session_counts_landed_reps() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(1.0)
	assert_eq(BodyRefiningManager.get_set_rep(), 1, "the first rep")
	assert_almost_eq(BodyRefiningManager.get_rep_progress(), 0.5, 0.0001, "the stone half way up")
	_clock_to(CENTRE)
	_play.handle_press_event(_press(false))
	_at(5.0)
	assert_eq(BodyRefiningManager.get_set_rep(), 2, "on the second rep once the first landed")
	assert_eq(BodyRefiningManager.get_rep_progress(), 0.0, "waiting for the press")
	assert_almost_eq(BodyRefiningManager.get_set_progress(), 0.1, 0.0001, "a tenth of the set")

func test_a_new_set_starts_on_the_next_press() -> void:
	watch_signals(_play)
	for rep: int in 10:
		_lift(rep, CENTRE)
	_at(40.0)
	_clock_to(41.0)
	_play.handle_press_event(_press())
	assert_signal_emit_count(_play, "set_started", 2, "a second set")
	assert_eq(_bead_frames(), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int], "its beads start empty")

## A set stopped short pays the XP its reps stored, and is neither counted nor
## reported.
func test_stopping_mid_set_pays_the_stored_xp_and_counts_nothing() -> void:
	watch_signals(_play)
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "precondition: the XP is stored")
	_play.stop_set()
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 20.0, "the two reps' XP is paid")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "a stopped set is not counted")
	assert_signal_emit_count(_play, "set_completed", 0, "nor reported")
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")
	assert_false(_play.is_set_running())

## A set ends once its tenth rep's piece is back at rest. Stopped in that moment,
## after the tenth rep landed, it is finished, not dropped: counted, reported and
## paid, so a perfect set stopped there still unlocks Auto.
func test_stopping_after_the_tenth_rep_finishes_the_set() -> void:
	watch_signals(_play)
	for rep: int in 10:
		_lift(rep, CENTRE)
	_at(36.0 + CENTRE + 0.1)
	assert_true(_play.is_set_running(), "precondition: the tenth stone is still setting down")
	_play.stop_set()
	assert_signal_emit_count(_play, "set_completed", 1, "the set is reported")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "and counted")
	assert_eq(CharacterManager.get_stat_level(AttributeType.STRENGTH), 2, "its 100 XP paid: all of Lv 2's cost")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "to the last point")
	assert_false(_play.is_set_running())
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")

## Review Focus 3: the save on quit comes before the play hears of it, so closing
## the window mid-set pays the set's stored XP (and saves again).
func test_closing_the_window_mid_set_pays_the_stored_xp() -> void:
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	_play._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 20.0, "the two reps' XP is paid")
	assert_eq(_play.get_result().get_stored_stat_xp(AttributeType.STRENGTH), 0.0, "and none is left to pay twice")

#-----------------------------------------------------------------------------
# THE SET ON THE BOARD
#-----------------------------------------------------------------------------

## A brass ring marks the rep the player is on: the first bead not lit, while a
## set runs.
func test_the_ring_marks_the_rep_you_are_on() -> void:
	await wait_process_frames(1)
	assert_eq(_marked_bead(), -1, "no ring before a set")
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(0.5)
	assert_eq(_marked_bead(), 0, "the first rep in play")
	_clock_to(CENTRE)
	_play.handle_press_event(_press(false))
	_at(2.0)
	assert_eq(_marked_bead(), 1, "then the second, waiting for the press")
	for rep: int in range(1, 10):
		_lift(rep, CENTRE)
	_at(40.0)
	assert_eq(_marked_bead(), -1, "no ring once the set ends")

## Review Focus 4: leaves caught out of turn light their own beads; the ring stays
## on the first bead not lit.
func test_the_ring_stays_on_the_first_bead_not_lit() -> void:
	_ready_leaves()
	await wait_process_frames(1)
	var away: Vector2 = LEAF_START + Vector2(0, -200)
	_clock_to(0.0)
	_play.handle_press_event(_click(true, away))
	_play.handle_press_event(_click(false, away))
	_clock_to(0.5)
	_play.handle_press_event(_click(true, away))
	_play.handle_press_event(_click(false, away))
	var run := _play.get_run() as FallingLeafRun
	_clock_to(1.5)
	_play.handle_press_event(_click(true, run.leaf_position(1, roundi(1.5e6))))
	_at(1.5)
	assert_eq(_bead_frames()[1], 1, "the second leaf, caught first")
	assert_eq(_marked_bead(), 0, "the ring stays on the first")
	assert_eq(BodyRefiningManager.get_set_rep(), 2, "one rep landed")

## The tenth rep's landing ends the set with a flash of the beads' brass frame.
func test_the_tenth_rep_flashes_the_set_frame() -> void:
	var frame: LacquerFrameOverlay = _play.get_node("%SetFrame") as LacquerFrameOverlay
	assert_false(frame.visible, "hidden before")
	for rep: int in 10:
		_lift(rep, CENTRE)
		if rep < 9:
			_at(rep * 4.0 + 3.0)
			assert_false(frame.is_flashing(), "rep %d: no flash mid-set" % rep)
	_at(40.0)
	assert_true(frame.is_flashing(), "the set's end flashes it")

#-----------------------------------------------------------------------------
# WHAT A REP SHOWS
#-----------------------------------------------------------------------------

## Each tier pops the bead it lights, a Miss its crossed bead alone: the stone's
## red stop line shows why.
func test_each_tier_pops_its_bead() -> void:
	var cases: Array[Dictionary] = [
		{"held": CENTRE, "tier": Tier.PERFECT},
		{"held": 1.2, "tier": Tier.GOOD},
		{"held": 0.9, "tier": Tier.OK},
		{"held": 0.6, "tier": Tier.MISS},
	]
	for rep: int in cases.size():
		var case: Dictionary = cases[rep]
		_lift(rep, case["held"])
		assert_eq(_bead_frames()[rep], DrillPlay.BEAD_FRAMES[case["tier"]], "held %.2f s: the bead lit" % case["held"])
		_assert_pops_bead(case["tier"], Color.WHITE, "held %.2f s" % case["held"])

## A rep that could not pay everything pops its bead alone, as any other: the pay
## line and the Last set card say what went unpaid.
func test_a_rep_at_the_cap_or_at_full_health_pops_its_bead_alone() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(ResourceManager.get_max_health())
	_lift(0, CENTRE)
	_assert_pops_bead(Tier.PERFECT, Color.WHITE, "capped and full")

## A drill's other stat at the cap takes no XP at the set's end, and the rep still
## restores Health.
func test_a_capped_minor_stat_takes_no_xp() -> void:
	CharacterManager.set_stat_level(AttributeType.BODY, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(50.0)
	var body_xp: float = CharacterManager.get_stat_xp(AttributeType.BODY)
	_ready_stance(HorseStanceRun.BAND_START)
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_clock_to(0.2)
	_play.handle_press_event(_press(false))
	_at(2.0)
	_assert_pops_bead(Tier.PERFECT, Color.WHITE, "Body capped")
	assert_eq(ResourceManager.get_health(), 54.0, "Health still refills")
	_play.stop_set()
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), body_xp, "Body takes no XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 14.0, "Strength still does")

## The result notes the bead each rep lit, for the Last set card.
func test_the_result_reads_the_reps_in_bead_order() -> void:
	_lift(0, CENTRE)
	_lift(1, 0.6)
	assert_eq(_play.get_result().get_bead_tiers(), [Tier.PERFECT, Tier.MISS] as Array[Tier])

func test_the_stone_stands_on_the_jade() -> void:
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(1.0)
	var stone: TextureRect = _play.get_stage().get_node("%Stone") as TextureRect
	var fill: Control = _play.get_stage().get_node("%Fill") as Control
	assert_eq(stone.position.y + stone.size.y, StoneLiftingStage.REST_BASE_Y - 200.0, "a second of lifting: the stone's base 200 px up")
	assert_eq(fill.position.y, StoneLiftingStage.REST_BASE_Y - 200.0, "the jade reaches the stone's base")
	assert_eq(fill.size.y, 200.0)

## The band across the track lights exactly while a release would score Perfect.
func test_the_band_lights_while_the_base_is_in_the_brass() -> void:
	var band: LacquerStripRect = _play.get_stage().get_node("%Band") as LacquerStripRect
	assert_eq(band.get_frame().x, StoneLiftingStage.BAND_DIM, "dim before a set")
	_clock_to(0.0)
	_play.handle_press_event(_press())
	var cases: Array[Dictionary] = [
		{"at": 1.0, "lit": false},
		{"at": CENTRE - 0.07, "lit": true},
		{"at": CENTRE + 0.07, "lit": true},
		{"at": CENTRE + 0.08, "lit": false},
	]
	for case: Dictionary in cases:
		_at(case["at"])
		var frame: int = StoneLiftingStage.BAND_LIT if case["lit"] else StoneLiftingStage.BAND_DIM
		assert_eq(band.get_frame().x, frame, "%.2f s into the lift" % case["at"])

## A judged rep leaves a line in its tier's colour where the stone's base stopped,
## and the next lift clears it.
func test_a_rep_leaves_a_mark_where_the_base_stopped() -> void:
	var mark: LacquerStripRect = _play.get_stage().get_node("%StopMark") as LacquerStripRect
	assert_false(mark.visible, "no mark before a set")
	var cases: Array[Dictionary] = [
		{"held": 1.2, "tier": Tier.GOOD},
		{"held": CENTRE, "tier": Tier.PERFECT},
		{"held": 0.9, "tier": Tier.OK},
		{"held": 0.6, "tier": Tier.MISS},
	]
	for rep: int in cases.size():
		var case: Dictionary = cases[rep]
		_lift(rep, case["held"])
		_at(rep * 4.0 + 3.0)
		assert_true(mark.visible, "held %.2f s: a mark, kept once the stone is down" % case["held"])
		assert_eq(mark.get_frame().x, StoneLiftingStage.STOP_MARK_FRAMES[case["tier"]], "held %.2f s: the tier's colour" % case["held"])
		var base: float = StoneLiftingStage.base_y(case["held"] / 2.0)
		assert_eq(mark.position.y, base - StoneLiftingStage.STOP_MARK_RISE, "held %.2f s: at the base" % case["held"])
	_clock_to(16.0)
	_play.handle_press_event(_press())
	_at(16.1)
	assert_false(mark.visible, "the next lift clears it")

## A stone that dropped from the top leaves no mark. With no slot to miss (#143),
## a rep's mark stays while the drill waits for the next lift.
func test_a_drop_leaves_no_mark_and_a_pause_keeps_the_last() -> void:
	var mark: LacquerStripRect = _play.get_stage().get_node("%StopMark") as LacquerStripRect
	_clock_to(0.0)
	_play.handle_press_event(_press())
	_at(2.5)
	assert_false(mark.visible, "dropped at the top")
	_play.handle_press_event(_press(false))
	_lift(1, 1.2)
	_at(8.5)
	assert_true(mark.visible, "precondition: a Good rep's mark")
	_at(60.0)
	assert_true(mark.visible, "a minute later it is still there")

## The stage shows at rest with nothing left of the last rep: once the set stops,
## and when another drill is picked and Stone Lifting again.
func test_the_stage_at_rest_has_no_mark() -> void:
	var mark: LacquerStripRect = _play.get_stage().get_node("%StopMark") as LacquerStripRect
	_lift(0, 1.2)
	_play.stop_set()
	assert_false(mark.visible, "the set stopped")
	_play.setup(BodyRefiningManager.get_drill(STARTING_DRILL_ID))
	_lift(0, 1.2)
	_play.setup(BodyRefiningManager.get_drill("horse_stance"))
	_play.setup(BodyRefiningManager.get_drill(STARTING_DRILL_ID))
	var band: LacquerStripRect = _play.get_stage().get_node("%Band") as LacquerStripRect
	assert_false(mark.visible, "Horse Stance, then Stone Lifting again")
	assert_eq(band.get_frame().x, StoneLiftingStage.BAND_DIM, "and the band dim")

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

## With Auto on and unlocked the play starts a set by itself and plays it: a rep
## each 4 s, each restoring 0.4 of a Perfect rep's Health and storing 0.4 of its
## Strength XP, paid when the set ends (#110, #143). Auto's next set waits for its
## pace: ten reps of 4 s from the last one's start.
func test_auto_plays_reps_at_the_auto_rate_and_pace() -> void:
	ResourceManager.set_health(20.0)
	watch_signals(_play)
	_auto_on()
	_frames_to(4.0)
	assert_true(_play.is_set_running(), "Auto started a set by itself")
	assert_true(_play.is_auto_set())
	assert_signal_emit_count(_play, "rep_judged", 1, "one rep in its first 4 s")
	var params: Array = get_signal_parameters(_play, "rep_judged")
	if params.size() == 3:
		assert_eq((params[0] as DrillRun.Judgement).tier, Tier.AUTO, "an Auto rep")
	assert_almost_eq(ResourceManager.get_health(), 21.6, 0.0001, "0.4 of 4 Health")
	assert_almost_eq(_play.get_result().get_stored_stat_xp(AttributeType.STRENGTH), 4.0, 0.0001, "0.4 of 10 Strength XP, stored")
	assert_eq(_bead_frames()[0], 1, "its bead lights Perfect's frame")
	assert_eq(_play._beads[0].self_modulate, DrillPlay.AUTO_BEAD_TINT, "dimmed")
	_frames_to(38.5)
	assert_signal_emit_count(_play, "rep_judged", 10, "ten reps a set, the last stone down by 38.5 s")
	assert_almost_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 40.0, 0.0001, "a set pays 40 Strength XP as it ends")
	assert_signal_emit_count(_play, "set_completed", 1, "the set is reported")
	var completed: Array = get_signal_parameters(_play, "set_completed")
	if not completed.is_empty():
		assert_true((completed[0] as DrillSetResult).is_auto(), "as an Auto set")
		assert_false((completed[0] as DrillSetResult).is_perfect(), "never perfect")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "and counted")
	_at(39.5)
	assert_false(_play.is_set_running(), "Review Focus 5: the next set waits for Auto's pace")
	_at(40.0)
	assert_true(_play.is_set_running(), "and starts 40 s after the last one did")

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

## Turning Auto off drops Auto's set: its reps' XP is paid, it is neither counted
## nor reported, and the next set waits for a press.
func test_turning_auto_off_drops_its_set() -> void:
	watch_signals(_play)
	_auto_on()
	_frames_to(9.0)
	_play.set_auto_play(false)
	assert_false(_play.is_set_running())
	assert_almost_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 8.0, 0.0001, "two reps' XP paid at the stop")
	assert_signal_emit_count(_play, "set_completed", 0, "the set is not reported")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "nor counted")
	_at(10.0)
	assert_false(_play.is_set_running(), "no set until a press")

## Review Focus 5: turning Auto back on starts its set at once, whatever its pace.
func test_turning_auto_on_starts_at_once() -> void:
	_auto_on()
	_frames_to(39.0)
	_play.set_auto_play(false)
	_play.set_auto_play(true)
	_at(39.5)
	assert_true(_play.is_auto_set(), "a new Auto set at once")
	assert_true(_play.is_set_running())

## An Auto rep never earns the drill's other stat, so rep_judged carries Strength
## alone; it pops Perfect's bead dimmed, as its bead lights.
func test_an_auto_rep_does_not_report_the_other_stat_unpaid() -> void:
	ResourceManager.set_health(20.0)
	_play.setup(BodyRefiningManager.get_drill("waterfall_tempering"))
	BodyRefiningManager.unlock_auto("waterfall_tempering")
	_play.set_auto_play(true)
	watch_signals(_play)
	_frames_to(2.0)
	assert_signal_emit_count(_play, "rep_judged", 1, "the first surge braced")
	var params: Array = get_signal_parameters(_play, "rep_judged")
	if params.size() == 3:
		assert_eq((params[2] as Dictionary).keys(), [AttributeType.STRENGTH], "the XP Strength stored, alone")
	_assert_pops_bead(Tier.AUTO, DrillPlay.AUTO_BEAD_TINT, "an Auto rep")
