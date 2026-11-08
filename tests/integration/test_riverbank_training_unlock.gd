extends GutTest

## First Steps Out is the first adventure: however a run ends (a won fight, a
## lost one, a fight cut short, or no fight at all), its end completes the
## quest's first step and opens NPC 3's talk. The run itself opens nothing else:
## Riverbank Training waits for First Steps Out's end at that talk. Drives the
## real AdventureView scene through ActionManager, the way the zone starts a run.

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const ADVENTURE_ENDED: String = "q_first_steps_adventure_ended"
const NPC_2_TALKED: String = "celestial_intervener_dialogue_2"
const NPC_3_ACTION: String = "celestial_intervener_dialogue_3"
const RIVERBANK_ACTION: String = "riverbank_training_action"
const SPIRIT_VALLEY_ID: String = "SpiritValley"

var _view: AdventureView

func before_each() -> void:
	# Ending a run resumes the zone's idle action, which writes to the save.
	# Run on a fresh one, never the developer's save loaded in memory.
	_use_fresh_save()
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

## The run ends once in each case (adventure_completed, in the stop_adventure()
## call that fires the event), with the fight's edges (#138) played or cut.
func test_every_way_a_run_ends_opens_npc_3_and_not_the_river() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a won fight", "end": "win"},
		{"name": "a lost fight", "end": "loss"},
		{"name": "a fight the run's stop cuts short on its way in", "end": "stop"},
		{"name": "a fight the run's stop cuts short mid-fight", "end": "stop_live"},
		{"name": "no fight", "end": "no_fight"},
	]
	var ends: Array[int] = [0]
	_view.adventure_completed.connect(func(_result: AdventureResultData) -> void: ends[0] += 1)
	for case: Dictionary in cases:
		_use_fresh_save()
		EventManager.trigger_event(NPC_2_TALKED)
		ends[0] = 0
		_start_adventure()
		if case.end != "no_fight":
			_view._on_start_combat(_fight())
		match case.end:
			"win":
				# Takes the enemy's Health once both fighters have landed, so
				# AdventureCombat ends the fight as in play; the run stops in its close.
				_view.finish_fight_transition()
				_view.force_win_combat()
				_view.stop_adventure()
			"loss":
				_view.combat.trigger_combat_end.emit(false, 0)
				_view.finish_fight_transition()
			"stop_live":
				_view.finish_fight_transition()
				_view.stop_adventure()
			"stop", "no_fight":
				_view.stop_adventure()
		assert_eq(ends[0], 1, "%s: the run ends once" % case.name)
		assert_true(EventManager.has_event_triggered(ADVENTURE_ENDED), "%s: the first adventure is done" % case.name)
		assert_true(_is_available(NPC_3_ACTION), "%s: NPC 3's talk is open" % case.name)
		assert_false(_is_available(RIVERBANK_ACTION), "%s: Riverbank Training waits for the talk" % case.name)

## The adventure action is current while the start's zoom runs, before any run
## has started. A stop then ends no adventure.
func test_a_stop_before_the_run_starts_ends_no_adventure() -> void:
	_view.stop_adventure()
	assert_false(EventManager.has_event_triggered(ADVENTURE_ENDED))

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

func _is_available(action_id: String) -> bool:
	for action: ZoneActionData in ZoneManager.get_available_actions(SPIRIT_VALLEY_ID):
		if action.action_id == action_id:
			return true
	return false
