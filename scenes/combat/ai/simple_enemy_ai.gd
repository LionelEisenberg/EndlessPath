class_name SimpleEnemyAI
extends Node

## SimpleEnemyAI
## A basic AI controller that casts abilities whenever they are ready.

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var combatant: CombatantNode
var target: CombatantNode
var active: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func setup(p_combatant: CombatantNode, p_target: CombatantNode) -> void:
	combatant = p_combatant
	target = p_target
	active = true
	Log.info("SimpleEnemyAI: Initialized for %s targeting %s" % [combatant.name, target.name])

#-----------------------------------------------------------------------------
# PROCESS
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not active or not combatant or not target:
		return
		
	_try_cast_abilities()

func _try_cast_abilities() -> void:
	# Iterate through all abilities and try to use them
	# In a real AI, we would have priorities, logic, etc.
	# Here we just cast the first available ability we find (or all of them if possible)
	
	var ability_count = combatant.ability_manager.get_ability_count()
	
	for i in range(ability_count):
		var ability = combatant.ability_manager.get_ability(i)
		
		# Skip if not ready or can't afford
		if not ability.is_ready():
			continue
			
		if not ability.ability_data.can_afford(combatant.resource_manager):
			continue
			
		# Try to use it
		# Note: use_ability_instance handles the actual resource consumption and cooldown start
		# We just need to trigger it.
		combatant.ability_manager.use_ability_instance(ability, target)
