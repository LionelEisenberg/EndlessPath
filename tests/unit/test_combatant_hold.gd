extends GutTest

## CombatantNode.set_held(): a held fighter does nothing of its fight (its
## techniques' casts and cooldowns, its buffs and their ticks, its own vitals, an
## AI driving it) while its visual plays on. AdventureCombat holds both fighters
## on a fight's way in and from the hit that decides it (#138).

const COMBATANT_SCENE: PackedScene = preload("res://scenes/combat/combatant/combatant_node.tscn")
const AMORPHOUS_SPIRIT: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")

var _striker: CombatantNode
var _spirit: CombatantNode
var _ai: SimpleEnemyAI

func before_each() -> void:
	# A fighter with Basic Strike, whose opening cooldown runs from its first frame.
	_striker = COMBATANT_SCENE.instantiate()
	add_child_autofree(_striker)
	var data: CombatantData = AMORPHOUS_SPIRIT.duplicate()
	var abilities: Array[AbilityData] = [BASIC_STRIKE]
	data.abilities = abilities
	_striker.setup(data, null, false)
	# An Amorphous Spirit driven by its AI, as AdventureCombat sets one up.
	_spirit = COMBATANT_SCENE.instantiate()
	add_child_autofree(_spirit)
	_spirit.setup(AMORPHOUS_SPIRIT, null, false)
	_ai = SimpleEnemyAI.new()
	_ai.name = "EnemyAI"
	_spirit.add_child(_ai)
	_ai.setup(_spirit, _striker)

func _opening_left() -> float:
	var strike: CombatAbilityInstance = _striker.ability_manager.abilities[0]
	return strike.cooldown_timer.time_left

func _dot() -> BuffEffectData:
	var dot := BuffEffectData.new()
	dot.buff_id = "test_dot"
	dot.duration = 10.0
	dot.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	dot.dot_damage_per_tick = 2.0
	return dot

func test_a_held_fighters_clocks_stand_still() -> void:
	_striker.set_held(true)
	_spirit.set_held(true)

	await wait_seconds(0.3)

	assert_almost_eq(_opening_left(), CombatAbilityInstance.INITIAL_COOLDOWN, 0.001, "the technique's opening stands still")
	assert_almost_eq(_ai._opening_left, CombatAbilityInstance.INITIAL_COOLDOWN, 0.001, "and so does the AI's")

func test_a_held_fighter_takes_no_tick() -> void:
	_spirit.buff_manager.apply_buff(_dot())
	var health: float = _spirit.vitals_manager.current_health
	_spirit.set_held(true)

	await wait_seconds(CombatBuffManager.DOT_TICK_INTERVAL + 0.2)

	assert_eq(_spirit.vitals_manager.current_health, health, "its damage over time ticks nothing")
	assert_true(_spirit.buff_manager.get_active_buff("test_dot") != null, "and the buff waits, unspent")

func test_a_released_fighter_runs_again() -> void:
	_striker.set_held(true)
	_striker.set_held(false)

	await wait_seconds(0.3)

	assert_lt(_opening_left(), CombatAbilityInstance.INITIAL_COOLDOWN - 0.2, "its opening counts down again")

func test_only_the_visual_plays_on_while_held() -> void:
	_spirit.set_held(true)

	assert_true(_spirit.is_held(), "the fighter says it is held")
	assert_true(_spirit.visual.can_process(), "its visual plays on")
	for part: Node in [_spirit.ability_manager, _spirit.buff_manager, _spirit.consumable_manager, _spirit.effect_manager, _spirit.vitals_manager, _ai]:
		assert_false(part.can_process(), "%s stands still" % part.name)
	_spirit.set_held(false)
	assert_false(_spirit.is_held(), "and lets go")
	assert_true(_ai.can_process(), "its AI runs again")
