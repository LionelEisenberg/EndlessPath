class_name FallingLeaf
extends Control

## FallingLeaf
## One leaf on Falling Leaf's stage, with the dotted trail of its swing behind it
## so the player can lead it. FallingLeafStage stands it every frame: hanging
## golden under the branch while a shake would drop it (#143); falling, tilted the
## way it swings, a trail dot wherever it was each TRAIL_STEP_USEC back since its
## drop; lying where it landed; or hidden. Its pieces stand in the stage's px.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How far back in its fall each trail dot stands from the next.
const TRAIL_STEP_USEC: int = 100_000
## How far ahead the leaf looks to see which way it swings.
const SWING_LOOK_USEC: int = 10_000
## Half the leaf's frame and half a trail dot, from their middles to their corners.
const HALF_LEAF: Vector2 = Vector2(16, 16)
const HALF_DOT: Vector2 = Vector2(2, 2)
## The leaf strip's frames: tilted as it swings right or left, golden as it hangs
## ready to drop, and lying flat.
const SWING_RIGHT_FRAME: int = 0
const SWING_LEFT_FRAME: int = 1
const HANGING_FRAME: int = 2
const LANDED_FRAME: int = 3

const GRID: Vector2 = Vector2(2, 2)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _leaf: LacquerStripRect = %Leaf
@onready var _trail: Control = %Trail

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows leaf `index` of `run` falling at `t_usec`, tilted the way it swings, with
## the dots of its trail since its drop.
func show_falling(run: FallingLeafRun, index: int, t_usec: int) -> void:
	visible = true
	var at: Vector2 = run.leaf_position(index, t_usec)
	var swings_right: bool = run.leaf_position(index, t_usec + SWING_LOOK_USEC).x >= at.x
	_leaf.set_frame(SWING_RIGHT_FRAME if swings_right else SWING_LEFT_FRAME)
	_leaf.position = (at - HALF_LEAF).snapped(GRID)
	_trail.visible = true
	var back: int = t_usec
	for dot: Control in _trail.get_children():
		back -= TRAIL_STEP_USEC
		dot.visible = run.is_airborne(index, back)
		if dot.visible:
			dot.position = (run.leaf_position(index, back) - HALF_DOT).snapped(GRID)

## Shows the leaf hanging golden at `point`, under the branch, with no trail.
func show_hanging(point: Vector2) -> void:
	visible = true
	_leaf.set_frame(HANGING_FRAME)
	_leaf.position = (point - HALF_LEAF).snapped(GRID)
	_trail.visible = false

## Shows the leaf lying flat at `point`, where it landed, with no trail.
func show_landed(point: Vector2) -> void:
	visible = true
	_leaf.set_frame(LANDED_FRAME)
	_leaf.position = (point - HALF_LEAF).snapped(GRID)
	_trail.visible = false
