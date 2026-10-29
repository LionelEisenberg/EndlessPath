extends GutTest

## Pins TribulationRun, the judge of the Tribulation's breathing trial. It runs
## on a copy of the shipped Foundation Tribulation (so a test can change its
## tempo): the schedule of breaths and beats it builds, the phase and the spheres
## it reports for a time, and how it judges presses, releases and the passing of
## time. Times are the trial's own clock in seconds. The breath periods are
## packed 32-bit floats, so beat times carry a little rounding error and are
## compared within EPS; the judging windows are far wider than that.
##
## Beats, with b0 the first (2.5623 s) and b24 the last (35.5389 s):
##   0-5 Steady breath, 6-11 Heartbeat, 12-17 Echo (the two spheres interleave:
##   A, B, A, B, A, B), 18-23 Quickening, 24 the last breath, which is held.

const Result := TribulationRun.Result
const FOUNDATION_TRIBULATION_PATH: String = "res://resources/tribulation/foundation_tribulation.tres"

## Where a shrinking sphere crosses the ring, as a share of its out-breath:
## (1.88 - 1) / (1.88 - 0.42) for a phase's breath, and (2.54 - 1) / (2.54 - 0.42)
## for the last breath.
const CROSS: float = 0.88 / 1.46
const LAST_CROSS: float = 1.54 / 2.12

## How far a computed time or ratio may sit from the figure written in a test.
const EPS: float = 0.001

## The shipped Tribulation's beats: six in each of the four phases, and the last
## breath's. Tests that walk the beats count up to it instead of to the size of
## the array under test, so an empty array cannot pass them.
const BEAT_COUNT: int = 25

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A run on a copy of the shipped Foundation Tribulation at `tempo`.
func _run(tempo: float = 1.0) -> TribulationRun:
	var shipped: TribulationData = load(FOUNDATION_TRIBULATION_PATH) as TribulationData
	assert_not_null(shipped, "%s loads as a TribulationData" % FOUNDATION_TRIBULATION_PATH)
	var data: TribulationData = shipped.duplicate(true) as TribulationData
	data.tempo = tempo
	return TribulationRun.new(data)

## The time of beat `index` of `run`.
func _beat_time(run: TribulationRun, index: int) -> float:
	return run.get_beat_times()[index]

## The time the last beat's hold ends: the sphere has shrunk into the core.
func _hold_end(run: TribulationRun) -> float:
	return _beat_time(run, run.get_beat_times().size() - 1) + run.get_hold_seconds()

## Presses every beat from the first to beat `index` on its time, calling
## advance() just before each press as the board does every frame.
func _hit_through(run: TribulationRun, index: int) -> void:
	var times: PackedFloat64Array = run.get_beat_times()
	for i: int in index + 1:
		run.advance(times[i])
		run.press(times[i])

## A run that has hit every beat, the last one included: the hold has begun.
func _holding_run() -> TribulationRun:
	var run: TribulationRun = _run()
	_hit_through(run, 24)
	return run

## A run that lets the first `missed` beats pass unpressed, hits every other
## beat on its time, and holds the last one to the end.
func _run_missing(missed: int) -> TribulationRun:
	var run: TribulationRun = _run()
	var times: PackedFloat64Array = run.get_beat_times()
	if missed > 0:
		run.advance(times[missed - 1] + 0.15)
	for i: int in range(missed, times.size()):
		run.advance(times[i])
		run.press(times[i])
	run.advance(_hold_end(run) + 0.01)
	return run

## The name of the phase playing at `t`, or "" when none is (the last breath).
func _phase_name(run: TribulationRun, t: float) -> String:
	var phase: TribulationPhaseData = run.phase_at(t)
	return "" if phase == null else phase.phase_name

## The one sphere breathing at `t`. Fails the test and returns an empty
## dictionary when there is not exactly one.
func _only_sphere(run: TribulationRun, t: float) -> Dictionary:
	var spheres: Array[Dictionary] = run.spheres_at(t)
	assert_eq(spheres.size(), 1, "exactly one sphere breathes at %s s" % t)
	return spheres[0] if spheres.size() == 1 else {}

#-----------------------------------------------------------------------------
# SCHEDULE
#-----------------------------------------------------------------------------

func test_foundation_has_25_beats() -> void:
	assert_eq(_run().get_beat_times().size(), BEAT_COUNT, "six Steady, six Heartbeat, six Echo, six Quickening and the last breath")

func test_run_lasts_about_38_seconds() -> void:
	assert_almost_eq(_run().get_duration(), 37.97, EPS, "30.47 s to the last breath, then its 1.8 s in, 4.5 s out and the 1.2 s end pause")

func test_first_beat_crosses_the_ring() -> void:
	var first: float = _beat_time(_run(), 0)
	# The 1.2 s lead-in, the sphere's 0.85 s in-breath, then the share of its 0.85 s out-breath it takes to shrink from 1.88 R to the ring.
	assert_almost_eq(first, 1.2 + 0.85 + 0.85 * CROSS, EPS)
	assert_almost_eq(first, 2.5623, EPS)

func test_phase_starts() -> void:
	var run: TribulationRun = _run()
	assert_almost_eq(run.get_phase_start(0), 1.2, EPS, "Steady breath follows the lead-in")
	assert_almost_eq(run.get_phase_start(1), 11.4, EPS, "Heartbeat follows six 1.7 s breaths")
	assert_almost_eq(run.get_phase_start(2), 18.2, EPS, "Echo follows the 6.8 s Heartbeat")
	assert_almost_eq(run.get_phase_start(3), 24.1, EPS, "Quickening starts 0.8 s after Echo's second sphere ends, at 23.3 s")
	assert_almost_eq(run.get_last_breath_start(), 30.47, EPS, "the last breath starts 0.5 s after Quickening ends")

func test_echo_beats_interleave() -> void:
	var times: PackedFloat64Array = _run().get_beat_times()
	# Sphere A at 18.2 + 1.6 i + 0.8 * (1 + CROSS) and sphere B at 18.8 + 1.5 i + 0.75 * (1 + CROSS).
	var expected: Array[float] = [19.4822, 20.0021, 21.0822, 21.5021, 22.6822, 23.0021]
	for i: int in expected.size():
		assert_almost_eq(times[12 + i], expected[i], EPS, "beat %d, %s sphere" % [12 + i, "first" if i % 2 == 0 else "second"])

func test_beats_are_in_time_order() -> void:
	var times: PackedFloat64Array = _run().get_beat_times()
	for i: int in range(1, BEAT_COUNT):
		assert_gt(times[i], times[i - 1], "beat %d comes after beat %d" % [i, i - 1])

func test_last_beat_and_hold() -> void:
	var run: TribulationRun = _run()
	assert_almost_eq(_beat_time(run, 24), 30.47 + 1.8 + 4.5 * LAST_CROSS, EPS)
	assert_almost_eq(_beat_time(run, 24), 35.5389, EPS)
	assert_almost_eq(run.get_hold_seconds(), 4.5 * (1.0 - LAST_CROSS), EPS)
	assert_almost_eq(run.get_hold_seconds(), 1.2311, EPS, "from the ring to the core")

func test_tempo_divides_every_duration() -> void:
	var normal: TribulationRun = _run()
	var fast: TribulationRun = _run(2.0)
	assert_almost_eq(fast.get_duration(), 18.985, EPS)
	var normal_times: PackedFloat64Array = normal.get_beat_times()
	var fast_times: PackedFloat64Array = fast.get_beat_times()
	assert_eq(fast_times.size(), normal_times.size(), "the same beats")
	for i: int in BEAT_COUNT:
		assert_almost_eq(fast_times[i], normal_times[i] / 2.0, EPS, "beat %d comes twice as soon" % i)
	assert_almost_eq(fast.get_hold_seconds(), normal.get_hold_seconds() / 2.0, EPS, "the hold is half as long")
	assert_almost_eq(fast.get_last_breath_start(), normal.get_last_breath_start() / 2.0, EPS)
	assert_almost_eq(fast.get_phase_start(3), normal.get_phase_start(3) / 2.0, EPS)

func test_a_run_without_phases_has_only_the_last_breath() -> void:
	var run: TribulationRun = TribulationRun.new(TribulationData.new())
	assert_eq(run.get_beat_times().size(), 1, "just the last beat")
	assert_almost_eq(run.get_last_breath_start(), 1.7, EPS, "the 1.2 s lead-in and the 0.5 s gap")
	assert_null(run.phase_at(0.0), "there is no phase to name")
	assert_false(run.aura_rush_at(0.0), "nothing rushes before the last breath")
	assert_true(run.aura_rush_at(run.get_last_breath_start()), "and the last breath always does")

#-----------------------------------------------------------------------------
# PHASES AND SPHERES
#-----------------------------------------------------------------------------

func test_phase_at() -> void:
	var run: TribulationRun = _run()
	assert_eq(_phase_name(run, 0.0), "Steady breath", "the lead-in belongs to the first phase")
	assert_eq(_phase_name(run, 11.39), "Steady breath")
	assert_eq(_phase_name(run, 11.41), "Heartbeat")
	assert_eq(_phase_name(run, 23.9), "Echo", "Quickening's gap belongs to Echo")
	assert_eq(_phase_name(run, 24.2), "Quickening")
	assert_eq(_phase_name(run, 30.3), "Quickening")
	assert_null(run.phase_at(30.5), "the last breath is no phase")

func test_aura_rush_at() -> void:
	var run: TribulationRun = _run()
	assert_false(run.aura_rush_at(5.0), "Steady breath has no rush")
	assert_true(run.aura_rush_at(25.0), "Quickening rushes")
	assert_true(run.aura_rush_at(33.0), "the last breath always rushes")

func test_spheres_breathe() -> void:
	var run: TribulationRun = _run()
	assert_eq(run.spheres_at(0.5).size(), 0, "nothing breathes in the lead-in")

	var born: Dictionary = _only_sphere(run, 1.2)
	assert_almost_eq(born.get("ratio", -1.0), 0.42, EPS, "the first sphere starts at its smallest")
	assert_false(born.get("bright", true), "a sphere breathing in is faint")
	assert_false(born.get("echo", true), "and the first sphere is no echo")

	# 0.01 s into the 0.85 s out-breath: 1.88 - 1.46 * (0.01 / 0.85). At exactly
	# 2.05 s float rounding can leave the sphere breathing in.
	var shrinking: Dictionary = _only_sphere(run, 2.06)
	assert_almost_eq(shrinking.get("ratio", -1.0), 1.8628, EPS, "it has just begun to shrink from 1.88 R")
	assert_true(shrinking.get("bright", false), "a sphere breathing out is bright")

	var on_the_ring: Dictionary = _only_sphere(run, _beat_time(run, 0))
	assert_almost_eq(on_the_ring.get("ratio", -1.0), 1.0, EPS, "on the beat the sphere is on the ring")
	assert_true(on_the_ring.get("bright", false))

	var pair: Array[Dictionary] = run.spheres_at(18.9)
	assert_eq(pair.size(), 2, "Echo's two spheres breathe together")
	var echoes: int = 0
	for sphere: Dictionary in pair:
		if sphere["echo"]:
			echoes += 1
	assert_eq(echoes, 1, "one of them is the echo")

func test_last_breath_grows_past_the_ring() -> void:
	var run: TribulationRun = _run()
	var peak: Dictionary = _only_sphere(run, 30.47 + 1.8)
	assert_almost_eq(peak.get("ratio", -1.0), 2.54, EPS, "it grows to 2.54 R, well past the ring")

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## A press inside the good window hits the first beat: perfect right on it, good
## 0.10 s either side. The offset is the press minus the beat, negative when
## early, and a hit counts as its grade with no crack.
func test_press_inside_the_good_window_is_a_hit() -> void:
	var cases: Array[Dictionary] = [
		{"name": "right on the beat", "offset": 0.0, "result": Result.PERFECT},
		{"name": "0.10 s late", "offset": 0.10, "result": Result.GOOD},
		{"name": "0.10 s early", "offset": -0.10, "result": Result.GOOD},
	]
	for case: Dictionary in cases:
		var run: TribulationRun = _run()
		var res: Dictionary = run.press(_beat_time(run, 0) + case["offset"])
		var perfect: bool = case["result"] == Result.PERFECT
		assert_eq(res["result"], case["result"], case["name"])
		assert_almost_eq(res["offset"], case["offset"], EPS, "%s: the offset" % case["name"])
		assert_false(res["last"], "%s: the first beat is not the last" % case["name"])
		assert_eq(run.perfect_count, 1 if perfect else 0, "%s: perfect count" % case["name"])
		assert_eq(run.good_count, 0 if perfect else 1, "%s: good count" % case["name"])
		assert_eq(run.cracks, 0, "%s: no crack" % case["name"])

func test_early_press_is_a_miss() -> void:
	var run: TribulationRun = _run()
	var b0: float = _beat_time(run, 0)
	var res: Dictionary = run.press(b0 - 0.20)
	assert_eq(res["result"], Result.EARLY_MISS, "0.20 s early is past the good window but inside the early reach")
	assert_almost_eq(res["offset"], -0.20, EPS)
	assert_eq(run.cracks, 1)
	assert_eq(run.advance(b0 + 0.5).size(), 0, "the beat was judged by the early press: it is not missed again")
	assert_eq(run.cracks, 1)

## The edge of the good window is written once. A press exactly the good window after a
## beat, as a float (beat + window), is judged by the same subtraction that settles the beat
## as late: it is a hit, or the beat was already lost, and never an early miss with a positive
## offset, which the board would read as "Too early" for a late press. On the shipped beats
## beat + window rounds a hair past the window for some (0, 4 and 5). Each beat gets a run of
## its own that has hit the beats before it, so it is the beat under test that the press finds.
func test_a_press_at_the_edge_of_the_good_window_is_never_early_after_the_beat() -> void:
	var good_window: float = (load(FOUNDATION_TRIBULATION_PATH) as TribulationData).good_window
	var times: PackedFloat64Array = _run().get_beat_times()
	assert_eq(times.size(), BEAT_COUNT, "precondition: the shipped beats")
	for index: int in BEAT_COUNT:
		var run: TribulationRun = _run()
		if index > 0:
			_hit_through(run, index - 1)
		var res: Dictionary = run.press(times[index] + good_window)
		var early_after_the_beat: bool = res["result"] == Result.EARLY_MISS and res["offset"] > 0.0
		assert_false(early_after_the_beat, "beat %d: a press %s s after it is not an early miss (offset %s)" % [index, String.num(good_window, 17), String.num(res["offset"], 17)])

func test_press_far_from_any_beat_is_ignored() -> void:
	var run: TribulationRun = _run()
	var b0: float = _beat_time(run, 0)
	var res: Dictionary = run.press(b0 - 0.40)
	assert_eq(res["result"], Result.IGNORED, "0.40 s early is beyond the 0.30 s early reach")
	assert_eq(run.cracks, 0)
	assert_eq(run.press(b0)["result"], Result.PERFECT, "an ignored press leaves the beat to be pressed")

func test_unpressed_beat_is_a_late_miss() -> void:
	var run: TribulationRun = _run()
	var b0: float = _beat_time(run, 0)
	assert_eq(run.advance(b0 + 0.13).size(), 0, "0.13 s late is still inside the good window")
	assert_eq(run.cracks, 0)
	var events: Array[Dictionary] = run.advance(b0 + 0.15)
	assert_eq(events.size(), 1, "0.15 s late is past it")
	if events.size() == 1:
		assert_eq(events[0]["result"], Result.LATE_MISS)
		assert_false(events[0]["last"], "the first beat is not the last")
	assert_eq(run.cracks, 1)

func test_press_after_a_stall_counts_the_missed_beat_first() -> void:
	# Beats 16 and 17 are Echo's close pair, at 22.682 s and 23.002 s. The board
	# stalled from beat 15 until 22.90 s: beat 16 is long gone, and the press is
	# for beat 17.
	var run: TribulationRun = _run()
	_hit_through(run, 15)
	var res: Dictionary = run.press(22.90)
	assert_eq(res["result"], Result.GOOD, "the press lands on beat 17")
	assert_almost_eq(res["offset"], -0.102, EPS, "0.102 s before beat 17, not 0.218 s after beat 16")
	assert_eq(run.cracks, 1, "beat 16 was counted as the press was judged, not only when the next advance reports it")
	var events: Array[Dictionary] = run.advance(22.90)
	assert_eq(events.size(), 1, "beat 16 is missed, and the miss reaches the next advance")
	if events.size() == 1:
		assert_eq(events[0]["result"], Result.LATE_MISS)
		assert_false(events[0]["last"])
	assert_eq(run.cracks, 1)
	assert_eq(run.advance(22.90).size(), 0, "and only once")

func test_nearest_beat_in_echos_close_pair() -> void:
	var run: TribulationRun = _run()
	_hit_through(run, 15)
	var b16: float = _beat_time(run, 16)
	var b17: float = _beat_time(run, 17)
	var first: Dictionary = run.press(b16 + 0.06)
	assert_eq(first["result"], Result.PERFECT, "beat 17 is also in reach, but beat 16 is nearer")
	assert_almost_eq(first["offset"], 0.06, EPS)
	var second: Dictionary = run.press(b17 - 0.01)
	assert_eq(second["result"], Result.PERFECT, "beat 17 was left for this press")
	assert_eq(run.cracks, 0)
	assert_eq(run.perfect_count, 18, "beats 0 to 15, then these two")

func test_a_tie_goes_to_the_earlier_beat() -> void:
	# Two beats 0.25 s apart, at 2.5 s and 2.75 s, on numbers a double holds
	# exactly: spheres between 0 R and 2 R cross the ring halfway through their
	# 1 s out-breath, and the second starts 0.25 s after the first. A press at
	# 2.625 s is 0.125 s from both.
	var phase: TribulationPhaseData = TribulationPhaseData.new()
	phase.breath_periods = PackedFloat32Array([2.0])
	phase.echo_periods = PackedFloat32Array([2.0])
	phase.echo_offset = 0.25
	var data: TribulationData = TribulationData.new()
	data.lead_in = 1.0
	data.phases.append(phase)
	data.sphere_min_ratio = 0.0
	data.sphere_max_ratio = 2.0
	var run: TribulationRun = TribulationRun.new(data)
	var times: PackedFloat64Array = run.get_beat_times()
	assert_eq(times[0], 2.5, "the first sphere's beat")
	assert_eq(times[1], 2.75, "the second sphere's beat")

	var res: Dictionary = run.press(2.625)
	assert_eq(res["result"], Result.GOOD)
	assert_eq(res["offset"], 0.125, "it is the first beat, 0.125 s ago, that was pressed")
	assert_eq(run.press(2.75)["result"], Result.PERFECT, "the second beat is still there")

func test_the_windows_do_not_scale_with_tempo() -> void:
	var run: TribulationRun = _run(2.0)
	var b0: float = _beat_time(run, 0)
	assert_almost_eq(b0, 2.5623 / 2.0, EPS, "the beat comes twice as soon")
	assert_eq(run.press(b0 + 0.10)["result"], Result.GOOD, "0.10 s late is still good, as at tempo 1.0")
	var other: TribulationRun = _run(2.0)
	assert_eq(other.press(b0 + 0.05)["result"], Result.PERFECT, "0.05 s late is still perfect")

func test_mashing_fails() -> void:
	# Every beat's first press falls about 0.26 s early: past the good window but
	# inside the early reach, so the beat is lost with a crack. The presses
	# after it have no beat to judge.
	var run: TribulationRun = _run()
	var t: float = 0.0
	for i: int in range(1, 1000):
		t = 0.05 * i
		run.advance(t)
		run.press(t)
		if run.is_failed():
			break
	assert_true(run.is_failed(), "mashing fails the run")
	assert_eq(run.cracks, 4)
	assert_lt(t, _beat_time(run, 3), "and it does so before the fourth beat has come")

#-----------------------------------------------------------------------------
# THE HOLD
#-----------------------------------------------------------------------------

func test_hitting_the_last_beat_starts_the_hold() -> void:
	var run: TribulationRun = _run()
	_hit_through(run, 23)
	assert_false(run.is_holding(), "no hold before the last beat")
	var b24: float = _beat_time(run, 24)
	run.advance(b24)
	var res: Dictionary = run.press(b24)
	assert_eq(res["result"], Result.PERFECT)
	assert_true(res["last"], "it is the last beat")
	assert_true(run.is_holding())
	assert_false(run.is_finished(run.get_duration() + 10.0), "a run still holding is not finished")

func test_an_early_press_on_the_last_beat_starts_no_hold() -> void:
	var run: TribulationRun = _run()
	_hit_through(run, 23)
	var b24: float = _beat_time(run, 24)
	var res: Dictionary = run.press(b24 - 0.20)
	assert_eq(res["result"], Result.EARLY_MISS)
	assert_true(res["last"])
	assert_false(run.is_holding(), "only a hit starts the hold")
	assert_eq(run.cracks, 1)
	assert_eq(run.advance(b24 + 0.5).size(), 0, "the last beat is judged: it is not missed again")

func test_early_release_cracks() -> void:
	var run: TribulationRun = _holding_run()
	var res: Dictionary = run.release(_hold_end(run) - 0.10)
	assert_eq(res["result"], Result.RELEASED_EARLY, "0.10 s before the sphere reaches the core")
	assert_true(res["last"])
	assert_eq(run.cracks, 1)
	assert_false(run.is_holding(), "letting go ends the hold")

func test_release_within_tolerance_is_held() -> void:
	var run: TribulationRun = _holding_run()
	var res: Dictionary = run.release(_hold_end(run) - 0.04)
	assert_eq(res["result"], Result.HELD, "0.04 s early is inside the 0.05 s release tolerance")
	assert_true(res["last"])
	assert_eq(run.cracks, 0)
	assert_false(run.is_holding())

func test_holding_to_the_end_is_held() -> void:
	var run: TribulationRun = _holding_run()
	var events: Array[Dictionary] = run.advance(_hold_end(run) + 0.01)
	assert_eq(events.size(), 1, "the hold ends by itself")
	if events.size() == 1:
		assert_eq(events[0]["result"], Result.HELD)
		assert_true(events[0]["last"])
	assert_false(run.is_holding())
	assert_eq(run.release(_hold_end(run) + 0.02)["result"], Result.IGNORED, "a release after the hold has ended is nothing")
	assert_eq(run.cracks, 0)

func test_hold_progress() -> void:
	var run: TribulationRun = _run()
	var b24: float = _beat_time(run, 24)
	var halfway: float = b24 + run.get_hold_seconds() / 2.0
	assert_eq(run.hold_progress(halfway), 0.0, "0 before the hold has begun")
	_hit_through(run, 24)
	assert_almost_eq(run.hold_progress(halfway), 0.5, EPS, "half-way through the hold")
	assert_almost_eq(run.hold_progress(b24), 0.0, EPS, "0 as the hold begins")
	assert_almost_eq(run.hold_progress(b24 + run.get_hold_seconds() + 1.0), 1.0, EPS, "never more than 1")
	run.release(halfway)
	assert_eq(run.hold_progress(halfway), 0.0, "0 again once the hold is let go")

func test_a_press_during_the_hold_is_ignored() -> void:
	# A held key repeats; the board filters those out, and the judge would not
	# count them either: there is no beat left to press.
	var run: TribulationRun = _holding_run()
	var res: Dictionary = run.press(_beat_time(run, 24) + 0.5)
	assert_eq(res["result"], Result.IGNORED)
	assert_true(run.is_holding(), "the hold goes on")
	assert_eq(run.cracks, 0)

func test_release_without_a_hold_is_ignored() -> void:
	var run: TribulationRun = _run()
	var res: Dictionary = run.release(5.0)
	assert_eq(res["result"], Result.IGNORED, "there is nothing to let go of")
	assert_eq(run.cracks, 0)
	assert_eq(run.press(_beat_time(run, 0))["result"], Result.PERFECT, "and the stray release took nothing from the trial")

func test_missing_the_last_beat_starts_no_hold() -> void:
	var run: TribulationRun = _run()
	_hit_through(run, 23)
	var events: Array[Dictionary] = run.advance(_beat_time(run, 24) + 0.2)
	assert_eq(events.size(), 1)
	if events.size() == 1:
		assert_eq(events[0]["result"], Result.LATE_MISS)
		assert_true(events[0]["last"], "it was the last beat")
	assert_false(run.is_holding())
	assert_eq(run.cracks, 1)

#-----------------------------------------------------------------------------
# THE END
#-----------------------------------------------------------------------------

func test_fourth_crack_fails_at_once() -> void:
	var run: TribulationRun = _run()
	var b3: float = _beat_time(run, 3)
	var events: Array[Dictionary] = run.advance(b3 + 0.15)
	assert_eq(events.size(), 4, "beats 0 to 3 are all missed")
	for event: Dictionary in events:
		assert_eq(event["result"], Result.LATE_MISS)
	assert_true(run.is_failed(), "the fourth crack fails the run")
	assert_eq(run.cracks, 4)
	assert_eq(run.press(b3 + 0.2)["result"], Result.IGNORED, "nothing is judged after the failure")
	assert_eq(run.press(_beat_time(run, 4))["result"], Result.IGNORED, "not even a press right on the next beat")
	assert_eq(run.perfect_count + run.good_count, 0, "which scores nothing")
	assert_eq(run.advance(_beat_time(run, 5) + 0.15).size(), 0, "nor the beats that pass later")
	assert_eq(run.cracks, 4)
	assert_false(run.is_finished(run.get_duration() + 1.0), "a failed run is never finished")

func test_a_press_that_finds_the_run_failed_by_late_beats_keeps_their_events() -> void:
	# After a stall the press resolves the missed beats first. Four of them fail
	# the run, and the press is nothing, but the misses still reach the board.
	var run: TribulationRun = _run()
	var b3: float = _beat_time(run, 3)
	var res: Dictionary = run.press(b3 + 0.15)
	assert_eq(res["result"], Result.IGNORED)
	assert_true(run.is_failed())
	assert_eq(run.cracks, 4)
	assert_eq(run.perfect_count + run.good_count, 0, "and no beat was hit")
	assert_eq(run.advance(b3 + 0.15).size(), 4, "the four misses come with the next advance")
	assert_eq(run.advance(b3 + 0.2).size(), 0, "and only once")

func test_three_cracks_do_not_fail() -> void:
	var run: TribulationRun = _run()
	var events: Array[Dictionary] = run.advance(_beat_time(run, 2) + 0.15)
	assert_eq(events.size(), 3)
	assert_eq(run.cracks, 3)
	assert_false(run.is_failed())

func test_clean_run_passes_at_the_end() -> void:
	var run: TribulationRun = _run_missing(0)
	var duration: float = run.get_duration()
	assert_false(run.is_failed())
	assert_false(run.is_holding())
	assert_false(run.is_finished(duration - 0.01), "the end pause is still playing")
	assert_true(run.is_finished(duration), "the trial is over")
	assert_eq(run.grade(), "Flawless")
	assert_eq(run.perfect_count, BEAT_COUNT, "every beat was pressed perfectly")

func test_grades() -> void:
	assert_eq(_run_missing(0).grade(), "Flawless", "no cracks")
	var one: TribulationRun = _run_missing(1)
	assert_eq(one.grade(), "Clean", "one crack")
	assert_true(one.is_finished(one.get_duration()), "a run with cracks passes if it does not fail")
	assert_eq(_run_missing(2).grade(), "Scraped through", "two cracks")
	assert_eq(_run_missing(3).grade(), "Scraped through", "three cracks")
	var failed: TribulationRun = _run_missing(4)
	assert_eq(failed.grade(), "Failed", "four cracks")
	assert_false(failed.is_finished(failed.get_duration()))

func test_progress() -> void:
	var run: TribulationRun = _run()
	var duration: float = run.get_duration()
	assert_eq(run.progress(0.0), 0.0)
	assert_almost_eq(run.progress(duration / 2.0), 0.5, EPS, "half-way at half the duration")
	assert_eq(run.progress(duration + 5.0), 1.0, "never more than 1")
	assert_eq(run.progress(-1.0), 0.0, "nor less than 0")
