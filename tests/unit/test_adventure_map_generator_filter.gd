extends GutTest

## Verifies that the map generator filters special_encounter_pool entries by
## their unlock_conditions Dictionary before selecting one for each special tile.

const TEST_EVENT: String = "test_filter_event"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_gated_encounter() -> AdventureEncounter:
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = TEST_EVENT
	var enc := AdventureEncounter.new()
	enc.encounter_id = "gated"
	# Require the event to have fired.
	enc.unlock_conditions = {cond: true}
	return enc

func _make_open_encounter() -> AdventureEncounter:
	var enc := AdventureEncounter.new()
	enc.encounter_id = "open"
	return enc

func test_filter_drops_gated_encounters_when_unmet() -> void:
	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()

	var pool: Array = [_make_gated_encounter(), _make_open_encounter()]
	var eligible: Array = generator._build_eligible_special_pool(pool)

	assert_eq(eligible.size(), 1, "only the open encounter should be eligible")
	assert_eq(eligible[0].encounter_id, "open")
	generator.queue_free()

func test_filter_keeps_gated_encounters_when_met() -> void:
	EventManager.trigger_event(TEST_EVENT)

	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()

	var pool: Array = [_make_gated_encounter(), _make_open_encounter()]
	var eligible: Array = generator._build_eligible_special_pool(pool)

	assert_eq(eligible.size(), 2, "both encounters should be eligible once event fires")
	generator.queue_free()

func test_filter_respects_false_expected_value() -> void:
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = "never_fired_event"
	var enc := AdventureEncounter.new()
	enc.encounter_id = "requires_event_false"
	# Require the event to NOT have fired (expected bool = false).
	enc.unlock_conditions = {cond: false}

	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()

	var eligible: Array = generator._build_eligible_special_pool([enc])
	assert_eq(eligible.size(), 1, "encounter should be eligible when required-false event has not fired")

	EventManager.trigger_event("never_fired_event")
	var eligible_after: Array = generator._build_eligible_special_pool([enc])
	assert_eq(eligible_after.size(), 0, "encounter should be filtered out when required-false event fires")
	generator.queue_free()
