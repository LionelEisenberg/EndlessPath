class_name ZoneAtmosphere
extends CanvasLayer

## ZoneAtmosphere
## Drops vignette + drifting mist + spirit motes onto a view.
## Drop this scene as a child of a Node2D root (e.g. ZoneTilemap or AdventureTilemap).

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

const MIST_DRIFT_RANGE := Vector2(60, 40)
const MIST_DRIFT_DURATION := 14.0

# Smoke spritesheet frame animation settings.
# mist_sheet.png is a 7x7 grid (49 cells) with 45 valid frames (0..44);
# the last 4 cells in the bottom-right corner are empty.
const SMOKE_MAX_FRAME := 44
const SMOKE_FPS := 12.0

var _frame_time: float = 0.0

func _ready() -> void:
	_start_mist_drift(_mist_a, 0.0)
	_start_mist_drift(_mist_b, MIST_DRIFT_DURATION * 0.33)
	_start_mist_drift(_mist_c, MIST_DRIFT_DURATION * 0.66)

func _process(delta: float) -> void:
	_frame_time += delta
	var base := _frame_time * SMOKE_FPS
	# Phase-offset each sprite so they never show the same frame simultaneously.
	# pingpong() bounces 0 → SMOKE_MAX_FRAME → 0 so the "dense → dispersed" cycle
	# reverses smoothly instead of popping back to frame 0.
	_mist_a.frame = int(pingpong(base, SMOKE_MAX_FRAME))
	_mist_b.frame = int(pingpong(base + 15.0, SMOKE_MAX_FRAME))
	_mist_c.frame = int(pingpong(base + 30.0, SMOKE_MAX_FRAME))

func _start_mist_drift(mist: Sprite2D, delay: float) -> void:
	if not mist:
		return
	var origin := mist.position
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(mist, "position", origin + MIST_DRIFT_RANGE, MIST_DRIFT_DURATION * 0.5)
	tween.tween_property(mist, "position", origin, MIST_DRIFT_DURATION * 0.5)
