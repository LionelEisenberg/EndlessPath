class_name CombatEffectManager
extends Node

## CombatEffectManager
# Handles processing effects received by the combatant from other combatants abilities.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var combatant_data: CombatantData
var resource_manager: CombatResourceManager

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func setup(data: CombatantData, p_resource_manager: CombatResourceManager) -> void:
	combatant_data = data
	resource_manager = p_resource_manager

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

func process_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData) -> void:
	if not resource_manager:
		Log.error("CombatEffectManager: No resource manager set!")
		return
		
	# Calculate final value based on source attributes and target attributes (us)
	# Note: calculate_damage handles defense calculation if we pass our attributes
	var final_value = 0.0
	
	match effect.effect_type:
		CombatEffectData.EffectType.DAMAGE:
			final_value = effect.calculate_damage(source_attributes, combatant_data.attributes)
			resource_manager.current_health -= final_value
			Log.info("CombatEffectManager: Took %.1f damage from %s" % [final_value, effect.effect_name])
			
		CombatEffectData.EffectType.HEAL:
			final_value = effect.calculate_value(source_attributes)
			resource_manager.current_health += final_value
			Log.info("CombatEffectManager: Healed %.1f from %s" % [final_value, effect.effect_name])
