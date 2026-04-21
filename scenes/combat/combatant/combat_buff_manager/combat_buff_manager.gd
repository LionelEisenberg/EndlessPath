class_name CombatBuffManager
extends Node

## CombatBuffManager
## Manages all active buffs and debuffs on a combatant.
## Handles buff application, stacking, duration, DoT ticks, and damage modifiers.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DOT_TICK_INTERVAL: float = 1.0

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal buff_applied(buff_id: String, duration: float)
signal buff_removed(buff_id: String)
signal buff_refreshed(buff_id: String, new_duration: float)
signal buff_stacked(buff_id: String, stack_count: int)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var owner_combatant: CombatantNode
var active_buffs: Array[ActiveBuff] = []

var _dot_timer: Timer

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	_setup_dot_timer()

func _setup_dot_timer() -> void:
	_dot_timer = Timer.new()
	_dot_timer.wait_time = DOT_TICK_INTERVAL
	_dot_timer.one_shot = false
	_dot_timer.timeout.connect(_on_dot_tick)
	add_child(_dot_timer)

## Sets up the manager with owner combatant reference.
func setup(p_owner: CombatantNode) -> void:
	owner_combatant = p_owner

#-----------------------------------------------------------------------------
# PROCESS - Duration Updates
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_durations(delta)

func _update_durations(delta: float) -> void:
	var buffs_to_remove: Array[ActiveBuff] = []
	
	for buff in active_buffs:
		if buff.tick(delta):
			buffs_to_remove.append(buff)
	
	for buff in buffs_to_remove:
		_remove_buff(buff)

#-----------------------------------------------------------------------------
# PUBLIC API - Buff Application
#-----------------------------------------------------------------------------

## Apply a buff to this combatant.
func apply_buff(buff_data: BuffEffectData) -> void:
	if not buff_data.validate():
		Log.error("CombatBuffManager: Invalid buff data")
		return
	
	# Check if buff with same ID already exists
	var existing_buff = _find_buff_by_id(buff_data.buff_id)
	
	if existing_buff:
		# Refresh duration
		existing_buff.refresh_duration()
		Log.info("CombatBuffManager: Refreshed buff '%s' (%.1fs)" % [buff_data.buff_id, buff_data.duration])
		buff_refreshed.emit(buff_data.buff_id, buff_data.duration)
		
		# For DoT, also add a stack
		if buff_data.buff_type == BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			existing_buff.add_stack()
			Log.info("CombatBuffManager: DoT '%s' now has %d stacks" % [buff_data.buff_id, existing_buff.stack_count])
			buff_stacked.emit(buff_data.buff_id, existing_buff.stack_count)
	else:
		# Create new buff
		var new_buff = ActiveBuff.new(buff_data)
		active_buffs.append(new_buff)
		Log.info("CombatBuffManager: Applied buff '%s' for %.1fs" % [buff_data.buff_id, buff_data.duration])
		buff_applied.emit(buff_data.buff_id, buff_data.duration)

	# Start DoT timer if a DoT buff is now active and timer is stopped
	if buff_data.buff_type == BuffEffectData.BuffType.DAMAGE_OVER_TIME and _dot_timer.is_stopped():
		_dot_timer.start()

## Remove a buff by ID.
func remove_buff(buff_id: String) -> void:
	var buff = _find_buff_by_id(buff_id)
	if buff:
		_remove_buff(buff)

## Clear all active buffs (called on combat end).
func clear_all_buffs() -> void:
	for buff in active_buffs:
		buff_removed.emit(buff.buff_data.buff_id)
	active_buffs.clear()
	_dot_timer.stop()
	Log.info("CombatBuffManager: Cleared all buffs")

## Strips every active buff from this combatant as a mid-combat operation.
## Emits buff_removed for each buff removed and stops the DoT timer if no
## DoT buffs remain. Different from clear_all_buffs(), which is for combat end.
func strip_all_buffs() -> void:
	if active_buffs.is_empty():
		return

	var to_remove: Array[ActiveBuff] = active_buffs.duplicate()
	for buff in to_remove:
		_remove_buff(buff)
	Log.info("CombatBuffManager: Stripped %d buffs" % to_remove.size())

#-----------------------------------------------------------------------------
# PUBLIC API - Modifier Queries
#-----------------------------------------------------------------------------

## Get the total attribute modifier for a specific attribute.
## Returns 1.0 if no modifiers (base value = 100%).
## Multiple buffs stack multiplicatively.
func get_attribute_modifier(attr_type: CharacterAttributesData.AttributeType) -> float:
	var total_modifier: float = 1.0
	
	for buff in active_buffs:
		if buff.buff_data.buff_type == BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE:
			if buff.buff_data.attribute_modifiers.has(attr_type):
				total_modifier *= buff.buff_data.attribute_modifiers[attr_type]
	
	return total_modifier

## Get the total outgoing damage modifier.
## Returns 1.0 if no modifiers.
func get_outgoing_damage_modifier() -> float:
	var total_modifier: float = 1.0
	
	for buff in active_buffs:
		if buff.buff_data.buff_type == BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER:
			if not buff.is_consumed:
				total_modifier *= buff.buff_data.damage_multiplier
	
	return total_modifier

## Get the total incoming damage modifier.
## Returns 1.0 if no modifiers.
func get_incoming_damage_modifier() -> float:
	var total_modifier: float = 1.0
	
	for buff in active_buffs:
		if buff.buff_data.buff_type == BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER:
			if not buff.is_consumed:
				total_modifier *= buff.buff_data.damage_multiplier
	
	return total_modifier

## Returns the total outgoing damage modifier (multiplied across every active
## outgoing-damage buff) AND consumes any consume_on_use buffs in the process.
## Call once per outgoing damage event; multiply the result into the damage.
func consume_outgoing_modifier() -> float:
	var total_modifier: float = 1.0
	for buff in active_buffs:
		if buff.buff_data.buff_type != BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER:
			continue
		if buff.is_consumed:
			continue
		total_modifier *= buff.buff_data.damage_multiplier
		if buff.buff_data.consume_on_use:
			buff.is_consumed = true
			Log.info("CombatBuffManager: Consumed outgoing damage buff '%s'" % buff.buff_data.buff_id)
	return total_modifier

## Returns the total incoming damage modifier (multiplied across every active
## incoming-damage buff) AND consumes any consume_on_use buffs in the process.
## Call once per incoming damage event; multiply the result into the damage.
func consume_incoming_modifier() -> float:
	var total_modifier: float = 1.0
	for buff in active_buffs:
		if buff.buff_data.buff_type != BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER:
			continue
		if buff.is_consumed:
			continue
		total_modifier *= buff.buff_data.damage_multiplier
		if buff.buff_data.consume_on_use:
			buff.is_consumed = true
			Log.info("CombatBuffManager: Consumed incoming damage buff '%s'" % buff.buff_data.buff_id)
	return total_modifier

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _find_buff_by_id(buff_id: String) -> ActiveBuff:
	for buff in active_buffs:
		if buff.buff_data.buff_id == buff_id:
			return buff
	return null

func _remove_buff(buff: ActiveBuff) -> void:
	var was_dot: bool = buff.buff_data.buff_type == BuffEffectData.BuffType.DAMAGE_OVER_TIME
	active_buffs.erase(buff)
	Log.info("CombatBuffManager: Removed buff '%s'" % buff.buff_data.buff_id)
	buff_removed.emit(buff.buff_data.buff_id)

	# Stop DoT timer if no DoT buffs remain
	if was_dot and not _has_active_dots():
		_dot_timer.stop()

func _has_active_dots() -> bool:
	for buff in active_buffs:
		if buff.buff_data.buff_type == BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			return true
	return false

#-----------------------------------------------------------------------------
# DOT PROCESSING
#-----------------------------------------------------------------------------

func _on_dot_tick() -> void:
	for buff in active_buffs:
		if buff.buff_data.buff_type == BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			_apply_dot_damage(buff)

func _apply_dot_damage(buff: ActiveBuff) -> void:
	if not owner_combatant.vitals_manager:
		Log.error("CombatBuffManager: No vitals manager for DoT damage")
		return
	
	# Calculate damage: base damage * stack count
	var damage = buff.buff_data.dot_damage_per_tick * buff.stack_count
	
	Log.info("CombatBuffManager: DoT '%s' deals %.1f damage (%d stacks)" % [
		buff.buff_data.buff_id,
		damage,
		buff.stack_count
	])
	
	owner_combatant.vitals_manager.apply_vitals_change(-damage, 0, 0)
