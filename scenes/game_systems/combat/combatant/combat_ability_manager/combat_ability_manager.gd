class_name CombatAbilityManager
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_registered(instance: CombatAbilityInstance)
signal ability_used(instance: CombatAbilityInstance, target: CombatantNode)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var combatant_data: CombatantData
var resource_manager: CombatResourceManager
var abilities: Array[CombatAbilityInstance] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func setup(data: CombatantData, p_resource_manager: CombatResourceManager) -> void:
	combatant_data = data
	resource_manager = p_resource_manager
	
	_clear_abilities()
	
	for ability in combatant_data.abilities:
		_create_ability_instance(ability)

func _clear_abilities() -> void:
	for ability in abilities:
		ability.queue_free()
	abilities.clear()

func _create_ability_instance(ability_data: AbilityData) -> void:
	var instance = CombatAbilityInstance.new(ability_data, combatant_data.attributes)
	add_child(instance)
	abilities.append(instance)
	
	ability_registered.emit(instance)
	Log.info("CombatAbilityManager: %s: Registered ability %s" % [combatant_data.character_name, ability_data.ability_name])

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

func get_ability_count() -> int:
	return abilities.size()

func get_ability(index: int) -> CombatAbilityInstance:
	if index >= 0 and index < abilities.size():
		return abilities[index]
	return null

func use_ability(index: int, target: CombatantNode) -> bool:
	var instance = get_ability(index)

	# Consume Resources
	instance.ability_data.consume_costs(resource_manager)
	
	# Use Ability
	instance.use(target)
	ability_used.emit(instance)
	
	return true

func use_ability_instance(instance: CombatAbilityInstance, target: CombatantNode) -> bool:
	if not instance in abilities:
		Log.warn("CombatAbilityManager: %s: Ability instance %s not found" % [combatant_data.character_name, instance.ability_data.ability_name])
		#ability_failed.emit("Ability instance not found")
		return false
		
	# We can reuse the logic by finding the index, or just duplicating the checks.
	# Duplicating checks is safer if we want to support instances not in the list (though unlikely).
	# Better: Reuse logic.
	
	# Check Cooldown
	if not instance.is_ready():
		Log.debug("CombatAbilityManager: %s: Ability %s is on cooldown" % [combatant_data.character_name, instance.ability_data.ability_name])
		#ability_failed.emit("Ability on cooldown")
		return false
	
	# Check Resources
	if not instance.ability_data.can_afford(resource_manager):
		Log.warn("CombatAbilityManager: %s: Not enough resources for %s" % [combatant_data.character_name, instance.ability_data.ability_name])
		#ability_failed.emit("Not enough resources")
		return false
		
	# Consume Resources
	instance.ability_data.consume_costs(resource_manager)
	
	# Use Ability
	Log.info("CombatAbilityManager: %s: Used ability %s on %s" % [combatant_data.character_name, instance.ability_data.ability_name, target.name])
	instance.use(target)
	ability_used.emit(instance)
	return true
