extends GutTest

## Unit tests for FallingLeafRun, the judge of one set of Falling Leaf: once each 2 s
## rep a leaf drifts down past the figure's hand, reaching the palm at a time of
## its own, and the rep's first press catches it, judged by how far the leaf was
## from the palm. Near the hand a leaf falls 200 px a second, so 1 px is 5 ms. The
## rules every timed press shares are pinned in test_waterfall_run.gd. Every time
## is on the set's own clock in microseconds, from the press that started it.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
const EPS: float = 0.000001
## When each leaf reaches the palm, from its rep's start, unless a test says.
const ARRIVAL: int = 1_000_000
## How long after the palm a leaf nobody caught has fallen past the hand.
const FALLEN: int = 320_000

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A run of ten 2 s reps, as Falling Leaf's, each leaf reaching the palm at its
## arrival from its rep's start: `arrivals`, or ARRIVAL for each.
func _run(arrivals: Array = []) -> FallingLeafRun:
	var drill := DrillData.new()
	drill.id = "test_leaf"
	drill.strength_xp_per_rep = 4.0
	drill.minor_stat = CharacterAttributesData.AttributeType.AGILITY
	drill.minor_xp_per_rep = 2.0
	drill.health_per_rep = 2.0
	drill.input_kind = DrillData.InputKind.CATCH
	drill.rep_seconds = 2.0
	drill.reps_per_set = 10
	var times := PackedInt64Array()
	for rep: int in 10:
		times.append(arrivals[rep] if rep < arrivals.size() else ARRIVAL)
	return FallingLeafRun.new(drill, times)

#-----------------------------------------------------------------------------
# A CATCH
#-----------------------------------------------------------------------------

## The canvas's windows: in the palm (12 px) Perfect, in the fingers (24 px) Good,
## a brush (44 px) OK, each edge in the better tier, above or below the palm.
func test_a_catch_is_judged_by_the_leaf_s_distance_from_the_palm() -> void:
	var cases: Array[Dictionary] = [
		{"name": "on the palm", "offset": 0, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"name": "12 px below", "offset": 60_000, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"name": "12 px above", "offset": -60_000, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"name": "just past 12 px below", "offset": 60_001, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"name": "24 px above", "offset": -120_000, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"name": "44 px below", "offset": 220_000, "tier": Tier.OK, "miss": Miss.NONE},
		{"name": "just past 44 px above", "offset": -220_001, "tier": Tier.MISS, "miss": Miss.TOO_EARLY},
		{"name": "just past 44 px below", "offset": 220_001, "tier": Tier.MISS, "miss": Miss.TOO_LATE},
	]
	for case: Dictionary in cases:
		var run: FallingLeafRun = _run()
		var pressed_at: int = ARRIVAL + case["offset"]
		assert_almost_eq(run.offset_px_at(0, pressed_at), case["offset"] / 5000.0, EPS, "%s: where the leaf is" % case["name"])
		var judged: Array[DrillRun.Judgement] = run.press(pressed_at)
		assert_eq(judged.size(), 1, "%s: one judgement" % case["name"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].tier, case["tier"], "%s: the tier" % case["name"])
		assert_eq(judged[0].miss, case["miss"], "%s: the reason" % case["name"])
		assert_eq(judged[0].at_usec, pressed_at, "%s: judged at the press" % case["name"])

func test_each_leaf_reaches_the_palm_at_its_own_time() -> void:
	var run: FallingLeafRun = _run([900_000, 1_500_000, 1_200_000])
	assert_eq(run.target_usec(0), 900_000)
	assert_eq(run.target_usec(1), 2 * S + 1_500_000)
	assert_eq(run.target_usec(2), 4 * S + 1_200_000)
	assert_almost_eq(run.offset_px_at(1, 3_500_000), 0.0, EPS, "on the palm at its time")
	assert_almost_eq(run.offset_px_at(1, 3_400_000), -20.0, EPS, "20 px above it a tenth of a second before")

func test_a_leaf_nobody_catches_falls_past_the_hand() -> void:
	var run: FallingLeafRun = _run()
	assert_eq(run.advance(ARRIVAL + FALLEN - 1).size(), 0, "a press could still score")
	var judged: Array[DrillRun.Judgement] = run.advance(ARRIVAL + FALLEN)
	assert_eq(judged.size(), 1, "missed once it is 64 px below the palm")
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.LET_FALL)
		assert_eq(judged[0].at_usec, ARRIVAL + FALLEN)

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

## Review Focus 1: a hitch never changes a result. Each leaf nobody caught is
## missed once it has fallen past the hand, in order, however late the frame comes.
func test_a_long_gap_judges_each_rep_in_order() -> void:
	var run: FallingLeafRun = _run()
	var judged: Array[DrillRun.Judgement] = run.advance(21 * S)
	assert_eq(judged.size(), 10, "ten reps")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].miss, Miss.LET_FALL)
		assert_eq(judged[index].at_usec, index * 2 * S + ARRIVAL + FALLEN, "once its own leaf fell past")
	assert_eq(run.get_end_usec(), 20 * S, "the set ends with its last rep's slot")

## The leaves a set drops: each reaches the palm 0.9 to 1.5 s into its rep, the
## same for the same seed.
func test_the_leaf_times_stay_in_their_window() -> void:
	var arrivals: PackedInt64Array = FallingLeafRun.leaf_arrivals(7, 10)
	assert_eq(arrivals.size(), 10, "a leaf a rep")
	for index: int in arrivals.size():
		assert_between(arrivals[index], FallingLeafRun.ARRIVE_MIN_USEC, FallingLeafRun.ARRIVE_MAX_USEC, "leaf %d" % index)
	assert_eq(FallingLeafRun.leaf_arrivals(7, 10), arrivals, "the same seed, the same leaves")
	assert_ne(FallingLeafRun.leaf_arrivals(8, 10), arrivals, "another seed, other leaves")
