class_name ZoneTransition
extends Node

## ZoneTransition
## Handles the animated transition out of the zone view into an adventure: the
## camera zoom before the adventure view opens. Starting a run spends nothing
## (the run plays on the saved Madra pool as it stands), so nothing leaves the
## Madra orb and the zoom starts as the start is requested: a CameraPush, as the
## board transition's, to ZOOM_FACTOR times the zoom the player left it at, with
## the character at the map gap's focal point (ZoneMapMath.ZONE_SCREEN_ANCHOR).
## The map's camera holds still (ZoneTilemap.hold_camera()) from the push's
## start until reset_camera() or settle_camera() has put it back. MainView's
## ViewDissolve then takes the zone view away over the adventure
## (AdventureViewState).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ZOOM_DURATION: float = 0.5
## The zoom pushes the camera to this many times the zoom the player left it
## at: 2 to 3 at the zone view's opening zoom.
const ZOOM_FACTOR: float = 1.5

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _zone_tilemap: ZoneTilemap = null
var _is_transitioning: bool = false
var _pending_adventure_data: AdventureActionData = null
## The adventure zoom: active from its start until the camera is put back.
var _camera_push: CameraPush = CameraPush.new()
## The way back from the adventure zoom (reset_camera()), while it runs.
var _reset_tween: Tween = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_zone_tilemap = get_parent().find_child("ZoneTilemap", true, false)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Whether a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning

## Eases the camera back from the adventure zoom to where the player left it
## over duration seconds (called when returning to zone view), then lets the
## map's camera go. Does nothing without an adventure zoom to undo, or while
## the way back already runs.
func reset_camera(duration: float = 0.3) -> void:
	if not _camera_push.is_active() or _is_resetting():
		return
	_reset_tween = create_tween()
	_reset_tween.tween_method(_camera_push.apply, 1.0, 0.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_reset_tween.finished.connect(_end_camera_push)

## Ends the way back from the adventure zoom (reset_camera()) at once, at its
## end: the camera at the zoom and position it had before the adventure, and
## the map's camera let go. Does nothing while no way back runs.
func settle_camera() -> void:
	if not _is_resetting():
		return
	_reset_tween.kill()
	_end_camera_push()

#-----------------------------------------------------------------------------
# ADVENTURE TRANSITION — CAMERA ZOOM
#-----------------------------------------------------------------------------

## Zooms the camera into the character, then confirms the adventure. With no
## camera or character to zoom to, it confirms at once.
func _on_adventure_start_requested(action_data: AdventureActionData) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_pending_adventure_data = action_data

	var camera: Camera2D = _zone_tilemap.find_child("Camera2D", false, false) if _zone_tilemap else null
	var character: Node2D = _zone_tilemap.find_child("PlayerCharacter", true, false) if _zone_tilemap else null
	if camera and character:
		# Holding first ends the map's own camera moves under way, so the push
		# saves the camera where it comes to rest.
		_hold_map_camera(true)
		# The camera is a child of the map, so the push aims in the map's space.
		var focus: Vector2 = _zone_tilemap.to_local(character.global_position)
		_camera_push.begin(camera, focus, ZoneMapMath.ZONE_SCREEN_ANCHOR, camera.zoom.x * ZOOM_FACTOR)

		var tween: Tween = create_tween()
		tween.tween_method(_camera_push.apply, 0.0, 1.0, ZOOM_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.finished.connect(_on_zoom_complete)
	else:
		_on_zoom_complete()

func _on_zoom_complete() -> void:
	_is_transitioning = false
	if _pending_adventure_data:
		ActionManager.confirm_adventure_start(_pending_adventure_data)
		_pending_adventure_data = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Whether the way back from the adventure zoom runs.
func _is_resetting() -> bool:
	return _reset_tween != null and _reset_tween.is_valid()

## Puts the camera back where the adventure zoom found it and lets the map's
## camera go.
func _end_camera_push() -> void:
	_reset_tween = null
	_camera_push.restore()
	_hold_map_camera(false)

## Holds the map's camera still for the adventure zoom, or lets it go.
func _hold_map_camera(held: bool) -> void:
	if _zone_tilemap:
		_zone_tilemap.hold_camera(held)
