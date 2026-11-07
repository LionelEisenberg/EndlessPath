class_name FallingLeafStage
extends DrillStage

## FallingLeafStage
## Falling Leaf's scene: a branch across the top, the figure with its hands and
## legs rimmed in brass, and a ground line. It draws its FallingLeafRun: the leaf a
## shake would drop hanging golden under the branch where it will drop (#143: the
## first at the branch's middle before a set), each leaf from its drop, swaying down
## with the dotted trail of its swing (a FallingLeaf each); a caught leaf turns into
## its pellets, gone, and the brass ring snaps where the click came for RING_USEC; a
## leaf that slipped away or that nobody caught lies where it landed until the set
## ends. A rep's tier pops beside where it was decided, on the side of the stage
## with room for it, and a catch's pellets leave from the ring.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier

## How long the catch's ring shows.
const RING_USEC: int = 500_000
## Half the ring, from its middle to its corner.
const HALF_RING: Vector2 = Vector2(22, 22)
## A rep's tier pops FLOATER_GAP to the right of where it was decided, or, right
## of the stage's middle, FLOATER_GAP plus FLOATER_ROOM to the left of it, so the
## longest line fits on the stage; FLOATER_RISE above it, higher for a leaf on the
## ground so it clears the beads.
const FLOATER_GAP: float = 34.0
const FLOATER_ROOM: float = 160.0
const FLOATER_RISE: float = 40.0
const LANDED_FLOATER_RISE: float = 110.0

const GRID: Vector2 = Vector2(2, 2)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _leaves_box: Control = %Leaves
@onready var _ring: TextureRect = %CatchRing

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _leaves: Array[FallingLeaf] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for child: Node in _leaves_box.get_children():
		_leaves.append(child as FallingLeaf)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## No ring, and the set's first leaf hanging at the branch's middle: the branch
## waits for the press that shakes it.
func show_rest() -> void:
	for leaf: FallingLeaf in _leaves:
		leaf.visible = false
	_ring.visible = false
	if not _leaves.is_empty():
		var x: float = FallingLeafRun.FIRST_DROP_X
		_leaves[0].show_hanging(Vector2(x, FallingLeafRun.BRANCH_Y_AT_0 + x * FallingLeafRun.BRANCH_SLOPE))

## The leaf a shake would drop hanging under the branch, each other leaf where
## `run` has it at `t_usec`, and the ring of a catch made in the last RING_USEC.
func show_run(run: DrillRun, t_usec: int) -> void:
	var fall := run as FallingLeafRun
	var caught: Dictionary = {}
	var ring_shows: bool = false
	var ring_at: Vector2 = Vector2.ZERO
	for judgement: DrillRun.Judgement in run.get_judgements():
		if judgement.tier != Tier.MISS:
			caught[judgement.rep] = true
			if t_usec - judgement.at_usec < RING_USEC:
				ring_shows = true
				ring_at = judgement.point
	var hanging: int = fall.hanging_leaf_at(t_usec)
	for index: int in _leaves.size():
		var leaf: FallingLeaf = _leaves[index]
		if index >= fall.get_leaf_count() or caught.has(index):
			leaf.visible = false
		elif fall.is_airborne(index, t_usec):
			leaf.show_falling(fall, index, t_usec)
		elif fall.is_on_ground(index, t_usec):
			leaf.show_landed(fall.leaf_position(index, t_usec))
		elif index == hanging:
			leaf.show_hanging(fall.leaf_position(index, t_usec))
		else:
			leaf.visible = false
	_ring.visible = ring_shows
	if ring_shows:
		_ring.position = (ring_at - HALF_RING).snapped(GRID)

## Beside where the rep was decided, on the side with room.
func get_floater_anchor(judgement: DrillRun.Judgement) -> Vector2:
	var x: float = judgement.point.x + FLOATER_GAP
	if judgement.point.x > size.x / 2.0:
		x = judgement.point.x - FLOATER_GAP - FLOATER_ROOM
	var rise: float = LANDED_FLOATER_RISE if judgement.miss == DrillRun.Miss.LANDED else FLOATER_RISE
	return Vector2(x, judgement.point.y - rise).snapped(GRID)

## Where the click came: the ring.
func get_pellet_origin(judgement: DrillRun.Judgement) -> Vector2:
	return judgement.point
