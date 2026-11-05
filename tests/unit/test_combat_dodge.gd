extends GutTest

## Dodge: only the player dodges, at its Agility's chance. A dodge skips every
## effect on the target, riders too; the caster's self effects still apply.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Agility 25: 15 points above Lv 1, so the player can dodge.
const NIMBLE: float = 25.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A fighter of the given name and attributes, never in the tree: full vitals
## from those attributes and fresh managers, each set up for it.
func _combatant(character_name: String, is_player: bool, attributes: CharacterAttributesData) -> CombatantNode:
	var fighter := CombatantNode.new()
	autofree(fighter)
	fighter.is_player = is_player
	var data := CombatantData.new()
	data.character_name = character_name
	data.attributes = attributes
	fighter.combatant_data = data
	fighter.vitals_manager = VitalsManager.new()
	fighter.vitals_manager.character_attributes_data = attributes
	fighter.vitals_manager.initialize_current_values()
	fighter.ability_manager = CombatAbilityManager.new()
	fighter.buff_manager = CombatBuffManager.new()
	fighter.effect_manager = CombatEffectManager.new()
	add_child_autofree(fighter.vitals_manager)
	add_child_autofree(fighter.ability_manager)
	add_child_autofree(fighter.buff_manager)
	add_child_autofree(fighter.effect_manager)
	fighter.ability_manager.setup(fighter)
	fighter.buff_manager.setup(fighter)
	fighter.effect_manager.setup(fighter)
	return fighter

## Fixes the roll the fighter's dodges are checked against.
func _fix_roll(fighter: CombatantNode, roll: float) -> void:
	fighter.effect_manager.dodge_roll = func() -> float: return roll

## An instance of the ability for the caster, under its ability manager so its
## timers are ready.
func _instance(ability: AbilityData, caster: CombatantNode) -> CombatAbilityInstance:
	var instance := CombatAbilityInstance.new(ability, caster)
	caster.ability_manager.add_child(instance)
	return instance

## Puts the fighter mid-cast of Test Long Cast (3 s), as
## test_empty_palm_interrupt.gd does, and returns the cast.
func _start_casting(fighter: CombatantNode) -> CombatAbilityInstance:
	var long_cast := AbilityData.new()
	long_cast.ability_id = "test_long_cast"
	long_cast.ability_name = "Test Long Cast"
	long_cast.cast_time = 3.0
	long_cast.base_cooldown = 5.0
	var cast: CombatAbilityInstance = _instance(long_cast, fighter)
	fighter.ability_manager.abilities.append(cast)
	cast.is_casting = true
	cast.cast_timer.start(3.0)
	return cast

## Test Bite: 10 Physical damage and then an interrupt on its target, and Test
## Hunger (outgoing damage x1.5) on its caster.
func _bite() -> AbilityData:
	var damage := CombatEffectData.new()
	damage.effect_type = CombatEffectData.EffectType.DAMAGE
	damage.base_value = 10.0
	damage.damage_type = CombatEffectData.DamageType.PHYSICAL
	var interrupt := CombatEffectData.new()
	interrupt.effect_type = CombatEffectData.EffectType.CANCEL_CAST
	var hunger := BuffEffectData.new()
	hunger.buff_id = "test_hunger"
	hunger.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	hunger.damage_multiplier = 1.5
	var bite := AbilityData.new()
	bite.ability_id = "test_bite"
	bite.ability_name = "Test Bite"
	var on_target: Array[CombatEffectData] = [damage, interrupt]
	bite.effects_on_target = on_target
	var on_self: Array[CombatEffectData] = [hunger]
	bite.effects_on_self = on_self
	return bite

## Test Coalesce: a heal of 5 on its caster, and nothing on its target.
func _self_heal() -> AbilityData:
	var heal := CombatEffectData.new()
	heal.effect_type = CombatEffectData.EffectType.HEAL
	heal.base_value = 5.0
	var coalesce := AbilityData.new()
	coalesce.ability_id = "test_coalesce"
	coalesce.ability_name = "Test Coalesce"
	var on_self: Array[CombatEffectData] = [heal]
	coalesce.effects_on_self = on_self
	return coalesce

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## Only the player dodges, on a roll under its chance. Lv 1 Agility has none.
func test_only_the_player_dodges_under_its_chance() -> void:
	var chance: float = CharacterAttributesData.make({&"agility": NIMBLE}).get_dodge_chance()
	assert_gt(chance, 0.0, "precondition: Agility 25 can dodge")
	var cases: Array[Dictionary] = [
		{"name": "the player, a roll just under its chance", "is_player": true, "agility": NIMBLE, "roll": chance - 0.001, "dodges": true},
		{"name": "the player, a roll at its chance", "is_player": true, "agility": NIMBLE, "roll": chance, "dodges": false},
		{"name": "the player at Lv 1 Agility, the lowest roll", "is_player": true, "agility": 10.0, "roll": 0.0, "dodges": false},
		{"name": "an enemy, however nimble", "is_player": false, "agility": 100.0, "roll": 0.0, "dodges": false},
	]
	for case: Dictionary in cases:
		var fighter: CombatantNode = _combatant("Fighter", case["is_player"], CharacterAttributesData.make({&"agility": case["agility"]}))
		_fix_roll(fighter, case["roll"])
		assert_eq(fighter.effect_manager.try_dodge(), case["dodges"], case["name"])

## A manager with no owner, or with an owner that has no data, never dodges.
func test_a_bare_node_never_dodges() -> void:
	var manager := CombatEffectManager.new()
	add_child_autofree(manager)
	manager.dodge_roll = func() -> float: return 0.0
	assert_false(manager.try_dodge(), "no owner")
	var fighter := CombatantNode.new()
	autofree(fighter)
	fighter.is_player = true
	manager.setup(fighter)
	assert_false(manager.try_dodge(), "an owner with no data")

## A dodge stops the damage and the interrupt riding on it, and is logged. The
## biter's Hunger still applies.
func test_a_dodge_skips_every_target_effect_but_not_the_casters_own() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	_fix_roll(player, 0.0)
	var cast: CombatAbilityInstance = _start_casting(player)
	var beast: CombatantNode = _combatant("Dreadbeast", false, CharacterAttributesData.make())
	watch_signals(LogManager)
	_instance(_bite(), beast).execute_ability(player)
	assert_eq(player.vitals_manager.current_health, player.vitals_manager.max_health, "the damage never lands")
	assert_true(cast.is_casting, "nor does the interrupt")
	assert_eq(beast.buff_manager.active_buffs.size(), 1, "the biter's Hunger still applies")
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["[b]Player[/b] dodged Test Bite"])

## A roll over the chance lands the whole hit: the damage and the interrupt.
func test_a_missed_dodge_lands_the_hit() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	_fix_roll(player, 0.99)
	var cast: CombatAbilityInstance = _start_casting(player)
	_instance(_bite(), _combatant("Dreadbeast", false, CharacterAttributesData.make())).execute_ability(player)
	assert_eq(player.vitals_manager.current_health, 90.0, "the bite's 10 damage lands (no armor)")
	assert_false(cast.is_casting, "and so does its interrupt")

## A cast with no effect on its target never rolls a dodge, though SimpleEnemyAI
## aims every cast at the player (Coalesce heals only its caster).
func test_a_cast_without_target_effects_never_rolls() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	var rolls: Array[int] = [0]
	player.effect_manager.dodge_roll = func() -> float:
		rolls[0] += 1
		return 0.0
	_instance(_self_heal(), _combatant("Spirit", false, CharacterAttributesData.make())).execute_ability(player)
	assert_eq(rolls[0], 0, "no dodge is rolled for a self-heal aimed at the player")
