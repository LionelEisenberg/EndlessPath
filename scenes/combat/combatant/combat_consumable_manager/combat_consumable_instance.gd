class_name CombatConsumableInstance
extends Node

## CombatConsumableInstance
##
## One hotbar consumable in a fight: its definition, the hotbar slot it sits
## in (0 to 3) and its own cooldown. Mirrors CombatAbilityInstance, without
## casting: a consumable acts at once.
##
## LOGIC FLOW:
## 1. CombatConsumableManager calls use()
## 2. use() refuses while the cooldown runs or when none are left
## 3. Otherwise InventoryManager.use_consumable() fires the effects and takes
##    one off the stack, and the cooldown starts (when cooldown_seconds > 0)
##
## There is no opening cooldown: a consumable is ready as the fight opens. The
## instance is freed with its combatant when the fight ends, so every fight
## starts its cooldowns afresh.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal cooldown_started(duration: float)
signal cooldown_updated(time_left: float)
signal cooldown_ready()

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

var consumable_data: ConsumableDefinitionData
var slot_index: int
var cooldown_timer: Timer
var use_count: int = 0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(data: ConsumableDefinitionData, p_slot_index: int) -> void:
	consumable_data = data
	slot_index = p_slot_index
	name = "ConsumableInstance_%d" % p_slot_index

func _ready() -> void:
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

func _process(_delta: float) -> void:
	if not cooldown_timer.is_stopped():
		cooldown_updated.emit(cooldown_timer.time_left)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns true when the consumable is not recharging.
func is_ready() -> bool:
	return cooldown_timer.is_stopped()

## Returns how many of the consumable the player holds.
func get_count() -> int:
	return InventoryManager.get_consumable_count(consumable_data)

## Fires the consumable (its effects, then one off the stack) and starts its
## cooldown. Returns false, doing nothing, while it recharges or when none are
## left.
func use() -> bool:
	if not is_ready() or get_count() <= 0:
		return false
	if not InventoryManager.use_consumable(consumable_data):
		return false
	use_count += 1
	_start_cooldown(consumable_data.cooldown_seconds)
	return true

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _start_cooldown(duration: float) -> void:
	if duration <= 0.0:
		return
	cooldown_timer.start(duration)
	cooldown_started.emit(duration)

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()
