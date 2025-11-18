class_name AdventureCombat
extends Node2D

## AdventureCombat
## Handles combat encounters during adventure mode
## This scene manages the combat UI, enemy spawning, and combat resolution

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var player_resource_manager: CombatResourceManager = null
var encounter: CombatEncounter = null

## TODO: DELETE DEBUG if click, reduce all resources by 10%
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		player_resource_manager.current_health -= 10
		player_resource_manager.current_madra -= 10
		player_resource_manager.current_stamina -= 10

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("AdventureCombat: Initialized")

func initialize_with_player_resource_manager(e: CombatEncounter, prm: CombatResourceManager) -> void:
	self.encounter = e
	self.player_resource_manager = prm



#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

func start() -> void:
	Log.info("AdventureCombat: Starting combat")
