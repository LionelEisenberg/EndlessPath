class_name SimpleEnemyAI
extends Node

## SimpleEnemyAI
## Casts the longest-cooldown ability that is ready and affordable, once the
## fight's opening is over: the enemy's first cast waits out the player's opening
## cooldown (CombatAbilityInstance.INITIAL_COOLDOWN), so both sides start together.
## Here are a list of additional rules for the enemy AI to pick an ability:

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var combatant: CombatantNode
var target: CombatantNode
var active: bool = false

## Seconds of the fight's opening still to run. The AI casts nothing until it ends.
var _opening_left: float = 0.0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Initializes the AI with a combatant and a target, and starts the fight's
## opening. AdventureCombat sets it up in the frame the player's techniques start
## their opening cooldown and holds both fighters until the fight begins, so both
## openings count from the same frame and end in the same frame.
func setup(p_combatant: CombatantNode, p_target: CombatantNode) -> void:
	combatant = p_combatant
	target = p_target
	active = true
	_opening_left = CombatAbilityInstance.INITIAL_COOLDOWN
	
	Log.info("SimpleEnemyAI: Initialized for %s targeting %s" % [combatant.name, target.name])

## Whether the fight's opening is still running, so the enemy casts nothing yet.
func is_in_opening() -> bool:
	return _opening_left > 0.0

#-----------------------------------------------------------------------------
# PROCESS
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active or not combatant or not target:
		return

	if is_in_opening():
		_opening_left -= delta
		if is_in_opening():
			return

	if combatant.ability_manager.is_casting():
		return
		
	_try_cast_abilities()

func _try_cast_abilities() -> void:
	var ability = _get_next_ability()
	
	if ability:
		combatant.ability_manager.use_ability_instance(ability, target)
	

func _get_next_ability() -> CombatAbilityInstance:
	for ability in _abilities_sorted_by_cooldown_desc():
		if not combatant.ability_manager.can_cast_ability_instance(ability, target):
			continue
		
		if not _should_cast_ability(ability):
			continue
		
		return ability
	return null

## Decides whether the AI should fire an ability whose cooldown + costs are
## already satisfied. Heal-self abilities are gated on having enough missing
## HP to absorb the full heal; everything else fires immediately.
func _should_cast_ability(ability: CombatAbilityInstance) -> bool:
	if ability.ability_data.heals_self():
		return _has_enough_deficit_for_heal(ability)
	return true

## True if the combatant is missing at least as much HP as the heal would
## restore — i.e., casting the heal now wouldn't overheal.
func _has_enough_deficit_for_heal(ability: CombatAbilityInstance) -> bool:
	var caster_attrs: CharacterAttributesData = combatant.combatant_data.attributes
	var heal_amount: float = ability.ability_data.get_total_self_heal(caster_attrs)
	var deficit: float = combatant.vitals_manager.max_health - combatant.vitals_manager.current_health
	return deficit >= heal_amount

## Returns the combatant's abilities sorted by base_cooldown descending.
## Ties keep the original array order (GDScript's sort is stable).
## Duplicates the manager's array so the sort doesn't mutate live state.
func _abilities_sorted_by_cooldown_desc() -> Array[CombatAbilityInstance]:
	var result: Array[CombatAbilityInstance] = combatant.ability_manager.abilities.duplicate()
	result.sort_custom(func(a: CombatAbilityInstance, b: CombatAbilityInstance) -> bool:
		return a.ability_data.base_cooldown > b.ability_data.base_cooldown
	)
	return result
