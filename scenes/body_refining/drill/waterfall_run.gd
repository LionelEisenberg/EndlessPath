class_name WaterfallRun
extends TimedPressRun

## WaterfallRun
## The judge of one set of Waterfall Tempering (TimedPressRun's rules): the next
## surge of foam waits at the ledge until a press sends it down (#143); it rides the
## falls for LEAD_USEC and lands on the brace line, and the next press is judged by
## how close to the landing it came, at #97's windows. A surge with no press is
## BUCKLED: it crashes through.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long a surge rides from the ledge to the line once sent (the board draws it
## at that speed).
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

## A set of `drill`, each surge landing LEAD_USEC after the press that sends it.
func _init(drill: DrillData) -> void:
	super(drill, LEAD_USEC, PackedInt64Array([PERFECT_REACH_USEC, GOOD_REACH_USEC, OK_REACH_USEC, ZERO_REACH_USEC]), Miss.BUCKLED)
