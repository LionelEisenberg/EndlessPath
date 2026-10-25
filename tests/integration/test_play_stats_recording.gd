extends GutTest

## Where each play stat is recorded. The system that owns a moment calls the live
## save's stats (PlayStatsData): EventManager for an event's first firing,
## UnlockManager for a condition's latch, ResourceManager for gold earned,
## CyclingManager for a finished cycle, ActionManager for an adventure's start,
## AdventureTilemap for a won fight and the main scene for playtime. The tests
## call the real autoloads, with a fresh save bound to each and the original put
## back after it. How an adventure run ends is test_adventure_end_flow.gd's.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureTilemapScene := preload("res://scenes/adventure/adventure_tilemap/adventure_tilemap.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const MainGameScript := preload("res://scenes/main/main_game/main_game.gd")
const ADVENTURE_ACTION := AdventureMapFixture.ADVENTURE_ACTION

const EVENT_ID: String = "play_stats_recording_event"
const OTHER_EVENT_ID: String = "play_stats_recording_other_event"
const CONDITION_ID: String = "play_stats_recording_condition"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_condition_list: UnlockConditionList
## The fixture map a tilemap run plays on (see _start_a_tilemap_run()).
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
var _tilemaps: Array[AdventureTilemap] = []
## The player's vitals as a test that sets them found them, put back after it.
var _saved_vitals: Dictionary[StringName, float] = {}

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_condition_list = UnlockManager.unlock_condition_list
	_map = AdventureMapFixture.build_map()

func after_each() -> void:
	UnlockManager.unlock_condition_list = _original_condition_list
	for tilemap: AdventureTilemap in _tilemaps:
		# AdventureTilemap creates its AdventureMapGenerator node with .new() and
		# never frees it; free it here so these tests don't leave orphans.
		if is_instance_valid(tilemap) and is_instance_valid(tilemap.adventure_map_generator):
			tilemap.adventure_map_generator.free()
	_tilemaps.clear()
	if not _saved_vitals.is_empty():
		AdventureMapFixture.restore_vitals(_saved_vitals)
		_saved_vitals.clear()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the original save again resumes its idle action. Stop it, so its
	# tick timer does not run on into the next test.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The live save's stats, the ones every system records into.
func _stats() -> PlayStatsData:
	return PersistenceManager.save_game_data.stats

## A condition that latches once the event has fired.
func _event_condition(condition_id: String, event_id: String) -> UnlockConditionData:
	var condition := UnlockConditionData.new()
	condition.condition_id = condition_id
	condition.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	condition.target_value = event_id
	return condition

func _list_of(condition: UnlockConditionData) -> UnlockConditionList:
	var conditions: Array[UnlockConditionData] = [condition]
	var list := UnlockConditionList.new()
	list.list = conditions
	return list

## The fixture map's fight choice, on FIGHT.
func _fight() -> CombatChoice:
	return AdventureMapFixture.fight_choice(_map)

## The fixture map's boss choice, on BOSS.
func _boss() -> CombatChoice:
	return _map[AdventureMapFixture.BOSS].choices[0] as CombatChoice

## Starts a run on the fixture map in a real AdventureTilemap, the way the
## adventure view starts one, and puts `choice` under way, as picking its card
## does. A fight is not played: the tests answer it with handle_combat_result(),
## as AdventureView does when one ends.
func _start_a_tilemap_run(choice: CombatChoice) -> AdventureTilemap:
	var tilemap: AdventureTilemap = AdventureTilemapScene.instantiate()
	add_child_autofree(tilemap)
	_tilemaps.append(tilemap)
	# The project's hex layer script overrides _ready() without super(), so the
	# addon only sets up its cube<->map conversions when the shared TileSet
	# emits `changed`, which happens once after it first loads. Re-emit it so
	# this fresh tilemap's map layers are initialised.
	tilemap.full_map.tile_set.emit_changed()
	await get_tree().process_frame
	tilemap.start_adventure_on_map(ADVENTURE_ACTION, _map)
	tilemap.select_choice(choice)
	return tilemap

func _assert_empty(stats: PlayStatsData, what: String) -> void:
	assert_eq(stats.play_time, 0.0, "%s: no playtime" % what)
	assert_true(stats.event_first_times.is_empty(), "%s: no event time" % what)
	assert_true(stats.condition_first_times.is_empty(), "%s: no condition time" % what)
	assert_eq(stats.cycles_finished + stats.adventures_started + stats.adventures_won
			+ stats.adventures_lost + stats.adventures_timed_out + stats.fights_won, 0, "%s: no count" % what)
	assert_eq(stats.gold_earned, 0.0, "%s: no gold" % what)
	assert_eq(stats.built_from_preset, "", "%s: built from no preset" % what)

#-----------------------------------------------------------------------------
# PLAYTIME
#-----------------------------------------------------------------------------

func test_the_main_scene_adds_its_frames_to_play_time() -> void:
	# The script on its own, never main_game.tscn (see TESTING.md: the scene's
	# SaveTimer writes the save).
	var main_game: Node2D = autofree(MainGameScript.new())
	simulate(main_game, 4, 0.25)
	assert_eq(_stats().play_time, 1.0, "four frames of a quarter second")

#-----------------------------------------------------------------------------
# EVENTS AND CONDITIONS
#-----------------------------------------------------------------------------

func test_a_new_event_records_its_time() -> void:
	_stats().play_time = 12.5
	EventManager.trigger_event(EVENT_ID)
	assert_eq(_stats().event_first_times.get(EVENT_ID), 12.5)
	_stats().play_time = 80.0
	EventManager.trigger_event(EVENT_ID)
	assert_eq(_stats().event_first_times.get(EVENT_ID), 12.5, "an event that fires again keeps its first time")

func test_a_latched_condition_records_its_time() -> void:
	# The event fires first, with no condition waiting on it...
	_stats().play_time = 7.0
	EventManager.trigger_event(EVENT_ID)
	assert_false(UnlockManager.is_condition_unlocked(CONDITION_ID))
	# ...and the condition that needs it latches at the next sweep, later.
	UnlockManager.unlock_condition_list = _list_of(_event_condition(CONDITION_ID, EVENT_ID))
	_stats().play_time = 9.5
	EventManager.trigger_event(OTHER_EVENT_ID)
	assert_true(UnlockManager.is_condition_unlocked(CONDITION_ID), "the sweep after the event latched the condition")
	assert_eq(_stats().condition_first_times.get(CONDITION_ID), 9.5, "the condition's time is when it latched, not when its event fired")
	assert_eq(_stats().event_first_times.get(EVENT_ID), 7.0)
	assert_eq(_stats().first_time_of(CONDITION_ID), 9.5)

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

func test_add_gold_counts_as_earned_and_set_gold_does_not() -> void:
	ResourceManager.add_gold(40.0, true)
	assert_eq(_stats().gold_earned, 40.0, "gold added is gold earned")
	ResourceManager.set_gold(500.0)
	assert_eq(_stats().gold_earned, 40.0, "setting the gold is not earning it")
	assert_true(ResourceManager.spend_gold(100.0))
	assert_eq(_stats().gold_earned, 40.0, "spending gold is not earning it")
	ResourceManager.add_gold(-5.0, true)
	assert_eq(_stats().gold_earned, 40.0, "taking gold away earns nothing")
	ResourceManager.add_gold(2.5, true)
	assert_eq(_stats().gold_earned, 42.5, "the gold earned keeps adding up")

#-----------------------------------------------------------------------------
# CYCLES
#-----------------------------------------------------------------------------

func test_a_finished_cycle_counts_once() -> void:
	CyclingManager.set_last_cycle_result(CycleResult.new())
	assert_eq(_stats().cycles_finished, 1, "a cycle that ended is counted")
	CyclingManager.clear_last_cycle_result()
	assert_eq(_stats().cycles_finished, 1, "forgetting the result is not another cycle")
	CyclingManager.set_last_cycle_result(null)
	assert_eq(_stats().cycles_finished, 1, "neither is a null result")

#-----------------------------------------------------------------------------
# ADVENTURES AND FIGHTS
#-----------------------------------------------------------------------------

func test_confirming_an_adventure_counts_a_start() -> void:
	# The zone asks for the start when the action is picked, and can ask again.
	ActionManager.adventure_start_requested.emit(ADVENTURE_ACTION)
	ActionManager.adventure_start_requested.emit(ADVENTURE_ACTION)
	assert_eq(_stats().adventures_started, 0, "a request is not a start")
	ActionManager.confirm_adventure_start(ADVENTURE_ACTION, 50.0)
	assert_eq(_stats().adventures_started, 1, "the confirmed start is the real one")

func test_a_won_fight_counts_once() -> void:
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_fight())
	tilemap.handle_combat_result(true, 0)
	assert_eq(_stats().fights_won, 1, "the fight is won")
	# AdventureCombat reports a win again while its enemy sits at 0 Health, in
	# the frame before the enemy is freed.
	tilemap.handle_combat_result(true, 0)
	assert_eq(_stats().fights_won, 1, "the same fight's win, reported again, is not another win")

func test_the_next_fight_counts_again() -> void:
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_fight())
	tilemap.handle_combat_result(true, 0)
	# The next run's fight: a new choice under way.
	tilemap.stop_adventure()
	tilemap.start_adventure_on_map(ADVENTURE_ACTION, _map)
	tilemap.select_choice(_fight())
	tilemap.handle_combat_result(true, 0)
	assert_eq(_stats().fights_won, 2, "each fight is counted when it is won")

func test_a_won_boss_fight_counts_and_resolves_once() -> void:
	# The boss's win heals 10 Health, so how often it is resolved shows in the Health.
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 10.0
	var heal_effects: Array[EffectData] = [heal]
	_boss().success_effects = heal_effects
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_boss())
	watch_signals(tilemap)
	tilemap.handle_combat_result(true, 0)
	assert_eq(_stats().fights_won, 1, "the boss fight is won")
	assert_signal_emit_count(tilemap, "boss_defeated", 1)
	assert_eq(PlayerManager.vitals_manager.current_health, 60.0, "its success effects ran")
	# The boss's win ended the run: ActionManager.stop_action(true) has AdventureView
	# stop the map. AdventureCombat reports the win again while its enemy takes
	# another hit at 0 Health, before the enemy is freed.
	tilemap.stop_adventure()
	tilemap.handle_combat_result(true, 0)
	assert_eq(_stats().fights_won, 1, "the same boss fight's win, reported again, is not another win")
	assert_signal_emit_count(tilemap, "boss_defeated", 1, "the boss falls once")
	assert_eq(PlayerManager.vitals_manager.current_health, 60.0, "its success effects ran once")

func test_a_repeated_boss_win_marks_nothing_on_the_cleared_map() -> void:
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_boss())
	tilemap.handle_combat_result(true, 0)
	tilemap.stop_adventure()
	tilemap.handle_combat_result(true, 0)
	assert_false(tilemap.is_tile_visited(AdventureMapFixture.START), "no tile is marked on the map the run cleared")
	# What the repeat leaves on the map is what the next run starts from: a start
	# tile already counted as visited would show the player nothing around it.
	tilemap.start_adventure_on_map(ADVENTURE_ACTION, _map)
	assert_true(tilemap.is_tile_revealed(AdventureMapFixture.FIGHT), "the next run opens with the tiles around its start in view")
	assert_false(tilemap.is_tile_completed(AdventureMapFixture.START), "and its start tile unresolved")

func test_a_lost_fight_is_not_a_win() -> void:
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_fight())
	tilemap.handle_combat_result(false, 0)
	assert_eq(_stats().fights_won, 0)

func test_a_fights_gold_counts_as_earned() -> void:
	var tilemap: AdventureTilemap = await _start_a_tilemap_run(_fight())
	tilemap.handle_combat_result(true, 15)
	assert_eq(_stats().gold_earned, 15.0, "the gold the fight paid")
	assert_eq(_stats().fights_won, 1)

#-----------------------------------------------------------------------------
# A NEW SAVE
#-----------------------------------------------------------------------------

func test_a_new_save_has_empty_stats() -> void:
	_stats().count_fight_won()
	_stats().record_event(EVENT_ID)
	var fresh := SaveGameData.new_current()
	assert_not_same(fresh.stats, _stats(), "a new save has stats of its own, not another save's")
	_assert_empty(fresh.stats, "a new save")

func test_resetting_a_save_hands_back_empty_stats() -> void:
	var save := SaveGameData.new()
	var old_stats: PlayStatsData = save.stats
	save.stats.add_play_time(30.0)
	save.stats.record_event(EVENT_ID)
	save.stats.count_cycle_finished()
	save.stats.add_gold_earned(12.0)
	save.reset()
	assert_not_same(save.stats, old_stats, "reset() leaves new stats, not the old ones emptied")
	_assert_empty(save.stats, "a reset save")
