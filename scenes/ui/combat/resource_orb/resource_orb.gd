class_name ResourceOrb
extends Control

## ResourceOrb
## Liquid globe for a vital resource (Health, Madra). Uses the same liquid_wave
## orb as the zone and cycling resource panels. A pale "ghost" liquid lingers
## at the old level after a loss, and the ring pulses when the resource runs low.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")

const FILL_LERP_SPEED: float = 10.0
const GHOST_FALL_SPEED: float = 4.0
const GHOST_HOLD_TIME: float = 0.45
const LOW_PULSE_COLOR: Color = Color(1.5, 0.45, 0.4, 1.0)
const PREVIEW_TINT_OK: Color = Color(1.0, 1.0, 1.0, 1.0)
const PREVIEW_TINT_SHORT: Color = Color(1.0, 0.35, 0.3, 1.0)

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Display name used in the tooltip.
@export var resource_name: String = "Health"
@export var liquid_primary: Color = Color(0.86, 0.33, 0.3, 0.85)
@export var liquid_secondary: Color = Color(0.7, 0.2, 0.2, 1.0)
@export var liquid_tertiary: Color = Color(0.5, 0.11, 0.13, 1.0)
@export var foam_color: Color = Color(1.0, 0.72, 0.66, 1.0)
## The ring pulses while the resource is at or below this fraction (0 disables it).
@export_range(0.0, 1.0) var low_threshold: float = 0.0
## Spawns floating "+/-" text above the orb on changes of at least 1.
@export var show_floating_text: bool = false

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _liquid: TextureRect = %Liquid
@onready var _ghost: TextureRect = %GhostLiquid
@onready var _ring: Panel = %Ring
@onready var _value_label: Label = %ValueLabel
@onready var _max_label: Label = %MaxLabel
@onready var _cost_line: Panel = %CostLine

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _target_fill: float = 0.0
var _shown_fill: float = 0.0
var _ghost_fill: float = 0.0
var _ghost_hold: float = 0.0
var _current: float = -1.0
var _maximum: float = 0.0
var _is_low: bool = false
var _pulse_tween: Tween
var _preview_amount: float = 0.0
var _preview_tween: Tween

func _ready() -> void:
	var mat: ShaderMaterial = _liquid.material as ShaderMaterial
	mat.set_shader_parameter("swirl_col_primary", liquid_primary)
	mat.set_shader_parameter("swirl_col_secondary", liquid_secondary)
	mat.set_shader_parameter("swirl_col_tertiary", liquid_tertiary)
	mat.set_shader_parameter("foam_color", foam_color)
	_apply_fill()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Updates the orb. `regen_rate` is surfaced in the tooltip only.
func update_values(current: float, maximum: float, regen_rate: float = 0.0) -> void:
	var fill: float = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_value_label.text = str(int(current))
	_max_label.text = "/ %d" % int(maximum)
	tooltip_text = "%s  %d / %d" % [resource_name, int(current), int(maximum)]
	if regen_rate != 0.0:
		tooltip_text += "\nRegenerates %.1f / s" % regen_rate

	if _current < 0.0:
		# First update: snap without animating.
		_shown_fill = fill
		_ghost_fill = fill
	else:
		var diff: float = current - _current
		if fill < _target_fill:
			_ghost_hold = GHOST_HOLD_TIME
		if show_floating_text and absf(diff) >= 1.0:
			_spawn_floating_text(diff)
	_current = current
	_maximum = maximum
	_target_fill = fill
	_set_low(low_threshold > 0.0 and fill > 0.0 and fill <= low_threshold)
	if _preview_amount > 0.0:
		_update_cost_line()

## Marks the level the orb would drop to after spending `amount` (0 hides it).
## The mark turns red and sits at the bottom when the amount can't be afforded.
func preview_cost(amount: float) -> void:
	_preview_amount = maxf(amount, 0.0)
	_update_cost_line()

## Snaps to the given values without animating (e.g. at the start of an adventure).
func reset_values(current: float, maximum: float, regen_rate: float = 0.0) -> void:
	_current = -1.0
	update_values(current, maximum, regen_rate)
	_apply_fill()

#-----------------------------------------------------------------------------
# PROCESS
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_shown_fill = lerpf(_shown_fill, _target_fill, minf(1.0, delta * FILL_LERP_SPEED))
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		_ghost_fill = lerpf(_ghost_fill, _shown_fill, minf(1.0, delta * GHOST_FALL_SPEED))
	_ghost_fill = maxf(_ghost_fill, _shown_fill)
	_apply_fill()

func _apply_fill() -> void:
	(_liquid.material as ShaderMaterial).set_shader_parameter("progress", _shown_fill)
	(_ghost.material as ShaderMaterial).set_shader_parameter("progress", _ghost_fill)

#-----------------------------------------------------------------------------
# COST PREVIEW
#-----------------------------------------------------------------------------

func _update_cost_line() -> void:
	if _preview_amount <= 0.0 or _maximum <= 0.0:
		_cost_line.visible = false
		if _preview_tween and _preview_tween.is_valid():
			_preview_tween.kill()
		return
	var can_afford: bool = _preview_amount <= _current
	var after_fill: float = clampf((_current - _preview_amount) / _maximum, 0.0, 1.0) if can_afford else 0.0
	# A horizontal chord across the circle at the post-cost liquid level.
	var radius: float = size.x / 2.0
	var y: float = clampf((1.0 - after_fill) * size.y, 8.0, size.y - 8.0)
	var dy: float = y - size.y / 2.0
	var half_width: float = maxf(sqrt(maxf(radius * radius - dy * dy, 0.0)) - 6.0, 4.0)
	_cost_line.position = Vector2(radius - half_width, y - 1.5)
	_cost_line.size = Vector2(half_width * 2.0, 3.0)
	_cost_line.self_modulate = PREVIEW_TINT_OK if can_afford else PREVIEW_TINT_SHORT
	if not _cost_line.visible:
		_cost_line.visible = true
		_preview_tween = create_tween().set_loops()
		_preview_tween.tween_property(_cost_line, "modulate:a", 0.4, 0.35).set_trans(Tween.TRANS_SINE)
		_preview_tween.tween_property(_cost_line, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)

#-----------------------------------------------------------------------------
# LOW RESOURCE PULSE
#-----------------------------------------------------------------------------

func _set_low(is_low: bool) -> void:
	if is_low == _is_low:
		return
	_is_low = is_low
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_ring.self_modulate = Color.WHITE
	if _is_low:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_ring, "self_modulate", LOW_PULSE_COLOR, 0.3).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_ring, "self_modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)

#-----------------------------------------------------------------------------
# FLOATING TEXT
#-----------------------------------------------------------------------------

func _spawn_floating_text(diff: float) -> void:
	var floating_text: FloatingText = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(floating_text)
	var color: Color = Color("#7fd18b") if diff > 0.0 else Color("#e86a5c")
	var text: String = ("+%d" % int(diff)) if diff > 0.0 else str(int(diff))
	floating_text.show_text(text, color, global_position + Vector2(size.x * 0.5 - 20.0, -24.0))
