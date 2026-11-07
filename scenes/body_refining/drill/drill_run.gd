class_name DrillRun
extends RefCounted

## DrillRun
## The judge of one set of a drill, and the contract every drill's input plays
## through: the set's first press starts it, presses and releases come in as they
## happen, and each rep comes out judged, in order. Pure logic with no nodes:
## DrillPlay calls advance() every frame and press() and release() on input, and
## the tests drive it with exact times. Every time is on the set's own clock, in
## microseconds from the set's first press.
##
## A set is the drill's reps_per_set reps, each a slot of rep_seconds: rep k's slot
## runs from k rep lengths to k + 1. Each input measures how well a rep was played
## as a share from 0 to 1 (share_through() for an input judged by how far off a
## mark it was), and DrillRules.judge() turns the share into #97's tier, so the
## tiers feel the same on every drill. Results never depend on when frames fall:
## every call first judges, in order, whatever the time up to `t` decided. Each
## input kind has its own run, which for_drill() picks.

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## Why a rep was a MISS, or NONE for a scored rep. Never saved, so the values may
## be reordered; TOO_LATE serves every input that can come late.
enum Miss { NONE, TOO_LOW, DROPPED, TOO_LATE, TOO_DEEP, TOO_SHALLOW, TOO_EARLY, TOO_FAR, LANDED, BUCKLED }

## One judged rep.
class Judgement:
	## The rep, counted from 0.
	var rep: int = 0
	var tier: DrillRules.Tier = DrillRules.Tier.MISS
	var miss: Miss = Miss.NONE
	## Where the input's piece stood, 0 (at rest) to 1 (the top) of its travel,
	## for the inputs that move one along a track or a gauge; 0 for the others.
	var height: float = 0.0
	## When the rep was judged, on the set's clock.
	var at_usec: int = 0
	## Where the rep was decided, in the stage's px, for the inputs played about the
	## stage (a leaf's catch where the click came, its landing where it landed);
	## Vector2.ZERO for the others.
	var point: Vector2 = Vector2.ZERO

	func _init(p_rep: int, p_tier: DrillRules.Tier, p_miss: Miss, p_height: float, p_at_usec: int, p_point: Vector2 = Vector2.ZERO) -> void:
		rep = p_rep
		tier = p_tier
		miss = p_miss
		height = p_height
		at_usec = p_at_usec
		point = p_point

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _rep_usec: int = 0
var _reps: int = 0
var _judgements: Array[Judgement] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and reps, once.
func _init(drill: DrillData) -> void:
	_rep_usec = roundi(drill.rep_seconds * 1_000_000.0)
	_reps = drill.reps_per_set

## The run that plays and judges a set of `drill`, by its input kind. `rng_seed`
## makes what an input varies from set to set (Horse Stance's arc, Falling Leaf's
## leaves), the same for the same seed.
static func for_drill(drill: DrillData, rng_seed: int = 0) -> DrillRun:
	match drill.input_kind:
		DrillData.InputKind.HOLD_STEADY:
			var path: Array = HorseStanceRun.band_path(rng_seed, roundi(drill.rep_seconds * 1_000_000.0) * drill.reps_per_set)
			return HorseStanceRun.new(drill, path[0], path[1])
		DrillData.InputKind.CATCH:
			return FallingLeafRun.new(drill, FallingLeafRun.leaf_paths(rng_seed, drill))
		DrillData.InputKind.BEAT:
			return WaterfallRun.new(drill)
	return StoneLiftingRun.new(drill)

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges a press at `t`: what the time up to it decided first, then the press.
## Returns every rep judged, in order.
func press(t_usec: int) -> Array[Judgement]:
	return advance(t_usec)

## Judges a press at `t` aimed at `point`, in the stage's px. An input that aims at
## nothing takes it as a plain press().
func press_at(t_usec: int, _point: Vector2) -> Array[Judgement]:
	return press(t_usec)

## Judges a release at `t`: what the time up to it decided first, then the
## release. Returns every rep judged, in order.
func release(t_usec: int) -> Array[Judgement]:
	return advance(t_usec)

## Judges what the passing of time to `t` decided. Returns every rep judged, in
## order.
func advance(_t_usec: int) -> Array[Judgement]:
	return []

## Whether the press that starts a set is also the first rep's input (a hold),
## or only starts it.
func judges_starting_press() -> bool:
	return true

## The share of a rep played `offset` off its mark, in any one unit (time, px): 1
## on the mark, then straight lines through 0.85 at `perfect`, 0.6 at `good` and
## 0.3 at `ok`, down to 0 at `zero` and past it, either side. DrillRules.judge()
## turns it into the tier, each edge landing in the better one.
static func share_through(offset: float, perfect: float, good: float, ok: float, zero: float) -> float:
	var off: float = absf(offset)
	if off <= perfect:
		return lerpf(1.0, DrillRules.PERFECT_SHARE, off / perfect)
	if off <= good:
		return lerpf(DrillRules.PERFECT_SHARE, DrillRules.GOOD_SHARE, (off - perfect) / (good - perfect))
	if off <= ok:
		return lerpf(DrillRules.GOOD_SHARE, DrillRules.OK_SHARE, (off - good) / (ok - good))
	if off <= zero:
		return lerpf(DrillRules.OK_SHARE, 0.0, (off - ok) / (zero - ok))
	return 0.0

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

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

## When the set ends, on its clock: once every rep is judged, the end of its last
## slot. -1 until the last rep is judged.
func get_end_usec() -> int:
	return _reps * _rep_usec if _judgements.size() >= _reps else -1

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Records the next rep's judgement.
func _record(tier: DrillRules.Tier, miss: Miss, height: float, at: int) -> Judgement:
	return _record_rep(_judgements.size(), tier, miss, height, at)

## Records rep `rep`'s judgement, which may come out of turn (a leaf caught before
## an earlier one lands), with where its piece was.
func _record_rep(rep: int, tier: DrillRules.Tier, miss: Miss, height: float, at: int, point: Vector2 = Vector2.ZERO) -> Judgement:
	var judgement := Judgement.new(rep, tier, miss, height, at, point)
	_judgements.append(judgement)
	return judgement
