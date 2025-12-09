class_name CombatAbilityManager
extends Node

## CombatAbilityManager
##
## Manages the abilities for a specific combatant.
## Handles ability registration, resource checks, cooldown checks, and execution flow.
##
## ABILITY FLOW:
## 1. External system (UI/AI) calls use_ability_instance(instance, target)
## 2. Manager checks:
##    - Is already casting? (Blocking)
##    - Is ability on cooldown?
##    - Are resources available?
## 3. If checks pass:
##    - Resources are consumed immediately.
##    - Ability instance start_cast() is called.
##    - Internal signals emitted.

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

## Returns true if any ability is currently casting.
func is_casting() -> bool:
	for ability in abilities:
		if ability.is_casting:
			return true
	return false

## Returns the number of abilities.
func get_ability_count() -> int:
	return abilities.size()

## Returns the ability instance at the given index from the abilities array.
func get_ability(index: int) -> CombatAbilityInstance:
	if index >= 0 and index < abilities.size():
		return abilities[index]
	return null

## Uses the specific ability instance on the target.
## Returns true if the request was accepted (checks passed and cast started).
func use_ability_instance(instance: CombatAbilityInstance, enemy: CombatantNode) -> bool:
	if not instance in abilities:
		Log.warn("CombatAbilityManager: %s: Ability instance %s not found" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name])
		return false

	# Check Casting State (Global Lock)
	if is_casting():
		Log.warn("CombatAbilityManager: %s: Cannot use ability while casting" % [owner_combatant.combatant_data.character_name])
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
	
	# Start Cast
	# Log info is handled inside start_cast if casting, or locally if instant? 
	# Actually start_cast logs cast start. execute_ability logs execution. 
	# We can log the "Attempt" here.
	Log.info("CombatAbilityManager: %s: Triggering ability %s on %s" % [owner_combatant.combatant_data.character_name, instance.ability_data.ability_name, target.name])
	
	instance.start_cast(target)
	ability_used.emit(instance) # Emitted when usage is accepted/started
	return true
