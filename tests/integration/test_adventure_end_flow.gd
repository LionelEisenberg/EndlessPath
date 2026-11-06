extends GutTest

## How an adventure run ends and what the end card is told. Drives the real
## AdventureView scene through ActionManager, the same way the zone starts a run.
## It also checks how each end counts in the save's play stats (PlayStatsData).

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")

var _view: AdventureView
var _results: Array[AdventureResultData] = []
## The player's vitals as a test that sets them found them, put back after it.
var _saved_vitals: Dictionary[StringName, float] = {}

func before_each() -> void:
	# Ending a run resumes the zone's idle action, which writes to the save.
	# Run on a fresh one, never the developer's save loaded in memory.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
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
	if ActionManager.get_current_action() is AdventureActionData:
		ActionManager.clear_current_action()
	# Ending a run resumes the zone's idle action. Stop it properly, since
	# clearing it would leave its tick timer connected for the next test.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# AdventureTilemap creates its AdventureMapGenerator node with .new() and
	# never frees it; free it here so these tests don't leave orphans.
	if is_instance_valid(_view) and is_instance_valid(_view.adventure_tilemap.adventure_map_generator):
		_view.adventure_tilemap.adventure_map_generator.free()
	if not _saved_vitals.is_empty():
		AdventureMapFixture.restore_vitals(_saved_vitals)
		_saved_vitals.clear()

func test_timeout_reports_time_ran_out() -> void:
	_start_adventure(1)
	await wait_for_signal(_view.adventure_completed, 3.0)
	assert_eq(_results.size(), 1, "the adventure ends once")
	var stats: PlayStatsData = _stats()
	assert_eq(stats.adventures_started, 1, "the run was counted when it started")
	assert_eq(stats.adventures_timed_out, 1, "running out of time counts a timeout")
	assert_eq(stats.adventures_won + stats.adventures_lost, 0, "and no win or loss")

func test_boss_win_ends_the_adventure_once_as_a_victory() -> void:
	_start_adventure(300)
	var failure_effect := RecordingEffect.new()
	var boss_choice := _boss_choice(failure_effect)
	# What picking the boss's combat card does: the tilemap remembers the
	# choice and asks the view to start the fight.
	_view.adventure_tilemap._current_combat_choice = boss_choice
	_view._on_start_combat(boss_choice)

	_view.combat.trigger_combat_end.emit(true, 0)  # the boss falls

	assert_eq(_results.size(), 1, "the adventure ends exactly once")
	if _results.size() == 1:
		assert_true(_results[0].is_victory, "a boss win is a victory")
	assert_eq(failure_effect.calls, 0, "a boss win must not run the boss choice's failure effects")
	var stats: PlayStatsData = _stats()
	assert_eq(stats.adventures_started, 1, "the run was counted when it started")
	assert_eq(stats.adventures_won, 1, "a boss win counts a won adventure, once")
	assert_eq(stats.fights_won, 1, "and the boss fight as a won fight")
	assert_eq(stats.adventures_lost + stats.adventures_timed_out, 0, "and no loss or timeout")

	# AdventureCombat reports the win again while its enemy takes another hit at 0
	# Health, before the enemy is freed. The run is over: the boss's win counts,
	# resolves and ends nothing a second time, and marks nothing on the cleared map.
	_view.combat.trigger_combat_end.emit(true, 0)
	assert_eq(_results.size(), 1, "the adventure still ended once")
	assert_eq(stats.fights_won, 1, "the boss fight is counted once")
	assert_eq(stats.adventures_won, 1, "and so is the win")
	assert_eq(_view.adventure_tilemap.get_visited_tile_count(), 0, "the repeat marked nothing on the cleared map")

## The boss's win ends the run in the same frame. Its Core Density is already in
## the save when the run ends, and a repeat of the win pays nothing more.
func test_the_boss_pays_its_core_density_before_the_run_ends() -> void:
	_start_adventure(300)
	var xp_when_the_run_ended: Array[float] = []
	_view.adventure_completed.connect(func(_result: AdventureResultData) -> void:
		xp_when_the_run_ended.append(CultivationManager.get_core_density_xp()))
	var boss_choice := _boss_choice(RecordingEffect.new())
	# 9 is under Foundation's level-1 cost of 10, so the boss's XP stays in the
	# save's core_density_xp at level 0.
	var award := AwardCoreDensityXpEffectData.new()
	award.amount = 9.0
	boss_choice.success_effects.append(award)
	_view.adventure_tilemap._current_combat_choice = boss_choice
	_view._on_start_combat(boss_choice)

	_view.combat.trigger_combat_end.emit(true, 0)
	_view.combat.trigger_combat_end.emit(true, 0)

	assert_eq(xp_when_the_run_ended.size(), 1, "the run ended once")
	if xp_when_the_run_ended.size() == 1:
		assert_eq(xp_when_the_run_ended[0], 9.0, "with the boss's XP already in the save")
	assert_eq(CultivationManager.get_core_density_xp(), 9.0, "a repeat of the win pays nothing more")
	assert_eq(_view.adventure_tilemap.get_core_density_xp_earned(), 9.0, "and the run's total keeps it")

## The chest stays in sight beside the end card, and its Run ledger counts the
## boss's Core Density: the boss's win announces the run's figures before it ends
## the run.
func test_the_ledger_counts_the_boss() -> void:
	_start_adventure(300)
	var boss_choice := _boss_choice(RecordingEffect.new())
	var award := AwardCoreDensityXpEffectData.new()
	award.amount = 9.0
	boss_choice.success_effects.append(award)
	_view.adventure_tilemap._current_combat_choice = boss_choice
	_view._on_start_combat(boss_choice)

	_view.combat.trigger_combat_end.emit(true, 0)

	assert_eq(_results.size(), 1, "precondition: the boss's win ended the run")
	var core_value := _view.adventure_chest.get_expedition_page().get_node("%CoreValue") as Label
	assert_eq(core_value.text, "9", "the ledger beside the end card counts the boss")

#-----------------------------------------------------------------------------
# HOW A STOP COUNTS
#-----------------------------------------------------------------------------
# These stop the view with its run's state set directly and no map under it:
# stop_adventure() reads the run's data, the run's timer and the player's Health,
# and a randomly generated map can fail its critical-path check now and then.

func test_a_retreat_counts_nothing() -> void:
	_set_player_health(40.0)
	_begin_a_run_without_a_map(300.0)
	_view.stop_adventure()
	assert_eq(_results.size(), 1)
	var stats: PlayStatsData = _stats()
	assert_eq(stats.adventures_won + stats.adventures_lost + stats.adventures_timed_out, 0, "a retreat is no win, loss or timeout")

## The run spends from the saved pool, so a quit mid-run saves what it spent
## and what is left, and the end card is told the pool as it stands.
func test_a_run_quit_midway_keeps_what_it_spent_and_what_is_left() -> void:
	_set_player_health(40.0)
	ResourceManager.set_madra(80.0)
	_begin_a_run_without_a_map(300.0)
	PlayerManager.vitals_manager.apply_vitals_change(0.0, 0.0, -30.0)
	assert_eq(PersistenceManager.save_game_data.madra, 50.0, "mid-run, the save already holds what is left")
	_view.stop_adventure()
	assert_eq(ResourceManager.get_madra(), 50.0, "what the run spent stays spent, and the rest stays in the pool")
	assert_eq(_results.size(), 1, "the retreat ended the run once")
	if _results.size() == 1:
		assert_eq(_results[0].madra_left, 50.0, "the end card is told the Madra left")
		assert_eq(_results[0].madra_max, 100.0, "over the pool's max")

func test_zero_health_counts_a_lost_adventure() -> void:
	_set_player_health(0.0)
	_begin_a_run_without_a_map(300.0)
	_view.stop_adventure()
	assert_eq(_results.size(), 1)
	var stats: PlayStatsData = _stats()
	assert_eq(stats.adventures_lost, 1, "Health at 0 counts a loss")
	assert_eq(stats.adventures_won + stats.adventures_timed_out, 0, "and no win or timeout")

func test_stopping_with_no_run_counts_nothing() -> void:
	# The adventure action is current while the start's zoom runs, before any run has
	# started, and a save switch can stop it then: that is no end. Health at 0 and a
	# stopped timer would read as a loss or a timeout.
	_set_player_health(0.0)
	assert_false(_view.is_adventure_running(), "no run is on")
	_view.stop_adventure()
	var stats: PlayStatsData = _stats()
	assert_eq(stats.adventures_won + stats.adventures_lost + stats.adventures_timed_out, 0, "no run ended")

func test_a_save_switch_during_the_start_counts_nothing_in_the_new_save() -> void:
	# The pick makes the adventure action current, and the start's zoom runs before the
	# run starts. A save switch (a restart, a restore) stops the action then, and
	# ActionManager hands that stop to the view with the new save already live.
	_set_player_health(40.0)
	ActionManager._set_current_action(ADVENTURE_ACTION.duplicate())
	var new_save := SaveGameData.new()
	PersistenceManager.save_game_data = new_save
	PersistenceManager.save_data_reset.emit()
	assert_eq(_results.size(), 1, "the switch stopped the action, and the view heard it")
	var stats: PlayStatsData = new_save.stats
	assert_eq(stats.adventures_won + stats.adventures_lost + stats.adventures_timed_out, 0, "an adventure that never started did not end in the new save")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The stats of the save this test runs on (before_each binds a fresh one).
func _stats() -> PlayStatsData:
	return PersistenceManager.save_game_data.stats

## Gives the player `health` Health, the rest of the vitals known ones. They are
## put back after the test.
func _set_player_health(health: float) -> void:
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	PlayerManager.vitals_manager.current_health = health

## Puts the view in the middle of a run that was never started on a map: its data
## is the Shallow Woods action, and the run's timer has `time_left` seconds to go.
func _begin_a_run_without_a_map(time_left: float) -> void:
	_view.current_action_data = ADVENTURE_ACTION
	_view.get_run_timer().start(time_left)

## Starts the Shallow Woods adventure the way the zone does once the start's
## zoom ends, with the given time limit.
func _start_adventure(time_limit_seconds: int) -> void:
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	action.time_limit_seconds = time_limit_seconds
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action)

func _boss_choice(failure_effect: EffectData) -> CombatChoice:
	var choice := CombatChoice.new()
	choice.is_boss = true
	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	choice.enemy_pool = pool
	var failure_effects: Array[EffectData] = [failure_effect]
	choice.failure_effects = failure_effects
	return choice

class RecordingEffect extends EffectData:
	var calls: int = 0
	func process() -> void:
		calls += 1
	func _to_string() -> String:
		return "RecordingEffect(calls=%d)" % calls
