extends GutTest

## Control's cuts in a fight, the player's only. A cast, a cancelled cast and the
## cast gate use them; the opening cooldown does not.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Control 30: 20 points above Lv 1, so both cuts are well above 0.
const CONTROL: float = 30.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Test Technique: the Madra cost, cooldown and cast time given, and no effects.
func _technique(madra_cost: float, base_cooldown: float, cast_time: float = 0.0) -> AbilityData:
	var technique := AbilityData.new()
	technique.ability_id = "test_technique"
	technique.ability_name = "Test Technique"
	technique.madra_cost = madra_cost
	technique.base_cooldown = base_cooldown
	technique.cast_time = cast_time
	return technique

## A fighter, never in the tree: the player or an enemy, its data named after
## which, holding the Control given.
func _fighter(is_player: bool, control: float) -> CombatantNode:
	var fighter := CombatantNode.new()
	autofree(fighter)
	fighter.is_player = is_player
	var data := CombatantData.new()
	data.character_name = "Player" if is_player else "Enemy"
	data.attributes = CharacterAttributesData.make({&"control": control})
	fighter.combatant_data = data
	return fighter

## An instance of the ability for the fighter (or for no one), in the tree so
## its timers are ready: its opening cooldown runs.
func _instance(ability: AbilityData, fighter: CombatantNode) -> CombatAbilityInstance:
	var instance := CombatAbilityInstance.new(ability, fighter)
	add_child_autofree(instance)
	return instance

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## The cuts come from the player's snapshot; an enemy or an unowned instance has none.
func test_only_the_player_has_cuts() -> void:
	var snapshot := CharacterAttributesData.make({&"control": CONTROL})
	assert_gt(snapshot.get_cooldown_cut(), 0.0, "precondition: Control 30 cuts")
	var player: CombatAbilityInstance = _instance(_technique(8.0, 3.0), _fighter(true, CONTROL))
	assert_eq(player.get_cost_cut(), snapshot.get_madra_cost_cut(), "the player's Madra cost cut")
	assert_eq(player.get_cooldown_cut(), snapshot.get_cooldown_cut(), "the player's cooldown cut")
	var enemy: CombatAbilityInstance = _instance(_technique(8.0, 3.0), _fighter(false, CONTROL))
	assert_eq(enemy.get_cost_cut(), 0.0, "an enemy's Madra costs are never cut")
	assert_eq(enemy.get_cooldown_cut(), 0.0, "nor are its cooldowns")
	var unowned: CombatAbilityInstance = _instance(_technique(8.0, 3.0), null)
	assert_eq(unowned.get_cost_cut(), 0.0, "no owner: no Madra cost cut")
	assert_eq(unowned.get_cooldown_cut(), 0.0, "no owner: no cooldown cut")

## A cast starts the cut cooldown and reports it on cooldown_started.
func test_a_cast_starts_the_cut_cooldown() -> void:
	var technique: AbilityData = _technique(0.0, 2.0)
	var instance: CombatAbilityInstance = _instance(technique, _fighter(true, CONTROL))
	var cooldown: float = technique.get_cooldown(instance.get_cooldown_cut())
	assert_lt(cooldown, 2.0, "precondition: Control 30 shortens a 2 s cooldown")
	watch_signals(instance)
	instance.execute_ability(null)
	assert_almost_eq(instance.cooldown_timer.wait_time, cooldown, 0.0001, "the timer runs the cut cooldown")
	assert_signal_emitted_with_parameters(instance, "cooldown_started", [cooldown])

## A cancelled cast starts the cut cooldown too.
func test_a_cancelled_cast_starts_the_cut_cooldown() -> void:
	var technique: AbilityData = _technique(0.0, 5.0, 2.0)
	var instance: CombatAbilityInstance = _instance(technique, _fighter(true, CONTROL))
	instance.is_casting = true
	instance.cast_timer.start(2.0)
	instance.cancel_cast()
	assert_almost_eq(instance.cooldown_timer.wait_time, technique.get_cooldown(instance.get_cooldown_cut()), 0.0001)
	assert_lt(instance.cooldown_timer.wait_time, 5.0, "shorter than the full 5 s")

## Every fight still opens on the full 1.5 s, whatever the player's Control.
func test_the_opening_cooldown_is_never_cut() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 3.0), _fighter(true, CONTROL))
	assert_eq(instance.cooldown_timer.wait_time, CombatAbilityInstance.INITIAL_COOLDOWN)

## A technique with no cooldown stays ready after a cast, cut or not.
func test_a_technique_with_no_cooldown_stays_ready() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 0.0), _fighter(true, CONTROL))
	watch_signals(instance)
	instance.execute_ability(null)
	assert_true(instance.is_ready(), "no cooldown runs")
	assert_signal_not_emitted(instance, "cooldown_started")

## An enemy's cast starts its full cooldown, however much Control it has.
func test_an_enemys_cooldown_is_never_cut() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 30.0), _fighter(false, CONTROL))
	instance.execute_ability(null)
	assert_eq(instance.cooldown_timer.wait_time, 30.0)

## The cast gate and the payment use the cut Madra cost.
func test_the_gate_and_the_payment_use_the_cut_cost() -> void:
	var technique: AbilityData = _technique(8.0, 3.0)
	var player: CombatantNode = _fighter(true, CONTROL)
	var abilities: Array[AbilityData] = [technique]
	player.combatant_data.abilities = abilities
	var vitals := VitalsManager.new()
	add_child_autofree(vitals)
	player.vitals_manager = vitals
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	manager.setup(player)
	var instance: CombatAbilityInstance = manager.abilities[0]
	instance.cooldown_timer.stop()
	var cost: float = technique.get_madra_cost(instance.get_cost_cut())
	assert_lt(cost, 8.0, "precondition: Control 30 cuts the 8 Madra cost")
	vitals.current_madra = cost - 1.0
	assert_false(manager.can_cast_ability_instance(instance, null), "one Madra short of the cut cost")
	vitals.current_madra = cost
	assert_true(manager.can_cast_ability_instance(instance, null), "the cut cost is enough")
	assert_true(manager.use_ability_instance(instance, null), "the cast starts")
	assert_eq(vitals.current_madra, 0.0, "it paid the cut cost, not the full 8")
