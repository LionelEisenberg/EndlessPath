class_name HorseStanceStage
extends DrillStage

## HorseStanceStage
## Horse Stance's scene: the figure with its hips and legs rimmed in brass, the
## stance gauge over it, and an incense stick burning down over the set with the
## seconds left under it. It draws its HorseStanceRun: the needle at the run's
## depth and the arc where the run has it, lit in brass while the needle is in it
## and in tan while out (two gauges, one showing). A rep's tier pops over the
## gauge's deep end and its pellets leave from the needle's tip.

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
const SECONDS_FORMAT: String = "%d s"
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
@onready var _seconds: Label = %Seconds

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## How long a set of the drill runs, in microseconds.
var _set_usec: int = 0

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Reads how long a set of `drill` runs, for the incense.
func setup(drill: DrillData) -> void:
	_set_usec = roundi(drill.rep_seconds * 1_000_000.0) * drill.reps_per_set

## The needle standing, the arc where a set starts, and the incense whole.
func show_rest() -> void:
	_draw_gauge(0.0, HorseStanceRun.BAND_START, false)
	_draw_incense(_set_usec)

## The needle and the arc where `run` has them at `t_usec`, and the incense burnt
## down to what is left of the set.
func show_run(run: DrillRun, t_usec: int) -> void:
	var stance := run as HorseStanceRun
	_draw_gauge(stance.marker_at(t_usec), stance.band_centre_at(t_usec), stance.is_inside_at(t_usec))
	_draw_incense(maxi(0, _set_usec - t_usec))

## The ember flickers.
func tick(now_usec: int) -> void:
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

## The stick burnt down to what is left of the set, the ember on its top, and the
## seconds left under it.
func _draw_incense(left_usec: int) -> void:
	var share: float = float(left_usec) / _set_usec if _set_usec > 0 else 1.0
	var height: float = snappedf(STICK_FULL_PX * share, 2.0)
	_stick.position.y = STICK_FOOT_Y - height
	_stick.size.y = height
	_ember.position.y = STICK_FOOT_Y - height - EMBER_RISE
	_seconds.text = SECONDS_FORMAT % ceili(left_usec / 1_000_000.0)
