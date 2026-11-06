class_name FallingLeafRun
extends TimedPressRun

## FallingLeafRun
## The judge of one set of Falling Leaf (TimedPressRun's rules): once each rep a
## leaf drifts down past the figure's hand, reaching the palm at a time of its own
## (the run's arrivals), and the press catches it. Near the hand a leaf falls
## FALL_PX_PER_S, so its distance from the palm is a time from its arrival: a catch
## is judged by how far the leaf was from the palm, in the palm (12 px), the
## fingers (24 px) or a brush (44 px), the share falling to 0 at 64 px. A leaf
## nobody caught is LET_FALL once it is 64 px below the palm.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How fast a leaf falls near the hand, on the board's px.
const FALL_PX_PER_S: float = 200.0
## How far from the palm each tier reaches, as the time a leaf takes to fall it:
## 12, 24 and 44 px, and the share's 0 at 64 px.
const PALM_REACH_USEC: int = 60_000
const FINGERS_REACH_USEC: int = 120_000
const BRUSH_REACH_USEC: int = 220_000
const ZERO_REACH_USEC: int = 320_000
## When a set's leaves reach the palm, from their rep's start.
const ARRIVE_MIN_USEC: int = 900_000
const ARRIVE_MAX_USEC: int = 1_500_000

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## A set of `drill` whose rep k's leaf reaches the palm `arrivals[k]` into its rep.
func _init(drill: DrillData, arrivals: PackedInt64Array) -> void:
	super(drill, _palm_times(drill, arrivals), PackedInt64Array([PALM_REACH_USEC, FINGERS_REACH_USEC, BRUSH_REACH_USEC, ZERO_REACH_USEC]), Miss.LET_FALL)

## When each of a set's `reps` leaves reaches the palm, from its rep's start:
## ARRIVE_MIN_USEC to ARRIVE_MAX_USEC, the same for the same seed.
static func leaf_arrivals(rng_seed: int, reps: int) -> PackedInt64Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var arrivals := PackedInt64Array()
	for rep: int in reps:
		arrivals.append(rng.randi_range(ARRIVE_MIN_USEC, ARRIVE_MAX_USEC))
	return arrivals

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## How far below the palm rep `rep`'s leaf is at `t`, in px, negative above it,
## along its fall near the hand.
func offset_px_at(rep: int, t_usec: int) -> float:
	return (t_usec - target_usec(rep)) * FALL_PX_PER_S / 1_000_000.0

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## When each leaf reaches the palm on the set's clock.
static func _palm_times(drill: DrillData, arrivals: PackedInt64Array) -> PackedInt64Array:
	var rep_usec: int = roundi(drill.rep_seconds * 1_000_000.0)
	var times := PackedInt64Array()
	for rep: int in arrivals.size():
		times.append(rep * rep_usec + arrivals[rep])
	return times
