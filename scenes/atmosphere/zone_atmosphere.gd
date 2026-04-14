class_name ZoneAtmosphere
extends CanvasLayer

## ZoneAtmosphere
## Drops vignette + drifting mist + spirit motes onto a view.
## Drop this scene as a child of a Node2D root (e.g. ZoneTilemap or AdventureTilemap).

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

# Each mist wanders randomly within a bounding box around its spawn
# position. Per-sprite radius and duration ranges give each layer a
# distinct character — MistA is a big slow mass, MistC is a small quick
# wisp — while the random target picking keeps the motion unpredictable.
const MIST_A_DRIFT_RADIUS := Vector2(220, 130)
const MIST_A_MIN_DURATION := 5.0
const MIST_A_MAX_DURATION := 14.0

const MIST_B_DRIFT_RADIUS := Vector2(160, 95)
const MIST_B_MIN_DURATION := 3.0
const MIST_B_MAX_DURATION := 10.0

const MIST_C_DRIFT_RADIUS := Vector2(130, 75)
const MIST_C_MIN_DURATION := 2.0
const MIST_C_MAX_DURATION := 7.0

# mist_sheet.png is a 7x7 grid (49 cells) with 45 valid frames (0..44);
# the last 4 cells in the bottom-right corner are empty.
const SMOKE_MAX_FRAME := 44

var _mist_a_origin: Vector2
var _mist_b_origin: Vector2
var _mist_c_origin: Vector2

func _ready() -> void:
	# Pick a random smoke shape for each sprite on scene load. We don't
	# animate through frames because the spritesheet is authored as
	# "dense → dispersed" and playing it in either direction reads as
	# unnatural smoke motion.
	_mist_a.frame = randi_range(0, SMOKE_MAX_FRAME)
	_mist_b.frame = randi_range(0, SMOKE_MAX_FRAME)
	_mist_c.frame = randi_range(0, SMOKE_MAX_FRAME)

	# Remember each mist's spawn point — all random targets are offsets
	# from this origin so the mists don't wander permanently away.
	_mist_a_origin = _mist_a.position
	_mist_b_origin = _mist_b.position
	_mist_c_origin = _mist_c.position

	# Kick off three independent drift coroutines. Each call runs
	# asynchronously (non-blocking) so all three start immediately.
	_drift_mist_randomly(_mist_a, _mist_a_origin, MIST_A_DRIFT_RADIUS, MIST_A_MIN_DURATION, MIST_A_MAX_DURATION)
	_drift_mist_randomly(_mist_b, _mist_b_origin, MIST_B_DRIFT_RADIUS, MIST_B_MIN_DURATION, MIST_B_MAX_DURATION)
	_drift_mist_randomly(_mist_c, _mist_c_origin, MIST_C_DRIFT_RADIUS, MIST_C_MIN_DURATION, MIST_C_MAX_DURATION)

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
