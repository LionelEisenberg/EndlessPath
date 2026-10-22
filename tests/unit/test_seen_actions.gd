extends GutTest

## Unit tests for the seen-action record behind the activity cards' NEW tag
## (ZoneManager.mark_action_seen / is_action_seen, SaveGameData.seen_action_ids).
## The first time a save is initialised, every action already available counts
## as seen, so an existing save does not light NEW on every card; that pass
## runs once per save.

const FORAGING_ID: String = "sprint_forest_foraging_action"
const CYCLING_ID: String = "wilderness_cycling_action"
const FIRST_DIALOGUE_ID: String = "celestial_intervener_dialogue_1"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_load_save(SaveGameData.new())

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _load_save(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# MARKING
#-----------------------------------------------------------------------------

func test_mark_then_is_seen() -> void:
	assert_false(ZoneManager.is_action_seen(FORAGING_ID), "foraging is locked on a fresh save, so unseen")
	ZoneManager.mark_action_seen(FORAGING_ID)
	assert_true(ZoneManager.is_action_seen(FORAGING_ID))

func test_mark_twice_stores_once() -> void:
	ZoneManager.mark_action_seen(FORAGING_ID)
	ZoneManager.mark_action_seen(FORAGING_ID)
	assert_eq(PersistenceManager.save_game_data.seen_action_ids.count(FORAGING_ID), 1)

#-----------------------------------------------------------------------------
# FIRST INITIALISATION
#-----------------------------------------------------------------------------

func test_first_init_marks_available_actions_seen() -> void:
	var save := SaveGameData.new()
	save.unlock_progression.unlocked_condition_ids.append(FIRST_DIALOGUE_ID)
	_load_save(save)
	assert_true(ZoneManager.is_action_seen(CYCLING_ID), "cycling was available when the save was first initialised")
	assert_true(ZoneManager.is_action_seen(FIRST_DIALOGUE_ID))
	assert_false(ZoneManager.is_action_seen(FORAGING_ID), "foraging was still locked")
	assert_true(save.seen_actions_initialized)

func test_fresh_save_init_marks_only_the_first_dialogue() -> void:
	assert_eq(PersistenceManager.save_game_data.seen_action_ids, [FIRST_DIALOGUE_ID] as Array[String])
	assert_true(PersistenceManager.save_game_data.seen_actions_initialized)

func test_init_runs_once() -> void:
	UnlockManager.force_unlock_condition("q_fill_core_completed")
	PersistenceManager.save_data_reset.emit()
	assert_true(ZoneManager.get_available_actions("SpiritValley").any(
		func(action: ZoneActionData) -> bool: return action.action_id == FORAGING_ID),
		"foraging is available after the unlock, so a second pass would have marked it")
	assert_false(ZoneManager.is_action_seen(FORAGING_ID), "an action unlocked after the first pass stays NEW")
