class_name ZoneTransition
extends Node

## ZoneTransition
## Handles animated transitions out of the zone view.
## Coordinates particle effects, camera zoom, and Madra spending
## before switching to another view (adventure, cycling, etc.).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DRAIN_PARTICLE_COLOR: Color = Color(0.5, 0.78, 1.0, 0.85)
const DRAIN_MIN_PARTICLES: int = 8
const DRAIN_MAX_PARTICLES: int = 25
const DRAIN_SPAWN_INTERVAL: float = 0.04
const DRAIN_PARTICLE_FLIGHT_TIME: float = 0.6
const ZOOM_DURATION: float = 0.5
const ZOOM_TARGET: float = 3.0

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _zone_resource_panel: ZoneResourcePanel = null
var _zone_tilemap: Node2D = null
var _is_transitioning: bool = false
var _pending_adventure_data: AdventureActionData = null
var _drain_budget: float = 0.0
var _drain_budget_ratio: float = 0.0
var _drain_particles_spawned: int = 0
var _drain_total_particles: int = 0
var _drain_madra_per_particle: float = 0.0
var _drain_target_pos: Vector2 = Vector2.ZERO
var _saved_camera_zoom: Vector2 = Vector2.ZERO
var _saved_camera_position: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_zone_resource_panel = get_parent().find_child("ZoneResourcePanel", true, false)
	_zone_tilemap = get_parent().find_child("ZoneTilemap", true, false)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Whether a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning

## Reset camera to pre-transition state (called when returning to zone view).
func reset_camera(duration: float = 0.3) -> void:
	if _saved_camera_zoom == Vector2.ZERO:
		return
	var camera: Camera2D = _get_camera()
	if not camera:
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "zoom", _saved_camera_zoom, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(camera, "position", _saved_camera_position, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_saved_camera_zoom = Vector2.ZERO

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
	_drain_total_particles = int(lerpf(DRAIN_MIN_PARTICLES, DRAIN_MAX_PARTICLES, _drain_budget_ratio))
	_drain_madra_per_particle = _drain_budget / _drain_total_particles
	_drain_particles_spawned = 0

	# Cache particle target position
	var character: Node2D = _get_character()
	if character:
		_drain_target_pos = character.get_global_transform_with_canvas().origin
	else:
		_drain_target_pos = get_viewport().get_visible_rect().size * 0.5

	_spawn_next_drain_particle()

func _spawn_next_drain_particle() -> void:
	if _drain_particles_spawned >= _drain_total_particles:
		get_tree().create_timer(DRAIN_PARTICLE_FLIGHT_TIME + 0.1).timeout.connect(_on_drain_complete)
		return

	var from_pos: Vector2 = _zone_resource_panel.get_madra_orb_global_position()
	var base_size: float = lerpf(3.0, 6.0, _drain_budget_ratio)

	var particle: FlyingParticle = FlyingParticle.new()
	var offset: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	var duration: float = randf_range(DRAIN_PARTICLE_FLIGHT_TIME * 0.7, DRAIN_PARTICLE_FLIGHT_TIME)
	var size: float = randf_range(base_size * 0.7, base_size * 1.3)
	var curve_spread: float = randf_range(80.0, 150.0)
	get_tree().current_scene.add_child(particle)
	particle.launch(from_pos + offset, _drain_target_pos + offset, DRAIN_PARTICLE_COLOR, duration, size, Callable(), curve_spread)

	ResourceManager.spend_madra(_drain_madra_per_particle)
	_drain_particles_spawned += 1

	get_tree().create_timer(DRAIN_SPAWN_INTERVAL).timeout.connect(_spawn_next_drain_particle)

#-----------------------------------------------------------------------------
# ADVENTURE TRANSITION — CAMERA ZOOM
#-----------------------------------------------------------------------------

func _on_drain_complete() -> void:
	if _pending_adventure_data == null:
		return

	# Spend rounding leftovers
	var remaining: float = _drain_budget - (_drain_madra_per_particle * _drain_total_particles)
	if remaining > 0.01:
		ResourceManager.spend_madra(remaining)

	# Zoom camera into player
	var camera: Camera2D = _get_camera()
	var character: Node2D = _get_character()
	if camera and character:
		_saved_camera_zoom = camera.zoom
		_saved_camera_position = camera.position

		var target_pos: Vector2 = character.global_position + _zone_tilemap.tile_map.position / 2

		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(camera, "zoom", Vector2(ZOOM_TARGET, ZOOM_TARGET), ZOOM_DURATION) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(camera, "position", target_pos, ZOOM_DURATION) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
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
	if _zone_tilemap:
		return _zone_tilemap.find_child("Camera2D", false, false)
	return null

func _get_character() -> Node2D:
	if _zone_tilemap:
		return _zone_tilemap.find_child("PlayerCharacter", true, false)
	return null
