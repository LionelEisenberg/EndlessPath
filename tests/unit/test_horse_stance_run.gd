extends GutTest

## Unit tests for HorseStanceRun, the judge of one set of Horse Stance: hold and the
## stance gauge's needle sinks deeper, let go and it rises. Each rep is one stance
## (#143): a press sinks the player into it, it lands once the needle has spent
## HOLD_USEC inside an arc drifting along the gauge, judged by the share of the rep
## spent inside, and then the needle stands and the arc returns to the top. Every
## time is on the set's own clock in microseconds, from the first press. The arcs
## here are built in each test, still or moving along known lines, so every share
## and every time is exact.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
const EPS: float = 0.000001

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of ten reps with a 4 s Auto pace, as Horse Stance's.
func _drill() -> DrillData:
	var drill := DrillData.new()
	drill.id = "test_stance"
	drill.strength_xp_per_rep = 8.0
	drill.minor_stat = CharacterAttributesData.AttributeType.BODY
	drill.minor_xp_per_rep = 4.0
	drill.health_per_rep = 4.0
	drill.input_kind = DrillData.InputKind.HOLD_STEADY
	drill.rep_seconds = 4.0
	drill.reps_per_set = 10
	return drill

## A run whose every rep's arc passes through `centres` at `times` (usec from the
## rep's start), straight between them and held after the last.
func _run(times: Array, centres: Array) -> HorseStanceRun:
	return HorseStanceRun.new(_drill(), [[PackedInt64Array(times), PackedFloat64Array(centres)]])

## A run whose every rep's arc stands still with its centre at `centre`.
func _still(centre: float) -> HorseStanceRun:
	return _run([0], [centre])

## Plays `events` on `run` ([time, true for a press or false for a release]), then
## lets the time run to `until`; returns every rep judged.
func _play(run: HorseStanceRun, events: Array, until: int) -> Array[DrillRun.Judgement]:
	var judged: Array[DrillRun.Judgement] = []
	for event: Array in events:
		if event[1]:
			judged.append_array(run.press(event[0]))
		else:
			judged.append_array(run.release(event[0]))
	judged.append_array(run.advance(until))
	return judged

#-----------------------------------------------------------------------------
# THE NEEDLE
#-----------------------------------------------------------------------------

func test_the_needle_sinks_while_held_and_rises_when_let_go() -> void:
	var run: HorseStanceRun = _still(0.5)
	run.press(0)
	assert_almost_eq(run.marker_at(S), 0.5, EPS, "held a second: half way down the gauge")
	run.release(S)
	assert_almost_eq(run.marker_at(1_500_000), 0.25, EPS, "let go: it rises as fast")
	run.advance(3 * S)
	assert_eq(run.marker_at(3 * S), 0.0, "and stands")

## Held past the deepest the needle stays there; it never drops. Out of the arc
## at 0.5 from 1.24 s on, the rep is lost once 4.67 s of it were spent out.
func test_the_needle_stops_at_the_deepest_and_never_drops() -> void:
	var run: HorseStanceRun = _still(0.5)
	run.press(0)
	assert_eq(run.advance(3 * S).size(), 0, "nothing is judged while the rep can still land")
	assert_eq(run.marker_at(3 * S), 1.0, "held past the deepest, the needle stays there")
	var judged: Array[DrillRun.Judgement] = run.advance(6 * S)
	assert_eq(judged.size(), 1, "the rep is lost")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.TOO_DEEP, "deep longer than shallow")
		assert_eq(judged[0].at_usec, 1_240_000 + HorseStanceRun.OUT_LIMIT_USEC - 760_000, "the moment its time out reached the limit")
		assert_eq(judged[0].height, 1.0, "judged where the needle stood")

#-----------------------------------------------------------------------------
# A REP
#-----------------------------------------------------------------------------

## With the arc around the standing needle the rep is inside from its press: it
## lands the moment it has held the arc 2 s, a Perfect stance.
func test_a_rep_inside_from_the_start_lands_after_its_hold() -> void:
	var judged: Array[DrillRun.Judgement] = _play(_still(HorseStanceRun.BAND_START), [[0, true], [100_000, false]], 3 * S)
	assert_eq(judged.size(), 1, "one rep")
	if judged.size() == 1:
		assert_eq(judged[0].rep, 0)
		assert_eq(judged[0].tier, Tier.PERFECT)
		assert_eq(judged[0].at_usec, HorseStanceRun.HOLD_USEC, "2 s in the arc")

## Held deep through the arc at the gauge's deep end: out until 1.52 s, then in it
## until it lands at 3.52 s, 2 s of 3.52: OK.
func test_a_rep_lands_once_the_needle_has_held_the_arc() -> void:
	var judged: Array[DrillRun.Judgement] = _play(_still(0.88), [[0, true]], 5 * S)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].at_usec, 3_520_000)
		assert_eq(judged[0].tier, Tier.OK, "2 s in the arc over 3.52 s")
		assert_eq(judged[0].height, 1.0, "the needle at the deepest")

## The share is the part of the rep the needle spent in the arc, #97's tiers. Held
## `h` from the standing needle under an arc at the top, the needle is out from
## 0.48 s to 2h - 0.48 s, and the rep lands at 2h + 1.04 s.
func test_a_rep_is_judged_by_its_share_in_the_arc() -> void:
	var cases: Array[Dictionary] = [
		{"held": 655_000, "at": 2_350_000, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"held": 980_000, "at": 3_000_000, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"held": 1_480_000, "at": 4_000_000, "tier": Tier.OK, "miss": Miss.NONE},
		{"held": 4 * S, "at": 480_000 + HorseStanceRun.OUT_LIMIT_USEC, "tier": Tier.MISS, "miss": Miss.TOO_DEEP},
	]
	for case: Dictionary in cases:
		var what: String = "held %d us" % case["held"]
		var judged: Array[DrillRun.Judgement] = _play(_still(HorseStanceRun.BAND_START), [[0, true], [case["held"], false]], 8 * S)
		assert_eq(judged.size(), 1, "%s: one rep" % what)
		if judged.size() != 1:
			continue
		assert_eq(judged[0].at_usec, case["at"], "%s: when it ended" % what)
		assert_eq(judged[0].tier, case["tier"], "%s: the tier" % what)
		assert_eq(judged[0].miss, case["miss"], "%s: the reason" % what)

## Left standing under an arc at the deep end, the rep is lost the moment it has
## been out of the arc 4.67 s: too shallow.
func test_a_rep_out_of_the_arc_too_long_is_a_miss() -> void:
	var judged: Array[DrillRun.Judgement] = _play(_still(0.88), [[0, true], [100_000, false]], 10 * S)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.MISS)
		assert_eq(judged[0].miss, Miss.TOO_SHALLOW)
		assert_eq(judged[0].at_usec, HorseStanceRun.OUT_LIMIT_USEC)

## The arc moves along its path from the rep's press: a needle left standing is
## inside only while the arc is over it.
func test_a_moving_arc_counts_the_time_inside() -> void:
	var run: HorseStanceRun = _run([0, S, 2 * S], [0.12, 0.5, 0.12])
	run.press(0)
	run.release(100_000)
	run.advance(S)
	assert_false(run.is_inside_at(S), "the arc has left the standing needle at 1 s")
	run.advance(2_900_000)
	assert_true(run.is_inside_at(2_900_000), "and is back over it by 2.9 s")
	assert_true(run.is_rep_in_play(), "the rep runs on")

#-----------------------------------------------------------------------------
# BETWEEN REPS
#-----------------------------------------------------------------------------

## After a rep the needle rises whatever the press, and the arc slides back to
## the top with it, both arriving as the needle stands.
func test_after_a_rep_the_needle_stands_and_the_arc_returns() -> void:
	var run: HorseStanceRun = _still(0.88)
	_play(run, [[0, true]], 3_520_000)
	assert_false(run.is_rep_in_play(), "precondition: the rep landed at 3.52 s")
	run.advance(4_520_000)
	assert_almost_eq(run.marker_at(4_520_000), 0.5, EPS, "half way up a second later, though still held")
	assert_almost_eq(run.band_centre_at(4_520_000), 0.5, EPS, "the arc half way back")
	run.advance(5_520_000)
	assert_eq(run.marker_at(5_520_000), 0.0, "standing")
	assert_almost_eq(run.band_centre_at(5_520_000), HorseStanceRun.BAND_START, EPS, "the arc at the top")

func test_a_press_held_through_the_landing_sinks_nothing() -> void:
	var run: HorseStanceRun = _still(0.88)
	_play(run, [[0, true]], 20 * S)
	assert_eq(run.get_judged_count(), 1, "one rep, then nothing")
	assert_false(run.is_rep_in_play(), "the press still held starts no rep")
	assert_eq(run.marker_at(20 * S), 0.0)

## A press made while standing up sinks the player once they stand.
func test_a_press_made_while_standing_up_sinks_once_standing() -> void:
	var run: HorseStanceRun = _still(0.88)
	_play(run, [[0, true], [3_600_000, false], [4 * S, true]], 5 * S)
	assert_false(run.is_rep_in_play(), "still standing up at 5 s")
	run.advance(5_520_000)
	assert_true(run.is_rep_in_play(), "the rep starts as the needle stands")
	run.advance(6_020_000)
	assert_almost_eq(run.marker_at(6_020_000), 0.25, EPS, "sinking from 5.52 s")

## Review Focus 2: between reps nothing moves on. The arc rests at the top and a
## minute's wait judges nothing.
func test_a_pause_judges_nothing_and_the_arc_stays_still() -> void:
	var run: HorseStanceRun = _run([0, S], [0.12, 0.5])
	run.press(0)
	run.release(100_000)
	assert_eq(run.advance(5 * S).size(), 1, "precondition: the first rep, lost standing")
	assert_eq(run.advance(65 * S).size(), 0, "a minute's wait judges nothing")
	assert_almost_eq(run.band_centre_at(65 * S), HorseStanceRun.BAND_START, EPS, "the arc rests at the top")
	assert_false(run.is_rep_in_play())

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

func test_the_set_ends_once_the_needle_stands_after_the_tenth() -> void:
	var run: HorseStanceRun = _still(HorseStanceRun.BAND_START)
	var judged: Array[DrillRun.Judgement] = []
	for rep: int in 10:
		judged.append_array(run.press(rep * 3 * S))
		judged.append_array(run.release(rep * 3 * S + 100_000))
		if rep < 9:
			assert_eq(run.get_end_usec(), -1, "no end before the last rep")
	judged.append_array(run.advance(40 * S))
	assert_eq(judged.size(), 10, "ten reps")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].tier, Tier.PERFECT)
	assert_eq(run.get_end_usec(), 29 * S, "the tenth landed at 29 s with the needle standing")
	assert_eq(run.press(41 * S).size(), 0, "a press after the last rep judges nothing")
	assert_false(run.is_rep_in_play())

## The rep's progress is its hold: the time inside over HOLD_USEC, 0 between reps.
func test_hold_progress_follows_the_time_inside() -> void:
	var run: HorseStanceRun = _still(HorseStanceRun.BAND_START)
	run.press(0)
	run.release(100_000)
	run.advance(S)
	assert_almost_eq(run.hold_progress(), 0.5, EPS, "a second of the two")
	assert_almost_eq(run.rep_progress_at(S), 0.5, EPS)
	run.advance(3 * S)
	assert_eq(run.hold_progress(), 0.0, "the rep landed")

#-----------------------------------------------------------------------------
# THE ARC'S PATHS
#-----------------------------------------------------------------------------

## Each rep's arc starts at the top around the standing needle, stays on the
## gauge, turns every 0.8 to 1.6 s at 0.1 to 0.275 of the gauge a second, and
## outlasts the longest rep. A seed always makes the same paths.
func test_the_band_paths_start_at_the_top_and_stay_on_the_gauge() -> void:
	var paths: Array = HorseStanceRun.band_paths(7, 10)
	assert_eq(paths.size(), 10, "a path a rep")
	for path: Array in paths:
		var times: PackedInt64Array = path[0]
		var centres: PackedFloat64Array = path[1]
		assert_eq(times.size(), centres.size(), "a centre for every time")
		assert_eq(times[0], 0, "it starts with the rep")
		assert_eq(centres[0], HorseStanceRun.BAND_START, "at the top")
		assert_gte(times[times.size() - 1], HorseStanceRun.PATH_USEC, "it outlasts the longest rep")
		for index: int in range(1, times.size()):
			var duration: int = times[index] - times[index - 1]
			var speed: float = absf(centres[index] - centres[index - 1]) / (duration / 1_000_000.0)
			assert_between(duration, HorseStanceRun.TURN_MIN_USEC, HorseStanceRun.TURN_MAX_USEC, "turn %d comes in time" % index)
			assert_between(speed, HorseStanceRun.SPEED_MIN - EPS, HorseStanceRun.SPEED_MAX + EPS, "turn %d's speed" % index)
			assert_between(centres[index], HorseStanceRun.BAND_LOW, HorseStanceRun.BAND_HIGH, "turn %d stays on the gauge" % index)
	assert_eq(HorseStanceRun.band_paths(7, 10), paths, "the same seed, the same paths")
	assert_ne(HorseStanceRun.band_paths(8, 10), paths, "another seed, other paths")
