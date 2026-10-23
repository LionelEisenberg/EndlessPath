extends GutTest

## Unit tests for the seen-action record behind the activity cards' NEW tag
## (ZoneManager.mark_action_seen / is_action_seen, SaveGameData.seen_action_ids).
## The first time a save is initialised, every action already available counts
## as seen, so an existing save does not light NEW on every card; that pass
## runs once per save. A cycling technique unlocking lights the cycling card's
## NEW tag again (ZoneManager.mark_action_unseen).

const FORAGING_ID: String = "sprint_forest_foraging_action"
const CYCLING_ID: String = "wilderness_cycling_action"
const FIRST_DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
const MERCHANT_ID: String = "spirit_valley_merchant"

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

func test_mark_unseen_clears_seen() -> void:
	ZoneManager.mark_action_seen(FORAGING_ID)
	ZoneManager.mark_action_unseen(FORAGING_ID)
	assert_false(ZoneManager.is_action_seen(FORAGING_ID))

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
	# The merchant, not foraging: an idle action that unlocks starts on its own
	# (ActionManager), and starting an action marks it seen.
	UnlockManager.force_unlock_condition("merchant_discovered")
	PersistenceManager.save_data_reset.emit()
	assert_true(ZoneManager.get_available_actions("SpiritValley").any(
		func(action: ZoneActionData) -> bool: return action.action_id == MERCHANT_ID),
		"the merchant is available after the unlock, so a second pass would have marked it")
	assert_false(ZoneManager.is_action_seen(MERCHANT_ID), "an action unlocked after the first pass stays NEW")

#-----------------------------------------------------------------------------
# TECHNIQUE UNLOCKS
#-----------------------------------------------------------------------------

## Loads a save whose first pass counts the cycling card as seen, like a player
## who has played past the first dialogue.
func _load_save_with_cycling_seen() -> void:
	var save := SaveGameData.new()
	save.unlock_progression.unlocked_condition_ids.append(FIRST_DIALOGUE_ID)
	_load_save(save)

func test_technique_unlock_lights_the_cycling_card() -> void:
	_load_save_with_cycling_seen()
	assert_true(ZoneManager.is_action_seen(CYCLING_ID), "precondition: cycling was seen by the first pass")
	CyclingManager.unlock_technique("smooth_flow")
	assert_false(ZoneManager.is_action_seen(CYCLING_ID))

func test_technique_unlock_leaves_other_actions_seen() -> void:
	_load_save_with_cycling_seen()
	CyclingManager.unlock_technique("smooth_flow")
	assert_true(ZoneManager.is_action_seen(FIRST_DIALOGUE_ID), "only the cycling card lights up")

func test_opening_cycling_clears_it_again() -> void:
	_load_save_with_cycling_seen()
	CyclingManager.unlock_technique("smooth_flow")
	assert_false(ZoneManager.is_action_seen(CYCLING_ID), "precondition: the unlock lit the card")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_true(ZoneManager.is_action_seen(CYCLING_ID))
