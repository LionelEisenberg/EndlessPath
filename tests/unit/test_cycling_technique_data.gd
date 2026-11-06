extends GutTest

## Unit tests for the data the cycling view's technique drawers read: the Madra a
## cycle and a second of drawing pay at Spirit's multiplier, and the
## SaveGameData fields that remember which techniques the player has already
## seen.

const TMP_SAVE_PATH: String = "user://test_seen_techniques.tres"

#-----------------------------------------------------------------------------
# MADRA PER CYCLE AND PER SECOND
#-----------------------------------------------------------------------------

## A cycle pays base_madra_per_cycle times the multiplier, 1.0 when none is given.
func test_madra_per_cycle_at_a_multiplier() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 80.0
	var cases: Array[Dictionary] = [
		{"name": "no multiplier given", "multiplier": null, "expected": 80.0},
		{"name": "Spirit Lv 1", "multiplier": 1.0, "expected": 80.0},
		{"name": "Spirit 15", "multiplier": 1.5, "expected": 120.0},
		{"name": "Spirit Lv 10", "multiplier": 1.9, "expected": 152.0},
	]
	for case: Dictionary in cases:
		var madra: float = technique.get_madra_per_cycle() if case.multiplier == null else technique.get_madra_per_cycle(case.multiplier)
		assert_almost_eq(madra, case.expected, 0.0001, case.name)


func test_madra_per_second_spreads_the_cycles_madra_over_its_seconds() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 200.0
	technique.cycle_duration = 15.0
	assert_almost_eq(technique.get_madra_per_second(), 200.0 / 15.0, 0.0001)

func test_madra_per_second_follows_the_multiplier() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 80.0
	technique.cycle_duration = 15.0
	assert_almost_eq(technique.get_madra_per_second(1.9), 152.0 / 15.0, 0.0001)

func test_a_cycle_of_no_length_pays_no_madra_per_second() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 200.0
	technique.cycle_duration = 0.0
	assert_eq(technique.get_madra_per_second(), 0.0)

#-----------------------------------------------------------------------------
# SEEN TECHNIQUES IN THE SAVE
#-----------------------------------------------------------------------------

func test_reset_clears_seen_techniques() -> void:
	var data := SaveGameData.new()
	data.seen_cycling_technique_ids.append("smooth_flow")
	data.seen_cycling_techniques_initialized = true
	data.reset()
	assert_eq(data.seen_cycling_technique_ids, [] as Array[String], "reset forgets the seen techniques")
	assert_false(data.seen_cycling_techniques_initialized, "reset needs the first pass again")

func test_seen_techniques_survive_a_save() -> void:
	var data := SaveGameData.new()
	data.seen_cycling_technique_ids.append("smooth_flow")
	data.seen_cycling_technique_ids.append("torrential_flow")
	data.seen_cycling_techniques_initialized = true

	var save_error: Error = ResourceSaver.save(data, TMP_SAVE_PATH)
	var loaded: SaveGameData = null
	if save_error == OK:
		loaded = ResourceLoader.load(TMP_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData
	# The file has done its job; remove it before the asserts so no failure leaves it behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE_PATH))

	assert_eq(save_error, OK, "the save is written")
	assert_not_null(loaded, "the save loads back as a SaveGameData")
	if loaded == null:
		return
	assert_eq(loaded.seen_cycling_technique_ids, data.seen_cycling_technique_ids, "the seen techniques are saved")
	assert_true(loaded.seen_cycling_techniques_initialized, "the first-pass flag is saved")
