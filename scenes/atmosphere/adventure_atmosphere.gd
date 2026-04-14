class_name AdventureAtmosphere
extends CanvasLayer

## AdventureAtmosphere
## Same as ZoneAtmosphere but tuned for adventure view: slightly tighter
## vignette, fewer mist sprites, motes weighted toward cyan.

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

const MIST_DRIFT_RANGE := Vector2(50, 30)
const MIST_DRIFT_DURATION := 12.0

func _ready() -> void:
	_start_mist_drift(_mist_a, 0.0)
	_start_mist_drift(_mist_b, MIST_DRIFT_DURATION * 0.4)
	_start_mist_drift(_mist_c, MIST_DRIFT_DURATION * 0.7)

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
