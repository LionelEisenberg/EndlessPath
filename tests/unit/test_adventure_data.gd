extends GutTest

## Covers AdventureData validate() — each error branch + the happy path.

func _make_anchor(id: String, min_dist: int = 0, min_fillers: int = 0) -> AdventureEncounter:
	var enc := AdventureEncounter.new()
	enc.encounter_id = id
	enc.placement = AdventureEncounter.Placement.ANCHOR
	enc.min_distance_from_origin = min_dist
	enc.min_fillers_on_path = min_fillers
	return enc

func _make_filler(id: String) -> AdventureEncounter:
	var enc := AdventureEncounter.new()
	enc.encounter_id = id
	enc.placement = AdventureEncounter.Placement.FILLER
	return enc

func _make_quota(enc: AdventureEncounter, count: int) -> EncounterQuota:
	var q := EncounterQuota.new()
	q.encounter = enc
	q.count = count
	return q

func _make_valid_data() -> AdventureData:
	var data := AdventureData.new()
	data.max_distance_from_start = 6
	data.sparse_factor = 2
	data.boss_encounter = _make_anchor("boss", 5)
	data.encounter_quotas = [
		_make_quota(_make_anchor("rest", 3, 1), 1),
		_make_quota(_make_filler("combat"), 3),
	]
	return data

func test_valid_config_returns_empty_errors() -> void:
	var data := _make_valid_data()
	assert_eq(data.validate(), [], "well-formed config should produce no errors")

func test_missing_boss_is_error() -> void:
	var data := _make_valid_data()
	data.boss_encounter = null
	var errors: Array[String] = data.validate()
	assert_true(errors.size() >= 1)
	assert_string_contains(errors[0], "boss_encounter")

func test_boss_without_anchor_placement_is_error() -> void:
	var data := _make_valid_data()
	data.boss_encounter.placement = AdventureEncounter.Placement.FILLER
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("ANCHOR")))

func test_null_encounter_in_quota_is_error() -> void:
	var data := _make_valid_data()
	var bad := EncounterQuota.new()
	bad.count = 1
	data.encounter_quotas.append(bad)
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("null encounter")))

func test_non_positive_count_is_error() -> void:
	var data := _make_valid_data()
	data.encounter_quotas[0].count = 0
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("non-positive count")))

func test_min_distance_exceeds_max_is_error() -> void:
	var data := _make_valid_data()
	data.encounter_quotas[0].encounter.min_distance_from_origin = 10 # > max_distance_from_start = 6
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("exceeds max_distance_from_start")))

func test_min_fillers_without_filler_quota_is_error() -> void:
	var data := AdventureData.new()
	data.max_distance_from_start = 6
	data.sparse_factor = 2
	data.boss_encounter = _make_anchor("boss", 5)
	# Anchor requires fillers on path, but no FILLER quota present.
	data.encounter_quotas = [
		_make_quota(_make_anchor("rest_needs_filler", 3, 1), 1),
	]
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("no FILLER entries")))

func test_filler_quota_below_required_count_is_error() -> void:
	var data := AdventureData.new()
	data.max_distance_from_start = 6
	data.sparse_factor = 2
	data.boss_encounter = _make_anchor("boss", 5)
	# Rest requires 3 fillers on path; filler quota totals 2.
	data.encounter_quotas = [
		_make_quota(_make_anchor("rest_requires_3", 3, 3), 1),
		_make_quota(_make_filler("combat"), 2),
	]
	var errors: Array[String] = data.validate()
	assert_true(errors.any(func(e): return e.contains("only")))

func test_shipped_adventures_validate() -> void:
	var dir := DirAccess.open("res://resources/adventure/data/")
	assert_not_null(dir, "res://resources/adventure/data/ should exist")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var any_loaded := false
	while file_name != "":
		if file_name.ends_with(".tres"):
			any_loaded = true
			var data: AdventureData = load("res://resources/adventure/data/" + file_name)
			assert_not_null(data, "failed to load %s" % file_name)
			var errors: Array[String] = data.validate()
			assert_eq(errors, [], "%s produced errors: %s" % [file_name, errors])
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_true(any_loaded, "expected at least one adventure .tres to exist")
