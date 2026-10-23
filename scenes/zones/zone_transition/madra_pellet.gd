class_name MadraPellet
extends Node2D

## One pellet of the Madra drain that runs when an adventure starts: it flies
## from the cultivator's Madra orb to the character along a curve, then frees
## itself. Lacquer kit §1 rules 4 and 6: an opaque Madra-blue pellet with an
## ink outline (no glow, halo, trail or fade) that moves in 2 px steps, its
## position snapped to even screen px every frame.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## One art px of the kit is this many screen px; the pellet only ever stands
## on multiples of it.
const GRID: float = 2.0

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _start_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _control_point: Vector2 = Vector2.ZERO
var _duration: float = 0.6
var _elapsed: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	global_position = _point_at(t)
	if t >= 1.0:
		queue_free()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Sends the pellet from start to target over duration seconds, speeding up as
## it goes. The path bows up to curve_spread px off the straight line, to a
## random side.
func launch(start: Vector2, target: Vector2, duration: float, curve_spread: float) -> void:
	_start_pos = start
	_target_pos = target
	_duration = duration
	_elapsed = 0.0
	var midpoint: Vector2 = (start + target) * 0.5
	var perpendicular: Vector2 = (target - start).orthogonal().normalized()
	_control_point = midpoint + perpendicular * randf_range(-curve_spread, curve_spread)
	global_position = _point_at(0.0)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The pellet's point at t (0 to 1) on its eased curve, on the even-px grid.
func _point_at(t: float) -> Vector2:
	var eased: float = t * t
	var a: Vector2 = _start_pos.lerp(_control_point, eased)
	var b: Vector2 = _control_point.lerp(_target_pos, eased)
	return (a.lerp(b, eased) / GRID).round() * GRID
