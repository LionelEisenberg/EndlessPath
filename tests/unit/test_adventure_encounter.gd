extends GutTest

## Covers new schema fields (Placement, min_distance_from_origin,
## min_fillers_on_path) and the is_eligible() helper.

const TEST_EVENT: String = "test_adv_encounter_event"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func test_defaults() -> void:
	var enc := AdventureEncounter.new()
	assert_eq(enc.placement, AdventureEncounter.Placement.FILLER, "placement defaults to FILLER")
	assert_eq(enc.min_distance_from_origin, 0, "min_distance_from_origin defaults to 0")
	assert_eq(enc.min_fillers_on_path, 0, "min_fillers_on_path defaults to 0")

func test_is_eligible_with_no_conditions() -> void:
	var enc := AdventureEncounter.new()
	assert_true(enc.is_eligible(), "encounter with no unlock_conditions is always eligible")

func test_is_eligible_blocks_when_event_required_but_not_fired() -> void:
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = TEST_EVENT
	var enc := AdventureEncounter.new()
	enc.unlock_conditions = {cond: true}
	assert_false(enc.is_eligible(), "encounter should be ineligible before event fires")

func test_is_eligible_passes_when_event_required_and_fired() -> void:
	EventManager.trigger_event(TEST_EVENT)
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = TEST_EVENT
	var enc := AdventureEncounter.new()
	enc.unlock_conditions = {cond: true}
	assert_true(enc.is_eligible(), "encounter should be eligible once event fires")

func test_is_eligible_respects_expected_false() -> void:
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = "never_fired_event_for_enc_test"
	var enc := AdventureEncounter.new()
	# Require the event to NOT have fired.
	enc.unlock_conditions = {cond: false}
	assert_true(enc.is_eligible(), "expected=false condition passes when event has not fired")

	EventManager.trigger_event("never_fired_event_for_enc_test")
	assert_false(enc.is_eligible(), "expected=false condition fails after event fires")
