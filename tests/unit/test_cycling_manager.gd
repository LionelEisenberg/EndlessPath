extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _technique_a: CyclingTechniqueData
var _foundation: CyclingTechniqueData

func _create_test_technique(technique_id: String, technique_name: String) -> CyclingTechniqueData:
	var t := CyclingTechniqueData.new()
	t.id = technique_id
	t.technique_name = technique_name
	return t

func before_each() -> void:
	_save_data = SaveGameData.new()
	_foundation = _create_test_technique("foundation_technique", "Foundation Technique")
	_technique_a = _create_test_technique("tech_a", "Technique A")
	CyclingManager._live_save_data = _save_data
	CyclingManager._techniques_by_id = {
		"foundation_technique": _foundation,
		"tech_a": _technique_a,
	}

func after_each() -> void:
	CyclingManager._live_save_data = null
	CyclingManager._techniques_by_id = {}

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
