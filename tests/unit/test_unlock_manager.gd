extends GutTest

## Unit tests for UnlockManager.force_unlock_condition (dev-only wrapper).

var _save_data: SaveGameData

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.unlock_progression = UnlockProgressionData.new()
	UnlockManager.live_save_data = _save_data

func test_force_unlock_condition_adds_id() -> void:
	UnlockManager.force_unlock_condition("dev_test_cond")
	assert_true(
		"dev_test_cond" in _save_data.unlock_progression.unlocked_condition_ids,
		"force_unlock_condition should add the id to unlocked_condition_ids"
	)

func test_force_unlock_condition_is_idempotent() -> void:
	UnlockManager.force_unlock_condition("dev_test_cond")
	UnlockManager.force_unlock_condition("dev_test_cond")
	var count: int = 0
	for id: String in _save_data.unlock_progression.unlocked_condition_ids:
		if id == "dev_test_cond":
			count += 1
	assert_eq(count, 1, "calling twice should not add duplicate entries")

func test_force_unlock_condition_emits_signal() -> void:
	watch_signals(UnlockManager)
	UnlockManager.force_unlock_condition("dev_test_cond")
	assert_signal_emitted_with_parameters(
		UnlockManager,
		"condition_unlocked",
		["dev_test_cond"]
	)
