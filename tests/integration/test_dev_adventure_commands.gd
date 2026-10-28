extends GutTest

## The dev tools' adventure commands against a real AdventureView, hosted as
## test_adventure_end_flow.gd hosts it, but playing on the fixture map: a random
## Shallow Woods map can fail its critical-path check, and the error that logs fails
## the test it lands in. Force-win kills the fight's enemy through its Health, so the
## real death path runs: AdventureCombat pays the fight's gold and fires the Beat 2
## event, and the view and the map end the fight as a win. Exit ends the run through
## the real stop. A dev command is not play, so none of it counts in the save's play
## stats (PlayStatsData). Each test binds a fresh save, calls the real autoloads, and
## puts the original save and the player's vitals back after it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const ADVENTURE_ACTION := AdventureMapFixture.ADVENTURE_ACTION

## The event a won fight fires: Foundation Beat 2's quest step waits for it.
const ENEMY_DEFEATED_EVENT: String = "q_first_steps_enemy_defeated"
## The Madra the zone's drain hands the run.
const RUN_MADRA: float = 50.0
## The prefix of every line a dev command logs.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _view: AdventureView
## The action the run was started with: a copy, so no test touches the shared resource.
var _action: AdventureActionData
## The fixture map the run plays on.
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
## What the view announced as each run ended.
var _results: Array[AdventureResultData] = []
var _original_save: SaveGameData
## The player's vitals as the test found them, put back after it: they are one object
## shared by every test.
var _saved_vitals: Dictionary[StringName, float] = {}
var _saved_madra: float = 0.0

func before_each() -> void:
	# A fight's end pays gold and resolves a tile, and a run's end resumes the zone's
	# idle action, all into the save. Run on a fresh one, never the developer's save
	# in memory.
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	_saved_madra = PlayerManager.vitals_manager.current_madra
	_map = AdventureMapFixture.build_map()
	_results.clear()
	_view = AdventureViewScene.instantiate()
	add_child_autofree(_view)
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
	_view.adventure_tilemap.full_map.tile_set.emit_changed()
	await get_tree().process_frame
	_view.adventure_completed.connect(func(result: AdventureResultData) -> void: _results.append(result))

func after_each() -> void:
	# Ends the run (and the idle action its end resumes) on the fresh save.
	_stop_actions()
	# AdventureTilemap creates its AdventureMapGenerator node with .new() and
	# never frees it; free it here so these tests don't leave orphans.
	if is_instance_valid(_view) and is_instance_valid(_view.adventure_tilemap.adventure_map_generator):
		_view.adventure_tilemap.adventure_map_generator.free()
	# A fight keeps listening to the player's Health after it ends, so the view goes
	# before the Health is put back: a Health of 0 would end a fight that is over.
	if is_instance_valid(_view):
		_view.free()
	AdventureMapFixture.restore_vitals(_saved_vitals)
	PlayerManager.vitals_manager.current_madra = _saved_madra
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the original save again resumes its idle action, if it has one. Stop
	# it, so its tick timer does not run on into the next test.
	_stop_actions()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Hands out a map it was given in place of a generated one, so that no test plays a
## random map.
class FixedMapGenerator extends AdventureMapGenerator:
	var map: Dictionary[Vector3i, AdventureEncounter] = {}

	## Returns the given map.
	func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
		return map

## The stats of the save this test runs on (before_each binds a fresh one).
func _stats() -> PlayStatsData:
	return PersistenceManager.save_game_data.stats

func _stop_actions() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## Starts the Shallow Woods the way the zone does once its Madra drain ends: the
## action becomes the current one and the run is confirmed with its budget. The run
## plays on the fixture map, which the tilemap is handed in place of a generated one.
func _start_run() -> void:
	var generator := FixedMapGenerator.new()
	generator.map = _map
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	tilemap.adventure_map_generator.free()
	tilemap.adventure_map_generator = generator
	_action = ADVENTURE_ACTION.duplicate()
	ActionManager._set_current_action(_action)
	ActionManager.confirm_adventure_start(_action, RUN_MADRA)

## Starts a run and puts a fight under way, as picking its combat card does: the
## tilemap remembers the choice and the view starts the fight. The fight is the
## fixture map's, against one Amorphous Spirit, unless a choice is given. Returns the
## choice.
func _start_a_fight(fight: CombatChoice = null) -> CombatChoice:
	_start_run()
	if fight == null:
		fight = AdventureMapFixture.fight_choice(_map)
	_view.adventure_tilemap._current_combat_choice = fight
	_view._on_start_combat(fight)
	return fight

## The [DEV] lines the player's log got since watch_signals(LogManager).
func _dev_lines() -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		if line.begins_with(DEV_LINE):
			lines.append(line)
	return lines

#-----------------------------------------------------------------------------
# FORCE-WIN
#-----------------------------------------------------------------------------

func test_force_win_pays_gold_and_fires_the_event() -> void:
	var fight: CombatChoice = _start_a_fight()
	var reward: int = AdventureCombat.gold_reward_for(fight, _action)
	assert_gt(reward, 0, "precondition: the fight pays gold")
	assert_false(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "precondition: no enemy has fallen yet")
	var gold_before: float = ResourceManager.get_gold()
	watch_signals(_view.combat)

	assert_eq(DevCommands.force_win_fight(_view), "")

	assert_true(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "the enemy's fall fired the Beat 2 event")
	assert_eq(ResourceManager.get_gold(), gold_before + reward, "the fight paid its gold")
	assert_signal_emit_count(_view.combat, "trigger_combat_end", 1)
	assert_signal_emitted_with_parameters(_view.combat, "trigger_combat_end", [true, reward])
	assert_false(_view.is_in_combat, "and the fight is over")

func test_force_win_twice_pays_once() -> void:
	var fight: CombatChoice = _start_a_fight()
	var reward: int = AdventureCombat.gold_reward_for(fight, _action)
	var gold_before: float = ResourceManager.get_gold()
	watch_signals(_view.combat)

	assert_eq(DevCommands.force_win_fight(_view), "")
	assert_eq(DevCommands.force_win_fight(_view), "No fight is on", "the fight is over, so a second press has nothing to win")

	assert_eq(ResourceManager.get_gold(), gold_before + reward, "the gold was paid once")
	assert_signal_emit_count(_view.combat, "trigger_combat_end", 1)

## A press on an enemy that is already down pays nothing: the Health setter reports
## 0 again, and AdventureCombat would pay the fight's gold a second time. The view
## drops the fight at once, so this test tells it the fight is still on: the one way
## to reach the guards on the enemy itself.
func test_force_win_ignores_an_enemy_that_is_already_down() -> void:
	_start_a_fight()
	assert_eq(DevCommands.force_win_fight(_view), "")
	var gold_won: float = ResourceManager.get_gold()
	watch_signals(_view.combat)

	_view.is_in_combat = true
	_view.force_win_combat()
	assert_signal_not_emitted(_view.combat, "trigger_combat_end")
	assert_eq(ResourceManager.get_gold(), gold_won, "the fallen enemy paid nothing more")

	# The enemy is freed once the frame ends, and a press must not reach into it.
	await get_tree().process_frame
	_view.force_win_combat()
	assert_signal_not_emitted(_view.combat, "trigger_combat_end")
	_view.is_in_combat = false

func test_dev_force_win_is_not_play() -> void:
	_start_a_fight()
	var gold_before: float = ResourceManager.get_gold()

	assert_eq(DevCommands.force_win_fight(_view), "")

	# The fight did end as a win: its gold is in the purse and its tile is resolved...
	assert_gt(ResourceManager.get_gold(), gold_before, "precondition: the win paid")
	assert_true(_view.adventure_tilemap.is_tile_completed(_view.adventure_tilemap.get_current_tile()), "precondition: the win resolved its tile")
	# ...and none of it counts as play.
	var stats: PlayStatsData = _stats()
	assert_eq(stats.fights_won, 0, "the fight is not counted as won")
	assert_eq(stats.gold_earned, 0.0, "nor its gold as earned")
	assert_false(stats.event_first_times.has(ENEMY_DEFEATED_EVENT), "nor the event's first time recorded")
	assert_false(stats.recording_paused, "and recording is on again")

## The boss's fall ends the whole run inside the one command: the fight, the win and
## the gold come from the real death path, and none of them counts as play.
func test_force_win_of_the_boss_wins_the_adventure() -> void:
	var boss: CombatChoice = _start_a_fight(_map[AdventureMapFixture.BOSS].choices[0] as CombatChoice)
	var reward: int = AdventureCombat.gold_reward_for(boss, _action)
	assert_gt(reward, 0, "precondition: the boss pays gold")
	var gold_before: float = ResourceManager.get_gold()

	assert_eq(DevCommands.force_win_fight(_view), "")

	assert_false(_view.is_adventure_running(), "the boss's fall ended the adventure")
	assert_eq(_results.size(), 1, "once")
	if _results.size() == 1:
		assert_true(_results[0].is_victory, "as a victory")
		assert_eq(_results[0].gold_earned, reward, "and the end card shows the boss's gold")
	assert_eq(ResourceManager.get_gold(), gold_before + reward, "the boss paid its gold once")
	var stats: PlayStatsData = _stats()
	assert_eq(stats.fights_won, 0, "the fight is not counted as won")
	assert_eq(stats.adventures_won, 0, "nor the adventure")
	assert_eq(stats.gold_earned, 0.0, "nor the gold as earned")

func test_force_win_logs_a_dev_line() -> void:
	_start_a_fight()
	watch_signals(LogManager)

	assert_eq(DevCommands.force_win_fight(_view), "")

	assert_eq(_dev_lines(), [DEV_LINE + "Won the fight"] as Array[String])

func test_force_win_refuses_without_a_fight() -> void:
	_start_run()
	assert_false(_view.is_in_combat, "precondition: no fight is on")
	var gold_before: float = ResourceManager.get_gold()
	watch_signals(LogManager)

	assert_eq(DevCommands.force_win_fight(_view), "No fight is on")
	assert_eq(DevCommands.force_win_fight(null), "No fight is on", "a view that is not there has none")

	assert_eq(ResourceManager.get_gold(), gold_before, "nothing was paid")
	assert_false(EventManager.has_event_triggered(ENEMY_DEFEATED_EVENT), "and no event fired")
	assert_eq(_dev_lines().size(), 0, "a refusal logs no [DEV] line")
	assert_false(_stats().recording_paused, "and leaves recording on")

#-----------------------------------------------------------------------------
# EXIT
#-----------------------------------------------------------------------------

func test_exit_as_victory_ends_the_run() -> void:
	_start_run()
	assert_true(_view.is_adventure_running(), "precondition: the run is on")
	watch_signals(LogManager)

	assert_eq(DevCommands.exit_adventure(_view, true), "")

	assert_false(_view.is_adventure_running(), "the adventure stopped")
	assert_false(ActionManager.get_current_action() is AdventureActionData, "and it is no longer the current action")
	assert_eq(_results.size(), 1, "the adventure ended once")
	if _results.size() == 1:
		assert_true(_results[0].is_victory, "as a victory")
	assert_eq(_stats().adventures_won, 0, "a dev exit is no win in the play stats")
	assert_eq(_dev_lines(), [DEV_LINE + "Ended the adventure as a victory"] as Array[String])

func test_exit_as_defeat_ends_the_run() -> void:
	_start_run()
	assert_true(_view.is_adventure_running(), "precondition: the run is on")
	# A run that ends at 0 Health counts as a loss in play, so a count of 0 shows the pause.
	PlayerManager.vitals_manager.current_health = 0.0
	watch_signals(LogManager)

	assert_eq(DevCommands.exit_adventure(_view, false), "")

	assert_false(_view.is_adventure_running(), "the adventure stopped")
	assert_eq(_results.size(), 1, "the adventure ended once")
	if _results.size() == 1:
		assert_false(_results[0].is_victory, "as a defeat")
		assert_eq(_results[0].defeat_reason, "Your health reached zero", "precondition: the end is one that play counts")
	assert_eq(_stats().adventures_lost, 0, "a dev exit is no loss in the play stats")
	assert_eq(_dev_lines(), [DEV_LINE + "Ended the adventure as a defeat"] as Array[String])

func test_exit_refuses_without_a_run() -> void:
	assert_false(_view.is_adventure_running(), "precondition: no run is on")
	watch_signals(LogManager)

	assert_eq(DevCommands.exit_adventure(_view, true), "No adventure is running")
	assert_eq(DevCommands.exit_adventure(null, false), "No adventure is running", "a view that is not there has no run")

	assert_eq(_results.size(), 0, "nothing ended")
	assert_eq(_dev_lines().size(), 0, "a refusal logs no [DEV] line")
	assert_false(_stats().recording_paused, "and leaves recording on")

#-----------------------------------------------------------------------------
# VITALS
#-----------------------------------------------------------------------------

func test_refill_vitals_keeps_the_run_madra() -> void:
	_start_run()
	var vitals: VitalsManager = PlayerManager.vitals_manager
	assert_eq(vitals.current_madra, RUN_MADRA, "precondition: the run starts with its Madra budget")
	# The run costs 40 Health, 95 Stamina and 17 Madra.
	vitals.apply_vitals_change(-40.0, -95.0, -17.0)
	var madra_left: float = vitals.current_madra
	assert_lt(madra_left, vitals.max_madra, "precondition: the run has spent Madra")
	assert_lt(vitals.current_health, vitals.max_health, "precondition: and Health")
	assert_lt(vitals.current_stamina, vitals.max_stamina, "precondition: and Stamina")

	assert_eq(DevCommands.refill_vitals(), "")

	assert_eq(vitals.current_health, vitals.max_health, "Health is full")
	assert_eq(vitals.current_stamina, vitals.max_stamina, "Stamina is full")
	assert_eq(vitals.current_madra, madra_left, "the Madra the run has left stays")
