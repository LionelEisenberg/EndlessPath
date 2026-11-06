extends GutTest

## Unit tests for HorseStanceRun, the judge of one set of Horse Stance: hold and the
## stone rises, let go and it sinks, and each 4 s rep is judged by how much of it
## the stone's base spent inside a band drifting along the track. Every time is on
## the set's own clock in microseconds, from the first press. The bands here are
## built in each test, still or moving along known lines, so every share is exact.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss

## One second on the set's clock.
const S: int = 1_000_000
const EPS: float = 0.000001

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of ten 4 s reps, as Horse Stance's.
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

## A run whose band's centre passes through `centres` at `times` (usec), straight
## between them and held after the last.
func _run(times: Array, centres: Array) -> HorseStanceRun:
	return HorseStanceRun.new(_drill(), PackedInt64Array(times), PackedFloat64Array(centres))

## A run whose band stands still with its centre at `centre`.
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

## A press at 0 and a release at `first_release`, then a tap every 0.1 s (let go,
## press, let go...) up to and including `last`, which holds the stone between the
## height it was let go at and 0.05 under it.
func _hover(first_release: int, last: int) -> Array:
	var events: Array = [[0, true]]
	var t: int = first_release
	var down: bool = false
	while t <= last:
		events.append([t, down])
		down = not down
		t += 100_000
	return events

#-----------------------------------------------------------------------------
# THE STONE
#-----------------------------------------------------------------------------

func test_the_stone_rises_while_held_and_sinks_when_let_go() -> void:
	var run: HorseStanceRun = _still(0.5)
	run.press(0)
	assert_almost_eq(run.marker_at(S), 0.5, EPS, "held a second: half way up")
	run.release(S)
	assert_almost_eq(run.marker_at(1_500_000), 0.25, EPS, "let go: it sinks as fast")
	assert_eq(run.marker_at(3 * S), 0.0, "and rests on the bottom")

func test_the_stone_stops_at_the_top_and_never_drops() -> void:
	var run: HorseStanceRun = _still(0.5)
	run.press(0)
	assert_eq(run.advance(3 * S).size(), 0, "nothing is judged before the rep's end")
	assert_eq(run.marker_at(3 * S), 1.0, "held past the top, the stone stays there")
	var judged: Array[DrillRun.Judgement] = run.advance(4 * S)
	assert_eq(judged.size(), 1, "the rep is judged at its end")
	if judged.size() == 1:
		assert_eq(judged[0].at_usec, 4 * S)
		assert_ne(judged[0].miss, Miss.DROPPED, "the stone never drops")
		assert_eq(judged[0].height, 1.0, "it is judged where it stands")

#-----------------------------------------------------------------------------
# A REP
#-----------------------------------------------------------------------------

## The share is the part of the rep the stone's base spent in the band.
func test_a_rep_is_judged_by_its_time_in_the_band() -> void:
	var cases: Array[Dictionary] = [
		# A band low on the track: the stone lifted 0.4 s and let sink never leaves it.
		{"name": "the whole rep inside", "centre": 0.1, "events": [[0, true], [400_000, false]], "tier": Tier.PERFECT, "miss": Miss.NONE},
		# Held up through a band in the middle: inside from 0.76 s to 1.24 s only.
		{"name": "held through the band", "centre": 0.5, "events": [[0, true]], "tier": Tier.MISS, "miss": Miss.OUT_OF_BAND},
		# In the band from 0.36 s, then kept there by taps: 3.64 s of 4.
		{"name": "kept in the band", "centre": 0.3, "events": _hover(600_000, 3_900_000), "tier": Tier.PERFECT, "miss": Miss.NONE},
		# The same until 2.9 s, then held: out of the band at 3.24 s, 2.88 s inside.
		{"name": "kept in, then held out", "centre": 0.3, "events": _hover(600_000, 2_800_000) + [[2_900_000, true]], "tier": Tier.GOOD, "miss": Miss.NONE},
		# Held out at 2.24 s: 1.88 s inside.
		{"name": "held out early", "centre": 0.3, "events": _hover(600_000, 1_800_000) + [[1_900_000, true]], "tier": Tier.OK, "miss": Miss.NONE},
	]
	for case: Dictionary in cases:
		var judged: Array[DrillRun.Judgement] = _play(_still(case["centre"]), case["events"], 4 * S)
		assert_eq(judged.size(), 1, "%s: one rep judged" % case["name"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "%s: the first rep" % case["name"])
		assert_eq(judged[0].tier, case["tier"], "%s: the tier" % case["name"])
		assert_eq(judged[0].miss, case["miss"], "%s: the reason" % case["name"])
		assert_eq(judged[0].at_usec, 4 * S, "%s: judged at the rep's end" % case["name"])

## The band moves: a stone left at rest is inside only once the band has come
## down over it, from 1.9 s here, 2.1 s of the rep.
func test_a_moving_band_counts_the_time_inside() -> void:
	var run: HorseStanceRun = _run([0, 2 * S], [0.5, 0.1])
	run.press(0)
	run.release(0)
	run.advance(S)
	assert_false(run.is_inside_at(S), "the band is still above the stone at 1 s")
	run.advance(3 * S)
	assert_true(run.is_inside_at(3 * S), "and over it at 3 s")
	var judged: Array[DrillRun.Judgement] = run.advance(4 * S)
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].tier, Tier.OK, "2.1 s of 4 inside")

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

## Review Focus 1: a hitch never changes a result. Each rep is judged at its own
## slot's end, in order, however late the frame comes.
func test_a_long_gap_judges_each_rep_in_order() -> void:
	var run: HorseStanceRun = _still(0.1)
	run.press(0)
	run.release(400_000)
	var judged: Array[DrillRun.Judgement] = run.advance(41 * S)
	assert_eq(judged.size(), 10, "ten reps")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].tier, Tier.PERFECT, "rep %d stayed in the band" % index)
		assert_eq(judged[index].at_usec, (index + 1) * 4 * S, "at the end of its own slot")
	assert_eq(run.get_end_usec(), 40 * S, "a stone at rest ends the set with its last rep")

func test_the_set_ends_once_the_stone_has_sunk() -> void:
	var run: HorseStanceRun = _still(0.5)
	run.press(0)
	assert_eq(run.get_end_usec(), -1, "no end before the last rep")
	assert_eq(run.advance(40 * S).size(), 10, "every rep judged, the stone held at the top")
	assert_eq(run.get_end_usec(), 42 * S, "the set ends once the stone has sunk from the top")
	assert_almost_eq(run.marker_at(41 * S), 0.5, EPS, "it sinks though the press is still down")
	assert_eq(run.press(43 * S).size(), 0, "a press after the last rep judges nothing")
	assert_eq(run.marker_at(43 * S), 0.0, "and lifts nothing")

#-----------------------------------------------------------------------------
# THE BAND'S PATH
#-----------------------------------------------------------------------------

## The band a set plays: it starts low, stays on the track, turns every 0.8 to
## 1.6 s at 0.1 to 0.275 of the track a second, and lasts the whole set. A seed
## always makes the same path.
func test_the_band_path_stays_on_the_track() -> void:
	var path: Array = HorseStanceRun.band_path(7, 40 * S)
	var times: PackedInt64Array = path[0]
	var centres: PackedFloat64Array = path[1]
	assert_eq(times.size(), centres.size(), "a centre for every time")
	assert_eq(times[0], 0, "it starts with the set")
	assert_eq(centres[0], HorseStanceRun.BAND_START, "low on the track")
	assert_gte(times[times.size() - 1], 40 * S, "it lasts the whole set")
	for index: int in range(1, times.size()):
		var duration: int = times[index] - times[index - 1]
		var speed: float = absf(centres[index] - centres[index - 1]) / (duration / 1_000_000.0)
		assert_between(duration, HorseStanceRun.TURN_MIN_USEC, HorseStanceRun.TURN_MAX_USEC, "turn %d comes in time" % index)
		assert_between(speed, HorseStanceRun.SPEED_MIN - EPS, HorseStanceRun.SPEED_MAX + EPS, "turn %d's speed" % index)
		assert_between(centres[index], HorseStanceRun.BAND_LOW, HorseStanceRun.BAND_HIGH, "turn %d stays on the track" % index)
	assert_eq(HorseStanceRun.band_path(7, 40 * S), path, "the same seed, the same path")
	assert_ne(HorseStanceRun.band_path(8, 40 * S), path, "another seed, another path")
