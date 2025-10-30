extends Control

signal current_technique_changed(data)

@onready var cycling_technique_node = %CyclingTechnique
@onready var cycling_resource_panel_node = %CyclingResourcePanel
@onready var cycling_technique_selector = %CyclingTechniqueSelector

var current_cycling_technique_data: CyclingTechniqueData = null

func _ready():
	# Connect the signal passively to both subnodes' setter methods using Callable
	self.connect("current_technique_changed", Callable(cycling_technique_node, "set_technique_data"))
	self.connect("current_technique_changed", Callable(cycling_resource_panel_node, "set_technique_data"))
	
	cycling_resource_panel_node.open_technique_selector.connect(_on_open_technique_selector)
	#cycling_technique_selector.technique_selected.connect(_on_technique_selected)

	# Emit initial technique
	var foundation_technique = preload("res://resources/game_systems/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres")
	set_current_technique(foundation_technique)

func set_current_technique(data: CyclingTechniqueData):
	current_cycling_technique_data = data
	current_technique_changed.emit(data)

func _on_open_technique_selector():
	cycling_technique_selector.visible = true
	
