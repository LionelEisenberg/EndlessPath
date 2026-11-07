class_name StoneLiftingStage
extends DrillStage

## StoneLiftingStage
## Stone Lifting's scene (#100): the carved figure with its arms rimmed in brass, a
## carved track with the stone riding a jade column up it, and the tiers' marks on
## rails beside it. It draws its StoneLiftingRun: the stone rising while held,
## resting where a rep stopped it, then setting down. A rep's tier pops beside the
## stone and its pellets leave from the stone's middle.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The stone's base at rest, where it meets the jade, and its travel to the top,
## in the stage's px; it moves in 2 px steps.
const REST_BASE_Y: float = 492.0
const TRAVEL_PX: float = 400.0
const STONE_HEIGHT: float = 56.0
## Where the tier word pops, from the stone's top left.
const FLOATER_OFFSET: Vector2 = Vector2(84, 6)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _stone: TextureRect = %Stone
@onready var _fill: NinePatchRect = %Fill

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The stone at rest.
func show_rest() -> void:
	_draw_stone(0.0)

## The stone where `run` has it at `t_usec`.
func show_run(run: DrillRun, t_usec: int) -> void:
	_draw_stone((run as StoneLiftingRun).height_at(t_usec))

## The stone where the rep stopped it.
func show_judgement(judgement: DrillRun.Judgement) -> void:
	_draw_stone(judgement.height)

## Beside the stone.
func get_floater_anchor(_judgement: DrillRun.Judgement) -> Vector2:
	return _stone.position + FLOATER_OFFSET

## The stone's middle.
func get_pellet_origin(_judgement: DrillRun.Judgement) -> Vector2:
	return _stone.position + _stone.size / 2.0

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Stands the stone at `height` of its travel (0 at rest, 1 at the top), on the
## 2 px grid, with the jade from its base down to the rest line.
func _draw_stone(height: float) -> void:
	var base: float = REST_BASE_Y - snappedf(height * TRAVEL_PX, 2.0)
	_stone.position.y = base - STONE_HEIGHT
	_fill.position.y = base
	_fill.size.y = REST_BASE_Y - base
