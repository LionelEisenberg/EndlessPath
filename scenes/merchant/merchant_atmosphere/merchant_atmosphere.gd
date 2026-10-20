class_name MerchantAtmosphere
extends Control

## MerchantAtmosphere
## The shop's ethereal layer behind its content: a soft top light, drifting
## mist (the Atmosphere scene's mist_sheet.png) and floating motes. Colours
## come from the MerchantAtmosphere type of the shop's zone theme, so each
## zone tints the same layer differently.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const THEME_TYPE := &"MerchantAtmosphere"

# mist_sheet.png is a 7x7 grid with 45 valid frames (0..44), as in Atmosphere.
const MIST_MAX_FRAME := 44

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var mist_drift_radius: Vector2 = Vector2(120, 80)
@export_range(0.5, 30.0) var mist_min_duration: float = 6.0
@export_range(0.5, 30.0) var mist_max_duration: float = 14.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _top_light: TextureRect = %TopLight
@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC
@onready var _motes_primary: GPUParticles2D = %MotesPrimary
@onready var _motes_secondary: GPUParticles2D = %MotesSecondary

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply_theme_colours()
	for mist: Sprite2D in [_mist_a, _mist_b, _mist_c]:
		mist.frame = randi_range(0, MIST_MAX_FRAME)
		_drift_mist(mist, mist.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_apply_theme_colours()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _apply_theme_colours() -> void:
	var mist := get_theme_color(&"mist", THEME_TYPE)
	_mist_a.modulate = mist
	_mist_b.modulate = mist
	_mist_c.modulate = mist
	_top_light.modulate = get_theme_color(&"light", THEME_TYPE)
	_motes_primary.modulate = get_theme_color(&"mote_primary", THEME_TYPE)
	_motes_secondary.modulate = get_theme_color(&"mote_secondary", THEME_TYPE)

## Drifts a mist sprite toward random points around its origin, one sine-eased
## segment after another, like Atmosphere._drift_mist_randomly().
func _drift_mist(mist: Sprite2D, origin: Vector2) -> void:
	while is_instance_valid(mist):
		var target := origin + Vector2(
			randf_range(-mist_drift_radius.x, mist_drift_radius.x),
			randf_range(-mist_drift_radius.y, mist_drift_radius.y)
		)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(mist, "position", target, randf_range(mist_min_duration, mist_max_duration))
		await tween.finished
