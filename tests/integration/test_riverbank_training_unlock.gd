extends GutTest

## Riverbank Training opens when First Steps Out ends, at NPC 3's talk, or at
## once when a fight is lost: a lost fight sends the player home at 0 Health, and
## the river is the only home source of Health. A won fight, a fight the run's
## stop cuts short, and a run with no fight open nothing. Drives the real
## AdventureView scene through ActionManager, the way the zone starts a run.

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const ENEMY_DEFEATED: String = "q_first_steps_enemy_defeated"
const RIVERBANK_ACTION: String = "riverbank_training_action"
const SPIRIT_VALLEY_ID: String = "SpiritValley"

var _view: AdventureView

func before_each() -> void:
	# Ending a run resumes the zone's idle action, which writes to the save.
	# Run on a fresh one, never the developer's save loaded in memory.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_view = AdventureViewScene.instantiate()
	add_child_autofree(_view)
	await get_tree().process_frame

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

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_only_a_lost_fight_opens_riverbank_training() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a won fight", "end": "win", "opens": false, "enemy_defeated": true},
		{"name": "a lost fight", "end": "loss", "opens": true, "enemy_defeated": false},
		{"name": "a fight the run's stop cuts short", "end": "stop", "opens": false, "enemy_defeated": false},
	]
	for case: Dictionary in cases:
		_use_fresh_save()
		_start_adventure()
		_view._on_start_combat(_fight())
		match case.end:
			"win":
				# Takes the enemy's Health, so AdventureCombat ends the fight as in play.
				_view.force_win_combat()
				_view.stop_adventure()
			"loss":
				_view.combat.trigger_combat_end.emit(false, 0)
			"stop":
				_view.stop_adventure()
		assert_eq(_is_riverbank_open(), case.opens, "%s: Riverbank Training is open" % case.name)
		assert_eq(EventManager.has_event_triggered(ENEMY_DEFEATED), case.enemy_defeated, "%s: only a win counts as the enemy defeated" % case.name)

func test_a_run_with_no_fight_keeps_riverbank_training_shut() -> void:
	_start_adventure()
	_view.stop_adventure()
	assert_false(_is_riverbank_open(), "Riverbank Training stays shut")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Binds a fresh save, leaving the running action, if any, stopped.
func _use_fresh_save() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

## Starts the Shallow Woods adventure the way the zone does once the start's
## zoom ends.
func _start_adventure() -> void:
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action)

## A fight against one Amorphous Spirit, remembered by the tilemap as picking
## its card does.
func _fight() -> CombatChoice:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	choice.enemy_pool = pool
	_view.adventure_tilemap._current_combat_choice = choice
	return choice

func _is_riverbank_open() -> bool:
	for action: ZoneActionData in ZoneManager.get_available_actions(SPIRIT_VALLEY_ID):
		if action.action_id == RIVERBANK_ACTION:
			return true
	return false
