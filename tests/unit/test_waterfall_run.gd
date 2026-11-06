extends GutTest

## Unit tests for WaterfallRun, the judge of one set of Waterfall Tempering: once
## each 3 s rep a blow of water lands 1.5 s into it, on a steady beat, and the
## first press of the rep is judged by how close to the landing it came. They also
## pin the rules every timed press shares (TimedPressRun): one judged press a rep,
## a rep with no press missed at its deadline, every rep judged in order. Every
## time is on the set's own clock in microseconds, from the press that started it,
## which is not judged.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
## When the first blow lands.
const BEAT: int = 1_500_000
## How long after a landing a rep with no press is missed.
const DEADLINE: int = 260_000

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A run of ten 3 s reps, as Waterfall Tempering's.
func _run() -> WaterfallRun:
	var drill := DrillData.new()
	drill.id = "test_waterfall"
	drill.strength_xp_per_rep = 6.0
	drill.minor_stat = CharacterAttributesData.AttributeType.BODY
	drill.minor_xp_per_rep = 3.0
	drill.health_per_rep = 3.0
	drill.input_kind = DrillData.InputKind.BEAT
	drill.rep_seconds = 3.0
	drill.reps_per_set = 10
	return WaterfallRun.new(drill)

#-----------------------------------------------------------------------------
# A PRESS
#-----------------------------------------------------------------------------

## #97's windows: within 0.05 s Perfect, 0.1 s Good, 0.18 s OK, each edge in the
## better tier, either side of the landing.
func test_a_press_is_judged_by_its_time_from_the_landing() -> void:
	var cases: Array[Dictionary] = [
		{"offset": 0, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"offset": 50_000, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"offset": -50_000, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"offset": 50_001, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"offset": -100_000, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"offset": 180_000, "tier": Tier.OK, "miss": Miss.NONE},
		{"offset": -180_001, "tier": Tier.MISS, "miss": Miss.TOO_EARLY},
		{"offset": 180_001, "tier": Tier.MISS, "miss": Miss.TOO_LATE},
	]
	for case: Dictionary in cases:
		var judged: Array[DrillRun.Judgement] = _run().press(BEAT + case["offset"])
		assert_eq(judged.size(), 1, "%d us off: one judgement" % case["offset"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "the first rep")
		assert_eq(judged[0].tier, case["tier"], "%d us off: the tier" % case["offset"])
		assert_eq(judged[0].miss, case["miss"], "%d us off: the reason" % case["offset"])
		assert_eq(judged[0].at_usec, BEAT + case["offset"], "judged at the press")

func test_each_blow_lands_on_a_steady_beat() -> void:
	var run: WaterfallRun = _run()
	for rep: int in 10:
		assert_eq(run.target_usec(rep), rep * 3 * S + BEAT, "blow %d lands 1.5 s into its rep" % rep)

func test_a_blow_nobody_meets_is_missed() -> void:
	var run: WaterfallRun = _run()
	assert_eq(run.advance(BEAT + DEADLINE - 1).size(), 0, "a press could still score")
	var judged: Array[DrillRun.Judgement] = run.advance(BEAT + DEADLINE)
	assert_eq(judged.size(), 1, "missed once no press can score")
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.MISSED_BEAT)
		assert_eq(judged[0].at_usec, BEAT + DEADLINE)

## Review Focus 2: mashing can't catch every beat. The first press of a rep is the
## one judged; the next press waits for the next rep.
func test_only_the_first_press_of_a_rep_is_judged() -> void:
	var run: WaterfallRun = _run()
	var judged: Array[DrillRun.Judgement] = run.press(BEAT - 500_000)
	assert_eq(judged.size(), 1, "a press half a second early is judged")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.TOO_EARLY)
	assert_eq(run.press(BEAT).size(), 0, "a press on the beat after it judges nothing")
	judged = run.press(3 * S + BEAT)
	assert_eq(judged.size(), 1, "the next rep's beat is judged")
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1)
		assert_eq(judged[0].tier, Tier.PERFECT)

func test_a_release_judges_nothing() -> void:
	var run: WaterfallRun = _run()
	assert_eq(run.release(BEAT).size(), 0, "only a press meets a blow")
	assert_eq(run.get_judged_count(), 0)

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

## Review Focus 1: a hitch never changes a result. Each rep nobody pressed in is
## missed at its own deadline, in order, however late the frame comes.
func test_a_long_gap_judges_each_rep_in_order() -> void:
	var run: WaterfallRun = _run()
	var judged: Array[DrillRun.Judgement] = run.advance(31 * S)
	assert_eq(judged.size(), 10, "ten reps")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].miss, Miss.MISSED_BEAT)
		assert_eq(judged[index].at_usec, index * 3 * S + BEAT + DEADLINE, "at its own deadline")

func test_a_set_is_ten_beats_and_ends_after_the_last() -> void:
	var run: WaterfallRun = _run()
	var judged: Array[DrillRun.Judgement] = []
	for rep: int in 10:
		judged.append_array(run.press(rep * 3 * S + BEAT))
		judged.append_array(run.release(rep * 3 * S + BEAT + 100_000))
	assert_eq(judged.size(), 10, "ten reps")
	for judgement: DrillRun.Judgement in judged:
		assert_eq(judgement.tier, Tier.PERFECT, "rep %d" % judgement.rep)
	assert_eq(run.get_end_usec(), 30 * S, "the set ends with its last rep's slot")
	assert_eq(run.press(31 * S).size(), 0, "a press after the last rep judges nothing")
