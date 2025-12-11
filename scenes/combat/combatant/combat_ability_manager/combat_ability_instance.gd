class_name CombatAbilityInstance
extends Node

## CombatAbilityInstance
## 
## Handles the lifecycle of a specific ability for a combatant.
##
## LOGIC FLOW:
## 1. Manager calls start_cast(target)
## 2. If cast_time > 0:
##    - Enter "casting" state
##    - Start cast_timer
##    - Emit cast_started
##    - While casting, emit cast_updated every frame
##    - On timeout -> execute_ability(target) & emit cast_finished
## 3. If cast_time <= 0:
##    - Immediately call execute_ability(target)
##
## EXECUTION:
## - Applies effects to target
## - Starts cooldown timer
## - Consumes outgoing modifiers

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const INITIAL_COOLDOWN: float = 1.5

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal cooldown_started(duration: float)
signal cooldown_updated(time_left: float)
signal cooldown_ready()

# Casting Signals
signal cast_started(instance: CombatAbilityInstance, duration: float)
signal cast_updated(instance: CombatAbilityInstance, time_left: float)
signal cast_finished(instance: CombatAbilityInstance)

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

var ability_data: AbilityData
var owner_combatant: CombatantNode
var cooldown_timer: Timer
var cast_timer: Timer
var use_count: int = 0

# Casting State
var is_casting: bool = false
var _current_target: CombatantNode = null

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(data: AbilityData, p_owner: CombatantNode) -> void:
	ability_data = data
	owner_combatant = p_owner
	name = "AbilityInstance_%s" % data.ability_name

func _ready() -> void:
	# Cooldown Timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Cast Timer
	cast_timer = Timer.new()
	cast_timer.one_shot = true
	cast_timer.timeout.connect(_on_cast_timeout)
	add_child(cast_timer)
	
	cooldown_timer.wait_time = max(ability_data.base_cooldown, 0.001)
	_start_cooldown(INITIAL_COOLDOWN)

func _process(_delta: float) -> void:
	if not cooldown_timer.is_stopped():
		cooldown_updated.emit(cooldown_timer.time_left)
		
	if is_casting and not cast_timer.is_stopped():
		cast_updated.emit(self, cast_timer.time_left)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Checks if the ability is ready to be used (not on cooldown and not casting).
func is_ready() -> bool:
	return cooldown_timer.is_stopped() and not is_casting

## Starts the casting process for the ability.
## If cast_time is 0, executes immediately.
func start_cast(target: CombatantNode) -> void:
	if not is_ready():
		Log.warn("CombatAbilityInstance: Attempted to start cast while not ready.")
		return
	
	_current_target = target
	
	if ability_data.cast_time > 0:
		is_casting = true
		cast_timer.start(ability_data.cast_time)
		cast_started.emit(self, ability_data.cast_time)
		Log.info("CombatAbilityInstance: Started casting %s (%.1fs)" % [ability_data.ability_name, ability_data.cast_time])
	else:
		execute_ability(target)

## Internal method to execute the ability effects. 
## Called immediately for instant abilities, or after cast timer for casted abilities.
func execute_ability(target: CombatantNode) -> void:
	use_count += 1
	
	# Start Cooldown
	var cooldown = ability_data.base_cooldown
	_start_cooldown(cooldown)
	
	# Get modified attributes (with buff multipliers applied)
	var modified_attributes = _get_modified_attributes()
	
	# Consume outgoing damage modifiers if this is an offensive ability
	if ability_data.ability_type == AbilityData.AbilityType.OFFENSIVE:
		if owner_combatant.buff_manager:
			owner_combatant.buff_manager.consume_outgoing_modifier()
	
	# Apply Effects
	if target:
		for effect in ability_data.effects:
			if target.has_method("receive_effect"):
				target.receive_effect(effect, modified_attributes)
				
	Log.info("CombatAbilityInstance: Executed ability %s" % ability_data.ability_name)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _start_cooldown(cooldown: float) -> void:
	if ability_data.base_cooldown > 0:
		cooldown_timer.start(cooldown)
		cooldown_started.emit(ability_data.base_cooldown)

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()

func _on_cast_timeout() -> void:
	if is_casting:
		is_casting = false
		execute_ability(_current_target)
		cast_finished.emit(self)
		_current_target = null

## Creates a modified copy of source_attributes with buff multipliers applied.
func _get_modified_attributes() -> CharacterAttributesData:
	var source_attributes = owner_combatant.combatant_data.attributes
	if not owner_combatant.buff_manager:
		return source_attributes
	
	# Create a new attributes data with modified values
	var modified = CharacterAttributesData.new()
	
	for attr_type in CharacterAttributesData.AttributeType.values():
		var base_value = source_attributes.get_attribute(attr_type)
		var multiplier = owner_combatant.buff_manager.get_attribute_modifier(attr_type)
		var final_value = base_value * multiplier
		modified.attributes[attr_type] = final_value
		
		if multiplier != 1.0:
			var attr_name = CharacterAttributesData.AttributeType.keys()[attr_type]
			Log.info("CombatAbilityInstance: %s modified by %.2fx (%.1f -> %.1f)" % [attr_name, multiplier, base_value, final_value])
	
	return modified
