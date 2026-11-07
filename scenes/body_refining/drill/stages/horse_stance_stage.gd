class_name HorseStanceStage
extends DrillStage

## HorseStanceStage
## Horse Stance's scene: the figure with its hips and legs rimmed in brass, the
## stance gauge over it, and an incense stick that counts the set, not seconds
## (#143): it burns only while the needle is in the arc, a tenth of the stick a
## rep, and is whole again for the next set. It draws its HorseStanceRun: the
## needle at the run's depth and the arc where the run has it, lit in brass while a
## rep's needle is in it and in tan otherwise (two gauges, one showing). A rep's
## tier pops over the gauge's deep end and its pellets leave from the needle's tip.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The gauge's top left, its hub in the gauge's px, and how far from the hub the
## needle's tip stands.
const GAUGE_AT: Vector2 = Vector2(82, 250)
const HUB: Vector2 = Vector2(180, 186)
const TIP_PX: float = 150.0
## The incense stick's foot, its height while the whole set is left, and how far
## over its top the ember stands; it burns down in 2 px steps.
const STICK_FOOT_Y: float = 248.0
const STICK_FULL_PX: float = 188.0
const EMBER_RISE: float = 18.0
## The ember flickers through its strip, a frame each EMBER_FRAME_USEC.
const EMBER_FRAMES: int = 3
const EMBER_FRAME_USEC: int = 200_000
## Where a rep's tier pops.
const FLOATER_ANCHOR: Vector2 = Vector2(340, 236)

const PROGRESS: StringName = &"progress"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _gauge_lit: TextureRect = %GaugeLit
@onready var _gauge_dim: TextureRect = %GaugeDim
@onready var _needle: ColorRect = %Needle
@onready var _stick: TextureRect = %IncenseStick
@onready var _ember: LacquerStripRect = %IncenseEmber

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## How many reps a set of the drill has: the incense burns a tenth of its stick
## each, for ten.
var _reps: int = 10

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Reads how many reps a set of `drill` has, for the incense.
func setup(drill: DrillData) -> void:
	_reps = maxi(drill.reps_per_set, 1)

## The needle standing, the arc at the top where each rep starts, and the incense
## whole.
func show_rest() -> void:
	_draw_gauge(0.0, HorseStanceRun.BAND_START, false)
	_draw_incense(0.0)

## The needle and the arc where `run` has them at `t_usec`, brass while a rep's
## needle is in the arc, and the incense burnt down by the reps that landed and the
## hold of the rep in play.
func show_run(run: DrillRun, t_usec: int) -> void:
	var stance := run as HorseStanceRun
	var inside: bool = stance.is_rep_in_play() and stance.is_inside_at(t_usec)
	_draw_gauge(stance.marker_at(t_usec), stance.band_centre_at(t_usec), inside)
	_draw_incense((stance.get_judged_count() + stance.hold_progress()) / _reps)

## The ember flickers.
func tick(now_usec: int) -> void:
	@warning_ignore("integer_division")
	_ember.set_frame((now_usec / EMBER_FRAME_USEC) % EMBER_FRAMES)

## Over the gauge's deep end.
func get_floater_anchor(_judgement: DrillRun.Judgement) -> Vector2:
	return FLOATER_ANCHOR

## The needle's tip where the rep left it.
func get_pellet_origin(judgement: DrillRun.Judgement) -> Vector2:
	return needle_tip(judgement.height)

## Where the needle's tip stands at `depth` (0 standing, 1 the deepest stance), in
## the stage's px.
static func needle_tip(depth: float) -> Vector2:
	var angle: float = PI * (1.0 - depth)
	return GAUGE_AT + HUB + Vector2(cos(angle), -sin(angle)) * TIP_PX

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The needle at `depth`, the arc centred at `band_centre`, and the gauge lit
## while `inside`.
func _draw_gauge(depth: float, band_centre: float, inside: bool) -> void:
	(_needle.material as ShaderMaterial).set_shader_parameter(PROGRESS, depth)
	(_gauge_lit.material as ShaderMaterial).set_shader_parameter(PROGRESS, band_centre)
	(_gauge_dim.material as ShaderMaterial).set_shader_parameter(PROGRESS, band_centre)
	_gauge_lit.visible = inside
	_gauge_dim.visible = not inside

## The stick burnt down by `burnt` of its height, 0 to 1, with the ember on its top.
func _draw_incense(burnt: float) -> void:
	var height: float = snappedf(STICK_FULL_PX * (1.0 - clampf(burnt, 0.0, 1.0)), 2.0)
	_stick.position.y = STICK_FOOT_Y - height
	_stick.size.y = height
	_ember.position.y = STICK_FOOT_Y - height - EMBER_RISE
