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

@onready var player_info_panel: CombatantInfoPanel = %PlayerInfoPanel
@onready var player_resource_manager : CombatResourceManager = %PlayerResourceManager

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
var current_encounter: AdventureEncounter = null

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
	
	# Connect to the combat node
	combat.trigger_combat_end.connect(_on_stop_combat)
	
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
func _on_start_combat(encounter: CombatEncounter) -> void:
	if encounter == null:
		Log.error("AdventureView: Cannot start combat with null encounter")
		return
	
	Log.info("AdventureView: Transitioning to combat view - %s" % encounter.encounter_name)
	tilemap_view.visible = false
	combat_view.visible = true
	
	# Start the combat encounter
	if combat:
		combat.initialize_with_player_resource_manager(encounter, player_resource_manager)
		combat.start()
		

## Transition from combat view back to tilemap view
func _on_stop_combat(successful: bool = false) -> void:
	Log.info("AdventureView: Transitioning from combat to tilemap - Success: %s" % successful)
	tilemap_view.visible = true
	combat_view.visible = false
	
	# Notify the tilemap that combat has ended
	combat.stop()
	adventure_tilemap._stop_combat(successful)
	
	if not successful:
		ActionManager.stop_action(successful)

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Initialize resource values
func _initialize_combat_resources() -> void:
	player_resource_manager._initialize_current_values()
	player_info_panel.setup(player_resource_manager)
