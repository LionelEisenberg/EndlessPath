class_name AbilityData
extends Resource

## AbilityData
## Base class for all player and enemy abilities in combat
## Defines costs, cooldowns, targeting, effects, and attribute scaling

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum AbilityType {
	OFFENSIVE,      ## Damage-dealing abilities
}

enum TargetType {
	SELF,                ## Only targets the caster
	SINGLE_ENEMY,        ## One enemy
	ALL_ALLIES,          ## All allies
}

enum CostType {
	NONE,
	HEALTH,
	MADRA,
	STAMINA,
	MIXED    ## Multiple resource costs
}

#-----------------------------------------------------------------------------
# BASIC ABILITY INFO
#-----------------------------------------------------------------------------

@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var ability_type: AbilityType = AbilityType.OFFENSIVE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

#-----------------------------------------------------------------------------
# COSTS & COOLDOWN
#-----------------------------------------------------------------------------

@export_group("Costs & Cooldown")
@export var health_cost: float = 0.0
@export var madra_cost: float = 0.0
@export var stamina_cost: float = 0.0
@export var base_cooldown : float = 0.0
@export var cast_time: float = 0.0       ## Time in seconds to cast (0 = instant)

#-----------------------------------------------------------------------------
# EFFECTS
#-----------------------------------------------------------------------------

@export_group("Effects")
## Array of combat effects this ability applies
@export var effects: Array[CombatEffectData] = []

#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

func validate() -> bool:
	if ability_id.is_empty():
		Log.error("AbilityData: ability_id is empty")
		return false
	
	if ability_name.is_empty():
		Log.error("AbilityData[%s]: ability_name is empty" % ability_id)
		return false
	
	if effects.is_empty():
		Log.warn("AbilityData[%s]: No effects defined" % ability_id)
	
	return true

#-----------------------------------------------------------------------------
# COST CHECKING
#-----------------------------------------------------------------------------

## Check if a character can afford this ability's costs
func can_afford(resource_manager: CombatResourceManager) -> bool:
	if resource_manager == null:
		return false
	
	if health_cost > 0 and resource_manager.current_health < health_cost:
		return false
	
	if madra_cost > 0 and resource_manager.current_madra < madra_cost:
		return false
	
	if stamina_cost > 0 and resource_manager.current_stamina < stamina_cost:
		return false
	
	return true

## Consume the resources required for this ability
func consume_costs(resource_manager: CombatResourceManager) -> bool:
	if not can_afford(resource_manager):
		return false
	
	if not is_equal_approx(health_cost, 0.0):
		resource_manager.apply_damage(health_cost)
	if not is_equal_approx(madra_cost, 0.0):
		resource_manager.current_madra -= madra_cost
	if not is_equal_approx(stamina_cost, 0.0):
		resource_manager.current_stamina -= stamina_cost
	
	return true

#-----------------------------------------------------------------------------
# GETTERS
#-----------------------------------------------------------------------------

func get_total_cost_display() -> String:
	var costs = []
	if health_cost > 0:
		costs.append("Health: %.0f" % health_cost)
	if madra_cost > 0:
		costs.append("Madra: %.0f" % madra_cost)
	if stamina_cost > 0:
		costs.append("Stamina: %.0f" % stamina_cost)
	
	if costs.is_empty():
		return "Free"
	return ", ".join(costs)

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "AbilityData[%s] '%s' (Type: %s, Target: %s, Cost: %s, Cooldown: %d turns)" % [
		ability_id,
		ability_name,
		AbilityType.keys()[ability_type],
		TargetType.keys()[target_type],
		get_total_cost_display(),
	]
