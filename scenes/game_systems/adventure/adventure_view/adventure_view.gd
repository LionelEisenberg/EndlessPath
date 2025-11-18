class_name AdventureView
extends Control

## AdventureView
## Main controller for the adventure mode, managing transitions between
## tilemap exploration and combat encounters

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var adventure_tilemap: AdventureTilemap = %AdventureTilemap
@onready var combat: AdventureCombat = %AdventureCombat

@onready var tilemap_view: Control = %TilemapView
@onready var combat_view: Control = %CombatView

@onready var character_info_panel: Panel = %CharacterInfoPanel

# TODO: DELETE AND UPDATE
@onready var health_label = $CharacterInfoPanel/Label
@onready var madra_label = $CharacterInfoPanel/Label2
@onready var stamina_label = $CharacterInfoPanel/Label3

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
var current_encounter: AdventureEncounter = null

var max_health: float = 100.0
var current_health: float:
	set(value):
		current_health = value
		_update_combat_resource_bars()

var max_madra: float = 100.0
var current_madra: float:
	set(value):
		current_madra = value
		_update_combat_resource_bars()

var max_stamina: float = 100.0
var current_stamina: float:
	set(value):
		current_stamina = value
		_update_combat_resource_bars()

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("AdventureView: Initializing")
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureView: ActionManager is missing!")
	
	if adventure_tilemap:
		adventure_tilemap.start_combat.connect(_on_start_combat)
	else:
		Log.error("AdventureView: AdventureTilemap reference is missing!")
	
	# TODO: Remove this temporary debug button
	$Button2.pressed.connect(_on_stop_combat)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Start an adventure with the given action data
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureView: Starting adventure - %s" % action_data.action_name)

	# Initialize resource values
	_initialize_combat_resources()
	
	adventure_tilemap.start_adventure(action_data)
	
	# Ensure we're showing the tilemap view
	tilemap_view.visible = true
	combat_view.visible = false


## Stop the current adventure and cleanup
func stop_adventure() -> void:
	Log.info("AdventureView: Stopping adventure")
	adventure_tilemap.stop_adventure()

#-----------------------------------------------------------------------------
# PRIVATE METHODS - View Management
#-----------------------------------------------------------------------------

## Transition from tilemap view to combat view
func _on_start_combat(encounter: AdventureEncounter) -> void:
	if encounter == null:
		Log.error("AdventureView: Cannot start combat with null encounter")
		return
	
	Log.info("AdventureView: Transitioning to combat view - %s" % encounter.encounter_name)
	tilemap_view.visible = false
	combat_view.visible = true
	
	# Start the combat encounter

## Transition from combat view back to tilemap view
func _on_stop_combat(encounter: AdventureEncounter = null, successful: bool = false) -> void:
	Log.info("AdventureView: Transitioning from combat to tilemap - Success: %s" % successful)
	tilemap_view.visible = true
	combat_view.visible = false
	
	# Notify the tilemap that combat has ended
	adventure_tilemap._stop_combat(encounter, successful)

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Initialize resource values
func _initialize_combat_resources() -> void:
	max_health = CharacterManager.get_max_health()
	current_health = max_health
	max_madra = CharacterManager.get_max_madra()
	current_madra = max_madra
	max_stamina = CharacterManager.get_max_stamina()
	current_stamina = max_stamina

	_update_combat_resource_bars()

## Update resource bars
func _update_combat_resource_bars() -> void:
	health_label.text = "Health: %s / %s" % [current_health, max_health]
	madra_label.text = "Madra: %s / %s" % [current_madra, max_madra]
	stamina_label.text = "Stamina: %s / %s" % [current_stamina, max_stamina]
