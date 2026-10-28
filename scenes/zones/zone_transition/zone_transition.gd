class_name ZoneTransition
extends Node

## ZoneTransition
## Handles the animated transition out of the zone view into an adventure.
## Coordinates the Madra pellet drain, camera zoom, and Madra spending
## before the adventure view opens.
## The drain runs on its own clock in _process, so it takes as long at any
## frame rate: the pellets leave the orb DRAIN_SPAWN_INTERVAL apart and all of
## them land on the character. The zoom starts on the frame the last one lands.
## It eases the camera to ZOOM_FACTOR times the zoom the player left it at while
## the character crosses the screen on a straight line to the map gap's focal
## point (ZoneMapMath.ZONE_SCREEN_ANCHOR). MainView's ViewDissolve then takes
## the zone view away over the adventure (AdventureViewState).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## What the drain pours from the orb to the character: an opaque Madra pellet
## that moves in 2 px steps (lacquer kit §1 rules 4 and 6).
const DRAIN_PELLET_SCENE: PackedScene = preload("res://scenes/zones/zone_transition/madra_pellet.tscn")
const DRAIN_MIN_PARTICLES: int = 8
const DRAIN_MAX_PARTICLES: int = 25
const DRAIN_SPAWN_INTERVAL: float = 0.04
const DRAIN_PARTICLE_FLIGHT_TIME: float = 0.6
## How far from the orb's centre a pellet may leave, each way on each axis.
## Every pellet lands on the same point of the character.
const DRAIN_SOURCE_SPREAD: float = 15.0
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
## Whether the drain's clock runs, from the first pellet to the last landing.
var _is_draining: bool = false
## Seconds since the first pellet left, on the drain's clock.
var _drain_elapsed: float = 0.0
## When, on the drain's clock, the last pellet sent so far lands.
var _drain_lands_at: float = 0.0
## The character's point in the camera's space, and where it stood on screen
## when the zoom began.
var _zoom_focus: Vector2 = Vector2.ZERO
var _zoom_start_screen: Vector2 = Vector2.ZERO
var _has_saved_camera: bool = false
var _saved_camera_zoom: Vector2 = Vector2.ZERO
var _saved_camera_position: Vector2 = Vector2.ZERO

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
	if _drain_particles_spawned >= _drain_total_particles and _drain_elapsed >= _drain_lands_at:
		_is_draining = false
		_on_drain_complete()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Whether a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning

## Reset camera to pre-transition state (called when returning to zone view).
func reset_camera(duration: float = 0.3) -> void:
	if not _has_saved_camera:
		return
	var camera: Camera2D = _get_camera()
	if not camera:
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "zoom", _saved_camera_zoom, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(camera, "position", _saved_camera_position, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_has_saved_camera = false

## The camera position (its screen centre, offset zero) partway through the
## adventure zoom, at progress 0 to 1 and the camera's zoom then: the one that
## puts the world point focus on the straight screen line from start_screen,
## where it stood when the zoom began, to the map gap's focal point
## (ZoneMapMath.ZONE_SCREEN_ANCHOR).
static func zoom_camera_position(focus: Vector2, start_screen: Vector2, zoom: float, progress: float) -> Vector2:
	var screen: Vector2 = start_screen.lerp(ZoneMapMath.ZONE_SCREEN_ANCHOR, progress)
	return focus - (screen - ZoneMapMath.VIEWPORT_SIZE / 2.0) / zoom

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
	_drain_lands_at = 0.0
	_is_draining = true
	_spawn_due_drain_particles()

## Sends every pellet whose time has come on the drain's clock.
func _spawn_due_drain_particles() -> void:
	while _drain_particles_spawned < _drain_total_particles \
			and _drain_particles_spawned * DRAIN_SPAWN_INTERVAL <= _drain_elapsed:
		_spawn_drain_particle()

func _spawn_drain_particle() -> void:
	var from_pos: Vector2 = _cultivator_plate.get_madra_orb_global_position()

	var pellet: MadraPellet = DRAIN_PELLET_SCENE.instantiate()
	var offset: Vector2 = Vector2(
		randf_range(-DRAIN_SOURCE_SPREAD, DRAIN_SOURCE_SPREAD),
		randf_range(-DRAIN_SOURCE_SPREAD, DRAIN_SOURCE_SPREAD))
	var duration: float = randf_range(DRAIN_PARTICLE_FLIGHT_TIME * 0.7, DRAIN_PARTICLE_FLIGHT_TIME)
	var curve_spread: float = randf_range(80.0, 150.0)
	_get_pellet_parent().add_child(pellet)
	pellet.launch(from_pos + offset, _drain_target_pos, duration, curve_spread)
	_drain_lands_at = maxf(_drain_lands_at, _drain_elapsed + duration)

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
	if _pending_adventure_data == null:
		return

	# Zoom camera into player
	var camera: Camera2D = _get_camera()
	var character: Node2D = _get_character()
	if camera and character:
		_has_saved_camera = true
		_saved_camera_zoom = camera.zoom
		_saved_camera_position = camera.position

		# The camera is a child of the map, so its position is in the map's space.
		_zoom_focus = _zone_tilemap.to_local(character.global_position)
		_zoom_start_screen = ZoneMapMath.world_to_screen(_zoom_focus, camera.position, camera.zoom.x)

		var tween: Tween = create_tween()
		tween.tween_method(_apply_zoom, 0.0, 1.0, ZOOM_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.finished.connect(_on_zoom_complete)
	else:
		_on_zoom_complete()

## The camera at progress (0 to 1) through the zoom.
func _apply_zoom(progress: float) -> void:
	var zoom: float = lerpf(_saved_camera_zoom.x, _saved_camera_zoom.x * ZOOM_FACTOR, progress)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = zoom_camera_position(_zoom_focus, _zoom_start_screen, zoom, progress)

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
