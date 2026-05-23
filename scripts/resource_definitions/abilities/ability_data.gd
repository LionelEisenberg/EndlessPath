class_name AbilityData
extends Resource

## AbilityData
## Base class for all player and enemy abilities in combat.
## Defines costs, cooldowns, targeting, effects, and attribute scaling.
##
## An ability's "kind" (damage / heal / buff / utility / etc.) is *not* a
## top-level tag — it's derived from the effects on the ability. Use the
## predicate methods below (deals_damage, heals_self, etc.) when you need
## to ask "what does this ability do?". This way composite abilities
## (damage + debuff, damage + interrupt, etc.) are handled naturally.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum MadraType {
	NONE, ## No Madra affinity (physical abilities)
	PURE, ## Pure Madra
}

enum AbilitySource {
	INNATE, ## Always available, persists across path changes
	PATH, ## Unlocked via path tree, resets with path
}

#-----------------------------------------------------------------------------
# BASIC ABILITY INFO
#-----------------------------------------------------------------------------

@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Classification")
@export var madra_type: MadraType = MadraType.NONE
@export var ability_source: AbilitySource = AbilitySource.INNATE

#-----------------------------------------------------------------------------
# COSTS & COOLDOWN
#-----------------------------------------------------------------------------

@export_group("Costs & Cooldown")
@export var health_cost: float = 0.0
@export var madra_cost: float = 0.0
@export var stamina_cost: float = 0.0
@export var base_cooldown: float = 0.0
@export var cast_time: float = 0.0 ## Time in seconds to cast (0 = instant)

#-----------------------------------------------------------------------------
# EFFECTS
#-----------------------------------------------------------------------------

@export_group("Effects")
## Effects that apply to the ability's enemy target (damage, debuffs, etc.).
## An ability requires an enemy target iff this array is non-empty.
@export var effects_on_target: Array[CombatEffectData] = []
## Effects that apply to the caster (self-buffs, self-heals, etc.).
@export var effects_on_self: Array[CombatEffectData] = []

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

	if effects_on_target.is_empty() and effects_on_self.is_empty():
		Log.warn("AbilityData[%s]: No effects defined" % ability_id)

	return true

#-----------------------------------------------------------------------------
# EFFECT PREDICATES
#-----------------------------------------------------------------------------
# Each predicate inspects the ability's effect lists. A single ability can
# satisfy multiple predicates (e.g., a damage attack that also applies a
# debuff returns true from deals_damage() AND debuffs_target()).

## True if this ability deals damage to its target.
func deals_damage() -> bool:
	return _has_target_effect(CombatEffectData.EffectType.DAMAGE)

## True if this ability heals the caster.
func heals_self() -> bool:
	return _has_self_effect(CombatEffectData.EffectType.HEAL)

## True if this ability applies a buff to the caster.
func buffs_self() -> bool:
	return _has_self_effect(CombatEffectData.EffectType.BUFF)

## True if this ability applies a debuff (BUFF effect) to its target.
func debuffs_target() -> bool:
	return _has_target_effect(CombatEffectData.EffectType.BUFF)

## True if this ability interrupts the target's current cast.
func interrupts_target() -> bool:
	return _has_target_effect(CombatEffectData.EffectType.CANCEL_CAST)

## True if this ability strips buffs from the target.
func strips_target_buffs() -> bool:
	return _has_target_effect(CombatEffectData.EffectType.STRIP_BUFFS)

## Sum of all self-heal amounts on this ability, including attribute scaling.
## Returns 0.0 for abilities that don't heal the caster.
func get_total_self_heal(caster_attrs: CharacterAttributesData) -> float:
	var total: float = 0.0
	for effect in effects_on_self:
		if effect.effect_type == CombatEffectData.EffectType.HEAL:
			total += effect.calculate_value(caster_attrs)
	return total

func _has_target_effect(t: CombatEffectData.EffectType) -> bool:
	for effect in effects_on_target:
		if effect.effect_type == t:
			return true
	return false

func _has_self_effect(t: CombatEffectData.EffectType) -> bool:
	for effect in effects_on_self:
		if effect.effect_type == t:
			return true
	return false

#-----------------------------------------------------------------------------
# COST CHECKING
#-----------------------------------------------------------------------------

## Check if a character can afford this ability's costs
func can_afford(vitals_manager: VitalsManager) -> bool:
	if vitals_manager == null:
		return false

	if health_cost > 0 and vitals_manager.current_health < health_cost:
		return false

	if madra_cost > 0 and vitals_manager.current_madra < madra_cost:
		return false

	if stamina_cost > 0 and vitals_manager.current_stamina < stamina_cost:
		return false

	return true

## Consume the resources required for this ability
func consume_costs(vitals_manager: VitalsManager) -> bool:
	if not can_afford(vitals_manager):
		return false

	if not is_equal_approx(health_cost, 0.0):
		vitals_manager.apply_vitals_change(-health_cost, 0, 0)
	if not is_equal_approx(stamina_cost, 0.0):
		vitals_manager.apply_vitals_change(0, -stamina_cost, 0)
	if not is_equal_approx(madra_cost, 0.0):
		vitals_manager.apply_vitals_change(0, 0, -madra_cost)

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
	return "AbilityData[%s] '%s' (OnTarget: %d, OnSelf: %d, Madra: %s, Source: %s, Cost: %s, CD: %.1fs)" % [
		ability_id,
		ability_name,
		effects_on_target.size(),
		effects_on_self.size(),
		MadraType.keys()[madra_type],
		AbilitySource.keys()[ability_source],
		get_total_cost_display(),
		base_cooldown,
	]
