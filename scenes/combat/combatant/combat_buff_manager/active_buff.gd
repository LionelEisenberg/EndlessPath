class_name ActiveBuff
extends RefCounted

## ActiveBuff
## Runtime instance tracking an active buff on a combatant.
## Stores the buff definition, remaining duration, and stack count.

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

## Reference to the buff definition
var buff_data: BuffEffectData

## Time remaining until buff expires (seconds)
var time_remaining: float

## Stack count for DoT stacking (increases damage multiplicatively)
var stack_count: int = 1

## For consume_on_use buffs: true if this buff has been used
var is_consumed: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(data: BuffEffectData) -> void:
	buff_data = data
	time_remaining = data.duration
	stack_count = 1
	is_consumed = false

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Refresh the duration to the buff's full duration
func refresh_duration() -> void:
	time_remaining = buff_data.duration

## Add a stack (for DoT stacking)
func add_stack() -> void:
	stack_count += 1

## Update the timer, returns true if buff should be removed
func tick(delta: float) -> bool:
	time_remaining -= delta
	return time_remaining <= 0.0 or is_consumed

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "ActiveBuff[%s] (%.1fs remaining, %d stacks)" % [
		buff_data.buff_id,
		time_remaining,
		stack_count
	]
