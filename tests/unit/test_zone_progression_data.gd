extends GutTest

func test_training_tick_progress_defaults_to_empty_dict() -> void:
	var zp := ZoneProgressionData.new()
	assert_true(zp.training_tick_progress.is_empty(), "training_tick_progress should default to empty")

func test_training_tick_progress_accepts_string_int_pairs() -> void:
	var zp := ZoneProgressionData.new()
	zp.training_tick_progress["spirit_well_training"] = 42
	assert_eq(zp.training_tick_progress["spirit_well_training"], 42)

func test_training_tick_progress_persists_via_resource_save_load() -> void:
	var zp := ZoneProgressionData.new()
	zp.zone_id = "SpiritValley"
	zp.training_tick_progress["spirit_well_training"] = 7
	zp.training_tick_progress["other_training"] = 99

	var tmp_path: String = "user://__test_zone_progression.tres"
	ResourceSaver.save(zp, tmp_path)
	var loaded: ZoneProgressionData = ResourceLoader.load(tmp_path, "ZoneProgressionData", ResourceLoader.CACHE_MODE_IGNORE)

	assert_eq(loaded.training_tick_progress["spirit_well_training"], 7)
	assert_eq(loaded.training_tick_progress["other_training"], 99)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
