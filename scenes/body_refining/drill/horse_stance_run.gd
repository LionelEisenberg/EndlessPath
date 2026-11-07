class_name HorseStanceRun
extends DrillRun

## HorseStanceRun
## The judge of one set of Horse Stance (DrillRun's contract): hold and the stance
## gauge's needle sinks deeper, let go and it rises, and keep it inside a brass arc
## that drifts along the gauge.
##
## The needle's depth runs from 0 (standing) to 1 (the deepest stance). It moves at
## one speed each way, the whole gauge in SINK_USEC while held and RISE_USEC once let
## go, and stops at both ends: it never drops. The arc covers BAND_HEIGHT of the
## gauge, and its centre follows the path the run was made with: straight between
## its points, held after the last (band_path() makes one for a set). The needle is
## inside while it is within half the arc of its centre. Each rep is judged at its
## slot's end by the share of the slot the needle spent inside; a MISS below
## DrillRules' OK share is TOO_DEEP or TOO_SHALLOW, the side it spent longer on.
##
## The times are exact: the needle and the arc move in straight lines between
## their turns, so the run steps from one turn to the next (a slot's end, a point of
## the arc's path, the needle reaching an end, a press or a release) and adds up
## each step's time inside, too deep and too shallow. After the last rep the needle
## rises whatever the press, and the set ends once it stands; presses after the last
## rep sink nothing.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long the needle takes over the whole gauge, sinking while held and rising
## once let go.
const SINK_USEC: int = 2_000_000
const RISE_USEC: int = 2_000_000
## The arc's width, a share of the gauge: a quarter.
const BAND_HEIGHT: float = 0.24
## Where a set's arc starts (shallow, near the standing needle), and the arc's
## centre held between BAND_LOW and BAND_HIGH so all of it stays on the gauge.
const BAND_START: float = 0.2
const BAND_LOW: float = 0.12
const BAND_HIGH: float = 0.88
## How long the arc drifts between turns, and how fast, in gauge a second.
const TURN_MIN_USEC: int = 800_000
const TURN_MAX_USEC: int = 1_600_000
const SPEED_MIN: float = 0.1
const SPEED_MAX: float = 0.275

## How often Auto looks at the needle and the arc: it sinks while the needle is
## shallower than the arc's centre and rises while deeper, deciding only on this
## grid, so its play never depends on when frames fall.
const AUTO_STEP_USEC: int = 50_000

## Later than any time a set reaches.
const _NEVER: int = 9_223_372_036_854_775_807

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The arc's path: its centre at each time, straight between.
var _band_times: PackedInt64Array = PackedInt64Array()
var _band_centres: PackedFloat64Array = PackedFloat64Array()
## Whether the needle is sinking, and where it stood when it last turned.
var _held: bool = false
var _turn_usec: int = 0
var _turn_depth: float = 0.0
## How far the set has been judged, and the rep in play's time inside, too deep
## and too shallow so far.
var _settled_usec: int = 0
var _inside_usec: float = 0.0
var _deep_usec: float = 0.0
var _shallow_usec: float = 0.0
var _end_usec: int = -1
## The last step of the Auto grid Auto decided at.
var _auto_usec: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and reps, and takes the arc's path: its centre (0
## to 1 of the gauge) at each time (usec).
func _init(drill: DrillData, band_times: PackedInt64Array, band_centres: PackedFloat64Array) -> void:
	super(drill)
	_band_times = band_times
	_band_centres = band_centres

## An arc's path for a set `set_usec` long, the same for the same seed: from
## BAND_START, a turn every TURN_MIN_USEC to TURN_MAX_USEC at SPEED_MIN to SPEED_MAX,
## deeper or shallower at random where the gauge has room, and on past the set's
## end. Returns [times as a PackedInt64Array, centres as a PackedFloat64Array].
static func band_path(rng_seed: int, set_usec: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var times := PackedInt64Array([0])
	var centres := PackedFloat64Array([BAND_START])
	var t: int = 0
	var centre: float = BAND_START
	while t < set_usec:
		var duration: int = rng.randi_range(TURN_MIN_USEC, TURN_MAX_USEC)
		var distance: float = rng.randf_range(SPEED_MIN, SPEED_MAX) * duration / 1_000_000.0
		var room_up: float = BAND_HIGH - centre
		var room_down: float = centre - BAND_LOW
		var up: bool
		if distance <= room_up and distance <= room_down:
			up = rng.randf() < 0.5
		elif distance <= room_up or distance <= room_down:
			up = distance <= room_up
		else:
			# No room either way: as far as the gauge allows, toward the room. The
			# gauge is wide enough that this is still faster than SPEED_MIN.
			up = room_up >= room_down
			distance = maxf(room_up, room_down)
		centre = clampf(centre + (distance if up else -distance), BAND_LOW, BAND_HIGH)
		t += duration
		times.append(t)
		centres.append(centre)
	return [times, centres]

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges what the time up to `t` decided, then sinks the needle from there.
## Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if not _held and _judgements.size() < _reps:
		_turn(t_usec, true)
	return judged

## Judges what the time up to `t` decided, then lets the needle rise from there.
## Returns every rep judged, in order.
func release(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if _held:
		_turn(t_usec, false)
	return judged

## Judges every rep whose slot ended by `t`. Returns them, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Plays the set as Auto up to `t`: at each step of the AUTO_STEP_USEC grid, sinks
## the needle while it is shallower than the arc's centre and lets it rise while
## deeper. Returns every rep judged, in order.
func play_auto(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _auto_usec + AUTO_STEP_USEC <= t_usec and _judgements.size() < _reps:
		_auto_usec += AUTO_STEP_USEC
		judged.append_array(_settle(_auto_usec))
		var shallow: bool = marker_at(_auto_usec) < band_centre_at(_auto_usec)
		if shallow and not _held:
			judged.append_array(press(_auto_usec))
		elif not shallow and _held:
			judged.append_array(release(_auto_usec))
	judged.append_array(advance(t_usec))
	return judged

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## The needle's depth at `t`, 0 (standing) to 1 (the deepest stance). Ask it for a
## time no earlier than the last call's.
func marker_at(t_usec: int) -> float:
	var moved: float = float(t_usec - _turn_usec)
	if _held:
		return minf(1.0, _turn_depth + moved / SINK_USEC)
	return maxf(0.0, _turn_depth - moved / RISE_USEC)

## The arc's centre at `t`, 0 to 1 of the gauge.
func band_centre_at(t_usec: int) -> float:
	var count: int = _band_times.size()
	if count == 0:
		return BAND_START
	if t_usec <= _band_times[0]:
		return _band_centres[0]
	for index: int in range(1, count):
		if t_usec <= _band_times[index]:
			var from: int = _band_times[index - 1]
			var weight: float = float(t_usec - from) / float(_band_times[index] - from)
			return lerpf(_band_centres[index - 1], _band_centres[index], weight)
	return _band_centres[count - 1]

## Whether the needle is inside the arc at `t`. Ask it for a time no earlier than
## the last call's.
func is_inside_at(t_usec: int) -> bool:
	return absf(marker_at(t_usec) - band_centre_at(t_usec)) <= BAND_HEIGHT / 2.0

## When the set ends: once its last rep is judged and the needle stands again. -1
## until the last rep is judged.
func get_end_usec() -> int:
	return _end_usec

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Adds up the times up to `t`, step by step between turns, judging each slot that
## ends on the way.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _settled_usec < t and _judgements.size() < _reps:
		var slot_end: int = (_judgements.size() + 1) * _rep_usec
		var step_end: int = mini(mini(t, slot_end), mini(_next_band_point(_settled_usec), _next_stop(_settled_usec)))
		var split: Vector3 = _split_between(_settled_usec, step_end)
		_shallow_usec += split.x
		_inside_usec += split.y
		_deep_usec += split.z
		_settled_usec = step_end
		if step_end == slot_end:
			judged.append(_judge(slot_end))
	return judged

## Turns the needle at `t`: sinking when `held`, rising otherwise.
func _turn(t: int, held: bool) -> void:
	_turn_depth = marker_at(t)
	_turn_usec = t
	_held = held

## The first point of the arc's path after `t`.
func _next_band_point(t: int) -> int:
	for time: int in _band_times:
		if time > t:
			return time
	return _NEVER

## When the needle reaches the deepest end (sinking) or stands (rising) after `t`.
func _next_stop(t: int) -> int:
	var stop: int
	if _held:
		stop = _turn_usec + ceili((1.0 - _turn_depth) * SINK_USEC)
	else:
		stop = _turn_usec + ceili(_turn_depth * RISE_USEC)
	return stop if stop > t else _NEVER

## How long the needle was too shallow, inside and too deep from `from` to `to`, a
## step on which it and the arc move in straight lines, as (shallow, inside, deep):
## the parts of the step where their gap is under, within and over half the arc.
func _split_between(from: int, to: int) -> Vector3:
	var half: float = BAND_HEIGHT / 2.0
	var gap_from: float = marker_at(from) - band_centre_at(from)
	var gap_to: float = marker_at(to) - band_centre_at(to)
	var span: float = float(to - from)
	if is_equal_approx(gap_from, gap_to):
		if gap_from > half:
			return Vector3(0.0, 0.0, span)
		if gap_from < -half:
			return Vector3(span, 0.0, 0.0)
		return Vector3(0.0, span, 0.0)
	# Where along the step (0 to 1) the gap crosses each edge of the arc.
	var at_low: float = clampf((-half - gap_from) / (gap_to - gap_from), 0.0, 1.0)
	var at_high: float = clampf((half - gap_from) / (gap_to - gap_from), 0.0, 1.0)
	var inside: float = absf(at_high - at_low)
	var deep: float
	var shallow: float
	if gap_to > gap_from:
		deep = 1.0 - at_high
		shallow = at_low
	else:
		deep = at_high
		shallow = 1.0 - at_low
	return Vector3(shallow, inside, deep) * span

## Judges the rep whose slot ended at `at` by its time inside. After the last rep
## the needle rises, and the set ends once it stands.
func _judge(at: int) -> Judgement:
	var tier: DrillRules.Tier = DrillRules.judge(_inside_usec / _rep_usec)
	var miss: Miss = Miss.NONE
	if tier == DrillRules.Tier.MISS:
		miss = Miss.TOO_DEEP if _deep_usec >= _shallow_usec else Miss.TOO_SHALLOW
	_inside_usec = 0.0
	_deep_usec = 0.0
	_shallow_usec = 0.0
	var depth: float = marker_at(at)
	var judgement: Judgement = _record(tier, miss, depth, at)
	if _judgements.size() >= _reps:
		_turn(at, false)
		_end_usec = at + ceili(depth * RISE_USEC)
	return judgement
