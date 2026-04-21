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
## `outgoing_modifier` is the source's outgoing-damage buff multiplier,
## already consumed on the source side and passed here to multiply into
## damage. Defaults to 1.0 for non-damage effects.
func process_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData, outgoing_modifier: float = 1.0) -> void:
	if not owner_combatant.vitals_manager:
		Log.error("CombatEffectManager: No resource manager set!")
		return

	# Calculate final value based on source attributes and target attributes (us)
	# Note: calculate_damage handles defense calculation if we pass our attributes
	var final_value = 0.0

	match effect.effect_type:
		CombatEffectData.EffectType.DAMAGE:
			final_value = effect.calculate_damage(source_attributes, owner_combatant.combatant_data.attributes)

			# Apply outgoing damage modifier from the source's buffs
			if outgoing_modifier != 1.0:
				Log.info("CombatEffectManager: Outgoing damage modifier: %.2f" % outgoing_modifier)
				final_value *= outgoing_modifier

			# Apply incoming damage modifier from our buffs (consumes consume_on_use)
			if owner_combatant.buff_manager:
				var incoming_modifier: float = owner_combatant.buff_manager.consume_incoming_modifier()
				if incoming_modifier != 1.0:
					Log.info("CombatEffectManager: Incoming damage modifier: %.2f" % incoming_modifier)
					final_value *= incoming_modifier
			
			Log.info("CombatEffectManager: %s Took %.1f damage from %s" % [owner_combatant.combatant_data.character_name, final_value, effect.effect_name])
			owner_combatant.vitals_manager.apply_vitals_change(-final_value, 0, 0)
			
			if LogManager:
				# If player takes damage: Player (green) took damage (red)
				# If enemy takes damage: Enemy (red) took damage (white/yellow?)
				# Lets keep it simple:
				# [b]Target[/b] took [color=red]X Damage[/color]
				LogManager.log_message("[b]%s[/b] took [color=red]%d Damage[/color]" % [owner_combatant.combatant_data.character_name, int(final_value)])
			
		CombatEffectData.EffectType.HEAL:
			final_value = effect.calculate_value(source_attributes)
			Log.info("CombatEffectManager: %s Healed %.1f from %s" % [owner_combatant.combatant_data.character_name, final_value, effect.effect_name])
			owner_combatant.vitals_manager.apply_vitals_change(final_value, 0, 0)
			
			if LogManager:
				LogManager.log_message("[b]%s[/b] healed for [color=green]%d Health[/color]" % [owner_combatant.combatant_data.character_name, int(final_value)])
		
		CombatEffectData.EffectType.BUFF:
			# Route to buff manager
			if owner_combatant.buff_manager and effect is BuffEffectData:
				var buff_effect := effect as BuffEffectData
				owner_combatant.buff_manager.apply_buff(buff_effect)
			else:
				Log.error("CombatEffectManager: Cannot apply buff - missing buff_manager or invalid effect type")

		CombatEffectData.EffectType.CANCEL_CAST:
			# owner_combatant here = the target of this effect.
			# Cancel the target's in-progress cast if any.
			if owner_combatant.ability_manager:
				var cancelled: bool = owner_combatant.ability_manager.cancel_current_cast()
				if cancelled:
					Log.info("CombatEffectManager: %s's cast was cancelled by %s" % [
						owner_combatant.combatant_data.character_name, effect.effect_name])
					if LogManager:
						LogManager.log_message("[b]%s[/b]'s cast was [color=cyan]interrupted[/color]!" % owner_combatant.combatant_data.character_name)
			else:
				Log.error("CombatEffectManager: Cannot cancel cast - missing ability_manager")

		CombatEffectData.EffectType.STRIP_BUFFS:
			# owner_combatant here = the target of this effect.
			# Strip all buffs currently on the target.
			if owner_combatant.buff_manager:
				owner_combatant.buff_manager.strip_all_buffs()
				Log.info("CombatEffectManager: %s's buffs stripped by %s" % [
					owner_combatant.combatant_data.character_name, effect.effect_name])
				if LogManager:
					LogManager.log_message("[b]%s[/b]'s buffs were [color=cyan]stripped[/color]!" % owner_combatant.combatant_data.character_name)
			else:
				Log.error("CombatEffectManager: Cannot strip buffs - missing buff_manager")
