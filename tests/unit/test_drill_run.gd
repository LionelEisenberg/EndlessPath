extends GutTest

## Unit tests for DrillRun, the contract every drill's input plays through: the
## input it reads (the drill_press action, Space or the left mouse button), the run
## each input kind gets, the reps' slots on the set's clock, and the share that
## turns how far off a rep was into #97's tiers.

const InputKind = DrillData.InputKind

## One second on the set's clock.
const S: int = 1_000_000

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
		{"kind": InputKind.HOLD_STEADY, "run": "StoneLiftingRun"},
		{"kind": InputKind.CATCH, "run": "StoneLiftingRun"},
		{"kind": InputKind.BEAT, "run": "StoneLiftingRun"},
	]
	for case: Dictionary in cases:
		var run: DrillRun = DrillRun.for_drill(_drill(case["kind"]))
		assert_not_null(run, "%s gets a run" % InputKind.keys()[case["kind"]])
		if run != null:
			assert_eq(run.get_script().get_global_name(), StringName(case["run"]), "%s's run" % InputKind.keys()[case["kind"]])

#-----------------------------------------------------------------------------
# THE SLOTS
#-----------------------------------------------------------------------------

## Rep k's slot runs from k rep lengths to k + 1 on the set's clock.
func test_rep_progress_follows_the_slot() -> void:
	var run: DrillRun = DrillRun.for_drill(_drill())
	assert_eq(run.rep_at(0), 0)
	assert_almost_eq(run.rep_progress_at(2 * S), 0.5, 0.000001)
	assert_eq(run.rep_at(4 * S), 1)
	assert_almost_eq(run.rep_progress_at(5 * S), 0.25, 0.000001)
	assert_eq(run.rep_at(50 * S), 9, "the last rep, past the set's end")
	assert_eq(run.rep_progress_at(50 * S), 1.0)

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
