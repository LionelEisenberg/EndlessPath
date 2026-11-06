class_name DrillRun
extends RefCounted

## DrillRun
## The judge of one set of Stone Lifting: hold to lift the stone, let go with its
## base in the brass band. Pure logic with no nodes: DrillPlay calls advance()
## every frame and press() and release() on input, and the tests drive it with
## exact times. Every time is on the set's own clock, in microseconds from the
## set's first press.
##
## A set is the drill's reps_per_set reps, each a slot of rep_seconds: rep k's slot
## runs from k rep lengths to k + 1. Held, the stone rises steadily and would
## reach the top RISE_USEC after the lift began. A release judges the lift by how
## long it held the stone up: its offset from BAND_CENTRE_USEC turns into a share
## (share_for_offset()), and DrillRules.judge() turns the share into a tier, so a
## MISS below the band is TOO_LOW. A lift held to the top drops the stone, a MISS
## (DROPPED). A lift still held when its slot ends is judged there, as if let go.
## A slot nobody lifted in is a MISS (TOO_LATE) at its end. Results never depend on
## when frames fall: every call first judges, in order, whatever the time up to
## `t` decided.
##
## After a judgement the stone rests where it stopped for REST_HOLD_USEC (not after
## a drop), then sets down over SET_DOWN_USEC; a stone at rest needs no setting
## down. The next rep lifts once its slot has begun and the stone is down: a press
## then lifts at once, and a press made earlier and still held lifts the moment
## both are true. The set ends once its last rep is judged and its stone is down
## (get_end_usec()), and presses after the last rep judge nothing.

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## Why a rep was a MISS, or NONE for a scored rep.
enum Miss { NONE, TOO_LOW, DROPPED, TOO_LATE }

## One judged rep.
class Judgement:
	## The rep, counted from 0.
	var rep: int = 0
	var tier: DrillRules.Tier = DrillRules.Tier.MISS
	var miss: Miss = Miss.NONE
	## Where the stone stopped, 0 (at rest) to 1 (the top) of its travel.
	var height: float = 0.0
	## When the rep was judged, on the set's clock.
	var at_usec: int = 0

	func _init(p_rep: int, p_tier: DrillRules.Tier, p_miss: Miss, p_height: float, p_at_usec: int) -> void:
		rep = p_rep
		tier = p_tier
		miss = p_miss
		height = p_height
		at_usec = p_at_usec

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long a lift takes the stone from rest to the top, where it drops.
const RISE_USEC: int = 2_000_000
## How long a lift holds the stone up when its base is at the band's centre.
const BAND_CENTRE_USEC: int = 1_370_000
## How far off the band's centre, in time held, each tier reaches: the brass
## centre third Perfect, the band Good, a band's height either side OK (the tan
## above the band ends at the top). The share falls to 0 at ZERO_SHARE_REACH_USEC.
const PERFECT_REACH_USEC: int = 70_000
const GOOD_REACH_USEC: int = 210_000
const OK_REACH_USEC: int = 630_000
const ZERO_SHARE_REACH_USEC: int = 1_050_000
## How long a judged stone rests where it stopped, then how long it takes to set down.
const REST_HOLD_USEC: int = 300_000
const SET_DOWN_USEC: int = 300_000

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _rep_usec: int = 0
var _reps: int = 0
var _judgements: Array[Judgement] = []
## When the lift in progress began, or -1 when the stone is not being lifted.
var _lift_start: int = -1
## Whether the press is down, and since when.
var _held: bool = false
var _held_since: int = 0
## The last judgement, when its stone starts to set down, and when it is down.
var _last: Judgement = null
var _rest_end_usec: int = 0
var _stone_down_usec: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and reps, once.
func _init(drill: DrillData) -> void:
	_rep_usec = roundi(drill.rep_seconds * 1_000_000.0)
	_reps = drill.reps_per_set

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges a press at `t`: what the time up to it decided first, then the press,
## which lifts the stone if the rep may begin (or once it may, while it stays
## held). Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if not _held:
		_held = true
		_held_since = t_usec
	judged.append_array(_settle(t_usec))
	return judged

## Judges a release at `t`: what the time up to it decided first, then the lift
## it lets go of, if one is in progress. Returns every rep judged, in order.
func release(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	_held = false
	if _lift_start >= 0:
		judged.append(_judge_lift(t_usec))
	return judged

## Judges what the passing of time to `t` decided: drops, lifts held to their
## slot's end and slots nobody lifted in. Returns every rep judged, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## The share of a rep whose stone stopped `offset_usec` (in time held) off the
## band's centre: 1 at the centre, then straight lines through 0.85 at the brass's
## edge, 0.6 at the band's and 0.3 at the tan's, down to 0 at
## ZERO_SHARE_REACH_USEC. DrillRules.judge() turns it into the tier, each edge
## landing in the better one.
static func share_for_offset(offset_usec: int) -> float:
	var off: int = absi(offset_usec)
	if off <= PERFECT_REACH_USEC:
		return lerpf(1.0, DrillRules.PERFECT_SHARE, float(off) / PERFECT_REACH_USEC)
	if off <= GOOD_REACH_USEC:
		return lerpf(DrillRules.PERFECT_SHARE, DrillRules.GOOD_SHARE, float(off - PERFECT_REACH_USEC) / (GOOD_REACH_USEC - PERFECT_REACH_USEC))
	if off <= OK_REACH_USEC:
		return lerpf(DrillRules.GOOD_SHARE, DrillRules.OK_SHARE, float(off - GOOD_REACH_USEC) / (OK_REACH_USEC - GOOD_REACH_USEC))
	if off <= ZERO_SHARE_REACH_USEC:
		return lerpf(DrillRules.OK_SHARE, 0.0, float(off - OK_REACH_USEC) / (ZERO_SHARE_REACH_USEC - OK_REACH_USEC))
	return 0.0

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## Whether the stone is being lifted, as of the last call.
func is_lifting() -> bool:
	return _lift_start >= 0

## The stone's height at `t`, 0 (at rest) to 1 (the top) of its travel: rising
## during a lift, resting where the last rep stopped it, then setting down. Ask it
## for a time no earlier than the last call's.
func height_at(t_usec: int) -> float:
	if _lift_start >= 0:
		return clampf(float(t_usec - _lift_start) / RISE_USEC, 0.0, 1.0)
	if _last == null or t_usec >= _stone_down_usec:
		return 0.0
	if t_usec < _rest_end_usec:
		return _last.height
	return _last.height * (1.0 - float(t_usec - _rest_end_usec) / SET_DOWN_USEC)

## The rep whose slot holds `t`, counted from 0, the last one past the set's end.
func rep_at(t_usec: int) -> int:
	@warning_ignore("integer_division")
	return mini(maxi(t_usec, 0) / _rep_usec, _reps - 1)

## How far through its rep's slot `t` is, 0 to 1; 1 past the set's last slot.
func rep_progress_at(t_usec: int) -> float:
	if t_usec >= _reps * _rep_usec:
		return 1.0
	return float(maxi(t_usec, 0) - rep_at(t_usec) * _rep_usec) / _rep_usec

## How many reps have been judged.
func get_judged_count() -> int:
	return _judgements.size()

## Every rep judged so far, in order.
func get_judgements() -> Array[Judgement]:
	return _judgements.duplicate()

## When the set ends: once its last rep is judged and that stone is down. -1
## until the last rep is judged.
func get_end_usec() -> int:
	return _stone_down_usec if _judgements.size() >= _reps else -1

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Judges, in order, what the time up to `t` decided for the reps still to come:
## the lift in progress drops at the top or is judged at its slot's end; with no
## lift, a held press lifts once it may, and a slot that ends with no lift is
## TOO_LATE.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _judgements.size() < _reps:
		var slot_end: int = (_judgements.size() + 1) * _rep_usec
		if _lift_start >= 0:
			var top: int = _lift_start + RISE_USEC
			if top <= t and top <= slot_end:
				judged.append(_judge_drop(top))
			elif slot_end <= t:
				judged.append(_judge_lift(slot_end))
			else:
				break
		else:
			if _held and _try_lift(t):
				continue
			if slot_end <= t:
				judged.append(_judge_too_late(slot_end))
			else:
				break
	return judged

## Starts the held press's lift at the first moment it may begin: once the next
## rep's slot has begun and the stone is down, and not before the press. Returns
## true when that moment is no later than `t` and inside the slot.
func _try_lift(t: int) -> bool:
	var slot_start: int = _judgements.size() * _rep_usec
	var start: int = maxi(maxi(_held_since, slot_start), _stone_down_usec)
	if start > t or start >= slot_start + _rep_usec:
		return false
	_lift_start = start
	return true

## Judges the lift in progress let go at `at`.
func _judge_lift(at: int) -> Judgement:
	var held: int = at - _lift_start
	var tier: DrillRules.Tier = DrillRules.judge(share_for_offset(held - BAND_CENTRE_USEC))
	var miss: Miss = Miss.TOO_LOW if tier == DrillRules.Tier.MISS else Miss.NONE
	return _record(tier, miss, clampf(float(held) / RISE_USEC, 0.0, 1.0), at, REST_HOLD_USEC)

## The lift in progress reached the top at `at`: the stone drops.
func _judge_drop(at: int) -> Judgement:
	return _record(DrillRules.Tier.MISS, Miss.DROPPED, 1.0, at, 0)

## The rep's slot ended at `at` with no lift.
func _judge_too_late(at: int) -> Judgement:
	return _record(DrillRules.Tier.MISS, Miss.TOO_LATE, 0.0, at, 0)

## Records the next rep's judgement; the stone rests `rest` there, then sets down
## (at once, from rest, when it stopped at 0).
func _record(tier: DrillRules.Tier, miss: Miss, height: float, at: int, rest: int) -> Judgement:
	var judgement := Judgement.new(_judgements.size(), tier, miss, height, at)
	_judgements.append(judgement)
	_lift_start = -1
	_last = judgement
	_rest_end_usec = at + rest
	_stone_down_usec = _rest_end_usec + (SET_DOWN_USEC if height > 0.0 else 0)
	return judgement
