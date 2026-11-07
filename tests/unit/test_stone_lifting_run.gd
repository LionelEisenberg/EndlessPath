extends GutTest

## Unit tests for StoneLiftingRun, the judge of one set of Stone Lifting: hold to
## lift the stone, let go with its base in the brass band. Every time is on the
## set's own clock in microseconds, from the first press, so each result is pinned
## at an exact time whatever the frames do.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
## How long a release at the band's centre has held the stone.
const CENTRE: int = 1_370_000

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of `reps` reps of 4 s, as Stone Lifting's.
func _drill(reps: int = 10) -> DrillData:
	var drill := DrillData.new()
	drill.id = "test_drill"
	drill.strength_xp_per_rep = 6.0
	drill.health_per_rep = 4.0
	drill.rep_seconds = 4.0
	drill.reps_per_set = reps
	return drill

## A run whose first press, at time 0, lifted the stone.
func _lifted() -> StoneLiftingRun:
	var run := StoneLiftingRun.new(_drill())
	assert_eq(run.press(0).size(), 0, "precondition: the first press judges nothing")
	assert_true(run.is_lifting(), "precondition: the first press lifts")
	return run

#-----------------------------------------------------------------------------
# THE SHARE
#-----------------------------------------------------------------------------

## The share falls through the canvas's windows as the stone stops further from
## the band's centre, and each edge lands in the better tier.
func test_the_share_falls_through_the_windows() -> void:
	var cases: Array[Dictionary] = [
		{"offset": 0, "share": 1.0},
		{"offset": 70_000, "share": 0.85},
		{"offset": -70_000, "share": 0.85},
		{"offset": 210_000, "share": 0.6},
		{"offset": -210_000, "share": 0.6},
		{"offset": 630_000, "share": 0.3},
		{"offset": -630_000, "share": 0.3},
		{"offset": 1_050_000, "share": 0.0},
		{"offset": -2_000_000, "share": 0.0},
	]
	for case: Dictionary in cases:
		assert_almost_eq(StoneLiftingRun.share_for_offset(case["offset"]), case["share"], 0.000001, "%d us off the centre" % case["offset"])
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(70_000)), Tier.PERFECT, "the brass's edge is Perfect")
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(70_001)), Tier.GOOD, "just past it is Good")
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(210_000)), Tier.GOOD, "the band's edge is Good")
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(210_001)), Tier.OK, "just past it is OK")
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(630_000)), Tier.OK, "the tan's edge is OK")
	assert_eq(DrillRules.judge(StoneLiftingRun.share_for_offset(630_001)), Tier.MISS, "just past it is a Miss")

#-----------------------------------------------------------------------------
# A REP
#-----------------------------------------------------------------------------

## A release is judged by how long it held the stone up.
func test_a_release_is_judged_by_how_long_it_was_held() -> void:
	var cases: Array[Dictionary] = [
		{"held": CENTRE, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"held": 1_200_000, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"held": 900_000, "tier": Tier.OK, "miss": Miss.NONE},
		{"held": 1_850_000, "tier": Tier.OK, "miss": Miss.NONE},
		{"held": 600_000, "tier": Tier.MISS, "miss": Miss.TOO_LOW},
	]
	for case: Dictionary in cases:
		var run: StoneLiftingRun = _lifted()
		var judged: Array[DrillRun.Judgement] = run.release(case["held"])
		assert_eq(judged.size(), 1, "held %d us: one judgement" % case["held"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "the first rep")
		assert_eq(judged[0].tier, case["tier"], "held %d us: the tier" % case["held"])
		assert_eq(judged[0].miss, case["miss"], "held %d us: the reason" % case["held"])
		assert_eq(judged[0].at_usec, case["held"], "judged at the release")
		assert_almost_eq(judged[0].height, float(case["held"]) / StoneLiftingRun.RISE_USEC, 0.000001, "where the stone stopped")
		assert_false(run.is_lifting(), "the lift is over")

func test_holding_past_the_top_drops_the_stone() -> void:
	var run: StoneLiftingRun = _lifted()
	var judged: Array[DrillRun.Judgement] = run.advance(2_500_000)
	assert_eq(judged.size(), 1, "the stone dropped")
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.DROPPED)
		assert_eq(judged[0].at_usec, StoneLiftingRun.RISE_USEC, "at the top, 2 s after the lift, however late the frame")
		assert_eq(judged[0].height, 1.0)
	assert_eq(run.release(2_600_000).size(), 0, "letting go after the drop judges nothing")

#-----------------------------------------------------------------------------
# BETWEEN REPS
#-----------------------------------------------------------------------------

## No slot: a rep never ends on its own while the stone rests, however long the
## player waits.
func test_a_pause_judges_nothing() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.advance(60 * S).size(), 0, "a minute's wait judges nothing")
	assert_eq(run.get_judged_count(), 1)
	assert_false(run.is_lifting())

## A new press lifts whenever the stone is down, and the rep is judged from it.
func test_a_press_lifts_whenever_the_stone_is_down() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.press(30 * S).size(), 0)
	assert_true(run.is_lifting(), "the press lifts at once")
	var judged: Array[DrillRun.Judgement] = run.release(30 * S + CENTRE)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1, "the second rep")
		assert_eq(judged[0].tier, Tier.PERFECT, "timed from the press")

## A press made while the stone sets down lifts it the moment it is down.
func test_a_press_made_while_the_stone_sets_down_lifts_as_it_lands() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	run.press(CENTRE + 400_000)
	assert_false(run.is_lifting(), "the stone is still setting down")
	run.advance(CENTRE + 600_000)
	assert_true(run.is_lifting(), "and lifts the moment it is down, 0.6 s after the release")
	run.advance(CENTRE + 1_600_000)
	assert_almost_eq(run.height_at(CENTRE + 1_600_000), 0.5, 0.000001, "a second of lifting")

## A press held through a drop lifts nothing more: the player lets go and presses
## again (#100's held press, which could cost two reps, goes).
func test_a_press_held_through_a_drop_lifts_nothing() -> void:
	var run: StoneLiftingRun = _lifted()
	var judged: Array[DrillRun.Judgement] = run.advance(2 * S)
	assert_eq(judged.size(), 1, "precondition: the stone dropped")
	run.advance(10 * S)
	assert_false(run.is_lifting(), "still held, the press lifts nothing")
	run.release(10 * S)
	run.press(11 * S)
	assert_true(run.is_lifting(), "a new press lifts")

## A press while the stone rests judges nothing.
func test_a_press_during_the_rest_judges_nothing() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.press(CENTRE + 100_000).size(), 0)
	assert_eq(run.get_judged_count(), 1)

## While the stone rises the rep's progress is its height; at rest it is 0.
func test_rep_progress_is_the_lift() -> void:
	var run: StoneLiftingRun = _lifted()
	run.advance(S)
	assert_almost_eq(run.rep_progress_at(S), 0.5, 0.000001, "half way up")
	run.release(CENTRE)
	assert_eq(run.rep_progress_at(CENTRE), 0.0, "no rep in play once it is let go")

func test_the_stone_rests_then_sets_down() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	var stopped: float = float(CENTRE) / StoneLiftingRun.RISE_USEC
	assert_almost_eq(run.height_at(CENTRE), stopped, 0.000001, "where it was let go")
	assert_almost_eq(run.height_at(CENTRE + 300_000), stopped, 0.000001, "it rests there 0.3 s")
	assert_almost_eq(run.height_at(CENTRE + 450_000), stopped / 2.0, 0.000001, "then sets down")
	assert_eq(run.height_at(CENTRE + 600_000), 0.0, "and is down 0.6 s after the release")

func test_a_dropped_stone_falls_at_once() -> void:
	var run: StoneLiftingRun = _lifted()
	run.advance(2 * S)
	assert_eq(run.height_at(2 * S), 1.0)
	assert_almost_eq(run.height_at(2_150_000), 0.5, 0.000001, "it falls without resting")
	assert_eq(run.height_at(2_300_000), 0.0)

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

func test_a_set_is_ten_reps_and_ends_when_the_last_stone_is_down() -> void:
	var run := StoneLiftingRun.new(_drill())
	var judged: Array[DrillRun.Judgement] = []
	for rep: int in 10:
		judged.append_array(run.press(rep * 2 * S))
		judged.append_array(run.release(rep * 2 * S + CENTRE))
	assert_eq(judged.size(), 10, "ten reps, two seconds apart")
	for judgement: DrillRun.Judgement in judged:
		assert_eq(judgement.tier, Tier.PERFECT, "rep %d" % judgement.rep)
	assert_eq(run.get_judged_count(), 10)
	assert_eq(run.get_end_usec(), 18 * S + CENTRE + 600_000, "the set ends when the tenth stone is down")
	assert_eq(run.press(30 * S).size(), 0, "a press after the last rep judges nothing")
	assert_false(run.is_lifting())

func test_a_set_has_no_end_before_its_last_rep() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.get_end_usec(), -1)
