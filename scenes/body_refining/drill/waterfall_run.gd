class_name WaterfallRun
extends TimedPressRun

## WaterfallRun
## The judge of one set of Waterfall Tempering (TimedPressRun's rules): once each
## rep a surge of foam rides down the falls and lands on the brace line
## BEAT_AT_USEC into the rep, a steady beat, and the press is judged by how close
## to the landing it came, at #97's windows. A rep with no press is BUCKLED: the
## surge crashes through.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## When each rep's surge lands, from its slot's start, and how long it rides from
## the ledge to the line (the board draws it from there).
const BEAT_AT_USEC: int = 1_500_000
const LEAD_USEC: int = 1_500_000
## How far from the landing each tier reaches (#97's 0.05, 0.1 and 0.18 s), and
## where the share falls to 0.
const PERFECT_REACH_USEC: int = 50_000
const GOOD_REACH_USEC: int = 100_000
const OK_REACH_USEC: int = 180_000
const ZERO_REACH_USEC: int = 260_000

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## A set of `drill`, a surge landing BEAT_AT_USEC into each of its reps.
func _init(drill: DrillData) -> void:
	super(drill, _landings(drill), PackedInt64Array([PERFECT_REACH_USEC, GOOD_REACH_USEC, OK_REACH_USEC, ZERO_REACH_USEC]), Miss.BUCKLED)

## When each rep's surge lands on the set's clock.
static func _landings(drill: DrillData) -> PackedInt64Array:
	var rep_usec: int = roundi(drill.rep_seconds * 1_000_000.0)
	var landings := PackedInt64Array()
	for rep: int in drill.reps_per_set:
		landings.append(rep * rep_usec + BEAT_AT_USEC)
	return landings
