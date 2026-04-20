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
@onready var vitals_manager: VitalsManager = %VitalsManager
@onready var ability_manager: CombatAbilityManager = %CombatAbilityManager
@onready var effect_manager: CombatEffectManager = %CombatEffectManager
@onready var buff_manager: CombatBuffManager = %CombatBuffManager

# Data
var combatant_data: CombatantData
var is_player: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	pass

## Sets up the combatant with data and optional external resources.
func setup(
	data: CombatantData,
	external_vitals_manager: VitalsManager = null,
	p_is_player: bool = false
) -> void:
	is_player = p_is_player
	combatant_data = data
	
	# Setup Managers - Resource, Ability, Effect
	if external_vitals_manager:
		vitals_manager = external_vitals_manager
	else:
		vitals_manager = %VitalsManager
		vitals_manager.character_attributes_data = combatant_data.attributes
		vitals_manager.initialize_current_values()
	
	buff_manager.setup(self)
	ability_manager.setup(self)
	effect_manager.setup(self)

	_update_visuals()

	Log.info("CombatantNode: Setup complete for " + combatant_data.character_name)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Called by other combatants/abilities to apply effects.
## `outgoing_modifier` carries the source's outgoing-damage buff multiplier
## (already consumed on the source side). Defaults to 1.0 for non-damage
## effects or callers that don't need to scale damage.
func receive_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData, outgoing_modifier: float = 1.0) -> void:
	effect_manager.process_effect(effect, source_attributes, outgoing_modifier)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _update_visuals() -> void:
	# pass
	pass
