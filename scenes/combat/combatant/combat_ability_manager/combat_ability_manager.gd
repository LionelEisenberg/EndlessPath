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
var vitals_manager: VitalsManager
var abilities: Array[CombatAbilityInstance] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Sets up the manager with data and resources.
func setup(data: CombatantData, p_vitals_manager: VitalsManager) -> void:
	combatant_data = data
	vitals_manager = p_vitals_manager
	
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

## Returns the number of abilities.
func get_ability_count() -> int:
	return abilities.size()

## Returns the ability instance at the given index from the abilities array.
func get_ability(index: int) -> CombatAbilityInstance:
	if index >= 0 and index < abilities.size():
		return abilities[index]
	return null

## Uses the specific ability instance on the target.
func use_ability_instance(instance: CombatAbilityInstance, target: CombatantNode) -> bool:
	if not instance in abilities:
		Log.warn("CombatAbilityManager: %s: Ability instance %s not found" % [combatant_data.character_name, instance.ability_data.ability_name])
		return false

	# Check Cooldown
	if not instance.is_ready():
		Log.warn("CombatAbilityManager: %s: Ability %s is on cooldown" % [combatant_data.character_name, instance.ability_data.ability_name])
		return false
	
	# Check Resources
	if not instance.ability_data.can_afford(vitals_manager):
		Log.warn("CombatAbilityManager: %s: Not enough resources for %s" % [combatant_data.character_name, instance.ability_data.ability_name])
		return false
		
	# Consume Resources
	instance.ability_data.consume_costs(vitals_manager)
	
	# Use Ability
	Log.info("CombatAbilityManager: %s: Used ability %s on %s" % [combatant_data.character_name, instance.ability_data.ability_name, target.name])
	instance.use(target)
	ability_used.emit(instance)
	return true
