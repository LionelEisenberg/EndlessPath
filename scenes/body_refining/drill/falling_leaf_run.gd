class_name FallingLeafRun
extends DrillRun

## FallingLeafRun
## The judge of one set of Falling Leaf (DrillRun's contract): once each rep a leaf
## drops from the branch and sways down to the ground line in FALL_USEC, so two
## are often in the air, and a click catches one. The pointer is the hand: a press
## aimed at a point (press_at()) catches the nearest airborne leaf within REACH_PX,
## judged by how far from the leaf's middle it came, in the palm (PALM_PX), the
## fingers (FINGERS_PX) or a brush (BRUSH_PX); further, up to REACH_PX, it is a MISS
## (TOO_FAR) and the leaf slips away. A press further than REACH_PX from every leaf
## does nothing, and so does a press with no point. A leaf nobody caught is a MISS
## (LANDED) when it reaches the ground, and stays there.
##
## Each leaf is a rep, and a leaf can be caught before an earlier one lands, so the
## judgements come out in the order of their times, each carrying its leaf as its
## rep and, as its point, where the click came (the catch's ring stands there) or
## where the leaf landed. The set ends once every leaf is judged,
## and not before the last rep's slot is over. Points are in the stage's px. The
## press that starts a set shakes the branch: it is not judged.

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## One leaf's fall: when it drops, where from, and how it sways on the way down.
class Leaf:
	## When it drops from the branch, on the set's clock.
	var drop_usec: int = 0
	## Where it drops from: its middle's x, and its y under the branch there.
	var x: float = 0.0
	var top_y: float = 0.0
	## How far it sways either side, how long a swing takes, and where it starts in it.
	var sway_px: float = 0.0
	var sway_period_usec: int = 1
	var sway_phase: float = 0.0

	func _init(p_drop_usec: int, p_x: float, p_top_y: float, p_sway_px: float, p_sway_period_usec: int, p_sway_phase: float) -> void:
		drop_usec = p_drop_usec
		x = p_x
		top_y = p_top_y
		sway_px = p_sway_px
		sway_period_usec = p_sway_period_usec
		sway_phase = p_sway_phase

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long a leaf takes from the branch to the ground, at an even speed, and
## where its middle is once it lies on the ground line.
const FALL_USEC: int = 3_600_000
const GROUND_Y: float = 856.0
## How far from a leaf's middle each tier reaches, and how far a click still
## reaches the leaf (a MISS past BRUSH_PX).
const PALM_PX: float = 12.0
const FINGERS_PX: float = 24.0
const BRUSH_PX: float = 36.0
const REACH_PX: float = 48.0
## The branch: a leaf hangs under it at BRANCH_Y_AT_0 + BRANCH_SLOPE x, and drops
## from between DROP_X_MIN and DROP_X_MAX.
const BRANCH_Y_AT_0: float = 46.0
const BRANCH_SLOPE: float = 0.095
const DROP_X_MIN: float = 40.0
const DROP_X_MAX: float = 400.0
## How far a leaf sways either side, and how long a swing takes.
const SWAY_MIN_PX: float = 16.0
const SWAY_MAX_PX: float = 32.0
const SWAY_MIN_USEC: int = 1_400_000
const SWAY_MAX_USEC: int = 2_000_000

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _leaves: Array[Leaf] = []
## Whether each leaf has been judged, caught or landed.
var _judged: Array[bool] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Reads the drill's rep length and takes the set's leaves, a rep each.
func _init(drill: DrillData, leaves: Array[Leaf]) -> void:
	super(drill)
	_leaves = leaves
	_reps = leaves.size()
	for leaf: Leaf in leaves:
		_judged.append(false)

## A set's leaves for `drill`, the same for the same seed: one a rep, dropped at its
## slot's start from a random point of the branch, with a random sway.
static func leaf_paths(rng_seed: int, drill: DrillData) -> Array[Leaf]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rep_usec: int = roundi(drill.rep_seconds * 1_000_000.0)
	var leaves: Array[Leaf] = []
	for rep: int in drill.reps_per_set:
		var x: float = rng.randf_range(DROP_X_MIN, DROP_X_MAX)
		leaves.append(Leaf.new(rep * rep_usec, x, BRANCH_Y_AT_0 + x * BRANCH_SLOPE, rng.randf_range(SWAY_MIN_PX, SWAY_MAX_PX), rng.randi_range(SWAY_MIN_USEC, SWAY_MAX_USEC), rng.randf_range(0.0, TAU)))
	return leaves

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Judges what the time up to `t` decided; a press with no point catches nothing.
func press(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Judges what the time up to `t` decided, then the click at `point`: the nearest
## airborne leaf within REACH_PX, by its distance, the click being the judgement's
## point. Returns every rep judged, in the order of their times.
func press_at(t_usec: int, point: Vector2) -> Array[Judgement]:
	var judged: Array[Judgement] = _settle(t_usec)
	var nearest: int = -1
	var nearest_distance: float = REACH_PX
	for index: int in _leaves.size():
		if not _judged[index] and is_airborne(index, t_usec):
			var distance: float = leaf_position(index, t_usec).distance_to(point)
			if distance <= nearest_distance:
				nearest = index
				nearest_distance = distance
	if nearest >= 0:
		var tier: DrillRules.Tier = DrillRules.judge(DrillRun.share_through(nearest_distance, PALM_PX, FINGERS_PX, BRUSH_PX, REACH_PX))
		var miss: Miss = Miss.TOO_FAR if tier == DrillRules.Tier.MISS else Miss.NONE
		_judged[nearest] = true
		judged.append(_record_rep(nearest, tier, miss, 0.0, t_usec, point))
	return judged

## Judges every leaf that landed by `t`. Returns them, in order.
func release(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## Judges every leaf that landed by `t`. Returns them, in order.
func advance(t_usec: int) -> Array[Judgement]:
	return _settle(t_usec)

## The press that starts a set shakes the branch.
func judges_starting_press() -> bool:
	return false

#-----------------------------------------------------------------------------
# QUERIES
#-----------------------------------------------------------------------------

## How many leaves the set drops.
func get_leaf_count() -> int:
	return _leaves.size()

## Leaf `index`'s middle at `t`, in the stage's px: on the branch until it drops,
## swaying down at an even speed, then where it landed.
func leaf_position(index: int, t_usec: int) -> Vector2:
	var leaf: Leaf = _leaves[index]
	var fallen: int = clampi(t_usec - leaf.drop_usec, 0, FALL_USEC)
	var swing: float = TAU * float(fallen) / leaf.sway_period_usec + leaf.sway_phase
	var x: float = leaf.x + leaf.sway_px * (sin(swing) - sin(leaf.sway_phase))
	return Vector2(x, lerpf(leaf.top_y, GROUND_Y, float(fallen) / FALL_USEC))

## Whether leaf `index` is in the air at `t`: dropped and not yet on the ground.
func is_airborne(index: int, t_usec: int) -> bool:
	var leaf: Leaf = _leaves[index]
	return t_usec >= leaf.drop_usec and t_usec < leaf.drop_usec + FALL_USEC

## Whether leaf `index` has reached the ground by `t`.
func is_on_ground(index: int, t_usec: int) -> bool:
	return t_usec >= _leaves[index].drop_usec + FALL_USEC

## Whether leaf `index` has been judged, caught or landed.
func is_judged(index: int) -> bool:
	return _judged[index]

## When the set ends: once every leaf is judged, and not before its last rep's
## slot is over. -1 until then.
func get_end_usec() -> int:
	if _judgements.size() < _reps:
		return -1
	var last: int = 0
	for judgement: Judgement in _judgements:
		last = maxi(last, judgement.at_usec)
	return maxi(last, _reps * _rep_usec)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Judges, in order, every leaf nobody caught that landed by `t`.
func _settle(t: int) -> Array[Judgement]:
	var judged: Array[Judgement] = []
	for index: int in _leaves.size():
		var landing: int = _leaves[index].drop_usec + FALL_USEC
		if not _judged[index] and landing <= t:
			_judged[index] = true
			judged.append(_record_rep(index, DrillRules.Tier.MISS, Miss.LANDED, 0.0, landing, leaf_position(index, landing)))
	return judged
