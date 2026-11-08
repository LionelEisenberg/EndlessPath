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
## gauge; the needle is inside while it is within half the arc of its centre.
##
## Each rep is one stance (#143). A press made since the last judgement, with the
## needle standing, starts a rep: the player sinks, and the rep's arc drifts from
## BAND_START, around the standing needle, along that rep's path (band_paths()). The
## rep lands the moment its needle has spent HOLD_USEC inside, judged by the share of
## the rep it spent inside (HOLD_USEC over the rep's time, from its press). It is a
## MISS the moment its time outside reaches OUT_LIMIT_USEC, past which it could no
## longer reach OK: TOO_DEEP or TOO_SHALLOW, the side it spent longer on. Then the
## player stands: the needle rises whatever the press, and the arc slides back to
## BAND_START, arriving as the needle stands. A press made while the needle rises
## sinks the player once it stands; a press still held from the rep sinks nothing.
## Between reps nothing moves, and nothing is judged however long the player waits.
##
## The times are exact: the needle and the arc move in straight lines between their
## turns, so the run steps from one turn to the next (a point of the arc's path, the
## needle reaching an end, a press or a release) and, inside each step, finds where
## the time inside or outside reaches its mark. The set ends once its last rep is
## judged and the needle stands; presses after the last rep sink nothing.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long the needle takes over the whole gauge, sinking while held and rising
## once let go.
const SINK_USEC: int = 2_000_000
const RISE_USEC: int = 2_000_000
## The arc's width, a share of the gauge: a quarter.
const BAND_HEIGHT: float = 0.24
## Where each rep's arc starts and rests between reps: at the top, its near edge on
## the standing needle. The arc's centre stays between BAND_LOW and BAND_HIGH, so
## all of it stays on the gauge.
const BAND_START: float = 0.12
const BAND_LOW: float = 0.12
const BAND_HIGH: float = 0.88
## How long the arc drifts between turns, and how fast, in gauge a second.
const TURN_MIN_USEC: int = 800_000
const TURN_MAX_USEC: int = 1_600_000
const SPEED_MIN: float = 0.1
const SPEED_MAX: float = 0.275
## How long the needle must spend in the arc to land a rep.
const HOLD_USEC: int = 2_000_000
## How long a rep may spend out of the arc: past it the share, HOLD_USEC over the
## rep's time, could no longer reach DrillRules.OK_SHARE. HOLD_USEC x (1 / 0.3 - 1),
## rounded up.
const OUT_LIMIT_USEC: int = 4_666_667
## How long each rep's arc path runs: past the longest a rep can last.
const PATH_USEC: int = 7_000_000

## How often Auto looks at the needle and the arc: it sinks while the needle is
## shallower than the arc's centre and rises while deeper, deciding only on this
## grid, so its play never depends on when frames fall.
const AUTO_STEP_USEC: int = 50_000

## Later than any time a set reaches.
const _NEVER: int = 9_223_372_036_854_775_807

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Each rep's arc path, [times, centres], times from the rep's start.
var _paths: Array = []
## Whether the press is down, and since when.
var _held: bool = false
var _held_since: int = 0
## Whether the needle is sinking, and where it stood when it last turned.
var _sinking: bool = false
var _turn_usec: int = 0
var _turn_depth: float = 0.0
## When the rep in play began, or -1 between reps; its time inside, outside, too
## deep and too shallow so far.
var _rep_start: int = -1
var _inside_usec: float = 0.0
var _out_usec: float = 0.0
var _deep_usec: float = 0.0
var _shallow_usec: float = 0.0
## How far the set has been judged.
var _settled_usec: int = 0
## When the last rep was judged, and the stand after it: from then until the
## needle stands, the arc slides from where it was to BAND_START.
var _judged_at: int = 0
var _stand_end_usec: int = 0
var _stand_centre: float = BAND_START
var _end_usec: int = -1
## The last step of the Auto grid Auto decided at.
var _auto_usec: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's reps and Auto's pace, and takes the arc's paths: rep k's arc
## follows `paths[k % paths.size()]`, a [PackedInt64Array of times from the rep's
## start, PackedFloat64Array of centres (0 to 1 of the gauge)], straight between its
## points and held after the last.
func _init(drill: DrillData, paths: Array) -> void:
	super(drill)
	_paths = paths

## A path for each of `reps` reps, the same for the same seed (band_path()).
static func band_paths(rng_seed: int, reps: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var paths: Array = []
	for rep: int in reps:
		paths.append(band_path(rng, PATH_USEC))
	return paths

## An arc's path `path_usec` long from `rng`: from BAND_START, a turn every
## TURN_MIN_USEC to TURN_MAX_USEC at SPEED_MIN to SPEED_MAX, deeper or shallower at
## random where the gauge has room, and on past its end. Returns [times as a
## PackedInt64Array, centres as a PackedFloat64Array].
static func band_path(rng: RandomNumberGenerator, path_usec: int) -> Array:
	var times := PackedInt64Array([0])
	var centres := PackedFloat64Array([BAND_START])
	var t: int = 0
	var centre: float = BAND_START
	while t < path_usec:
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

## Judges what the time up to `t` decided, then the press: during a rep the needle
## sinks from there; standing, a new press starts the next rep (as the needle
## stands, if it is still rising). Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if not _held:
		_held = true
		_held_since = t_usec
		if _rep_start >= 0:
			_turn(t_usec, true)
	judged.append_array(_settle(t_usec))
	return judged

## Judges what the time up to `t` decided, then lets the needle rise from there.
## Returns every rep judged, in order.
func release(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if _held:
		_held = false
		if _rep_start >= 0:
			_turn(t_usec, false)
	return judged

## Judges what the passing of time to `t` decided: a rep landing or lost, and a
## held press starting the next rep as the needle stands. Returns them, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Plays the set as Auto up to `t`, deciding on the AUTO_STEP_USEC grid: during a
## rep, sinks the needle while it is shallower than the arc's centre and lets it
## rise while deeper; between reps, lets go, and starts rep k once its turn at
## Auto's pace has come and the needle stands. Returns every rep judged, in order.
func play_auto(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _auto_usec + AUTO_STEP_USEC <= t_usec and _judgements.size() < _reps:
		_auto_usec += AUTO_STEP_USEC
		judged.append_array(_settle(_auto_usec))
		if _rep_start >= 0:
			var shallow: bool = marker_at(_auto_usec) < band_centre_at(_auto_usec)
			if shallow and not _held:
				judged.append_array(press(_auto_usec))
			elif not shallow and _held:
				judged.append_array(release(_auto_usec))
		else:
			if _held:
				judged.append_array(release(_auto_usec))
			var turn: bool = _auto_usec >= _judgements.size() * _rep_usec and _auto_usec >= _stand_end_usec
			if turn and _judgements.size() < _reps:
				judged.append_array(press(_auto_usec))
	judged.append_array(advance(t_usec))
	return judged

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## The needle's depth at `t`, 0 (standing) to 1 (the deepest stance). Ask it for a
## time no earlier than the last call's.
func marker_at(t_usec: int) -> float:
	var moved: float = float(t_usec - _turn_usec)
	if _sinking:
		return minf(1.0, _turn_depth + moved / SINK_USEC)
	return maxf(0.0, _turn_depth - moved / RISE_USEC)

## The arc's centre at `t`, 0 to 1 of the gauge: on the rep's path during a rep,
## sliding back to BAND_START while the player stands, and resting there between
## reps.
func band_centre_at(t_usec: int) -> float:
	if _rep_start >= 0:
		return _path_centre(_judgements.size(), t_usec - _rep_start)
	if t_usec >= _stand_end_usec or _stand_end_usec <= _judged_at:
		return BAND_START
	var weight: float = float(t_usec - _judged_at) / float(_stand_end_usec - _judged_at)
	return lerpf(_stand_centre, BAND_START, clampf(weight, 0.0, 1.0))

## Whether the needle is inside the arc at `t`. Ask it for a time no earlier than
## the last call's.
func is_inside_at(t_usec: int) -> bool:
	return absf(marker_at(t_usec) - band_centre_at(t_usec)) <= BAND_HEIGHT / 2.0

## Whether a rep is in play, as of the last call.
func is_rep_in_play() -> bool:
	return _rep_start >= 0

## How much of its hold the rep in play has done, as of the last call: its time
## inside over HOLD_USEC. 0 between reps.
func hold_progress() -> float:
	return clampf(_inside_usec / HOLD_USEC, 0.0, 1.0) if _rep_start >= 0 else 0.0

## The rep in play's motion: its hold (hold_progress()).
func rep_progress_at(_t_usec: int) -> float:
	return hold_progress()

## When the set ends: once its last rep is judged and the needle stands. -1 until
## the last rep is judged.
func get_end_usec() -> int:
	return _end_usec

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Judges what the time up to `t` decided. During a rep, adds up its time inside
## and outside step by step between turns, landing or losing it the moment either
## reaches its mark. Between reps, starts the next rep once a new press is held
## and the needle stands.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _judgements.size() < _reps:
		if _rep_start >= 0:
			if _settled_usec >= t:
				break
			var step_end: int = mini(t, mini(_next_band_point(_settled_usec), _next_stop(_settled_usec)))
			var judgement: Judgement = _step(_settled_usec, step_end)
			if judgement != null:
				judged.append(judgement)
		else:
			if _held and _held_since >= _judged_at:
				var start: int = maxi(maxi(_held_since, _stand_end_usec), _settled_usec)
				if start <= t:
					_start_rep(start)
					continue
			_settled_usec = maxi(_settled_usec, t)
			break
	return judged

## Starts a rep at `t`: the needle sinks from where it stands, and the rep's arc
## sets off from BAND_START.
func _start_rep(t: int) -> void:
	_rep_start = t
	_settled_usec = t
	_inside_usec = 0.0
	_out_usec = 0.0
	_deep_usec = 0.0
	_shallow_usec = 0.0
	_turn(t, true)

## Adds up the rep's time from `from` to `to`, a step on which the needle and the
## arc move in straight lines, in order: out of the arc before the part inside,
## the part inside, then out after it. Judges the rep at the moment its time inside
## or outside reaches its mark, and returns that judgement; null when the step ends
## first.
func _step(from: int, to: int) -> Judgement:
	var inside: Vector2 = _inside_between(from, to)
	if inside.x > inside.y:
		inside = Vector2(to, to)
	var parts: Array[Vector3] = [
		Vector3(from, inside.x, 0.0),
		Vector3(inside.x, inside.y, 1.0),
		Vector3(inside.y, to, 0.0),
	]
	for part: Vector3 in parts:
		var span: float = part.y - part.x
		if span <= 0.0:
			continue
		if part.z > 0.0:
			var needed: float = HOLD_USEC - _inside_usec
			if needed <= span:
				_inside_usec = HOLD_USEC
				return _judge(roundi(part.x + needed), true)
			_inside_usec += span
		else:
			var allowed: float = OUT_LIMIT_USEC - _out_usec
			var deep: bool = marker_at(roundi((part.x + part.y) / 2.0)) > band_centre_at(roundi((part.x + part.y) / 2.0))
			var counted: float = minf(span, allowed)
			_out_usec += counted
			if deep:
				_deep_usec += counted
			else:
				_shallow_usec += counted
			if allowed <= span:
				return _judge(roundi(part.x + allowed), false)
	_settled_usec = to
	return null

## Where the needle is inside the arc from `from` to `to`, a straight step, as
## (start, end) times; start > end when it never is. The gap between needle and
## arc changes in a straight line, so it is inside on one stretch at most.
func _inside_between(from: int, to: int) -> Vector2:
	var half: float = BAND_HEIGHT / 2.0
	var gap_from: float = marker_at(from) - band_centre_at(from)
	var gap_to: float = marker_at(to) - band_centre_at(to)
	if is_equal_approx(gap_from, gap_to):
		return Vector2(from, to) if absf(gap_from) <= half else Vector2(to, from)
	var at_low: float = (-half - gap_from) / (gap_to - gap_from)
	var at_high: float = (half - gap_from) / (gap_to - gap_from)
	var enter: float = clampf(minf(at_low, at_high), 0.0, 1.0)
	var leave: float = clampf(maxf(at_low, at_high), 0.0, 1.0)
	if minf(at_low, at_high) > 1.0 or maxf(at_low, at_high) < 0.0:
		return Vector2(to, from)
	var span: float = float(to - from)
	return Vector2(from + enter * span, from + leave * span)

## Judges the rep in play at `at`: landed (by its share) or lost (a MISS, the side
## it spent longer on). The needle then rises whatever the press, the arc slides
## back with it, and after the last rep the set ends once the needle stands.
func _judge(at: int, landed: bool) -> Judgement:
	var tier: DrillRules.Tier = DrillRules.Tier.MISS
	var miss: Miss = Miss.TOO_DEEP if _deep_usec >= _shallow_usec else Miss.TOO_SHALLOW
	if landed:
		tier = DrillRules.judge(float(HOLD_USEC) / maxi(at - _rep_start, 1))
		miss = Miss.NONE
		if tier == DrillRules.Tier.MISS:
			miss = Miss.TOO_DEEP if _deep_usec >= _shallow_usec else Miss.TOO_SHALLOW
	var depth: float = marker_at(at)
	_stand_centre = band_centre_at(at)
	var judgement: Judgement = _record(tier, miss, depth, at)
	_rep_start = -1
	_inside_usec = 0.0
	_settled_usec = at
	_judged_at = at
	_turn(at, false)
	_stand_end_usec = at + ceili(depth * RISE_USEC)
	if _judgements.size() >= _reps:
		_end_usec = _stand_end_usec
	return judgement

## Turns the needle at `t`: sinking when `sinking`, rising otherwise.
func _turn(t: int, sinking: bool) -> void:
	_turn_depth = marker_at(t)
	_turn_usec = t
	_sinking = sinking

## Rep `rep`'s arc's centre `elapsed` into the rep.
func _path_centre(rep: int, elapsed: int) -> float:
	if _paths.is_empty():
		return BAND_START
	var path: Array = _paths[rep % _paths.size()]
	var times: PackedInt64Array = path[0]
	var centres: PackedFloat64Array = path[1]
	var count: int = times.size()
	if count == 0:
		return BAND_START
	if elapsed <= times[0]:
		return centres[0]
	for index: int in range(1, count):
		if elapsed <= times[index]:
			var from: int = times[index - 1]
			var weight: float = float(elapsed - from) / float(times[index] - from)
			return lerpf(centres[index - 1], centres[index], weight)
	return centres[count - 1]

## The first point of the rep in play's arc path after `t`, on the set's clock.
func _next_band_point(t: int) -> int:
	if _paths.is_empty() or _rep_start < 0:
		return _NEVER
	var path: Array = _paths[_judgements.size() % _paths.size()]
	for time: int in path[0]:
		if _rep_start + time > t:
			return _rep_start + time
	return _NEVER

## When the needle reaches the deepest end (sinking) or stands (rising) after `t`.
func _next_stop(t: int) -> int:
	var stop: int
	if _sinking:
		stop = _turn_usec + ceili((1.0 - _turn_depth) * SINK_USEC)
	else:
		stop = _turn_usec + ceili(_turn_depth * RISE_USEC)
	return stop if stop > t else _NEVER
