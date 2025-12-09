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

var owner_combatant: CombatantNode
var abilities: Array[CombatAbilityInstance] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Sets up the manager with owner combatant reference.
func setup(p_owner: CombatantNode) -> void:
	owner_combatant = p_owner
	
	_clear_abilities()
	
	for ability in owner_combatant.combatant_data.abilities:
		_create_ability_instance(ability)

func _clear_abilities() -> void:
	for ability in abilities:
		ability.queue_free()
	abilities.clear()

func _create_ability_instance(ability_data: AbilityData) -> void:
	var instance = CombatAbilityInstance.new(ability_data, owner_combatant)
	add_child(instance)
	abilities.append(instance)
	
	ability_registered.emit(instance)
	Log.info("CombatAbilityManager: %s: Registered ability %s" % [owner_combatant.combatant_data.character_name, ability_data.ability_name])

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
func use_ability_instance(instance: CombatAbilityInstance, enemy: CombatantNode) -> bool:
	if not instance in abilities:
		Log.warn("CombatAbilityManager: %s: Ability instance %s not found" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name])
		return false

	# Check Cooldown
	if not instance.is_ready():
		Log.warn("CombatAbilityManager: %s: Ability %s is on cooldown" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name])
		return false
	
	# Check Resources
	if not instance.ability_data.can_afford(owner_combatant.vitals_manager):
		Log.warn("CombatAbilityManager: %s: Not enough resources for %s" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name])
		return false
		
	# Consume Resources
	instance.ability_data.consume_costs(owner_combatant.vitals_manager)
	
	# Determine actual target based on target type
	var target = enemy
	if instance.ability_data.target_type == AbilityData.TargetType.SELF:
		target = owner_combatant
	
	# Use Ability
	Log.info("CombatAbilityManager: %s: Used ability %s on %s" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name, target.name])
	instance.use(target)
	ability_used.emit(instance)
	return true
