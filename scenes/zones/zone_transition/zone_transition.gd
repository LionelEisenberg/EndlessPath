class_name ZoneTransition
extends Node

## ZoneTransition
## Handles the animated transition out of the zone view into an adventure.
## Coordinates the Madra pellet drain, camera zoom, and Madra spending
## before the adventure view opens.
## The drain runs on its own clock in _process, so it takes as long at any
## frame rate: the pellets leave the orb DRAIN_SPAWN_INTERVAL apart and all of
## them land on the character. The zoom starts as the last one lands (its
## delivered signal): a CameraPush, as the board transition's, to ZOOM_FACTOR
## times the zoom the player left it at, with the character at the map gap's
## focal point (ZoneMapMath.ZONE_SCREEN_ANCHOR). The map's camera holds still
## (ZoneTilemap.hold_camera()) from the push's start until reset_camera() or
## settle_camera() has put it back. MainView's ViewDissolve then takes the zone
## view away over the adventure (AdventureViewState).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## What the drain pours from the orb to the character: an opaque Madra pellet
## that moves in 2 px steps (lacquer kit §1 rules 4 and 6). One leaves every
## DRAIN_SPAWN_INTERVAL s and flies DRAIN_PARTICLE_FLIGHT_TIME s, so they land in
## the rhythm they left, as a stream that sways up to DRAIN_BOW px to either side
## (PelletFlight.stream).
const DRAIN_PELLET_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")
const DRAIN_MIN_PARTICLES: int = 8
const DRAIN_MAX_PARTICLES: int = 25
const DRAIN_SPAWN_INTERVAL: float = 0.04
const DRAIN_PARTICLE_FLIGHT_TIME: float = 0.6
const DRAIN_BOW: float = 110.0
const ZOOM_DURATION: float = 0.5
## The zoom pushes the camera to this many times the zoom the player left it
## at: 2 to 3 at the zone view's opening zoom.
const ZOOM_FACTOR: float = 1.5

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Where the drain's pellets are added; null means the running scene, as in
## the game. Tests, which have no current scene, set it.
var pellet_parent: Node = null

var _cultivator_plate: CultivatorPlate = null
var _zone_tilemap: ZoneTilemap = null
var _camera: Camera2D = null
var _character: Node2D = null
var _is_transitioning: bool = false
var _pending_adventure_data: AdventureActionData = null
var _drain_budget: float = 0.0
var _drain_budget_ratio: float = 0.0
var _drain_particles_spawned: int = 0
var _drain_total_particles: int = 0  # includes the extra deficit particle when there is one
var _drain_madra_per_particle: float = 0.0  # whole-madra amount per "base" particle
var _drain_deficit_particle_amount: float = 0.0  # leftover carried by one extra particle; 0 if none
var _drain_target_pos: Vector2 = Vector2.ZERO
## Whether the drain's clock runs, from the first pellet leaving to the last.
var _is_draining: bool = false
## Seconds since the first pellet left, on the drain's clock.
var _drain_elapsed: float = 0.0
## The adventure zoom: active from its start until the camera is put back.
var _camera_push: CameraPush = CameraPush.new()
## The way back from the adventure zoom (reset_camera()), while it runs.
var _reset_tween: Tween = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_cultivator_plate = get_parent().find_child("CultivatorPlate", true, false) as CultivatorPlate
	_zone_tilemap = get_parent().find_child("ZoneTilemap", true, false)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)

func _process(delta: float) -> void:
	if not _is_draining:
		return
	_drain_elapsed += delta
	_spawn_due_drain_particles()

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
# ADVENTURE TRANSITION — PARTICLE DRAIN
#-----------------------------------------------------------------------------

func _on_adventure_start_requested(action_data: AdventureActionData) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_pending_adventure_data = action_data
	_drain_budget = ResourceManager.get_adventure_madra_budget()
	_drain_budget_ratio = clampf(_drain_budget / ResourceManager.get_adventure_madra_capacity(), 0.0, 1.0)
	var base_particles: int = int(lerpf(DRAIN_MIN_PARTICLES, DRAIN_MAX_PARTICLES, _drain_budget_ratio))
	# Use whole-madra amounts per particle so the bar drains in clean integer
	# steps. Any leftover from the floor (e.g. budget=100, base=19 -> per=5,
	# 19*5=95 leaves 5) gets carried by one extra particle at the end. This
	# avoids float accumulation in the per-particle subtraction path.
	_drain_madra_per_particle = floor(_drain_budget / base_particles)
	_drain_deficit_particle_amount = _drain_budget - (_drain_madra_per_particle * base_particles)
	_drain_total_particles = base_particles + (1 if _drain_deficit_particle_amount > 0.001 else 0)
	_drain_particles_spawned = 0

	# Cache node references for this transition
	_camera = _zone_tilemap.find_child("Camera2D", false, false) if _zone_tilemap else null
	_character = _zone_tilemap.find_child("PlayerCharacter", true, false) if _zone_tilemap else null

	# Cache particle target position
	var character: Node2D = _character
	if character:
		_drain_target_pos = character.get_global_transform_with_canvas().origin
	else:
		_drain_target_pos = get_viewport().get_visible_rect().size * 0.5

	# The first pellet leaves at once; _process sends the rest.
	_drain_elapsed = 0.0
	_is_draining = true
	_spawn_due_drain_particles()

## Sends every pellet whose time has come on the drain's clock, and stops the
## clock once the last one has left.
func _spawn_due_drain_particles() -> void:
	while _drain_particles_spawned < _drain_total_particles \
			and _drain_particles_spawned * DRAIN_SPAWN_INTERVAL <= _drain_elapsed:
		_spawn_drain_particle()
	_is_draining = _drain_particles_spawned < _drain_total_particles

func _spawn_drain_particle() -> void:
	var from_pos: Vector2 = _cultivator_plate.get_madra_orb_global_position()

	var pellet: LacquerPellet = DRAIN_PELLET_SCENE.instantiate()
	_get_pellet_parent().add_child(pellet)
	pellet.fly(PelletFlight.stream(from_pos, _drain_target_pos, DRAIN_PARTICLE_FLIGHT_TIME, DRAIN_BOW, _drain_particles_spawned))
	# Every pellet flies as long and they leave in turn, so the last one sent
	# lands last: the zoom starts as it lands.
	if _drain_particles_spawned == _drain_total_particles - 1:
		pellet.delivered.connect(_on_drain_complete, CONNECT_ONE_SHOT)

	# The final particle carries the leftover deficit (when budget doesn't
	# divide evenly by base count). Every other particle spends the whole-
	# madra per-particle amount.
	var is_deficit_particle: bool = (
		_drain_deficit_particle_amount > 0.001
		and _drain_particles_spawned == _drain_total_particles - 1
	)
	var amount: float = _drain_deficit_particle_amount if is_deficit_particle else _drain_madra_per_particle
	ResourceManager.spend_madra(amount)

	_drain_particles_spawned += 1

#-----------------------------------------------------------------------------
# ADVENTURE TRANSITION — CAMERA ZOOM
#-----------------------------------------------------------------------------

func _on_drain_complete() -> void:
	# A pellet also delivers as it leaves the tree, which it can do with this
	# node as the game quits.
	if _pending_adventure_data == null or not is_inside_tree():
		return

	# Zoom camera into player
	var camera: Camera2D = _get_camera()
	var character: Node2D = _get_character()
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
		ActionManager.confirm_adventure_start(_pending_adventure_data, _drain_budget)
		_pending_adventure_data = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _get_camera() -> Camera2D:
	return _camera

func _get_character() -> Node2D:
	return _character

func _get_pellet_parent() -> Node:
	return pellet_parent if pellet_parent != null else get_tree().current_scene

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
