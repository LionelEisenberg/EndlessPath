class_name HorseStanceRun
extends DrillRun

## HorseStanceRun
## The judge of one set of Horse Stance (DrillRun's contract): hold and the stone
## rises, let go and it sinks, and keep its base inside a band that drifts along
## the track.
##
## The stone moves at one speed each way, the whole travel in RISE_USEC up or
## SINK_USEC down, and stops at the top and at rest: it never drops. The band is
## BAND_HEIGHT of the travel tall, and its centre follows the path the run was
## made with: straight between its points, held after the last (band_path() makes
## one for a set). The base is inside while it is within half the band's height
## of the centre. Each rep is judged at its slot's end by the share of the slot
## the base spent inside, a MISS (OUT_OF_BAND) below DrillRules' OK share.
##
## The time inside is exact: both the base and the band move in straight lines
## between their turns, so the run steps from one turn to the next (a slot's end,
## a point of the band's path, the stone reaching the top or the bottom, a press
## or a release) and adds the part of each step that was inside. After the last
## rep the stone sinks whatever the press, and the set ends once it is down;
## presses after the last rep lift nothing.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long the stone takes over the whole travel, rising while held and sinking
## once let go: 200 px a second on the board's 400 px track.
const RISE_USEC: int = 2_000_000
const SINK_USEC: int = 2_000_000
## The band's height, a share of the travel: 96 of 400 px.
const BAND_HEIGHT: float = 0.24
## Where a set's band starts (low, near the resting stone), and the band's centre
## held between BAND_LOW and BAND_HIGH so all of it stays on the track.
const BAND_START: float = 0.2
const BAND_LOW: float = 0.12
const BAND_HIGH: float = 0.88
## How long the band drifts between turns, and how fast, in travel a second.
const TURN_MIN_USEC: int = 800_000
const TURN_MAX_USEC: int = 1_600_000
const SPEED_MIN: float = 0.1
const SPEED_MAX: float = 0.275

## Later than any time a set reaches.
const _NEVER: int = 9_223_372_036_854_775_807

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The band's path: its centre at each time, straight between.
var _band_times: PackedInt64Array = PackedInt64Array()
var _band_centres: PackedFloat64Array = PackedFloat64Array()
## Whether the stone is rising, and where its base stood when it last turned.
var _held: bool = false
var _turn_usec: int = 0
var _turn_height: float = 0.0
## How far the set has been judged, and the time inside so far in the rep being played.
var _settled_usec: int = 0
var _inside_usec: float = 0.0
var _end_usec: int = -1

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and reps, and takes the band's path: its centre
## (0 to 1 of the travel) at each time (usec).
func _init(drill: DrillData, band_times: PackedInt64Array, band_centres: PackedFloat64Array) -> void:
	super(drill)
	_band_times = band_times
	_band_centres = band_centres

## A band's path for a set `set_usec` long, the same for the same seed: from
## BAND_START, a turn every TURN_MIN_USEC to TURN_MAX_USEC at SPEED_MIN to SPEED_MAX,
## up or down at random where the track has room, and on past the set's end.
## Returns [times as a PackedInt64Array, centres as a PackedFloat64Array].
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
			# No room either way: as far as the track allows, toward the room. The
			# track is wide enough that this is still faster than SPEED_MIN.
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

## Judges what the time up to `t` decided, then raises the stone from there.
## Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if not _held and _judgements.size() < _reps:
		_turn(t_usec, true)
	return judged

## Judges what the time up to `t` decided, then lets the stone sink from there.
## Returns every rep judged, in order.
func release(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if _held:
		_turn(t_usec, false)
	return judged

## Judges every rep whose slot ended by `t`. Returns them, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## The stone's base at `t`, 0 (at rest) to 1 (the top) of its travel. Ask it for a
## time no earlier than the last call's.
func marker_at(t_usec: int) -> float:
	var moved: float = float(t_usec - _turn_usec)
	if _held:
		return minf(1.0, _turn_height + moved / RISE_USEC)
	return maxf(0.0, _turn_height - moved / SINK_USEC)

## The band's centre at `t`, 0 to 1 of the travel.
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

## Whether the stone's base is inside the band at `t`. Ask it for a time no
## earlier than the last call's.
func is_inside_at(t_usec: int) -> bool:
	return absf(marker_at(t_usec) - band_centre_at(t_usec)) <= BAND_HEIGHT / 2.0

## When the set ends: once its last rep is judged and the stone has sunk to rest.
## -1 until the last rep is judged.
func get_end_usec() -> int:
	return _end_usec

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Adds the time inside up to `t`, step by step between turns, judging each slot
## that ends on the way.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _settled_usec < t and _judgements.size() < _reps:
		var slot_end: int = (_judgements.size() + 1) * _rep_usec
		var step_end: int = mini(mini(t, slot_end), mini(_next_band_point(_settled_usec), _next_stop(_settled_usec)))
		_inside_usec += _inside_between(_settled_usec, step_end)
		_settled_usec = step_end
		if step_end == slot_end:
			judged.append(_judge(slot_end))
	return judged

## Turns the stone at `t`: rising when `held`, sinking otherwise.
func _turn(t: int, held: bool) -> void:
	_turn_height = marker_at(t)
	_turn_usec = t
	_held = held

## The first point of the band's path after `t`.
func _next_band_point(t: int) -> int:
	for time: int in _band_times:
		if time > t:
			return time
	return _NEVER

## When the stone reaches the top (rising) or rest (sinking) after `t`.
func _next_stop(t: int) -> int:
	var stop: int
	if _held:
		stop = _turn_usec + ceili((1.0 - _turn_height) * RISE_USEC)
	else:
		stop = _turn_usec + ceili(_turn_height * SINK_USEC)
	return stop if stop > t else _NEVER

## How long the base was inside the band from `from` to `to`, a step on which both
## move in straight lines: the part of the step where their gap is within half
## the band.
func _inside_between(from: int, to: int) -> float:
	var half: float = BAND_HEIGHT / 2.0
	var gap_from: float = marker_at(from) - band_centre_at(from)
	var gap_to: float = marker_at(to) - band_centre_at(to)
	var span: float = float(to - from)
	if is_equal_approx(gap_from, gap_to):
		return span if absf(gap_from) <= half else 0.0
	var at_low: float = (-half - gap_from) / (gap_to - gap_from)
	var at_high: float = (half - gap_from) / (gap_to - gap_from)
	var start: float = clampf(minf(at_low, at_high), 0.0, 1.0)
	var end: float = clampf(maxf(at_low, at_high), 0.0, 1.0)
	return (end - start) * span

## Judges the rep whose slot ended at `at` by its time inside. After the last rep
## the stone sinks, and the set ends once it is down.
func _judge(at: int) -> Judgement:
	var tier: DrillRules.Tier = DrillRules.judge(_inside_usec / _rep_usec)
	_inside_usec = 0.0
	var miss: Miss = Miss.OUT_OF_BAND if tier == DrillRules.Tier.MISS else Miss.NONE
	var height: float = marker_at(at)
	var judgement: Judgement = _record(tier, miss, height, at)
	if _judgements.size() >= _reps:
		_turn(at, false)
		_end_usec = at + ceili(height * SINK_USEC)
	return judgement
