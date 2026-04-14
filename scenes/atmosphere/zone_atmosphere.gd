class_name ZoneAtmosphere
extends CanvasLayer

## ZoneAtmosphere
## Drops vignette + drifting mist + spirit motes onto a view.
## Drop this scene as a child of a Node2D root (e.g. ZoneTilemap or AdventureTilemap).

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

# Each mist has its own drift vector and duration so the three layers
# never feel mechanically synchronized. Drift offsets point in different
# directions (down-right / down-left / up-right) so no two sprites are
# tracing parallel paths.
const MIST_A_DRIFT := Vector2(180, 100)
const MIST_A_DURATION := 18.0

const MIST_B_DRIFT := Vector2(-120, 60)
const MIST_B_DURATION := 10.0

const MIST_C_DRIFT := Vector2(140, -40)
const MIST_C_DURATION := 7.0

# Smoke spritesheet frame animation settings.
# mist_sheet.png is a 7x7 grid (49 cells) with 45 valid frames (0..44);
# the last 4 cells in the bottom-right corner are empty.
const SMOKE_MAX_FRAME := 44
const SMOKE_FPS_A := 9.0    # slow billow
const SMOKE_FPS_B := 13.0   # medium
const SMOKE_FPS_C := 16.0   # fast dispersal

var _frame_time: float = 0.0

func _ready() -> void:
	_start_mist_drift(_mist_a, 0.0, MIST_A_DRIFT, MIST_A_DURATION)
	_start_mist_drift(_mist_b, MIST_B_DURATION * 0.4, MIST_B_DRIFT, MIST_B_DURATION)
	_start_mist_drift(_mist_c, MIST_C_DURATION * 0.6, MIST_C_DRIFT, MIST_C_DURATION)

func _process(delta: float) -> void:
	_frame_time += delta
	# Each mist cycles smoke frames at a different rate so they never sync.
	# pingpong() bounces 0 → SMOKE_MAX_FRAME → 0 so the "dense → dispersed"
	# loop reverses smoothly instead of popping back to frame 0.
	_mist_a.frame = int(pingpong(_frame_time * SMOKE_FPS_A, SMOKE_MAX_FRAME))
	_mist_b.frame = int(pingpong(_frame_time * SMOKE_FPS_B + 15.0, SMOKE_MAX_FRAME))
	_mist_c.frame = int(pingpong(_frame_time * SMOKE_FPS_C + 30.0, SMOKE_MAX_FRAME))

func _start_mist_drift(mist: Sprite2D, delay: float, drift_offset: Vector2, duration: float) -> void:
	if not mist:
		return
	var origin := mist.position
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(mist, "position", origin + drift_offset, duration * 0.5)
	tween.tween_property(mist, "position", origin, duration * 0.5)
