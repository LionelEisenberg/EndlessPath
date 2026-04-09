class_name FlyingParticle
extends Node2D

## FlyingParticle
## A glowing energy particle that flies from a start point to a target
## along a curved bezier path with a fading trail, then frees itself on arrival.

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _start_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _control_point: Vector2 = Vector2.ZERO
var _duration: float = 0.6
var _elapsed: float = 0.0
var _color: Color = Color(0.7, 0.85, 1.0, 1.0)
var _size: float = 5.0
var _trail: PackedVector2Array = PackedVector2Array()
var _on_arrive: Callable = Callable()
const MAX_TRAIL_LENGTH: int = 8

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _duration, 0.0, 1.0)

	# Ease-in for acceleration toward target
	var eased_t: float = t * t

	# Quadratic bezier
	var a: Vector2 = _start_pos.lerp(_control_point, eased_t)
	var b: Vector2 = _control_point.lerp(_target_pos, eased_t)
	global_position = a.lerp(b, eased_t)

	# Record trail
	_trail.append(global_position)
	if _trail.size() > MAX_TRAIL_LENGTH:
		_trail = _trail.slice(_trail.size() - MAX_TRAIL_LENGTH)

	queue_redraw()

	if t >= 1.0:
		if _on_arrive.is_valid():
			_on_arrive.call()
		queue_free()

func _draw() -> void:
	# Draw trail
	if _trail.size() >= 2:
		for i in range(_trail.size() - 1):
			var trail_t: float = float(i) / (_trail.size() - 1)
			var trail_color: Color = _color
			trail_color.a *= trail_t * 0.4
			var trail_size: float = _size * trail_t * 0.6
			var local_pos: Vector2 = _trail[i] - global_position
			draw_circle(local_pos, trail_size, trail_color)

	# Draw glow (larger, transparent)
	var glow_color: Color = _color
	glow_color.a *= 0.25
	draw_circle(Vector2.ZERO, _size * 2.5, glow_color)

	# Draw core (bright center)
	draw_circle(Vector2.ZERO, _size, _color)

	# Draw bright center dot
	var bright: Color = Color(1.0, 1.0, 1.0, _color.a * 0.7)
	draw_circle(Vector2.ZERO, _size * 0.4, bright)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Launch the particle from start to target.
## curve_spread: how far the bezier control point deviates from the straight line (pixels).
## curve_bias: offset the control point toward one side (-1.0 to 1.0, 0.0 = random).
func launch(start: Vector2, target: Vector2, color: Color, duration: float = 0.6, size: float = 5.0, on_arrive: Callable = Callable(), curve_spread: float = 60.0, curve_bias: float = 0.0) -> void:
	_start_pos = start
	_target_pos = target
	_color = color
	_duration = duration
	_size = size
	_on_arrive = on_arrive
	global_position = start

	# Bezier control point — perpendicular to the line between start and target
	var midpoint: Vector2 = (start + target) * 0.5
	var perpendicular: Vector2 = (target - start).rotated(PI * 0.5).normalized()
	var curve_amount: float
	if curve_bias == 0.0:
		curve_amount = randf_range(-curve_spread, curve_spread)
	else:
		curve_amount = curve_spread * curve_bias + randf_range(-curve_spread * 0.3, curve_spread * 0.3)
	_control_point = midpoint + perpendicular * curve_amount

	_trail.clear()
