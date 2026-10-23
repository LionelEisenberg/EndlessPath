extends GutTest

## How an adventure run ends and what the end card is told. Drives the real
## AdventureView scene through ActionManager, the same way the zone starts a run.

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")

var _view: AdventureView
var _results: Array[AdventureResultData] = []

func before_each() -> void:
	# Ending a run resumes the zone's idle action, which writes to the save.
	# Run on a fresh one, never the developer's save loaded in memory.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_results.clear()
	_view = AdventureViewScene.instantiate()
	add_child_autofree(_view)
	# The project's hex layer script overrides _ready() without super(), so the
	# addon only sets up its cube<->map conversions when the shared TileSet
	# emits `changed`, which happens once after it first loads. Re-emit it so
	# every fresh view in this file gets initialised map layers.
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

func test_timeout_reports_time_ran_out() -> void:
	_start_adventure(1)
	await wait_for_signal(_view.adventure_completed, 3.0)
	assert_eq(_results.size(), 1, "the adventure ends once")
	if _results.size() == 1:
		assert_eq(_results[0].defeat_reason, "Time ran out")

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

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Starts the Shallow Woods adventure the way the zone does once the Madra
## drain finishes, with the given time limit.
func _start_adventure(time_limit_seconds: int) -> void:
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	action.time_limit_seconds = time_limit_seconds
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action, 50.0)

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
