class_name TribulationRun
extends RefCounted

## TribulationRun
## The judge of one Tribulation, the breathing trial. It builds the trial's
## schedule from a TribulationData, then judges presses, releases and the passing
## of time against it. Pure logic with no nodes: the board calls advance() every
## frame and press() and release() on input, and the tests drive it with exact
## times.
##
## Every time is on the trial's own clock, in seconds from its start, with the
## tempo already applied. A breath is one sphere growing from the core and
## shrinking back. The instant the shrinking sphere crosses the brass ring is its
## beat, and the player presses on it. The last breath's beat is also a hold: the
## player keeps the key down while the sphere pours into the core.
##
## A press within the good window of a beat is a hit, perfect within the perfect
## window. A press earlier than that, but within the early reach of a beat, is an
## early miss and loses the beat. A beat nobody pressed within the good window is a
## late miss. Misses, and a hold let go too soon, are cracks. The crack that brings
## cracks to cracks_to_fail fails the run at once, and nothing more is judged. The
## windows are real seconds: they do not scale with the tempo.
##
## What is judged comes back as dictionaries. A press: {result, offset, last},
## where offset is the press minus the beat (negative when early) and last says
## whether it was the last beat. A release: {result, last: true}. Each event
## advance() returns: {result: LATE_MISS or HELD, last}.
##
## Results never depend on when frames fall. press() first settles every beat that
## is already late, and keeps those misses for the next advance().

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## What one judging came to.
enum Result {
	## A press within the perfect window of a beat.
	PERFECT,
	## A press within the good window of a beat, but not perfect.
	GOOD,
	## A press before a beat, past the good window but inside the early reach: a
	## crack, and the beat is lost.
	EARLY_MISS,
	## A beat nobody pressed in time: a crack.
	LATE_MISS,
	## The last breath's hold lasted until the sphere reached the core, or to
	## within the release tolerance of it.
	HELD,
	## The hold was let go too soon: a crack.
	RELEASED_EARLY,
	## A press or release that counted for nothing.
	IGNORED,
}

## One sphere's breath: it grows from min_ratio to max_ratio over in_seconds,
## then shrinks back over out_seconds. Ratios are multiples of R, the radius of
## the brass ring.
class Breath:
	## When the breath begins.
	var start: float = 0.0

	## Seconds spent growing.
	var in_seconds: float = 0.0

	## Seconds spent shrinking.
	var out_seconds: float = 0.0

	## The ratio the sphere starts and ends at.
	var min_ratio: float = 0.0

	## The ratio the sphere grows to.
	var max_ratio: float = 0.0

	## Whether this is the second sphere of an Echo phase.
	var echo: bool = false

	func _init(
		p_start: float,
		p_in_seconds: float,
		p_out_seconds: float,
		p_min_ratio: float,
		p_max_ratio: float,
		p_echo: bool,
	) -> void:
		start = p_start
		in_seconds = p_in_seconds
		out_seconds = p_out_seconds
		min_ratio = p_min_ratio
		max_ratio = p_max_ratio
		echo = p_echo

	## When the sphere has shrunk back to min_ratio.
	func get_end() -> float:
		return start + in_seconds + out_seconds

	## How far through its out-breath, 0 to 1, the sphere is when it crosses the
	## ring (ratio 1.0) on its way back down.
	func get_cross() -> float:
		return (max_ratio - 1.0) / (max_ratio - min_ratio)

	## Whether the sphere is breathing out at `t`: shrinking, and bright.
	func is_bright_at(t: float) -> bool:
		return t - start >= in_seconds

	## The sphere's ratio at `t`: min_ratio to max_ratio over the in-breath, then
	## back over the out-breath.
	func ratio_at(t: float) -> float:
		var elapsed: float = t - start
		var span: float = max_ratio - min_ratio
		if elapsed < in_seconds:
			return min_ratio + span * (elapsed / in_seconds)
		return max_ratio - span * ((elapsed - in_seconds) / out_seconds)

## One beat to press: the instant a breath's shrinking sphere crosses the ring.
class Beat:
	## When the sphere crosses the ring.
	var time: float = 0.0

	## Seconds from the ring to the core, which the player keeps the key down for.
	## 0.0 except on the last beat.
	var hold: float = 0.0

	## Whether this is the last breath's beat, a hit on which starts the hold.
	var last: bool = false

	## Whether the beat has been judged: pressed, or missed.
	var judged: bool = false

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## How many cracks the run has taken.
var cracks: int = 0

## How many beats were pressed perfectly.
var perfect_count: int = 0

## How many beats were pressed well, but not perfectly.
var good_count: int = 0

## The Tribulation being judged.
var _data: TribulationData

## Every sphere's breath, in the order they were laid out.
var _breaths: Array[Breath] = []

## Every beat, sorted by time.
var _beats: Array[Beat] = []

## The time of each of _beats.
var _beat_times: PackedFloat64Array = PackedFloat64Array()

## When each of the data's phases starts.
var _phase_starts: PackedFloat64Array = PackedFloat64Array()

## When the last breath starts.
var _last_breath_start: float = 0.0

## When the trial ends.
var _duration: float = 0.0

## The last breath's beat, the one that is held.
var _last_beat: Beat = null

## Whether the run has taken cracks_to_fail cracks.
var _failed: bool = false

## The last beat while the player holds it; null when nothing is held.
var _hold_beat: Beat = null

## Late misses press() settled, which the next advance() returns.
var _pending: Array[Dictionary] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Builds the schedule of `data`: its tempo is read here, once.
func _init(data: TribulationData) -> void:
	_data = data
	_build_schedule()

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges a press at `t`. Beats already late are settled first, and their misses
## come with the next advance(). The press then takes the nearest beat inside its
## reach (the earlier one on a tie): PERFECT or GOOD inside the windows, otherwise
## an EARLY_MISS, which cracks. A hit on the last beat starts the hold. With no beat
## in reach, or once the run has failed, the press is IGNORED.
## Returns {result, offset, last}; the offset is `t` minus the beat's time.
func press(t: float) -> Dictionary:
	# A run that failed earlier settles nothing here, so one check covers it too.
	_pending.append_array(_settle_late_beats(t))
	if _failed:
		return _ignored_press()
	var beat: Beat = _nearest_beat_in_reach(t)
	if beat == null:
		return _ignored_press()

	beat.judged = true
	var offset: float = t - beat.time
	var result: Result
	if absf(offset) <= _data.perfect_window:
		result = Result.PERFECT
		perfect_count += 1
	elif absf(offset) <= _data.good_window:
		result = Result.GOOD
		good_count += 1
	else:
		result = Result.EARLY_MISS
		_add_crack()
	if beat.last and result != Result.EARLY_MISS:
		_hold_beat = beat
	return {"result": result, "offset": offset, "last": beat.last}

## Judges the key coming up at `t`. It ends the hold: RELEASED_EARLY, which
## cracks, when it comes more than the release tolerance before the sphere
## reaches the core, otherwise HELD. IGNORED when nothing is held.
## Returns {result, last: true}.
func release(t: float) -> Dictionary:
	if _hold_beat == null:
		return {"result": Result.IGNORED, "last": true}
	var hold_end: float = _hold_beat.time + _hold_beat.hold
	_hold_beat = null
	if t < hold_end - _data.release_tolerance:
		_add_crack()
		return {"result": Result.RELEASED_EARLY, "last": true}
	return {"result": Result.HELD, "last": true}

## Judges the passing of time up to `t`. Returns the events since the last call, in
## order: the late misses press() settled, then a LATE_MISS for each unjudged beat
## more than the good window behind `t`, then a HELD when the hold has run to the
## core. Each is {result, last}. Once the run has failed it judges nothing more,
## and returns only what press() had settled, once.
func advance(t: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = _pending
	_pending = []
	events.append_array(_settle_late_beats(t))
	if _hold_beat != null and t >= _hold_beat.time + _hold_beat.hold:
		_hold_beat = null
		events.append({"result": Result.HELD, "last": true})
	return events

## Whether the run has failed: it took cracks_to_fail cracks.
func is_failed() -> bool:
	return _failed

## Whether the player is holding the last beat.
func is_holding() -> bool:
	return _hold_beat != null

## Whether the trial has been passed by `t`: not failed, not holding, and `t` has
## reached the end of the schedule.
func is_finished(t: float) -> bool:
	return not _failed and _hold_beat == null and t >= _duration

## The trial's grade: "Failed" when the run failed, otherwise "Flawless" for no
## cracks, "Clean" for one and "Scraped through" for more.
func grade() -> String:
	if _failed:
		return "Failed"
	if cracks == 0:
		return "Flawless"
	if cracks == 1:
		return "Clean"
	return "Scraped through"

#-----------------------------------------------------------------------------
# SCHEDULE
#-----------------------------------------------------------------------------

## Returns the time of every beat, in order.
func get_beat_times() -> PackedFloat64Array:
	return _beat_times.duplicate()

## Returns how long the last beat's hold lasts: the seconds from the sphere
## crossing the ring to reaching the core.
func get_hold_seconds() -> float:
	return _last_beat.hold

## Returns when the trial ends: the last breath's end and the end pause after it.
func get_duration() -> float:
	return _duration

## Returns when phase `index` of the data starts.
func get_phase_start(index: int) -> float:
	return _phase_starts[index]

## Returns when the last breath starts.
func get_last_breath_start() -> float:
	return _last_breath_start

#-----------------------------------------------------------------------------
# DRAWING QUERIES
#-----------------------------------------------------------------------------

## Returns the phase playing at `t`: the last one that has started. The lead-in
## belongs to the first phase, and a gap to the phase before it. Returns null
## from the last breath's start, which is no phase, and when the data has none.
func phase_at(t: float) -> TribulationPhaseData:
	if _phase_starts.is_empty() or t >= _last_breath_start:
		return null
	var index: int = 0
	for i: int in range(1, _phase_starts.size()):
		if _phase_starts[i] > t:
			break
		index = i
	return _data.phases[index]

## Returns whether Madra streams into the core at `t`: the phase's aura_rush, and
## always during the last breath.
func aura_rush_at(t: float) -> bool:
	if t >= _last_breath_start:
		return true
	var phase: TribulationPhaseData = phase_at(t)
	return phase != null and phase.aura_rush

## Returns a dictionary {ratio, bright, echo} for every sphere breathing at `t`:
## its radius as a multiple of R, whether it is shrinking (bright) rather than
## growing (faint), and whether it is an Echo's second sphere.
func spheres_at(t: float) -> Array[Dictionary]:
	var spheres: Array[Dictionary] = []
	for breath: Breath in _breaths:
		if t < breath.start or t >= breath.get_end():
			continue
		spheres.append({"ratio": breath.ratio_at(t), "bright": breath.is_bright_at(t), "echo": breath.echo})
	return spheres

## Returns how far the hold has run, 0 to 1, from the sphere crossing the ring to
## reaching the core. 0 when nothing is held.
func hold_progress(t: float) -> float:
	if _hold_beat == null:
		return 0.0
	return clampf((t - _hold_beat.time) / _hold_beat.hold, 0.0, 1.0)

## Returns how far through the trial `t` is, 0 to 1.
func progress(t: float) -> float:
	return clampf(t / _duration, 0.0, 1.0)

#-----------------------------------------------------------------------------
# SCHEDULE BUILDING
#-----------------------------------------------------------------------------

## Lays out the phases and the last breath, then sorts the beats by time:
## Echo's two spheres interleave. Beats at the very same time are
## interchangeable, so the sort need not be stable.
func _build_schedule() -> void:
	var k: float = 1.0 / _data.tempo
	var t: float = _data.lead_in * k
	for phase: TribulationPhaseData in _data.phases:
		t += phase.gap_before * k
		_phase_starts.append(t)
		var first_end: float = _add_phase_breaths(phase.breath_periods, t, k, false)
		var echo_end: float = _add_phase_breaths(phase.echo_periods, t + phase.echo_offset * k, k, true)
		t = first_end
		if not phase.echo_periods.is_empty():
			t = maxf(first_end, echo_end)

	_last_breath_start = t + _data.last_breath_gap * k
	var last_breath := Breath.new(
			_last_breath_start,
			_data.last_breath_in * k,
			_data.last_breath_out * k,
			_data.sphere_min_ratio,
			_data.last_breath_max_ratio,
			false)
	_last_beat = _add_breath(last_breath)
	_last_beat.last = true
	_last_beat.hold = last_breath.out_seconds * (1.0 - last_breath.get_cross())
	_duration = _last_breath_start + (_data.last_breath_in + _data.last_breath_out + _data.end_pause) * k

	_beats.sort_custom(func(a: Beat, b: Beat) -> bool: return a.time < b.time)
	for beat: Beat in _beats:
		_beat_times.append(beat.time)

## Adds one breath for each of `periods`, back to back from `start`: a period
## (divided by the tempo's `k`) is half spent growing and half shrinking. Returns
## when the last one ends.
func _add_phase_breaths(periods: PackedFloat32Array, start: float, k: float, echo: bool) -> float:
	var at: float = start
	for period: float in periods:
		var half: float = period * k / 2.0
		_add_breath(Breath.new(at, half, half, _data.sphere_min_ratio, _data.sphere_max_ratio, echo))
		at += period * k
	return at

## Adds `breath` and the beat at which its sphere crosses the ring. Returns the beat.
func _add_breath(breath: Breath) -> Beat:
	_breaths.append(breath)
	var beat := Beat.new()
	beat.time = breath.start + breath.in_seconds + breath.out_seconds * breath.get_cross()
	_beats.append(beat)
	return beat

#-----------------------------------------------------------------------------
# JUDGING HELPERS
#-----------------------------------------------------------------------------

## Judges every unjudged beat that `t` has left more than the good window behind
## as a LATE_MISS, in beat order, and returns those events. It stops at the
## crack that fails the run. "Behind" is `t - beat.time`, the very subtraction
## press() classifies a press with, so at the window's edge a press is a hit or
## the beat is already lost, never an early miss for a press after the beat.
func _settle_late_beats(t: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for beat: Beat in _beats:
		if _failed:
			break
		if beat.judged:
			continue
		if t - beat.time <= _data.good_window:
			break
		beat.judged = true
		_add_crack()
		events.append({"result": Result.LATE_MISS, "last": beat.last})
	return events

## Returns the unjudged beat nearest to `t` among those at most the early reach
## ahead of it, the earlier one on a tie. Null when there is none. The late beats
## are settled before this runs, so none left is more than the good window behind
## `t`.
func _nearest_beat_in_reach(t: float) -> Beat:
	var reach: float = _data.get_early_reach()
	var nearest: Beat = null
	for beat: Beat in _beats:
		if beat.judged:
			continue
		if beat.time - t > reach:
			break
		if nearest == null or absf(t - beat.time) < absf(t - nearest.time):
			nearest = beat
	return nearest

## Counts a crack, and fails the run on the one that reaches cracks_to_fail.
func _add_crack() -> void:
	cracks += 1
	if cracks >= _data.cracks_to_fail:
		_failed = true

## What a press that counted for nothing returns.
func _ignored_press() -> Dictionary:
	return {"result": Result.IGNORED, "offset": 0.0, "last": false}
