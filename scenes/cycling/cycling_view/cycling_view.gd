## Manages the cycling view, including technique selection and execution.
extends Control

signal current_technique_changed(technique_data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var cycling_technique_node: CyclingTechnique = %CyclingTechnique
@onready var cycling_resource_panel_node: CyclingResourcePanel = %CyclingResourcePanel
@onready var cycling_tab_panel: CyclingTabPanel = %CyclingTabPanel
@onready var close_button: Button = %CloseButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var current_cycling_technique_data: CyclingTechniqueData = null
var cycling_action_data: CyclingActionData = null

const MADRA_PARTICLE_COLOR: Color = Color(0.5, 0.78, 1.0, 0.85)
const MADRA_PARTICLE_SIZE: float = 4.0
const XP_PARTICLE_COUNT: int = 8

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Technique change propagation
	current_technique_changed.connect(cycling_technique_node.set_technique_data)
	current_technique_changed.connect(cycling_resource_panel_node.set_technique_data)
	current_technique_changed.connect(cycling_tab_panel.set_current_technique)

	# Cycling state signals
	cycling_technique_node.cycling_started.connect(cycling_resource_panel_node.on_cycling_started)
	cycling_technique_node.cycle_completed.connect(cycling_resource_panel_node.on_cycle_completed)

	# Particle feedback signals
	cycling_technique_node.madra_particle_requested.connect(_on_madra_particle_requested)
	cycling_technique_node.xp_particle_requested.connect(_on_xp_particle_requested)

	# Tab panel technique change
	cycling_tab_panel.technique_change_request.connect(_on_technique_change_request)
	_refresh_technique_list()

	# Listen for new technique unlocks
	CyclingManager.technique_unlocked.connect(_on_technique_unlocked)

	# Close button
	close_button.pressed.connect(_on_close_button_pressed)

	# ActionManager
	ActionManager.stop_cycling.connect(_on_stop_cycling)

	# Load equipped technique from CyclingManager
	_load_equipped_technique()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initializes the view with action data.
func initialize_cycling_action_data(action_data: CyclingActionData) -> void:
	cycling_action_data = action_data

## Sets the current technique.
func set_current_technique(technique_data: CyclingTechniqueData) -> void:
	current_cycling_technique_data = technique_data
	current_technique_changed.emit(technique_data)
	CyclingManager.equip_technique(technique_data.id)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_technique_change_request(technique_data: CyclingTechniqueData) -> void:
	set_current_technique(technique_data)
	cycling_tab_panel.show_resources_tab()

func _on_close_button_pressed() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"close_cycling_view"
	event.pressed = true
	Input.parse_input_event(event)

func _on_stop_cycling() -> void:
	cycling_technique_node.stop_cycling()

func _load_equipped_technique() -> void:
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	if equipped:
		current_cycling_technique_data = equipped
		current_technique_changed.emit(equipped)
	else:
		# Fallback: equip first unlocked technique
		var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
		if not unlocked.is_empty():
			set_current_technique(unlocked[0])

func _refresh_technique_list() -> void:
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	cycling_tab_panel.setup(unlocked)

func _on_technique_unlocked(_technique: CyclingTechniqueData) -> void:
	_refresh_technique_list()

#-----------------------------------------------------------------------------
# PARTICLE FEEDBACK
#-----------------------------------------------------------------------------

func _on_madra_particle_requested(from_pos: Vector2) -> void:
	var target: Vector2 = cycling_resource_panel_node.get_madra_orb_global_position()
	_spawn_particle(from_pos, target, MADRA_PARTICLE_COLOR, 0.5, MADRA_PARTICLE_SIZE,
		cycling_resource_panel_node.pulse_madra_orb)

func _on_xp_particle_requested(from_pos: Vector2, color: Color, quality: float) -> void:
	var target: Vector2 = cycling_resource_panel_node.get_core_density_orb_global_position()
	var count: int = int(XP_PARTICLE_COUNT * quality)
	for i in count:
		var offset: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		var duration: float = randf_range(0.4, 0.7)
		var size: float = randf_range(3.0, 5.0)
		# Only pulse on the last particle of the burst
		var callback: Callable = cycling_resource_panel_node.pulse_core_density_orb if i == count - 1 else Callable()
		_spawn_particle(from_pos + offset, target, color, duration, size, callback)

func _spawn_particle(from: Vector2, to: Vector2, color: Color, duration: float, size: float, on_arrive: Callable = Callable()) -> void:
	var particle: FlyingParticle = FlyingParticle.new()
	add_child(particle)
	particle.launch(from, to, color, duration, size, on_arrive)
