class_name ZoneResourcePanel
extends PanelContainer
## Floating resource orbs displaying Madra and Core Density.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_circle: ProgressShaderRect = %MadraCircle
@onready var _madra_label: Label = %MadraLabel
@onready var _core_density_rect: ProgressShaderRect = %CoreDensityRect
@onready var _core_density_label: RichTextLabel = %CoreDensityLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("ZoneResourcePanel")
	_connect_signals()
	_update_all_displays()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

const DRAIN_PARTICLE_COLOR: Color = Color(0.5, 0.78, 1.0, 0.85)
const DRAIN_MIN_PARTICLES: int = 8
const DRAIN_MAX_PARTICLES: int = 25
const DRAIN_SPAWN_INTERVAL: float = 0.04
const DRAIN_PARTICLE_FLIGHT_TIME: float = 0.6

var _pending_adventure_data: AdventureActionData = null
var _drain_budget: float = 0.0
var _drain_particles_spawned: int = 0
var _drain_total_particles: int = 0
var _drain_madra_per_particle: float = 0.0

func _connect_signals() -> void:
	ResourceManager.madra_changed.connect(_on_madra_changed)
	CultivationManager.core_density_level_updated.connect(_on_core_density_updated)
	CultivationManager.advancement_stage_changed.connect(_on_stage_changed)
	ActionManager.adventure_start_requested.connect(_on_adventure_start_requested)

func _update_all_displays() -> void:
	_update_madra()
	_update_core_density()

func _update_madra() -> void:
	var current_madra: float = ResourceManager.get_madra()
	var level: int = int(CultivationManager.get_core_density_level())
	var stage_res: AdvancementStageResource = CultivationManager._get_current_stage_resource()
	var max_madra: float = stage_res.get_max_madra(level) if stage_res else 0.0
	var progress: float = current_madra / max_madra if max_madra > 0 else 0.0
	_madra_circle.set_value(progress)
	_madra_label.text = "%d / %d" % [int(current_madra), int(max_madra)]

func _update_core_density() -> void:
	var level: float = CultivationManager.get_core_density_level()
	var stage_name: String = CultivationManager.get_current_advancement_stage_name()
	var progress: float = level / 100.0
	_core_density_rect.set_value(progress)
	_core_density_label.text = "[center][color=#D4A84A]%s[/color]\nLvl %d[/center]" % [stage_name, int(level)]

## Get the global position of the Madra orb center (for particle targets).
func get_madra_orb_global_position() -> Vector2:
	return _madra_circle.global_position + _madra_circle.size * 0.5

func _on_adventure_start_requested(action_data: AdventureActionData) -> void:
	_pending_adventure_data = action_data
	_drain_budget = ResourceManager.get_adventure_madra_budget()

	# Scale particle count with budget — more madra = more particles
	var budget_ratio: float = clampf(_drain_budget / ResourceManager.get_adventure_madra_capacity(), 0.0, 1.0)
	_drain_total_particles = int(lerpf(DRAIN_MIN_PARTICLES, DRAIN_MAX_PARTICLES, budget_ratio))
	_drain_madra_per_particle = _drain_budget / _drain_total_particles
	_drain_particles_spawned = 0

	_spawn_next_drain_particle()

func _spawn_next_drain_particle() -> void:
	if _drain_particles_spawned >= _drain_total_particles:
		# All spawned — wait for last particle to arrive, then confirm
		get_tree().create_timer(DRAIN_PARTICLE_FLIGHT_TIME + 0.1).timeout.connect(_on_drain_animation_complete)
		return

	var from_pos: Vector2 = get_madra_orb_global_position()
	var character: Node2D = get_tree().get_first_node_in_group("PlayerCharacter") as Node2D
	var to_pos: Vector2
	if character:
		var canvas_transform: Transform2D = character.get_global_transform_with_canvas()
		to_pos = canvas_transform.origin
	else:
		to_pos = get_viewport_rect().size * 0.5

	# Particle size scales with budget
	var budget_ratio: float = clampf(_drain_budget / ResourceManager.get_adventure_madra_capacity(), 0.0, 1.0)
	var base_size: float = lerpf(3.0, 6.0, budget_ratio)

	var particle: FlyingParticle = FlyingParticle.new()
	var offset: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	var duration: float = randf_range(DRAIN_PARTICLE_FLIGHT_TIME * 0.7, DRAIN_PARTICLE_FLIGHT_TIME)
	var size: float = randf_range(base_size * 0.7, base_size * 1.3)
	var curve_spread: float = randf_range(80.0, 150.0)
	get_tree().current_scene.add_child(particle)
	particle.launch(from_pos + offset, to_pos + offset, DRAIN_PARTICLE_COLOR, duration, size, Callable(), curve_spread)

	# Drain madra incrementally — orb visually decreases as particles fly
	ResourceManager.spend_madra(_drain_madra_per_particle)
	_drain_particles_spawned += 1

	# Schedule next particle
	get_tree().create_timer(DRAIN_SPAWN_INTERVAL).timeout.connect(_spawn_next_drain_particle)

func _on_drain_animation_complete() -> void:
	if _pending_adventure_data:
		# Spend any remaining madra (rounding leftovers)
		var remaining: float = _drain_budget - (_drain_madra_per_particle * _drain_total_particles)
		if remaining > 0.01:
			ResourceManager.spend_madra(remaining)
		ActionManager.confirm_adventure_start(_pending_adventure_data)
		_pending_adventure_data = null

func _on_madra_changed(_amount: float) -> void:
	_update_madra()

func _on_core_density_updated(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_core_density()
	_update_madra()
