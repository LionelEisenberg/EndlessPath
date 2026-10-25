class_name CombatConsumableManager
extends Node

## CombatConsumableManager
##
## Manages a combatant's hotbar consumables in a fight. Mirrors
## CombatAbilityManager: it holds one CombatConsumableInstance per filled
## hotbar slot and routes each use through a gate.
##
## CONSUMABLE FLOW:
## 1. The dock asks can_use_consumable_instance(instance)
## 2. AdventureCombat calls use_consumable_instance(instance), which checks:
##    - Is the instance this manager's own?
##    - Is it recharging?
##    - Is any left?
## 3. If the checks pass, the instance fires and consumable_used is emitted.
##
## Only the player uses consumables: setup() leaves an enemy's manager empty.
## A technique being cast never blocks a consumable, and using one never stops
## the cast.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted after a consumable fired.
signal consumable_used(instance: CombatConsumableInstance)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var owner_combatant: CombatantNode
## One instance per filled hotbar slot, in slot order.
var consumables: Array[CombatConsumableInstance] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Sets up the manager for its combatant: for the player, one instance per
## filled hotbar slot (a slot with none left still gets one); for anyone else,
## none.
func setup(p_owner: CombatantNode) -> void:
	owner_combatant = p_owner

	_clear_consumables()

	if not owner_combatant.is_player:
		return

	var hotbar: Dictionary[int, ConsumableDefinitionData] = InventoryManager.get_inventory().equipped_consumables
	var slots: Array[int] = []
	slots.assign(hotbar.keys())
	slots.sort()
	for slot_index: int in slots:
		if hotbar[slot_index] != null:
			_create_consumable_instance(hotbar[slot_index], slot_index)

func _clear_consumables() -> void:
	for instance: CombatConsumableInstance in consumables:
		instance.queue_free()
	consumables.clear()

func _create_consumable_instance(data: ConsumableDefinitionData, slot_index: int) -> void:
	var instance := CombatConsumableInstance.new(data, slot_index)
	add_child(instance)
	consumables.append(instance)
	Log.info("CombatConsumableManager: Registered consumable %s in hotbar slot %d" % [data.item_name, slot_index])

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns true if the instance is this manager's own, is not recharging and
## has at least one left.
func can_use_consumable_instance(instance: CombatConsumableInstance) -> bool:
	if not instance in consumables:
		return false
	return instance.is_ready() and instance.get_count() > 0

## Uses the consumable instance. Returns true if it fired.
func use_consumable_instance(instance: CombatConsumableInstance) -> bool:
	if not can_use_consumable_instance(instance):
		return false
	if not instance.use():
		return false
	consumable_used.emit(instance)
	return true

## Returns the instance for hotbar slot slot_index, or null when that slot is
## empty.
func get_instance_at_slot(slot_index: int) -> CombatConsumableInstance:
	for instance: CombatConsumableInstance in consumables:
		if instance.slot_index == slot_index:
			return instance
	return null
