extends GutTest

## Integration tests for the Tribulation as a Spirit Valley action. The card
## appears when Core Density reaches 100. ActionManager refuses the action below
## that and starts it at 100, stopping it hands the zone back to its idle action,
## a pass (the breakthrough) hides the card for good, and a failure (five levels
## lost) keeps the card but leaves it refused until the core is full again.
##
## The board is not here: these drive the flow through ActionManager and
## CultivationManager, the way the board will. Every test runs on a fresh save
## that all the managers are re-bound to, with the real Foundation and Copper
## stages. The original save goes back in after_each(), once nothing runs.

const Stage := CultivationManager.AdvancementStage

const ZONE_ID: String = "SpiritValley"
const TRIBULATION_ID: String = "spirit_valley_tribulation"
const FORAGING_ID: String = "sprint_forest_foraging_action"

## The condition that reveals the Tribulation's card.
const FULL_CORE_CONDITION: String = "core_density_full"
## The event whose unlock condition opens Spring Forest Foraging.
const FORAGING_EVENT: String = "q_fill_core_completed"

var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the managers back to the original save resumes the idle action it
	# left off with: stop that one too, so no timer runs on into the next file.
	_stop_everything()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Never leave an action running for the next test. Stopping a session action
## can resume the idle one, so stop until nothing is left.
func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## The Spirit Valley action, as the card and the board get it.
func _tribulation() -> TribulationActionData:
	return ZoneManager.get_action_by_id(TRIBULATION_ID) as TribulationActionData

## Fills the core the way play does: the last level is earned with XP, so the
## level-up reaches the cap, announces the full core and runs the unlock check.
func _fill_core() -> void:
	PersistenceManager.save_game_data.core_density_level = 99.0
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())

## Unlocks Spring Forest Foraging. It is the zone's first idle action, so it
## starts at once.
func _run_foraging() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs")

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## The ids of the actions Spirit Valley offers now, in list order.
func _available_ids() -> Array[String]:
	var ids: Array[String] = []
	for action: ZoneActionData in ZoneManager.get_available_actions(ZONE_ID):
		ids.append(action.action_id)
	return ids

#-----------------------------------------------------------------------------
# THE CARD APPEARS
#-----------------------------------------------------------------------------

func test_reaching_one_hundred_reveals_the_card() -> void:
	assert_does_not_have(_available_ids(), TRIBULATION_ID, "a core short of 100 hides the card")
	_fill_core()
	assert_true(UnlockManager.is_condition_unlocked(FULL_CORE_CONDITION), "the level-up to 100 unlocks the condition")
	assert_has(_available_ids(), TRIBULATION_ID, "and the card shows")

#-----------------------------------------------------------------------------
# STARTING THE TRIAL
#-----------------------------------------------------------------------------

func test_select_refuses_below_one_hundred() -> void:
	# The card stays listed after a failure (its condition is latched), so a click
	# on it with the core short must not stop what runs.
	_run_foraging()
	UnlockManager.force_unlock_condition(FULL_CORE_CONDITION)
	PersistenceManager.save_game_data.core_density_level = 95.0
	watch_signals(ActionManager)
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), FORAGING_ID, "the refused click leaves the current action running")
	assert_signal_not_emitted(ActionManager, "start_tribulation")
	assert_signal_not_emitted(ActionManager, "stop_foraging", "and nothing was stopped")

func test_select_at_one_hundred_starts_the_trial() -> void:
	_fill_core()
	var action: TribulationActionData = _tribulation()
	watch_signals(ActionManager)
	ActionManager.select_action(action)
	assert_signal_emitted_with_parameters(ActionManager, "start_tribulation", [action])
	assert_eq(ActionManager.get_current_action(), action, "the trial stays current until something stops it")

func test_stopping_resumes_the_idle_action() -> void:
	_run_foraging()
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial replaced foraging")
	watch_signals(ActionManager)
	ActionManager.stop_action(false)
	assert_signal_emit_count(ActionManager, "stop_tribulation", 1)
	assert_eq(_current_id(), FORAGING_ID, "leaving the trial resumes foraging, like closing the shop")

#-----------------------------------------------------------------------------
# THE RESULT
#-----------------------------------------------------------------------------

func test_a_pass_moves_to_copper_and_hides_the_card() -> void:
	_fill_core()
	assert_has(_available_ids(), TRIBULATION_ID, "precondition: the full core lists the card")
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial runs")
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: Foundation leads to a next stage")
	ActionManager.stop_action(true)
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER)
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "Copper starts at level 0")
	assert_does_not_have(_available_ids(), TRIBULATION_ID, "a passed Tribulation is not offered again")

func test_a_failure_costs_five_levels_and_keeps_the_card() -> void:
	_fill_core()
	ActionManager.select_action(_tribulation())
	assert_eq(_current_id(), TRIBULATION_ID, "precondition: the trial runs")
	CultivationManager.lose_core_density_levels(5)
	ActionManager.stop_action(false)
	assert_eq(CultivationManager.get_core_density_level(), 95.0, "the failure cost five levels")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION, "and the stage stays")
	assert_has(_available_ids(), TRIBULATION_ID, "the card is still offered: its condition is latched")
	watch_signals(ActionManager)
	ActionManager.select_action(_tribulation())
	assert_signal_not_emitted(ActionManager, "start_tribulation")
	assert_null(ActionManager.get_current_action(), "a second try is refused until the core is full again")

#-----------------------------------------------------------------------------
# THE ACTION'S TWO QUESTIONS
#-----------------------------------------------------------------------------

## Copper's core fills at 100 as well, but this trial leads out of Foundation.
func test_a_full_copper_core_cannot_face_the_foundation_trial() -> void:
	_fill_core()
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: Foundation leads to a next stage")
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: Copper's core is full")
	assert_false(_tribulation().can_attempt(), "the stage is past the trial's")
	watch_signals(ActionManager)
	ActionManager.select_action(_tribulation())
	assert_signal_not_emitted(ActionManager, "start_tribulation")
	assert_null(ActionManager.get_current_action())

func test_the_trial_is_passed_from_its_target_stage_on() -> void:
	var action: TribulationActionData = _tribulation()
	assert_false(action.is_passed(), "Foundation has not passed it")
	for stage: Stage in [Stage.COPPER, Stage.IRON]:
		PersistenceManager.save_game_data.current_advancement_stage = stage
		assert_true(action.is_passed(), "stage %s is at or past the trial's target" % Stage.find_key(stage))

func test_an_action_without_a_tribulation_is_never_passed_or_startable() -> void:
	var action := TribulationActionData.new()
	assert_null(action.tribulation, "precondition: nothing to face")
	assert_false(action.is_passed())
	_fill_core()
	assert_false(action.can_attempt(), "a full core is not enough without a trial to face")
