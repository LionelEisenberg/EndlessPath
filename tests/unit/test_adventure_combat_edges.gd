extends GutTest

## AdventureCombat's own edges (#138): a fight starts held, both fighters waiting
## off their spots and the enemy's name hidden; begin() starts it for both sides
## in one frame; the hit that takes a side to 0 Health decides it once, and from
## that hit nothing in the fight acts. Drives real fights, started the way
## AdventureView starts one.

const AdventureCombatScene := preload("res://scenes/combat/adventure_combat/adventure_combat.tscn")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const CRUDE_SCALE: ItemDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
## More damage than any health pool, so one hit always leaves 0 HP.
const LETHAL_DAMAGE := -1000000.0

var _combat: AdventureCombat
var _choice: CombatChoice
var _original_save: SaveGameData
var _original_player_health: float
## One entry per trigger_combat_end emission: [is_successful, gold_earned].
var _ends: Array[Array] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_player_health = PlayerManager.vitals_manager.current_health
	PlayerManager.vitals_manager.current_health = PlayerManager.vitals_manager.max_health
	_ends.clear()
	_new_combat()

func after_each() -> void:
	# Free the fight first so restoring the player's health below does not
	# reach its PlayerManager.vitals_manager connections.
	if is_instance_valid(_combat):
		_combat.free()
	PlayerManager.vitals_manager.current_health = _original_player_health
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _new_combat() -> void:
	if is_instance_valid(_combat):
		_combat.free()
	_combat = AdventureCombatScene.instantiate()
	add_child_autofree(_combat)
	_combat.trigger_combat_end.connect(func(won: bool, gold: int) -> void: _ends.append([won, gold]))

## Starts a fight against one Amorphous Spirit, as AdventureView does on a pick.
func _start_fight() -> void:
	_choice = CombatChoice.new()
	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	_choice.enemy_pool = pool
	_combat.initialize_combat(_choice, null)
	_combat.start()

func _ai() -> SimpleEnemyAI:
	return _combat.enemy_combatant.get_node("EnemyAI") as SimpleEnemyAI

func _technique() -> CombatAbilityInstance:
	return _combat.player_combatant.ability_manager.abilities[0]

func _dot() -> BuffEffectData:
	var dot := BuffEffectData.new()
	dot.buff_id = "test_dot"
	dot.duration = 10.0
	dot.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	dot.dot_damage_per_tick = 2.0
	return dot

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_a_fight_starts_held_with_its_name_hidden() -> void:
	_start_fight()

	assert_true(_combat.player_combatant.is_held(), "the player waits")
	assert_true(_combat.enemy_combatant.is_held(), "and so does the enemy")
	assert_false(_combat.is_live(), "the fight has not begun")
	assert_false(_combat.enemy_nameplate.visible, "the enemy's name waits for it to land")

func test_begin_starts_both_openings_in_one_frame() -> void:
	_start_fight()

	_combat.begin()

	assert_true(_combat.is_live(), "the fight is live")
	assert_false(_combat.player_combatant.is_held(), "the player acts")
	assert_false(_combat.enemy_combatant.is_held(), "and so does the enemy")
	assert_true(_combat.enemy_nameplate.visible, "the enemy's name shows")
	await wait_seconds(0.3)
	assert_lt(_ai()._opening_left, CombatAbilityInstance.INITIAL_COOLDOWN - 0.2, "the enemy's opening counts down")
	assert_almost_eq(_technique().cooldown_timer.time_left, _ai()._opening_left, 0.02, "with the player's, from the same frame")

func test_the_fight_is_decided_once() -> void:
	_start_fight()
	_combat.begin()

	for hit: int in 3:
		_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

	assert_eq(_ends.size(), 1, "one report, however often the enemy is hit at 0")
	if _ends.size() == 1:
		assert_eq(_ends[0], [true, AdventureCombat.gold_reward_for(_choice, null)], "a win, with its gold")
	assert_false(_combat.is_live(), "the fight is over")
	assert_true(_combat.player_combatant.is_held(), "the player holds still")
	assert_true(_combat.enemy_combatant.is_held(), "and so does the enemy")

func test_health_before_the_fight_starts_decides_nothing() -> void:
	_start_fight()

	_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)
	PlayerManager.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

	assert_eq(_ends.size(), 0, "no hit has landed: the fight is not decided")

func test_nothing_acts_after_the_deciding_hit() -> void:
	_start_fight()
	_combat.begin()
	_combat.enemy_combatant.buff_manager.apply_buff(_dot())
	var enemy_health: float = _combat.enemy_combatant.vitals_manager.current_health

	PlayerManager.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)
	await wait_seconds(CombatAbilityInstance.INITIAL_COOLDOWN + 0.2)

	assert_eq(_ends.size(), 1, "precondition: the player's fall decided the fight")
	assert_false(_combat.enemy_combatant.ability_manager.is_casting(), "the enemy starts no cast")
	assert_eq(_combat.enemy_combatant.vitals_manager.current_health, enemy_health, "its damage over time ticks nothing")

func test_presses_reach_only_a_live_fight() -> void:
	InventoryManager.award_items(CRUDE_SCALE, 3)
	InventoryManager.equip_consumable(CRUDE_SCALE as ConsumableDefinitionData, 0)
	_start_fight()
	var technique: CombatAbilityInstance = _technique()
	technique.cooldown_timer.stop()
	var consumable: CombatConsumableInstance = _combat.player_combatant.consumable_manager.get_instance_at_slot(0)
	assert_not_null(consumable, "precondition: the hotbar's Crude Scale is in the fight")
	var stages: Array[Dictionary] = [
		{"name": "before the fight starts", "decide": false},
		{"name": "after the deciding hit", "decide": true},
	]
	for stage: Dictionary in stages:
		if stage.decide:
			_combat.begin()
			technique.cooldown_timer.stop()
			_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

		_combat.on_player_ability_selected(technique)
		_combat.on_player_consumable_selected(consumable)

		assert_eq(technique.use_count, 0, "%s: no technique is used" % stage.name)
		assert_false(technique.is_casting, "%s: nor cast" % stage.name)
		assert_eq(InventoryManager.get_consumable_count(CRUDE_SCALE as ConsumableDefinitionData), 3, "%s: no consumable is used" % stage.name)

func test_the_loser_falls() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a win", "won": true},
		{"name": "a loss", "won": false},
	]
	for case: Dictionary in cases:
		_new_combat()
		PlayerManager.vitals_manager.current_health = PlayerManager.vitals_manager.max_health
		_start_fight()
		_combat.begin()
		var loser: CombatantNode = _combat.enemy_combatant if case.won else _combat.player_combatant
		var winner: CombatantNode = _combat.player_combatant if case.won else _combat.enemy_combatant
		(loser.vitals_manager as VitalsManager).apply_vitals_change(LETHAL_DAMAGE)

		_combat.play_defeat(case.won)
		if case.won:
			assert_false(_combat.enemy_nameplate.visible, "%s: the enemy's name goes as it starts to fall" % case.name)
		await wait_seconds(CombatantVisual.DEFEAT_SECONDS + 0.1)

		assert_true(loser.visual.is_fallen(), "%s: the loser is gone" % case.name)
		assert_false(winner.visual.is_fallen(), "%s: the winner stands" % case.name)
