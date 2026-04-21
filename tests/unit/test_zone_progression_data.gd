extends GutTest

func test_training_tick_progress_defaults_to_empty_dict() -> void:
	var zp := ZoneProgressionData.new()
	assert_true(zp.training_tick_progress.is_empty(), "training_tick_progress should default to empty")

func test_training_tick_progress_accepts_string_int_pairs() -> void:
	var zp := ZoneProgressionData.new()
	zp.training_tick_progress["aura_well_training"] = 42
	assert_eq(zp.training_tick_progress["aura_well_training"], 42)

func test_training_tick_progress_persists_via_resource_save_load() -> void:
	var zp := ZoneProgressionData.new()
	zp.zone_id = "SpiritValley"
	zp.training_tick_progress["aura_well_training"] = 7
	zp.training_tick_progress["other_training"] = 99

	var tmp_path: String = "user://__test_zone_progression.tres"
	ResourceSaver.save(zp, tmp_path)
	var loaded: ZoneProgressionData = ResourceLoader.load(tmp_path, "ZoneProgressionData", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.training_tick_progress["aura_well_training"], 7)
	assert_eq(loaded.training_tick_progress["other_training"], 99)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

#-----------------------------------------------------------------------------
# ZoneManager.get_training_ticks / increment_training_ticks
#-----------------------------------------------------------------------------

var _original_live_save: SaveGameData
var _save_data: SaveGameData

func before_each() -> void:
	_original_live_save = ZoneManager.live_save_data
	_save_data = SaveGameData.new()
	ZoneManager.live_save_data = _save_data

func after_each() -> void:
	ZoneManager.live_save_data = _original_live_save

func test_get_training_ticks_returns_zero_for_unseen_action() -> void:
	assert_eq(ZoneManager.get_training_ticks("unknown_action", "SpiritValley"), 0)

func test_increment_training_ticks_initializes_from_zero() -> void:
	var total: int = ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	assert_eq(total, 1)
	assert_eq(ZoneManager.get_training_ticks("aura_well_training", "SpiritValley"), 1)

func test_increment_training_ticks_accumulates_across_calls() -> void:
	ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley")
	var total: int = ZoneManager.increment_training_ticks("aura_well_training", "SpiritValley", 3)
	assert_eq(total, 5)

func test_increment_training_ticks_independent_per_action() -> void:
	ZoneManager.increment_training_ticks("a", "SpiritValley", 2)
	ZoneManager.increment_training_ticks("b", "SpiritValley", 7)
	assert_eq(ZoneManager.get_training_ticks("a", "SpiritValley"), 2)
	assert_eq(ZoneManager.get_training_ticks("b", "SpiritValley"), 7)
