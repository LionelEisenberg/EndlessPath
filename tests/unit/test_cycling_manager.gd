extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _technique_a: CyclingTechniqueData
var _foundation: CyclingTechniqueData
## CyclingManager's real state, given back after each test so later files see
## the real technique catalog.
var _saved_live_save_data: SaveGameData = null
var _saved_techniques_by_id: Dictionary = {}

func _create_test_technique(technique_id: String, technique_name: String) -> CyclingTechniqueData:
	var t := CyclingTechniqueData.new()
	t.id = technique_id
	t.technique_name = technique_name
	return t

func before_each() -> void:
	_saved_live_save_data = CyclingManager._live_save_data
	_saved_techniques_by_id = CyclingManager._techniques_by_id
	_save_data = SaveGameData.new()
	_foundation = _create_test_technique("foundation_technique", "Foundation Technique")
	_technique_a = _create_test_technique("tech_a", "Technique A")
	CyclingManager._live_save_data = _save_data
	CyclingManager._techniques_by_id = {
		"foundation_technique": _foundation,
		"tech_a": _technique_a,
	}

func after_each() -> void:
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()
	CyclingManager._live_save_data = _saved_live_save_data
	CyclingManager._techniques_by_id = _saved_techniques_by_id

# ----- Default state -----

func test_default_save_has_foundation_unlocked() -> void:
	assert_true(CyclingManager.is_technique_unlocked("foundation_technique"),
		"foundation_technique should be unlocked by default")

func test_default_equipped_is_foundation() -> void:
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	assert_not_null(equipped, "should have an equipped technique by default")
	assert_eq(equipped.id, "foundation_technique", "default equipped should be foundation")

# ----- get_unlocked_techniques -----

func test_get_unlocked_techniques_returns_matching_resources() -> void:
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked technique by default")
	assert_eq(unlocked[0].id, "foundation_technique", "should be foundation")

func test_get_unlocked_techniques_skips_unknown_ids() -> void:
	_save_data.unlocked_cycling_technique_ids.append("nonexistent_technique")
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 1, "should skip IDs not in catalog")

# ----- unlock_technique -----

func test_unlock_technique_adds_to_list() -> void:
	CyclingManager.unlock_technique("tech_a")
	assert_true(CyclingManager.is_technique_unlocked("tech_a"), "tech_a should be unlocked")
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	assert_eq(unlocked.size(), 2, "should now have 2 unlocked techniques")

func test_unlock_technique_is_idempotent() -> void:
	CyclingManager.unlock_technique("tech_a")
	CyclingManager.unlock_technique("tech_a")
	var count: int = _save_data.unlocked_cycling_technique_ids.count("tech_a")
	assert_eq(count, 1, "should not duplicate technique in save data")

func test_unlock_technique_emits_signal() -> void:
	watch_signals(CyclingManager)
	CyclingManager.unlock_technique("tech_a")
	assert_signal_emitted_with_parameters(CyclingManager, "technique_unlocked", [_technique_a])

func test_unlock_technique_unknown_id_pushes_error() -> void:
	CyclingManager.unlock_technique("nonexistent")
	assert_push_error("unknown technique_id")

func test_unlock_already_unlocked_does_not_emit_signal() -> void:
	watch_signals(CyclingManager)
	CyclingManager.unlock_technique("foundation_technique")
	assert_signal_not_emitted(CyclingManager, "technique_unlocked")

# ----- equip_technique -----

func test_equip_technique_changes_equipped() -> void:
	CyclingManager.unlock_technique("tech_a")
	CyclingManager.equip_technique("tech_a")
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	assert_eq(equipped.id, "tech_a", "equipped should be tech_a")

func test_equip_technique_updates_save_data() -> void:
	CyclingManager.unlock_technique("tech_a")
	CyclingManager.equip_technique("tech_a")
	assert_eq(_save_data.equipped_cycling_technique_id, "tech_a",
		"save data should store the equipped technique id")

func test_equip_technique_emits_signal() -> void:
	CyclingManager.unlock_technique("tech_a")
	watch_signals(CyclingManager)
	CyclingManager.equip_technique("tech_a")
	assert_signal_emitted_with_parameters(CyclingManager, "equipped_technique_changed", [_technique_a])

func test_equip_technique_unknown_id_pushes_error() -> void:
	CyclingManager.equip_technique("nonexistent")
	assert_push_error("unknown technique_id")

func test_equip_locked_technique_pushes_error() -> void:
	CyclingManager.equip_technique("tech_a")
	assert_push_error("cannot equip locked technique")

# ----- is_technique_unlocked -----

func test_is_technique_unlocked_true_for_unlocked() -> void:
	assert_true(CyclingManager.is_technique_unlocked("foundation_technique"))

func test_is_technique_unlocked_false_for_locked() -> void:
	assert_false(CyclingManager.is_technique_unlocked("tech_a"))

# ----- has_unequipped_unlocks -----

func test_has_unequipped_unlocks_false_when_none_unlocked() -> void:
	_save_data.unlocked_cycling_technique_ids = []
	_save_data.equipped_cycling_technique_id = ""
	assert_false(
		CyclingManager.has_unequipped_unlocks(),
		"No unlocks -> no badge"
	)


func test_has_unequipped_unlocks_true_when_unlock_not_equipped() -> void:
	# Default save has foundation_technique unlocked and equipped.
	# Unlock tech_a without equipping it -> badge should show.
	CyclingManager.unlock_technique("tech_a")
	assert_true(
		CyclingManager.has_unequipped_unlocks(),
		"Unlocked but not equipped -> badge should show"
	)


func test_has_unequipped_unlocks_false_when_equipped_matches_unlock() -> void:
	# Only foundation_technique unlocked, and it is the equipped technique.
	assert_false(
		CyclingManager.has_unequipped_unlocks(),
		"Equipped the only unlock -> no badge"
	)


func test_has_unequipped_unlocks_true_with_multiple_unlocks_one_equipped() -> void:
	# Foundation equipped (default), unlock tech_a but leave foundation equipped.
	CyclingManager.unlock_technique("tech_a")
	assert_true(
		CyclingManager.has_unequipped_unlocks(),
		"One unlock equipped, another unlocked -> badge should show"
	)

# ----- Seen techniques -----

func test_mark_seen_then_is_seen() -> void:
	CyclingManager.mark_technique_seen("tech_a")
	assert_true(CyclingManager.is_technique_seen("tech_a"), "marking a technique seen should record it")

func test_mark_seen_stores_once() -> void:
	CyclingManager.mark_technique_seen("tech_a")
	CyclingManager.mark_technique_seen("tech_a")
	var count: int = _save_data.seen_cycling_technique_ids.count("tech_a")
	assert_eq(count, 1, "should not duplicate technique in the seen list")

func test_mark_seen_ignores_empty_id() -> void:
	CyclingManager.mark_technique_seen("")
	assert_true(_save_data.seen_cycling_technique_ids.is_empty(), "an empty id is not a technique")

func test_empty_id_is_never_seen() -> void:
	_save_data.equipped_cycling_technique_id = ""
	assert_false(CyclingManager.is_technique_seen(""), "an empty id is not a technique, even with nothing equipped")

func test_equipped_counts_as_seen() -> void:
	CyclingManager.unlock_technique("tech_a")
	CyclingManager.equip_technique("tech_a")
	assert_true(CyclingManager.is_technique_seen("tech_a"),
		"the technique in use counts as seen even though it was never marked")

func test_unlocking_does_not_mark_seen() -> void:
	CyclingManager.unlock_technique("tech_a")
	assert_false(CyclingManager.is_technique_seen("tech_a"),
		"an unlocked technique stays NEW until it is seen or equipped")

# ----- First initialisation of the seen techniques -----

func test_first_init_marks_unlocked_techniques_seen() -> void:
	_save_data.unlocked_cycling_technique_ids.append("tech_a")
	CyclingManager._initialize_seen_techniques()
	assert_true(CyclingManager.is_technique_seen("tech_a"),
		"tech_a was unlocked when the save was first initialised")
	assert_true(_save_data.seen_cycling_techniques_initialized, "the first pass should be recorded in the save")

func test_init_runs_once() -> void:
	CyclingManager._initialize_seen_techniques()
	_save_data.unlocked_cycling_technique_ids.append("tech_a")
	CyclingManager._initialize_seen_techniques()
	assert_false(CyclingManager.is_technique_seen("tech_a"),
		"a technique unlocked after the first pass should stay NEW")

func test_save_reset_runs_the_first_pass_on_the_new_save() -> void:
	var new_save := SaveGameData.new()
	new_save.unlocked_cycling_technique_ids.append("tech_a")
	var persistence_save: SaveGameData = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = new_save
	CyclingManager._on_save_data_reset()
	PersistenceManager.save_game_data = persistence_save
	assert_true(new_save.seen_cycling_techniques_initialized, "the handler should run the first pass")
	assert_true(new_save.seen_cycling_technique_ids.has("tech_a"), "the new save's unlocked techniques should be seen")

# ----- Cycle session snapshot -----

func test_cycle_snapshot() -> void:
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(6.0, 10.0)
	assert_true(CyclingManager.is_cycle_running(), "a started session should be running")
	assert_true(is_equal_approx(CyclingManager.get_cycle_progress(), 0.4), "6 s of a 15 s cycle is 0.4")
	assert_eq(CyclingManager.get_cycle_elapsed(), 6.0, "elapsed should be what the last update gave")
	assert_eq(CyclingManager.get_cycle_duration(), 15.0, "duration should be what the start gave")
	assert_eq(CyclingManager.get_madra_rate(), 10.0, "rate should be what the last update gave")
	CyclingManager.end_cycle_session()
	assert_false(CyclingManager.is_cycle_running(), "an ended session should not be running")
	assert_eq(CyclingManager.get_cycle_progress(), 0.0, "progress should be 0 when no cycle runs")
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "rate should be 0 when no cycle runs")

func test_progress_is_clamped_to_one() -> void:
	CyclingManager.start_cycle_session(15.0)
	# A frame hitch can carry elapsed past the end before the cycle is ended.
	CyclingManager.update_cycle_session(16.0, 0.0)
	assert_eq(CyclingManager.get_cycle_progress(), 1.0, "progress should not pass 1")

func test_update_without_a_session_is_ignored() -> void:
	watch_signals(CyclingManager)
	CyclingManager.update_cycle_session(6.0, 10.0)
	assert_false(CyclingManager.is_cycle_running(), "an update should not start a session")
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "no Madra is drawn while no cycle runs")
	assert_signal_not_emitted(CyclingManager, "madra_rate_changed")

func test_starting_again_replaces_the_session() -> void:
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(6.0, 10.0)
	watch_signals(CyclingManager)
	CyclingManager.start_cycle_session(8.0)
	assert_eq(CyclingManager.get_cycle_elapsed(), 0.0, "the new session starts from 0 s")
	assert_eq(CyclingManager.get_cycle_duration(), 8.0, "the new session has its own duration")
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "the old session's rate is dropped")
	assert_signal_emitted_with_parameters(CyclingManager, "madra_rate_changed", [0.0])

# ----- madra_rate_changed -----

func test_rate_signal_fires_on_tenths() -> void:
	watch_signals(CyclingManager)
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(1.0, 13.3)
	CyclingManager.update_cycle_session(2.0, 13.32)
	CyclingManager.end_cycle_session()
	assert_signal_emit_count(CyclingManager, "madra_rate_changed", 2)
	# The last emission is the drop to 0 when the session ends.
	assert_signal_emitted_with_parameters(CyclingManager, "madra_rate_changed", [0.0])

func test_rate_signal_carries_the_new_rate() -> void:
	watch_signals(CyclingManager)
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(1.0, 13.3)
	assert_signal_emitted_with_parameters(CyclingManager, "madra_rate_changed", [13.3])

func test_rate_signal_stays_quiet_when_no_madra_is_drawn() -> void:
	watch_signals(CyclingManager)
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(5.0, 0.0)
	CyclingManager.end_cycle_session()
	assert_signal_not_emitted(CyclingManager, "madra_rate_changed")

func test_rate_signal_announces_a_drop_to_zero_once() -> void:
	watch_signals(CyclingManager)
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(1.0, 13.3)
	# The Madra cap is reached: the ball draws nothing for the rest of the cycle.
	CyclingManager.update_cycle_session(2.0, 0.0)
	CyclingManager.end_cycle_session()
	assert_signal_emit_count(CyclingManager, "madra_rate_changed", 2)
