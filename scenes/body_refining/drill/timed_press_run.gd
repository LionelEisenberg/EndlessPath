class_name TimedPressRun
extends DrillRun

## TimedPressRun
## A judge (DrillRun's contract) for a drill whose every rep is one moment to
## press at, such as a surge of water landing on a line. Each rep has a target
## time on the set's clock, inside its slot.
##
## The first press in a rep's slot is that rep's, judged by how far it came from
## the target: share_through() at the run's reaches (perfect, good, OK, zero), a
## MISS before the target TOO_EARLY and after it TOO_LATE. Further presses in a
## judged rep's slot do nothing, so mashing can't meet every target. A rep with no
## press is missed at its target plus the zero reach, once no press could score,
## with the run's own reason. A release does nothing. The press that starts a set
## only starts it: it is not judged.

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Each rep's target on the set's clock.
var _targets: PackedInt64Array = PackedInt64Array()
## How far off the target each tier reaches, and where the share falls to 0:
## perfect, good, OK, zero.
var _reaches: PackedInt64Array = PackedInt64Array()
## Why a rep with no press is a MISS.
var _no_press_miss: Miss = Miss.TOO_LATE

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and reps, and takes each rep's target, the
## reaches (perfect, good, OK, zero) and the reason a rep with no press misses.
func _init(drill: DrillData, targets: PackedInt64Array, reaches: PackedInt64Array, no_press_miss: Miss) -> void:
	super(drill)
	_targets = targets
	_reaches = reaches
	_no_press_miss = no_press_miss

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges what the time up to `t` decided, then the press: the next rep's, when
## `t` is in its slot. Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	var rep: int = _judgements.size()
	if rep < _reps and t_usec >= rep * _rep_usec:
		judged.append(_judge_press(rep, t_usec))
	return judged

## Judges what the time up to `t` decided; a release meets no target.
func release(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Judges every rep whose deadline passed by `t`. Returns them, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## The press that starts a set only starts it.
func judges_starting_press() -> bool:
	return false

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## Rep `rep`'s target on the set's clock.
func target_usec(rep: int) -> int:
	return _targets[rep]

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Misses, in order, every rep whose target plus the zero reach came by `t`.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _judgements.size() < _reps:
		var deadline: int = _targets[_judgements.size()] + _reaches[3]
		if deadline > t:
			break
		judged.append(_record(DrillRules.Tier.MISS, _no_press_miss, 0.0, deadline))
	return judged

## Judges rep `rep` pressed at `t`.
func _judge_press(rep: int, t: int) -> Judgement:
	var offset: int = t - _targets[rep]
	var tier: DrillRules.Tier = DrillRules.judge(DrillRun.share_through(offset, _reaches[0], _reaches[1], _reaches[2], _reaches[3]))
	var miss: Miss = Miss.NONE
	if tier == DrillRules.Tier.MISS:
		miss = Miss.TOO_EARLY if offset < 0 else Miss.TOO_LATE
	return _record(tier, miss, 0.0, t)
