extends GutTest

## Unit tests for DrillRun, the contract every drill's input plays through: the
## input it reads (the drill_press action, Space or the left mouse button), the run
## each input kind gets, the first press as every drill's first input, Auto's pace
## (a rep each rep_seconds), and the share that turns how far off a rep was into
## #97's tiers.

const InputKind = DrillData.InputKind

## One second on the set's clock.
const S: int = 1_000_000
## A point far from anything on any stage.
const FAR: Vector2 = Vector2(-1000, -1000)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of `kind`, 10 reps of `rep_seconds`.
func _drill(kind: InputKind = InputKind.HOLD_RELEASE, rep_seconds: float = 4.0) -> DrillData:
	var drill := DrillData.new()
	drill.id = "test_drill"
	drill.strength_xp_per_rep = 6.0
	drill.health_per_rep = 4.0
	drill.input_kind = kind
	drill.rep_seconds = rep_seconds
	drill.reps_per_set = 10
	return drill

#-----------------------------------------------------------------------------
# THE INPUT
#-----------------------------------------------------------------------------

## The drill's press is its own action, beside the Tribulation's, on the same two
## inputs: Space by its physical key and the left mouse button. Every drill plays
## on it.
func test_drill_press_is_space_and_the_left_button() -> void:
	assert_true(InputMap.has_action(&"drill_press"), "project.godot defines drill_press")
	if not InputMap.has_action(&"drill_press"):
		return
	var keys: Array[int] = []
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"drill_press"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
		elif event is InputEventMouseButton:
			buttons.append((event as InputEventMouseButton).button_index)
	assert_eq(keys, [KEY_SPACE] as Array[int], "Space, by its physical key")
	assert_eq(buttons, [MOUSE_BUTTON_LEFT] as Array[int], "and the left mouse button")

#-----------------------------------------------------------------------------
# THE RUNS
#-----------------------------------------------------------------------------

## Each input kind is played and judged by its own run.
func test_each_input_gets_its_run() -> void:
	var cases: Array[Dictionary] = [
		{"kind": InputKind.HOLD_RELEASE, "run": "StoneLiftingRun"},
		{"kind": InputKind.HOLD_STEADY, "run": "HorseStanceRun"},
		{"kind": InputKind.CATCH, "run": "FallingLeafRun"},
		{"kind": InputKind.BEAT, "run": "WaterfallRun"},
	]
	for case: Dictionary in cases:
		var run: DrillRun = DrillRun.for_drill(_drill(case["kind"]))
		assert_not_null(run, "%s gets a run" % InputKind.keys()[case["kind"]])
		if run != null:
			assert_eq(run.get_script().get_global_name(), StringName(case["run"]), "%s's run" % InputKind.keys()[case["kind"]])

## A press can carry the point it was aimed at (DrillPlay always sends one); the
## drills that aim at nothing take it as a plain press.
func test_a_press_at_a_point_is_a_press_for_the_runs_with_no_aim() -> void:
	var run := StoneLiftingRun.new(_drill())
	assert_eq(run.press_at(0, Vector2(9, 9)).size(), 0, "a press judges nothing yet")
	assert_true(run.is_lifting(), "and lifts the stone")

## The press that starts a set is its first rep's input on every drill: it lifts
## the stone (#143: every rep starts on the player's press).
func test_the_first_press_is_every_drill_s_first_input() -> void:
	var stone := DrillRun.for_drill(_drill(InputKind.HOLD_RELEASE)) as StoneLiftingRun
	stone.press_at(0, FAR)
	assert_true(stone.is_lifting(), "Stone Lifting: the stone rises")

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Auto plays every drill's input as a good player would (#110): played on frames
## of uneven length, every rep of the set is judged Perfect, on its own clock, and
## the set ends. The seed varies Horse Stance's arc and Falling Leaf's leaves.
func test_auto_plays_every_rep_of_each_input_perfect() -> void:
	var cases: Array[Dictionary] = [
		{"kind": InputKind.HOLD_RELEASE, "rep": 4.0},
		{"kind": InputKind.HOLD_STEADY, "rep": 4.0},
		{"kind": InputKind.CATCH, "rep": 2.0},
		{"kind": InputKind.BEAT, "rep": 3.0},
	]
	for case: Dictionary in cases:
		for rng_seed: int in [1, 7, 42]:
			var what: String = "%s, seed %d" % [InputKind.keys()[case["kind"]], rng_seed]
			var run: DrillRun = DrillRun.for_drill(_drill(case["kind"], case["rep"]), rng_seed)
			var judged: Array[DrillRun.Judgement] = []
			var t: int = 0
			var frame: int = 0
			while run.get_end_usec() < 0 and t < 60 * S:
				frame += 1
				t += [16_000, 17_000, 33_000][frame % 3]
				judged.append_array(run.play_auto(t))
			assert_eq(judged.size(), 10, "%s: ten reps judged" % what)
			var tiers: Array = judged.map(func(judgement: DrillRun.Judgement) -> DrillRules.Tier: return judgement.tier)
			assert_eq(tiers.count(DrillRules.Tier.PERFECT), 10, "%s: each Perfect (%s)" % [what, str(tiers)])
			assert_gte(run.get_end_usec(), 0, "%s: the set ends" % what)

## Auto's play doesn't hang on the frames: one call far into the set judges every
## rep up to it, as many short calls would.
func test_auto_catches_up_in_one_call() -> void:
	var run: DrillRun = DrillRun.for_drill(_drill(InputKind.BEAT, 3.0))
	assert_eq(run.play_auto(10 * S).size(), 3, "three surges landed by 10 s")

## Auto plays a rep each rep_seconds, from the set's start (#110's pace, #143):
## rep k is judged after k rep lengths and before k + 1, and a set takes ten.
func test_auto_keeps_its_pace() -> void:
	var cases: Array[Dictionary] = [
		{"kind": InputKind.HOLD_RELEASE, "rep": 4.0},
	]
	for case: Dictionary in cases:
		var what: String = InputKind.keys()[case["kind"]]
		var pace: int = roundi(case["rep"] * S)
		var run: DrillRun = DrillRun.for_drill(_drill(case["kind"], case["rep"]), 7)
		assert_eq(run.get_auto_set_usec(), 10 * pace, "%s: a set of Auto takes ten reps' pace" % what)
		var judged: Array[DrillRun.Judgement] = run.play_auto(60 * S)
		assert_eq(judged.size(), 10, "%s: ten reps" % what)
		for judgement: DrillRun.Judgement in judged:
			assert_between(judgement.at_usec, judgement.rep * pace, (judgement.rep + 1) * pace - 1, "%s: rep %d in its pace" % [what, judgement.rep])

#-----------------------------------------------------------------------------
# THE SHARE
#-----------------------------------------------------------------------------

## However far off a rep was, the share falls in straight lines through #97's
## tier edges at the input's own windows, either side of the mark.
func test_the_share_falls_through_any_windows() -> void:
	var cases: Array[Dictionary] = [
		{"offset": 0, "share": 1.0},
		{"offset": 50, "share": 0.85},
		{"offset": -50, "share": 0.85},
		{"offset": 25, "share": 0.925},
		{"offset": 100, "share": 0.6},
		{"offset": -100, "share": 0.6},
		{"offset": 180, "share": 0.3},
		{"offset": -180, "share": 0.3},
		{"offset": 220, "share": 0.15},
		{"offset": 260, "share": 0.0},
		{"offset": -5000, "share": 0.0},
	]
	for case: Dictionary in cases:
		assert_almost_eq(DrillRun.share_through(case["offset"], 50, 100, 180, 260), case["share"], 0.000001, "%d off the mark" % case["offset"])
