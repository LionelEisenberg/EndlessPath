extends GutTest

## Content lock: a Lv 1 fight (every stat 10, no gear) keeps its numbers. The
## techniques, the enemy blocks with armor and Ward, and the hits after defence.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")
const EMPTY_PALM: AbilityData = preload("res://resources/abilities/empty_palm.tres")
const POWER_FONT: AbilityData = preload("res://resources/abilities/power_font.tres")
const FAMISHING_BITE: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/famishing_bite.tres")
const MADRA_LASH: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/madra_lash.tres")
const COALESCE: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/coalesce.tres")
const AMORPHOUS_SPIRIT: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const COALESCING_SPIRIT: CombatantData = preload("res://resources/combat/combatant_data/coalescing_spirit.tres")
const STARVING_DREADBEAST: CombatantData = preload("res://resources/combat/combatant_data/starving_dreadbeast.tres")
const RAVENOUS_DREADBEAST: CombatantData = preload("res://resources/combat/combatant_data/ravenous_dreadbeast.tres")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The damage effect of an ability: its first effect on the target.
func _damage_of(ability: AbilityData) -> CombatEffectData:
	return ability.effects_on_target[0]

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## Armor 10 and Ward 10 cut the player's hits as Resilience 10 and Spirit 10
## did; Ward 25 as the Coalescing Spirit's Spirit 25 did.
func test_enemy_stat_blocks() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Amorphous Spirit", "enemy": AMORPHOUS_SPIRIT, "block": {&"strength": 10.0, &"body": 10.0, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 10.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
		{"name": "Coalescing Spirit", "enemy": COALESCING_SPIRIT, "block": {&"strength": 10.0, &"body": 20.0, &"agility": 10.0,
			&"spirit": 25.0, &"mind": 10.0, &"control": 10.0, &"armor": 10.0, &"ward": 25.0}},
		{"name": "Starving Dreadbeast", "enemy": STARVING_DREADBEAST, "block": {&"strength": 10.0, &"body": 8.5, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 12.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
		{"name": "Ravenous Dreadbeast", "enemy": RAVENOUS_DREADBEAST, "block": {&"strength": 15.0, &"body": 8.5, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 12.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
	]
	for case: Dictionary in cases:
		var attributes: CharacterAttributesData = (case["enemy"] as CombatantData).attributes
		for key: StringName in case["block"]:
			assert_eq(attributes.get(key), case["block"][key], "%s: %s" % [case["name"], key])

## Each technique scales from its side's main stat only and keeps its Lv 1 hit.
func test_player_techniques_at_lv_1() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Basic Strike", "ability": BASIC_STRIKE, "type": CombatEffectData.DamageType.PHYSICAL, "strength": 1.5, "spirit": 0.0, "value": 25.0},
		{"name": "Empty Palm", "ability": EMPTY_PALM, "type": CombatEffectData.DamageType.SPIRIT, "strength": 0.0, "spirit": 1.3, "value": 28.0},
		{"name": "Power Font", "ability": POWER_FONT, "type": CombatEffectData.DamageType.SPIRIT, "strength": 0.0, "spirit": 2.0, "value": 50.0},
	]
	for case: Dictionary in cases:
		var effect: CombatEffectData = _damage_of(case["ability"])
		assert_eq(effect.damage_type, case["type"], "%s: damage type" % case["name"])
		assert_almost_eq(effect.strength_scaling, case["strength"], 0.0001, "%s: per Strength" % case["name"])
		assert_almost_eq(effect.spirit_scaling, case["spirit"], 0.0001, "%s: per Spirit" % case["name"])
		assert_almost_eq(effect.calculate_value(CharacterAttributesData.make()), case["value"], 0.001, "%s: at Lv 1" % case["name"])

## Lv 1 hits after defence: x 100 / (100 + armor), with Ward for Spirit damage.
func test_player_hits_after_enemy_defence() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Basic Strike on the Amorphous Spirit", "ability": BASIC_STRIKE, "enemy": AMORPHOUS_SPIRIT, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Basic Strike on the Coalescing Spirit", "ability": BASIC_STRIKE, "enemy": COALESCING_SPIRIT, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Basic Strike on a Ravenous Dreadbeast", "ability": BASIC_STRIKE, "enemy": RAVENOUS_DREADBEAST, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Empty Palm on a Starving Dreadbeast", "ability": EMPTY_PALM, "enemy": STARVING_DREADBEAST, "damage": 28.0 * 100.0 / 110.0},
		{"name": "Empty Palm on the Coalescing Spirit", "ability": EMPTY_PALM, "enemy": COALESCING_SPIRIT, "damage": 22.4},
		{"name": "Power Font on the Amorphous Spirit", "ability": POWER_FONT, "enemy": AMORPHOUS_SPIRIT, "damage": 50.0 * 100.0 / 110.0},
		{"name": "Power Font on the Coalescing Spirit", "ability": POWER_FONT, "enemy": COALESCING_SPIRIT, "damage": 40.0},
	]
	for case: Dictionary in cases:
		var enemy: CombatantData = case["enemy"]
		assert_almost_eq(_damage_of(case["ability"]).calculate_damage(CharacterAttributesData.make(), enemy.attributes),
			case["damage"], 0.001, case["name"])

## At 0.91 per point, enemy hits on a Lv 1 player (no armor or Ward) land what
## Resilience 10 and Spirit 10 let through before.
func test_enemy_techniques_on_a_lv_1_player() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Famishing Bite from a Starving Dreadbeast", "ability": FAMISHING_BITE, "enemy": STARVING_DREADBEAST, "damage": 9.1},
		{"name": "Famishing Bite from a Ravenous Dreadbeast", "ability": FAMISHING_BITE, "enemy": RAVENOUS_DREADBEAST, "damage": 13.65},
		{"name": "Madra Lash from the Amorphous Spirit", "ability": MADRA_LASH, "enemy": AMORPHOUS_SPIRIT, "damage": 9.1},
		{"name": "Madra Lash from the Coalescing Spirit", "ability": MADRA_LASH, "enemy": COALESCING_SPIRIT, "damage": 22.75},
	]
	for case: Dictionary in cases:
		var enemy: CombatantData = case["enemy"]
		assert_almost_eq(_damage_of(case["ability"]).calculate_damage(enemy.attributes, CharacterAttributesData.make()),
			case["damage"], 0.001, case["name"])

## Coalesce heals 3 per Spirit: 75 for the Coalescing Spirit, with no defence.
func test_coalesce_heals_from_spirit() -> void:
	assert_almost_eq(COALESCE.get_total_self_heal(COALESCING_SPIRIT.attributes), 75.0, 0.001)
