extends GutTest

## SimpleEnemyAI waits out the fight's opening: the enemy's first cast starts as
## the player's techniques come off their 1.5 s opening cooldown, not on the
## fight's first frame. After it, the enemy casts as it always has. Drives real
## AdventureCombat fights, started the way AdventureView starts one, and steps
## the AI's _process() with gut.simulate() so the clock is exact.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureCombatScene := preload("res://scenes/combat/adventure_combat/adventure_combat.tscn")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const STARVING_DREADBEAST := preload("res://resources/combat/combatant_data/starving_dreadbeast.tres")
## One simulated frame.
const FRAME := 0.05

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _combat: AdventureCombat
var _original_save: SaveGameData
var _original_player_health: float

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_player_health = PlayerManager.vitals_manager.current_health

	_combat = AdventureCombatScene.instantiate()
	add_child_autofree(_combat)

func after_each() -> void:
	# Free the fight first so restoring the player's health below does not
	# reach its PlayerManager.vitals_manager connections.
	if is_instance_valid(_combat):
		_combat.free()
	PlayerManager.vitals_manager.current_health = _original_player_health
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Starts a fight against one enemy and begins it, as AdventureView does once both
## fighters have arrived: the openings start then.
func _start_fight(enemy: CombatantData) -> void:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [enemy]
	choice.enemy_pool = pool
	_combat.initialize_combat(choice, null)
	_combat.start()
	_combat.begin()

func _ai() -> SimpleEnemyAI:
	return _combat.enemy_combatant.get_node("EnemyAI") as SimpleEnemyAI

func _enemy_is_casting() -> bool:
	return _combat.enemy_combatant.ability_manager.is_casting()

## Steps the AI on by `seconds`, one FRAME at a time.
func _run_ai_for(seconds: float) -> void:
	gut.simulate(_ai(), roundi(seconds / FRAME), FRAME)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## The opening is the player's: INITIAL_COOLDOWN, the one every technique opens on.
func test_the_opening_lasts_the_players_opening_cooldown() -> void:
	_start_fight(AMORPHOUS_SPIRIT)
	assert_true(_ai().is_in_opening(), "a fight opens in the opening")
	_run_ai_for(CombatAbilityInstance.INITIAL_COOLDOWN - FRAME)
	assert_true(_ai().is_in_opening(), "a frame short of 1.5 s")
	_run_ai_for(FRAME)
	assert_false(_ai().is_in_opening(), "over at 1.5 s")

## Neither regular enemy casts during the opening, though their attacks have no
## cooldown of their own, and each starts its first cast as the opening ends.
func test_the_first_cast_waits_for_the_opening() -> void:
	var enemies: Array[CombatantData] = [AMORPHOUS_SPIRIT, STARVING_DREADBEAST]
	for enemy: CombatantData in enemies:
		_start_fight(enemy)
		_run_ai_for(CombatAbilityInstance.INITIAL_COOLDOWN - FRAME)
		assert_false(_enemy_is_casting(), "%s casts nothing during the opening" % enemy.character_name)
		_run_ai_for(FRAME)
		assert_true(_enemy_is_casting(), "%s starts its first cast as the opening ends" % enemy.character_name)
		_combat.stop()

## Only the first cast moves: once it lands, the next starts at once, as before.
func test_after_the_first_cast_the_next_starts_at_once() -> void:
	_start_fight(AMORPHOUS_SPIRIT)
	_run_ai_for(CombatAbilityInstance.INITIAL_COOLDOWN)
	var lash: CombatAbilityInstance = _combat.enemy_combatant.ability_manager.abilities[0]
	assert_true(lash.is_casting, "precondition: the first lash is under way")

	lash.cast_timer.start(0.01)
	var landed: bool = await wait_for_signal(lash.cast_finished, 1.0)
	assert_true(landed, "precondition: the first lash landed")
	_run_ai_for(FRAME)
	assert_true(lash.is_casting, "the next lash starts on the next frame")

## In real time, the enemy's first cast starts no earlier than the player's first
## technique comes off its opening cooldown, and within a frame of it.
func test_the_first_cast_starts_as_the_players_technique_comes_ready() -> void:
	_start_fight(AMORPHOUS_SPIRIT)
	var technique: CombatAbilityInstance = _combat.player_combatant.ability_manager.abilities[0]
	var lash: CombatAbilityInstance = _combat.enemy_combatant.ability_manager.abilities[0]
	var frames: Dictionary[StringName, int] = {}
	technique.cooldown_ready.connect(func() -> void: frames[&"ready"] = Engine.get_process_frames(), CONNECT_ONE_SHOT)
	lash.cast_started.connect(func(_i: CombatAbilityInstance, _d: float) -> void: frames[&"cast"] = Engine.get_process_frames(), CONNECT_ONE_SHOT)

	await wait_until(func() -> bool: return frames.has(&"ready") and frames.has(&"cast"), 3.0)

	assert_true(frames.has(&"ready") and frames.has(&"cast"), "precondition: both happened")
	if frames.has(&"ready") and frames.has(&"cast"):
		assert_between(frames[&"cast"] - frames[&"ready"], 0, 1, "the cast starts with the ready flash, not before")
