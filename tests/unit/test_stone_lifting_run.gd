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

func test_a_rep_with_no_lift_is_too_late() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.advance(8 * S - 1).size(), 0, "the second rep's slot has not ended")
	var judged: Array[DrillRun.Judgement] = run.advance(8 * S)
	assert_eq(judged.size(), 1, "the second rep is judged at its slot's end")
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1)
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.TOO_LATE)
		assert_eq(judged[0].at_usec, 8 * S)
		assert_eq(judged[0].height, 0.0)

func test_a_lift_held_at_the_slot_end_is_judged_there() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	run.press(7_500_000)
	assert_true(run.is_lifting(), "precondition: a late lift in the second rep")
	var judged: Array[DrillRun.Judgement] = run.advance(8 * S)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1)
		assert_eq(judged[0].at_usec, 8 * S, "judged where the rep's time ran out")
		assert_eq(judged[0].miss, Miss.TOO_LOW, "half a second held is too low")
		assert_almost_eq(judged[0].height, 0.25, 0.000001)

#-----------------------------------------------------------------------------
# BETWEEN REPS
#-----------------------------------------------------------------------------

func test_a_press_in_the_rest_of_a_judged_rep_lifts_nothing() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.press(2_500_000).size(), 0)
	run.advance(3 * S)
	assert_false(run.is_lifting(), "the first rep was judged: no second lift in its slot")
	assert_eq(run.get_judged_count(), 1)

func test_a_press_held_over_lifts_at_the_next_slot() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	run.press(3_900_000)
	assert_false(run.is_lifting(), "not before the second rep's slot")
	run.advance(4_500_000)
	assert_true(run.is_lifting(), "the held press lifts as the slot begins")
	assert_almost_eq(run.height_at(4_500_000), 0.25, 0.000001, "the lift began at 4 s")
	var judged: Array[DrillRun.Judgement] = run.release(4 * S + CENTRE)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.PERFECT, "timed from the slot's start")

## A stone still setting down when the next slot begins lifts once it is down.
func test_a_press_lifts_once_the_stone_is_down() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	run.press(5_900_000)
	var judged: Array[DrillRun.Judgement] = run.release(7_800_000)
	assert_eq(judged.size(), 1, "precondition: the second rep, let go late in its slot")
	run.press(8 * S)
	run.advance(8_200_000)
	assert_false(run.is_lifting(), "the stone is still setting down at 8.2 s")
	run.advance(8_400_000)
	assert_true(run.is_lifting(), "and lifts the moment it is down, at 8.4 s")
	run.advance(9_400_000)
	assert_almost_eq(run.height_at(9_400_000), 0.5, 0.000001, "a second of lifting from 8.4 s")

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
		judged.append_array(run.press(rep * 4 * S))
		judged.append_array(run.release(rep * 4 * S + CENTRE))
	assert_eq(judged.size(), 10, "ten reps")
	for judgement: DrillRun.Judgement in judged:
		assert_eq(judgement.tier, Tier.PERFECT, "rep %d" % judgement.rep)
	assert_eq(run.get_judged_count(), 10)
	assert_eq(run.get_end_usec(), 36 * S + CENTRE + 600_000, "the set ends when the tenth stone is down")
	assert_eq(run.press(38 * S).size(), 0, "a press after the last rep judges nothing")
	assert_false(run.is_lifting())

func test_a_set_has_no_end_before_its_last_rep() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	assert_eq(run.get_end_usec(), -1)

## Review Focus 3: a hitch never changes a result. Each rep nobody lifted is
## judged at its own slot's end, in order, however late the frame comes.
func test_a_long_gap_judges_each_slot_in_order() -> void:
	var run: StoneLiftingRun = _lifted()
	run.release(CENTRE)
	var judged: Array[DrillRun.Judgement] = run.advance(41 * S)
	assert_eq(judged.size(), 9, "reps 1 to 9")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index + 1, "in order")
		assert_eq(judged[index].miss, Miss.TOO_LATE)
		assert_eq(judged[index].at_usec, (index + 2) * 4 * S, "at the end of its own slot")
	assert_eq(run.get_end_usec(), 40 * S, "a stone left at rest needs no setting down")

#-----------------------------------------------------------------------------
# THE TARGET (#148)
#-----------------------------------------------------------------------------

## A lift in progress says what a release would score now, matching the release
## itself at every window's edge.
func test_the_release_tier_matches_a_release() -> void:
	var cases: Array[Dictionary] = [
		{"at": CENTRE, "tier": Tier.PERFECT},
		{"at": CENTRE - 70_000, "tier": Tier.PERFECT},
		{"at": CENTRE + 70_000, "tier": Tier.PERFECT},
		{"at": CENTRE - 80_000, "tier": Tier.GOOD},
		{"at": CENTRE + 210_000, "tier": Tier.GOOD},
		{"at": CENTRE - 300_000, "tier": Tier.OK},
		{"at": 600_000, "tier": Tier.MISS},
	]
	for case: Dictionary in cases:
		var run: StoneLiftingRun = _lifted()
		assert_eq(run.release_tier_at(case["at"]), case["tier"], "%d us into the lift" % case["at"])
		var judged: Array[DrillRun.Judgement] = run.release(case["at"])
		if judged.size() == 1:
			assert_eq(judged[0].tier, case["tier"], "%d us: the release agrees" % case["at"])

## With no lift in progress, a release would score nothing.
func test_no_lift_has_no_release_tier() -> void:
	var run := StoneLiftingRun.new(_drill())
	assert_eq(run.release_tier_at(0), Tier.MISS, "before the first press")
	run.press(0)
	run.release(CENTRE)
	assert_eq(run.release_tier_at(CENTRE + 100_000), Tier.MISS, "the stone resting after a rep")
