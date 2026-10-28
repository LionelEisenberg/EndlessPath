class_name CameraPush
extends RefCounted

## CameraPush
## A reversible push of a Camera2D toward a world point: begin() saves where
## the player left the camera and works out the end framing, apply() puts the
## camera between the two for a weight from 0 to 1 (the caller owns the curve;
## this only lerps), and restore() puts the camera back exactly as it was.
## The end zoom is a parameter, so the board transition (1.5 times the player's
## zoom) and a later adventure zoom (a fixed 3) share it.
## It sets camera.zoom and camera.position directly, as ZoneTransition does, and
## counts on nothing else moving the camera from begin() to restore(). The
## clamp controller clamps only on the other controllers' signals, but the zoom
## controller eases the zoom on its own for about a second after a wheel tick,
## and the glide to a zone and the way back from the adventure zoom are tweens
## of their own: the caller ends such moves before begin() and keeps them still
## until restore(), as the board transition does through its camera hold.

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _camera: Camera2D = null
var _is_active: bool = false
var _saved_zoom: Vector2 = Vector2.ONE
var _saved_position: Vector2 = Vector2.ZERO
var _end_zoom: Vector2 = Vector2.ONE
var _end_position: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Start a push on camera that ends with world_point at screen_point at
## end_zoom. The camera's zoom and position are saved unless a push is already
## saved, so a second begin() keeps the first one's start for restore().
func begin(camera: Camera2D, world_point: Vector2, screen_point: Vector2, end_zoom: float) -> void:
	if not _is_active:
		_camera = camera
		_saved_zoom = camera.zoom
		_saved_position = camera.position
		_is_active = true
	_end_zoom = Vector2(end_zoom, end_zoom)
	_end_position = BoardTransitionTiming.push_camera_position(world_point, screen_point, end_zoom)

## Move the camera to weight between where it started (0) and the end framing
## (1), zoom and position alike. Does nothing before begin().
func apply(weight: float) -> void:
	if not _has_camera():
		return
	_camera.zoom = _saved_zoom.lerp(_end_zoom, weight)
	_camera.position = _saved_position.lerp(_end_position, weight)

## Put the camera back to exactly the zoom and position begin() saved, and
## forget them. Does nothing before begin().
func restore() -> void:
	if _has_camera():
		_camera.zoom = _saved_zoom
		_camera.position = _saved_position
	_camera = null
	_is_active = false

## True from begin() until restore().
func is_active() -> bool:
	return _is_active

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## True while a push is saved and its camera is still alive.
func _has_camera() -> bool:
	return _is_active and is_instance_valid(_camera)
