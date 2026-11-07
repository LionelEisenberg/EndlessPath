class_name WaterfallStage
extends DrillStage

## WaterfallStage
## Waterfall Tempering's scene: a close-up under the falls, the figure's head and
## shoulders rimmed in brass, the falls streaming down in 2 px steps, and a brass
## brace line over the head between two rails marked with the tiers' windows at
## the surges' speed. It draws its WaterfallRun: each rep's surge of foam rides
## down the falls from its rep's start and lands on the line at its target. A surge
## braced with a scored press is gone, and the line rings: brass and swelling for
## a Perfect or Good press, tan for an OK one. Any other surge crashes through the
## line. A rep's tier pops beside the line and its pellets leave from the line's
## middle.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier

## The brace line, where a surge's middle lands.
const LINE_Y: float = 472.0
## How far over the line a surge starts, WaterfallRun.LEAD_USEC before it lands: it
## rides 280 px a second, the speed the rails' marks are drawn at.
const LEAD_PX: float = 420.0
## How far under the line a surge nobody braced against falls before it is gone.
const CRASH_PX: float = 60.0
const SURGE_HALF_HEIGHT: float = 16.0
## The falls stream a frame of their strip each FALLS_FRAME_USEC.
const FALLS_FRAMES: int = 4
const FALLS_FRAME_USEC: int = 100_000
## The ring of a braced surge: the brass ring swelling through BRASS_RING_FRAMES of
## the strip for a Perfect or Good press, the tan ring for an OK one, a frame each
## RING_FRAME_USEC.
const BRASS_RING_FRAMES: Array[int] = [0, 2, 3]
const TAN_RING_FRAME: int = 1
const RING_FRAME_USEC: int = 80_000
## Where a rep's tier pops, and where its pellets leave from: the line's middle.
const FLOATER_ANCHOR: Vector2 = Vector2(372, 402)
const PELLET_ORIGIN: Vector2 = Vector2(262, 472)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _falls: LacquerStripRect = %Falls
@onready var _surge: TextureRect = %Surge
@onready var _ring: LacquerStripRect = %Ring

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The first surge waiting at the top of the falls, and no ring.
func show_rest() -> void:
	_surge.visible = true
	_draw_surge(LEAD_PX)
	_ring.visible = false

## The surge of the rep in play where `run` has it at `t_usec`, and the ring of a
## surge braced in the last moments.
func show_run(run: DrillRun, t_usec: int) -> void:
	var falls := run as WaterfallRun
	var judgements: Array[DrillRun.Judgement] = run.get_judgements()
	var rep: int = run.rep_at(t_usec)
	var landing: int = falls.target_usec(rep)
	var above: float = float(landing - t_usec) * LEAD_PX / WaterfallRun.LEAD_USEC
	var braced: bool = rep < judgements.size() and judgements[rep].tier != Tier.MISS
	_surge.visible = t_usec >= landing - WaterfallRun.LEAD_USEC and not braced and above >= -CRASH_PX
	if _surge.visible:
		_draw_surge(above)
	_ring.visible = false
	if not judgements.is_empty():
		var last: DrillRun.Judgement = judgements[judgements.size() - 1]
		@warning_ignore("integer_division")
		var frame: int = (t_usec - last.at_usec) / RING_FRAME_USEC
		if last.tier != Tier.MISS and frame < BRASS_RING_FRAMES.size():
			_ring.visible = true
			_ring.set_frame(TAN_RING_FRAME if last.tier == Tier.OK else BRASS_RING_FRAMES[frame])

## The falls stream.
func tick(now_usec: int) -> void:
	@warning_ignore("integer_division")
	_falls.set_frame((now_usec / FALLS_FRAME_USEC) % FALLS_FRAMES)

## Beside the line.
func get_floater_anchor(_judgement: DrillRun.Judgement) -> Vector2:
	return FLOATER_ANCHOR

## The line's middle.
func get_pellet_origin(_judgement: DrillRun.Judgement) -> Vector2:
	return PELLET_ORIGIN

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Stands the surge with its middle `above` px over the line (under it when
## negative), on the 2 px grid.
func _draw_surge(above: float) -> void:
	_surge.position.y = snappedf(LINE_Y - above - SURGE_HALF_HEIGHT, 2.0)
