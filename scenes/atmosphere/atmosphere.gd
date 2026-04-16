class_name Atmosphere
extends CanvasLayer

## Atmosphere
## Unified atmosphere layer: vignette + drifting mist sprites + spirit mote
## particles. Instance this scene under any Node2D root (ZoneTilemap,
## AdventureTilemap, etc.) and tune the exported properties per instance
## to get different flavors (zone-wide vs adventure-tight, etc.).
##
## Tunable via @export:
##   Vignette: radius, softness, color
##   Mist A/B/C: drift radius, min/max duration
##   Motes: cyan and warm particle counts
##
## Further per-instance tweaks (modulate colors, particle material scales,
## textures) can be applied via "Editable Children" on the scene instance.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Vignette")
@export_range(0.0, 1.5) var vignette_radius: float = 0.55
@export_range(0.0, 1.0) var vignette_softness: float = 0.4
@export var vignette_color: Color = Color(0.0, 0.01, 0.04, 1.0)

@export_group("Mist A Drift")
@export var mist_a_drift_radius: Vector2 = Vector2(220, 130)
@export_range(0.5, 30.0) var mist_a_min_duration: float = 5.0
@export_range(0.5, 30.0) var mist_a_max_duration: float = 14.0

@export_group("Mist B Drift")
@export var mist_b_drift_radius: Vector2 = Vector2(160, 95)
@export_range(0.5, 30.0) var mist_b_min_duration: float = 3.0
@export_range(0.5, 30.0) var mist_b_max_duration: float = 10.0

@export_group("Mist C Drift")
@export var mist_c_drift_radius: Vector2 = Vector2(220, 130)
@export_range(0.5, 30.0) var mist_c_min_duration: float = 2.0
@export_range(0.5, 30.0) var mist_c_max_duration: float = 7.0

@export_group("Motes")
@export_range(0, 300) var cyan_mote_count: int = 60
@export_range(0, 300) var warm_mote_count: int = 30

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC
@onready var _mote_cyan: GPUParticles2D = %MoteParticlesCyan
@onready var _mote_warm: GPUParticles2D = %MoteParticlesWarm
@onready var _vignette_rect: ColorRect = %VignetteRect

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

# mist_sheet.png is a 7x7 grid (49 cells) with 45 valid frames (0..44);
# the last 4 cells in the bottom-right corner are empty.
const SMOKE_MAX_FRAME := 44

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _mist_a_origin: Vector2
var _mist_b_origin: Vector2
var _mist_c_origin: Vector2

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply_vignette_exports()
	_apply_mote_exports()
	_randomize_mist_frames()
	_capture_mist_origins()
	_start_mist_drift_coroutines()

#-----------------------------------------------------------------------------
# INIT HELPERS
#-----------------------------------------------------------------------------

## Duplicates the vignette material so per-instance shader params don't bleed
## between instances, then applies the exported vignette settings.
func _apply_vignette_exports() -> void:
	if _vignette_rect == null or _vignette_rect.material == null:
		return
	var mat := _vignette_rect.material.duplicate() as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("vignette_radius", vignette_radius)
	mat.set_shader_parameter("vignette_softness", vignette_softness)
	mat.set_shader_parameter("vignette_color", vignette_color)
	_vignette_rect.material = mat

func _apply_mote_exports() -> void:
	if _mote_cyan:
		_mote_cyan.amount = cyan_mote_count
	if _mote_warm:
		_mote_warm.amount = warm_mote_count

## Picks a random smoke shape per sprite on scene load. We don't animate
## through frames because the spritesheet is authored as "dense → dispersed"
## and playing it in either direction reads as unnatural smoke motion.
func _randomize_mist_frames() -> void:
	if _mist_a:
		_mist_a.frame = randi_range(0, SMOKE_MAX_FRAME)
	if _mist_b:
		_mist_b.frame = randi_range(0, SMOKE_MAX_FRAME)
	if _mist_c:
		_mist_c.frame = randi_range(0, SMOKE_MAX_FRAME)

## Remembers each mist's spawn point — all random targets are offsets from
## this origin so the mists don't wander permanently off-screen.
func _capture_mist_origins() -> void:
	if _mist_a:
		_mist_a_origin = _mist_a.position
	if _mist_b:
		_mist_b_origin = _mist_b.position
	if _mist_c:
		_mist_c_origin = _mist_c.position

## Kicks off three independent drift coroutines. Each call runs
## asynchronously (non-blocking) so all three start immediately.
func _start_mist_drift_coroutines() -> void:
	_drift_mist_randomly(_mist_a, _mist_a_origin, mist_a_drift_radius, mist_a_min_duration, mist_a_max_duration)
	_drift_mist_randomly(_mist_b, _mist_b_origin, mist_b_drift_radius, mist_b_min_duration, mist_b_max_duration)
	_drift_mist_randomly(_mist_c, _mist_c_origin, mist_c_drift_radius, mist_c_min_duration, mist_c_max_duration)

#-----------------------------------------------------------------------------
# DRIFT COROUTINE
#-----------------------------------------------------------------------------

## Continuously drifts a mist sprite toward random points within a bounding
## box around its origin. Each segment has a random duration and random
## target — no two segments are identical. Runs as a coroutine until the
## sprite is freed with the scene.
func _drift_mist_randomly(mist: Sprite2D, origin: Vector2, radius: Vector2, min_duration: float, max_duration: float) -> void:
	if not mist:
		return
	while is_instance_valid(mist):
		var target := origin + Vector2(
			randf_range(-radius.x, radius.x),
			randf_range(-radius.y, radius.y)
		)
		var duration := randf_range(min_duration, max_duration)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(mist, "position", target, duration)
		await tween.finished
