class_name StoneLiftingRun
extends DrillRun

## StoneLiftingRun
## The judge of one set of Stone Lifting (DrillRun's contract): hold to lift the
## stone, let go with its base in the brass band.
##
## Held, the stone rises steadily and would reach the top RISE_USEC after the lift
## began. A release judges the lift by how long it held the stone up: its offset
## from BAND_CENTRE_USEC turns into a share (share_for_offset()), and
## DrillRules.judge() turns the share into a tier, so a MISS below the band is
## TOO_LOW. A lift held to the top drops the stone, a MISS (DROPPED).
##
## After a judgement the stone rests where it stopped for REST_HOLD_USEC (not after
## a drop), then sets down over SET_DOWN_USEC; a stone at rest needs no setting
## down. The next rep lifts on a new press, one made since the last judgement, once
## the stone is down: a press then lifts at once, and a press made while it sets
## down lifts the moment it is down (#143: no slot, so the stone waits for the
## player as long as they like). A press still held from the last rep, through a
## drop, lifts nothing. The set ends once its last rep is judged and its stone is
## down (get_end_usec()), and presses after the last rep judge nothing.

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

## When the lift in progress began, or -1 when the stone is not being lifted.
var _lift_start: int = -1
## Whether the press is down, and since when.
var _held: bool = false
var _held_since: int = 0
## The last judgement, when it came, when its stone starts to set down, and when
## it is down.
var _last: Judgement = null
var _judged_at: int = 0
var _rest_end_usec: int = 0
var _stone_down_usec: int = 0

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges a press at `t`: what the time up to it decided first, then the press,
## which lifts the stone once it is down (at once, or as it lands while the press
## stays held). Returns every rep judged, in order.
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

## Judges what the passing of time to `t` decided: a lift held to the top drops.
## Returns every rep judged, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Plays the set as Auto up to `t`: lifts rep k once its turn at Auto's pace has
## come and the stone is down, and lets go BAND_CENTRE_USEC later, the stone's base
## at the band's centre. Returns every rep judged, in order.
func play_auto(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while true:
		if _lift_start >= 0:
			var let_go: int = _lift_start + BAND_CENTRE_USEC
			if let_go > t_usec:
				break
			judged.append_array(release(let_go))
		else:
			if _judgements.size() >= _reps:
				break
			var start: int = maxi(_judgements.size() * _rep_usec, _stone_down_usec)
			if start > t_usec:
				break
			judged.append_array(press(start))
	judged.append_array(advance(t_usec))
	return judged

## The share of a rep whose stone stopped `offset_usec` (in time held) off the
## band's centre, through the brass's edge, the band's and the tan's.
static func share_for_offset(offset_usec: int) -> float:
	return DrillRun.share_through(offset_usec, PERFECT_REACH_USEC, GOOD_REACH_USEC, OK_REACH_USEC, ZERO_SHARE_REACH_USEC)

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

## The tier a release at `t` would score: the lift's height turned back into time
## held, judged as a release judges it. MISS when no lift is in progress. Ask it
## for a time no earlier than the last call's.
func release_tier_at(t_usec: int) -> DrillRules.Tier:
	if _lift_start < 0:
		return DrillRules.Tier.MISS
	var held: int = roundi(height_at(t_usec) * RISE_USEC)
	return DrillRules.judge(share_for_offset(held - BAND_CENTRE_USEC))

## The rep in play's motion: the stone's height while it is lifted, else 0.
func rep_progress_at(t_usec: int) -> float:
	return height_at(t_usec) if _lift_start >= 0 else 0.0

## When the set ends: once its last rep is judged and that stone is down. -1
## until the last rep is judged.
func get_end_usec() -> int:
	return _stone_down_usec if _judgements.size() >= _reps else -1

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Judges, in order, what the time up to `t` decided: the lift in progress drops
## at the top; with no lift, a new press held lifts once the stone is down.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _judgements.size() < _reps:
		if _lift_start >= 0:
			var top: int = _lift_start + RISE_USEC
			if top > t:
				break
			judged.append(_judge_drop(top))
		elif not (_held and _try_lift(t)):
			break
	return judged

## Starts the held press's lift at the first moment it may begin: once the stone
## is down, and not before the press. A press made before the last judgement is
## held over from that rep and lifts nothing. Returns true when that moment is no
## later than `t`.
func _try_lift(t: int) -> bool:
	if _last != null and _held_since < _judged_at:
		return false
	var start: int = maxi(_held_since, _stone_down_usec)
	if start > t:
		return false
	_lift_start = start
	return true

## Judges the lift in progress let go at `at`.
func _judge_lift(at: int) -> Judgement:
	var held: int = at - _lift_start
	var tier: DrillRules.Tier = DrillRules.judge(share_for_offset(held - BAND_CENTRE_USEC))
	var miss: Miss = Miss.TOO_LOW if tier == DrillRules.Tier.MISS else Miss.NONE
	return _record_stone(tier, miss, clampf(float(held) / RISE_USEC, 0.0, 1.0), at, REST_HOLD_USEC)

## The lift in progress reached the top at `at`: the stone drops.
func _judge_drop(at: int) -> Judgement:
	return _record_stone(DrillRules.Tier.MISS, Miss.DROPPED, 1.0, at, 0)

## Records the next rep's judgement; the stone rests `rest` there, then sets down
## (at once, from rest, when it stopped at 0).
func _record_stone(tier: DrillRules.Tier, miss: Miss, height: float, at: int, rest: int) -> Judgement:
	var judgement: Judgement = _record(tier, miss, height, at)
	_lift_start = -1
	_last = judgement
	_judged_at = at
	_rest_end_usec = at + rest
	_stone_down_usec = _rest_end_usec + (SET_DOWN_USEC if height > 0.0 else 0)
	return judgement
