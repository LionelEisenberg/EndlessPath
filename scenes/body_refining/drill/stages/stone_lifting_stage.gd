class_name StoneLiftingStage
extends DrillStage

## StoneLiftingStage
## Stone Lifting's scene (#100): the carved figure with its arms rimmed in brass, a
## carved track with the stone riding a jade column up it, and the tiers' marks on
## rails beside it. The base is the part judged (#148): a brass sill along it reaches
## out to the rails, and a brass band crosses the track at the rails' brass, lit
## while a release would score Perfect. It draws its StoneLiftingRun: the stone
## rising while held, resting where a rep stopped it, then setting down. A judged
## rep leaves a line in its tier's colour where the base stopped, until the next
## lift. A rep's tier pops beside the stone and its pellets leave from the stone's
## middle.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The stone's base at rest, where it meets the jade, and its travel to the top,
## in the stage's px; it moves in 2 px steps.
const REST_BASE_Y: float = 492.0
const TRAVEL_PX: float = 400.0
const STONE_HEIGHT: float = 56.0
## Where the tier word pops, from the stone's top left (its left arm's tip).
const FLOATER_OFFSET: Vector2 = Vector2(96, 6)
## How far above the base the stop mark's top stands.
const STOP_MARK_RISE: float = 2.0
## The band's frames, dim and lit.
const BAND_DIM: int = 0
const BAND_LIT: int = 1
## The stop mark's frame for each tier: red, tan, cream, brass (Auto's is brass).
const STOP_MARK_FRAMES: Dictionary[DrillRules.Tier, int] = {
	DrillRules.Tier.MISS: 0,
	DrillRules.Tier.OK: 1,
	DrillRules.Tier.GOOD: 2,
	DrillRules.Tier.PERFECT: 3,
	DrillRules.Tier.AUTO: 3,
}

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _stone: TextureRect = %Stone
@onready var _fill: NinePatchRect = %Fill
@onready var _band: LacquerStripRect = %Band
@onready var _stop_mark: LacquerStripRect = %StopMark

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The stone at rest, the band dim and no stop mark.
func show_rest() -> void:
	_draw_stone(0.0)
	_band.set_frame(BAND_DIM)
	_stop_mark.visible = false

## The stone where `run` has it at `t_usec`, the band lit while a release would
## score Perfect, and the last stop mark gone once a lift is in progress.
func show_run(run: DrillRun, t_usec: int) -> void:
	var stone := run as StoneLiftingRun
	_draw_stone(stone.height_at(t_usec))
	_band.set_frame(BAND_LIT if stone.release_tier_at(t_usec) == DrillRules.Tier.PERFECT else BAND_DIM)
	if stone.is_lifting():
		_stop_mark.visible = false

## The stone where the rep stopped it, and a line in its tier's colour where its
## base stopped. A stone that dropped or was never lifted leaves none.
func show_judgement(judgement: DrillRun.Judgement) -> void:
	_draw_stone(judgement.height)
	_band.set_frame(BAND_DIM)
	var marked: bool = judgement.miss != DrillRun.Miss.DROPPED and judgement.miss != DrillRun.Miss.TOO_LATE
	_stop_mark.visible = marked
	if marked:
		_stop_mark.set_frame(STOP_MARK_FRAMES[judgement.tier])
		_stop_mark.position.y = base_y(judgement.height) - STOP_MARK_RISE

## Beside the stone.
func get_floater_anchor(_judgement: DrillRun.Judgement) -> Vector2:
	return _stone.position + FLOATER_OFFSET

## The stone's middle.
func get_pellet_origin(_judgement: DrillRun.Judgement) -> Vector2:
	return _stone.position + _stone.size / 2.0

## Where the stone's base stands at `height` of its travel (0 at rest, 1 at the
## top), on the 2 px grid, in the stage's px.
static func base_y(height: float) -> float:
	return REST_BASE_Y - snappedf(height * TRAVEL_PX, 2.0)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Stands the stone at `height` of its travel, with the jade from its base down
## to the rest line.
func _draw_stone(height: float) -> void:
	var base: float = base_y(height)
	_stone.position.y = base - STONE_HEIGHT
	_fill.position.y = base
	_fill.size.y = REST_BASE_Y - base
