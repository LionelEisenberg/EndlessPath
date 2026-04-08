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
var technique_list: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var foundation_technique: CyclingTechniqueData = technique_list.cycling_techniques[0]
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
	cycling_tab_panel.setup(technique_list)

	# Close button
	close_button.pressed.connect(_on_close_button_pressed)

	# ActionManager
	ActionManager.stop_cycling.connect(_on_stop_cycling)

	# Load saved technique
	_load_saved_technique()

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
	_save_current_technique(technique_data)

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

func _load_saved_technique() -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		set_current_technique(foundation_technique)
		return

	if not technique_list:
		set_current_technique(foundation_technique)
		return

	var saved_name: String = PersistenceManager.save_game_data.current_cycling_technique_name
	var found_technique: CyclingTechniqueData = null
	for technique: CyclingTechniqueData in technique_list.cycling_techniques:
		if technique.technique_name == saved_name:
			found_technique = technique
			break

	set_current_technique(found_technique if found_technique else foundation_technique)

func _save_current_technique(technique_data: CyclingTechniqueData) -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		return
	if technique_data and technique_data.technique_name:
		PersistenceManager.save_game_data.current_cycling_technique_name = technique_data.technique_name

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
