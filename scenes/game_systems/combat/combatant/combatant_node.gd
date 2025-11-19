class_name CombatantNode
extends Node2D

## CombatantNode
## Main node for a character in combat.
## Orchestrates Resource, Ability, and Effect components.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

# We create these in code or get them from children if they exist
@onready var resource_manager: CombatResourceManager = %CombatResourceManager
@onready var ability_manager: CombatAbilityManager = %CombatAbilityManager
@onready var effect_manager: CombatEffectManager = %CombatEffectManager

# Visuals
@onready var sprite: Sprite2D = $Sprite2D

# Data
var combatant_data: CombatantData
var is_player: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	pass

func setup(
	data: CombatantData, 
	external_resource_manager: CombatResourceManager = null, 
	p_is_player: bool = false
) -> void:
	# Setup is_player / combattant data
	if p_is_player and data:
		Log.warn("CombatantNode: is_player and combatant_data should not be set at the same time.")
	
	is_player = p_is_player
	combatant_data = data
	
	# Setup Managers - Resource, Ability, Effect
	if external_resource_manager:
		resource_manager = external_resource_manager
	else:
		resource_manager = $CombatResourceManager
		resource_manager.character_attributes_data = combatant_data.attributes
		resource_manager._initialize_current_values()
	
	ability_manager.setup(combatant_data, resource_manager)
	effect_manager.setup(combatant_data, resource_manager)

	_update_visuals()

	Log.info("CombatantNode: Setup complete for " + combatant_data.character_name)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Called by other combatants/abilities to apply effects
func receive_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData) -> void:
	effect_manager.process_effect(effect, source_attributes)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _update_visuals() -> void:
	sprite.texture = combatant_data.texture
