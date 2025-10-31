extends Control

signal current_technique_changed(data)

@onready var cycling_technique_node = %CyclingTechnique
@onready var cycling_resource_panel_node = %CyclingResourcePanel
@onready var cycling_technique_selector = %CyclingTechniqueSelector

var current_cycling_technique_data: CyclingTechniqueData = null

var technique_list: CyclingTechniqueList = preload("res://resources/game_systems/cycling/cycling_techniques/cycling_technique_list.tres")
var foundation_technique: CyclingTechniqueData = technique_list.cycling_techniques[0]

func _ready():
	# Connect the signal passively to both subnodes' setter methods using Callable
	current_technique_changed.connect(cycling_technique_node.set_technique_data)
	current_technique_changed.connect(cycling_resource_panel_node.set_technique_data)
	
	# Connect cycling state signals
	cycling_technique_node.cycling_started.connect(cycling_resource_panel_node.on_cycling_started)
	cycling_technique_node.cycle_completed.connect(cycling_resource_panel_node.on_cycle_completed)
	
	cycling_resource_panel_node.open_technique_selector.connect(_on_open_technique_selector)
	cycling_technique_selector.technique_change_request.connect(_on_technique_change_request)

	# Load saved technique or use default
	_load_saved_technique()

func set_current_technique(data: CyclingTechniqueData):
	current_cycling_technique_data = data
	current_technique_changed.emit(data)
	_save_current_technique(data)

func _on_technique_change_request(data: CyclingTechniqueData):
	set_current_technique(data)
	cycling_technique_selector.close_selector()

func _on_open_technique_selector():
	cycling_technique_selector.open_selector(current_cycling_technique_data)

func _load_saved_technique():
	"""Load the saved technique from SaveGameData by looking up name in technique list"""
	if not PersistenceManager or not PersistenceManager.save_game_data:
		# Fallback to foundation technique if no save data
		set_current_technique(foundation_technique)
		return
	
	if not technique_list:
		# No technique list available, use default
		set_current_technique(foundation_technique)
		return
	
	var saved_name = PersistenceManager.save_game_data.current_cycling_technique_name
	
	# Lookup technique by name in the list
	var found_technique: CyclingTechniqueData = null
	for technique in technique_list.cycling_techniques:
		if technique.technique_name == saved_name:
			found_technique = technique
			break
	
	if found_technique:
		set_current_technique(found_technique)
	else:
		# Technique not found in list, use default
		set_current_technique(foundation_technique)

func _save_current_technique(data: CyclingTechniqueData):
	"""Save the current technique name to SaveGameData"""
	if not PersistenceManager or not PersistenceManager.save_game_data:
		return
	
	if data and data.technique_name:
		PersistenceManager.save_game_data.current_cycling_technique_name = data.technique_name
	
