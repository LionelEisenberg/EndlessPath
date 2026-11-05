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
## - The target may dodge: its effects are skipped, the caster's own still apply
## - Starts cooldown timer, the player's shortened by Control (get_cooldown_cut())
## - Consumes outgoing modifiers

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const INITIAL_COOLDOWN: float = 1.5

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when a cooldown starts, with the duration actually started: the
## opening INITIAL_COOLDOWN, or the cooldown after the player's Control cut.
signal cooldown_started(duration: float)
signal cooldown_updated(time_left: float)
signal cooldown_ready()

# Casting Signals
signal cast_started(instance: CombatAbilityInstance, duration: float)
signal cast_updated(instance: CombatAbilityInstance, time_left: float)
signal cast_finished(instance: CombatAbilityInstance)
signal cast_cancelled(instance: CombatAbilityInstance)

## Emitted right before the ability's effects are applied (instant or after cast).
signal executed(instance: CombatAbilityInstance)

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

## The player's Madra cost cut, from the Control of its fight snapshot
## (CharacterAttributesData.get_madra_cost_cut()): the cast gate and the payment
## take it off the technique's Madra cost. 0.0 for an enemy or an instance with
## no owner, whose costs are never cut.
func get_cost_cut() -> float:
	var attributes: CharacterAttributesData = _player_attributes()
	return attributes.get_madra_cost_cut() if attributes != null else 0.0

## The player's cooldown cut, from the Control of its fight snapshot
## (CharacterAttributesData.get_cooldown_cut()): a cast and a cancelled cast take
## it off the technique's cooldown, the opening one never. 0.0 for an enemy or an
## instance with no owner, whose cooldowns are never cut.
func get_cooldown_cut() -> float:
	var attributes: CharacterAttributesData = _player_attributes()
	return attributes.get_cooldown_cut() if attributes != null else 0.0

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
## The target may dodge first: then none of its effects land, but the caster's own do.
func execute_ability(target: CombatantNode) -> void:
	use_count += 1
	executed.emit(self)

	# Start the cooldown, the player's cut by Control
	_start_cooldown(ability_data.get_cooldown(get_cooldown_cut()))

	# Get modified attributes (with buff multipliers applied)
	var modified_attributes = _get_modified_attributes()
	
	# Consume outgoing damage modifiers if this ability deals damage.
	# The modifier multiplies into damage at the target's process_effect.
	var outgoing_modifier: float = 1.0
	if ability_data.deals_damage():
		if owner_combatant.buff_manager:
			outgoing_modifier = owner_combatant.buff_manager.consume_outgoing_modifier()

	# Apply effects to the enemy target (outgoing modifier multiplies into damage there),
	# unless it dodges, which skips every one of them, riders too. The dodge is asked
	# last, so a cast with no effect on its target never rolls one.
	if target and target.has_method("receive_effect") \
			and not ability_data.effects_on_target.is_empty() \
			and not _dodged_by(target):
		for effect in ability_data.effects_on_target:
			target.receive_effect(effect, modified_attributes, outgoing_modifier)

	# Apply effects to self (caster), dodged or not. Outgoing modifier does not apply
	# here — self-effects are not "outgoing attacks" from the caster's perspective.
	if owner_combatant and owner_combatant.has_method("receive_effect"):
		for effect in ability_data.effects_on_self:
			owner_combatant.receive_effect(effect, modified_attributes, 1.0)

	Log.info("CombatAbilityInstance: Executed ability %s" % ability_data.ability_name)

## Cancels an in-progress cast. Stops the cast timer, resets casting state,
## starts the ability's cooldown (the player's cut by Control), and emits
## cast_cancelled.
## No-op if not currently casting.
func cancel_cast() -> void:
	if not is_casting:
		return

	is_casting = false
	cast_timer.stop()
	_current_target = null
	_start_cooldown(ability_data.get_cooldown(get_cooldown_cut()))
	cast_cancelled.emit(self)
	Log.info("CombatAbilityInstance: Cancelled cast of %s" % ability_data.ability_name)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

## Starts a cooldown of `cooldown` seconds and reports it on cooldown_started.
## A technique with no cooldown of its own starts none, not even the opening one.
func _start_cooldown(cooldown: float) -> void:
	if ability_data.base_cooldown > 0:
		cooldown_timer.start(cooldown)
		cooldown_started.emit(cooldown)

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()

func _on_cast_timeout() -> void:
	if is_casting:
		is_casting = false
		execute_ability(_current_target)
		cast_finished.emit(self)
		_current_target = null

## Whether the target dodges this cast (only the player can: its effect manager's
## try_dodge()). A dodge floats "Dodged" over the target and goes in the log.
func _dodged_by(target: CombatantNode) -> bool:
	if target.effect_manager == null or not target.effect_manager.try_dodge():
		return false
	if target.visual:
		target.visual.play_dodge()
	LogManager.log_message("[b]%s[/b] dodged %s" % [target.combatant_data.character_name, ability_data.ability_name])
	return true

## The player's fight snapshot, whose Control gives the cuts, or null for an
## enemy, for an instance with no owner and for an owner with no data.
func _player_attributes() -> CharacterAttributesData:
	if owner_combatant == null or not owner_combatant.is_player or owner_combatant.combatant_data == null:
		return null
	return owner_combatant.combatant_data.attributes

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
		modified.set_attribute(attr_type, final_value)
		
		if multiplier != 1.0:
			var attr_name = CharacterAttributesData.AttributeType.keys()[attr_type]
			Log.info("CombatAbilityInstance: %s modified by %.2fx (%.1f -> %.1f)" % [attr_name, multiplier, base_value, final_value])
	
	return modified
