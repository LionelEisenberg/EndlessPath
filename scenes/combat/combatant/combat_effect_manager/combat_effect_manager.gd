class_name CombatEffectManager
extends Node

## CombatEffectManager
# Handles processing effects received by the combatant from other combatants abilities.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var owner_combatant: CombatantNode

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Sets up the manager with owner combatant reference.
func setup(p_owner: CombatantNode) -> void:
	owner_combatant = p_owner

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Processes an incoming effect from a source.
func process_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData) -> void:
	if not owner_combatant.vitals_manager:
		Log.error("CombatEffectManager: No resource manager set!")
		return
		
	# Calculate final value based on source attributes and target attributes (us)
	# Note: calculate_damage handles defense calculation if we pass our attributes
	var final_value = 0.0
	
	match effect.effect_type:
		CombatEffectData.EffectType.DAMAGE:
			final_value = effect.calculate_damage(source_attributes, owner_combatant.combatant_data.attributes)
			
			# Apply incoming damage modifier from buffs
			if owner_combatant.buff_manager:
				var damage_modifier = owner_combatant.buff_manager.get_incoming_damage_modifier()
				if damage_modifier != 1.0:
					Log.info("CombatEffectManager: Incoming damage modifier: %.2f" % damage_modifier)
					final_value *= damage_modifier
				owner_combatant.buff_manager.consume_incoming_modifier()
			
			Log.info("CombatEffectManager: %s Took %.1f damage from %s" % [owner_combatant.combatant_data.character_name, final_value, effect.effect_name])
			owner_combatant.vitals_manager.apply_vitals_change(-final_value, 0, 0)
			
		CombatEffectData.EffectType.HEAL:
			final_value = effect.calculate_value(source_attributes)
			Log.info("CombatEffectManager: %s Healed %.1f from %s" % [owner_combatant.combatant_data.character_name, final_value, effect.effect_name])
			owner_combatant.vitals_manager.apply_vitals_change(final_value, 0, 0)
		
		CombatEffectData.EffectType.BUFF:
			# Route to buff manager
			if owner_combatant.buff_manager and effect is BuffEffectData:
				var buff_effect := effect as BuffEffectData
				owner_combatant.buff_manager.apply_buff(buff_effect)
			else:
				Log.error("CombatEffectManager: Cannot apply buff - missing buff_manager or invalid effect type")
