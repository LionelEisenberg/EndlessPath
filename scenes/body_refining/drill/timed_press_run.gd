class_name TimedPressRun
extends DrillRun

## TimedPressRun
## A judge (DrillRun's contract) for a drill whose every rep is one moment to press
## at, a lead after the press that starts the rep, such as a surge sent down the
## falls to land on a line.
##
## A press with no rep in play starts the next rep (#143): its target is the lead
## later. The first press after that is the rep's, judged by how far it came from
## the target: share_through() at the run's reaches (perfect, good, OK, zero), a
## MISS before the target TOO_EARLY and after it TOO_LATE. A rep with no press is
## missed at its target plus the zero reach, once no press could score, with the
## run's own reason. Then the next rep waits for a press, so nothing comes on its
## own. A release does nothing. The set ends the moment its last rep is judged.

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## How long after the press that starts a rep its target comes.
var _lead_usec: int = 0
## Each started rep's target on the set's clock.
var _targets: PackedInt64Array = PackedInt64Array()
## How far off the target each tier reaches, and where the share falls to 0:
## perfect, good, OK, zero.
var _reaches: PackedInt64Array = PackedInt64Array()
## Why a rep with no press is a MISS.
var _no_press_miss: Miss = Miss.TOO_LATE

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's reps and Auto's pace, and takes the lead from a rep's start to
## its target, the reaches (perfect, good, OK, zero) and the reason a rep with no
## press misses.
func _init(drill: DrillData, lead_usec: int, reaches: PackedInt64Array, no_press_miss: Miss) -> void:
	super(drill)
	_lead_usec = lead_usec
	_reaches = reaches
	_no_press_miss = no_press_miss

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges what the time up to `t` decided, then the press: the rep in play's, or
## with none in play, the start of the next rep. Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	if rep_in_play() >= 0:
		judged.append(_judge_press(rep_in_play(), t_usec))
	elif _targets.size() < _reps:
		_targets.append(t_usec + _lead_usec)
	return judged

## Judges what the time up to `t` decided; a release meets no target.
func release(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Judges a rep whose deadline passed by `t`. Returns it.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Plays the set as Auto up to `t`: starts rep k at k of Auto's pace and presses on
## its target. Returns every rep judged, in order.
func play_auto(t_usec: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	while _judgements.size() < _reps:
		var rep: int = rep_in_play()
		var at: int = _targets[rep] if rep >= 0 else _targets.size() * _rep_usec
		if at > t_usec:
			break
		judged.append_array(press(at))
	judged.append_array(_settle(t_usec))
	return judged

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## Rep `rep`'s target on the set's clock; -1 before the rep starts.
func target_usec(rep: int) -> int:
	return _targets[rep] if rep < _targets.size() else -1

## The rep started and not yet judged, or -1 when the next one waits for a press.
func rep_in_play() -> int:
	return _judgements.size() if _targets.size() > _judgements.size() else -1

## The rep in play's motion, from its start to its target; 0 with none in play.
func rep_progress_at(t_usec: int) -> float:
	var rep: int = rep_in_play()
	if rep < 0:
		return 0.0
	return clampf(1.0 - float(_targets[rep] - t_usec) / _lead_usec, 0.0, 1.0)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Misses the rep in play when its target plus the zero reach came by `t`.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	var rep: int = rep_in_play()
	if rep >= 0:
		var deadline: int = _targets[rep] + _reaches[3]
		if deadline <= t:
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
