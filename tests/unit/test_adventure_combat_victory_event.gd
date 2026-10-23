extends GutTest

## A combat win must fire the q_first_steps_enemy_defeated event (Foundation
## Beat 2's quest step) by the time AdventureCombat reports the win, and a loss
## must not. Drives the real AdventureCombat scene the way AdventureView starts
## a fight (initialize_combat(), then start()), and ends the fight by dropping
## the enemy's or the player's real vitals to 0 HP.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureCombatScene := preload("res://scenes/combat/adventure_combat/adventure_combat.tscn")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const ENEMY_DEFEATED_EVENT := "q_first_steps_enemy_defeated"
## More damage than any health pool, so one hit always leaves 0 HP.
const LETHAL_DAMAGE := -1000000.0

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _combat: AdventureCombat
var _original_save: SaveGameData
var _original_player_health: float
## One entry per trigger_combat_end emission:
## [is_successful, whether the event had fired when the signal was emitted].
var _combat_ends: Array[Array] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_player_health = PlayerManager.vitals_manager.current_health
	_combat_ends.clear()

	_combat = AdventureCombatScene.instantiate()
	add_child_autofree(_combat)
	_combat.trigger_combat_end.connect(_on_combat_end)

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

## Starts a fight against one Amorphous Spirit, as AdventureView._on_start_combat()
## does. Each test ends the fight in the same frame, before the enemy AI's first
## _process() can act.
func _start_fight() -> void:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	choice.enemy_pool = pool
	_combat.initialize_combat(choice, null)
	_combat.start()

func _on_combat_end(is_successful: bool, _gold_earned: int) -> void:
	_combat_ends.append([is_successful, EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT)])

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_combat_victory_triggers_enemy_defeated_event() -> void:
	_start_fight()
	assert_false(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "event starts untriggered on a fresh save")

	_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

	assert_eq(_combat_ends.size(), 1, "the fight ends once")
	if _combat_ends.size() == 1:
		assert_true(_combat_ends[0][0], "the fight ends as a win")
		assert_true(_combat_ends[0][1], "the event has fired by the time the win is reported")
	assert_true(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "event is triggered after the win")

func test_combat_defeat_does_not_trigger_event() -> void:
	_start_fight()

	PlayerManager.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

	assert_eq(_combat_ends.size(), 1, "the fight ends once")
	if _combat_ends.size() == 1:
		assert_false(_combat_ends[0][0], "the fight ends as a loss")
	assert_false(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "a loss must not trigger the event")
