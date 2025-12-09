class_name CombatAbilityInstance
extends Node

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

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

var ability_data: AbilityData
var owner_combatant: CombatantNode
var cooldown_timer: Timer
var use_count: int = 0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(data: AbilityData, p_owner: CombatantNode) -> void:
	ability_data = data
	owner_combatant = p_owner
	name = "AbilityInstance_%s" % data.ability_name

func _ready() -> void:
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	cooldown_timer.wait_time = ability_data.base_cooldown
	_start_cooldown(INITIAL_COOLDOWN)

func _process(_delta: float) -> void:
	if not cooldown_timer.is_stopped():
		cooldown_updated.emit(cooldown_timer.time_left)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Checks if the ability is ready to be used (not on cooldown).
func is_ready() -> bool:
	return cooldown_timer.is_stopped()

## Uses the ability on the given target.
func use(target: CombatantNode) -> void:
	if not is_ready():
		return
		
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
	for effect in ability_data.effects:
		if target.has_method("receive_effect"):
			target.receive_effect(effect, modified_attributes)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _start_cooldown(cooldown: float):
	if ability_data.base_cooldown > 0:
		cooldown_timer.start(cooldown)
		cooldown_started.emit(ability_data.base_cooldown)

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()

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
