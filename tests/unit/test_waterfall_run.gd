extends GutTest

## Unit tests for WaterfallRun, the judge of one set of Waterfall Tempering: the
## next surge waits at the ledge until a press sends it down (#143), it lands on the
## brace line 1.5 s later, and the next press is judged by how close to the landing
## it came. They also pin the rules every timed press shares (TimedPressRun): a
## press with no rep in play starts the next rep, one judged press a rep, a rep with
## no press missed at its deadline, and nothing coming on its own. Every time is on
## the set's own clock in microseconds, from the press that started it.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
## When a surge sent at 0 lands.
const LAND: int = 1_500_000
## How long after a landing a rep with no press is missed.
const DEADLINE: int = 260_000

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A run of ten reps with a 3 s Auto pace, as Waterfall Tempering's.
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

## A run whose first surge was sent at 0.
func _sent() -> WaterfallRun:
	var run: WaterfallRun = _run()
	assert_eq(run.press(0).size(), 0, "precondition: the first press sends a surge, judging nothing")
	return run

#-----------------------------------------------------------------------------
# A SURGE
#-----------------------------------------------------------------------------

func test_a_press_sends_the_waiting_surge() -> void:
	var run: WaterfallRun = _run()
	assert_eq(run.rep_in_play(), -1, "before the set, the surge waits at the ledge")
	assert_eq(run.target_usec(0), -1, "and has no landing yet")
	run.press(2 * S)
	assert_eq(run.rep_in_play(), 0, "the press sends it")
	assert_eq(run.target_usec(0), 2 * S + LAND, "to land 1.5 s later")

## #97's windows: within 0.05 s Perfect, 0.1 s Good, 0.18 s OK, each edge in the
## better tier, either side of the landing.
func test_a_brace_is_judged_by_its_time_from_the_landing() -> void:
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
		var judged: Array[DrillRun.Judgement] = _sent().press(LAND + case["offset"])
		assert_eq(judged.size(), 1, "%d us off: one judgement" % case["offset"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "the first rep")
		assert_eq(judged[0].tier, case["tier"], "%d us off: the tier" % case["offset"])
		assert_eq(judged[0].miss, case["miss"], "%d us off: the reason" % case["offset"])
		assert_eq(judged[0].at_usec, LAND + case["offset"], "judged at the press")

func test_a_surge_nobody_braces_for_buckles() -> void:
	var run: WaterfallRun = _sent()
	assert_eq(run.advance(LAND + DEADLINE - 1).size(), 0, "a press could still score")
	var judged: Array[DrillRun.Judgement] = run.advance(LAND + DEADLINE)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.BUCKLED, "it crashes through")
		assert_eq(judged[0].at_usec, LAND + DEADLINE)
	assert_eq(run.rep_in_play(), -1, "and the next surge waits")

## Once a rep is judged, the next press sends the next surge: it is not judged.
func test_the_press_after_a_judged_rep_sends_the_next() -> void:
	var run: WaterfallRun = _sent()
	run.press(LAND)
	assert_eq(run.press(LAND + 100_000).size(), 0, "a press after the brace judges nothing")
	assert_eq(run.rep_in_play(), 1, "it sends the second surge")
	assert_eq(run.target_usec(1), LAND + 100_000 + LAND)

## Review Focus 2: no surge comes on its own, however long the player waits.
func test_no_surge_comes_on_its_own() -> void:
	var run: WaterfallRun = _sent()
	run.press(LAND)
	assert_eq(run.advance(60 * S).size(), 0, "a minute's wait judges nothing")
	assert_eq(run.rep_in_play(), -1, "the next surge waits at the ledge")

func test_a_release_judges_nothing() -> void:
	var run: WaterfallRun = _sent()
	assert_eq(run.release(LAND).size(), 0)
	var judged: Array[DrillRun.Judgement] = run.press(LAND + 10_000)
	assert_eq(judged.size(), 1, "the press after the release is still the rep's")
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.PERFECT)

## The rep in play's motion is its surge's ride, from the ledge to the line.
func test_rep_progress_is_the_surge_s_ride() -> void:
	var run: WaterfallRun = _sent()
	run.advance(750_000)
	assert_almost_eq(run.rep_progress_at(750_000), 0.5, 0.000001, "half way down")
	run.press(LAND)
	assert_eq(run.rep_progress_at(LAND), 0.0, "braced: nothing in play")

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

func test_a_set_ends_with_its_tenth_surge() -> void:
	var run: WaterfallRun = _run()
	var judged: Array[DrillRun.Judgement] = []
	for rep: int in 10:
		judged.append_array(run.press(rep * 2 * S))
		judged.append_array(run.press(rep * 2 * S + LAND))
		if rep < 9:
			assert_eq(run.get_end_usec(), -1, "no end before the tenth")
	assert_eq(judged.size(), 10, "ten surges")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].tier, Tier.PERFECT)
	assert_eq(run.get_end_usec(), 18 * S + LAND, "the set ends at the tenth brace")
	assert_eq(run.press(30 * S).size(), 0, "a press after the last rep judges nothing")
	assert_eq(run.rep_in_play(), -1)
