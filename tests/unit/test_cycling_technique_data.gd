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
# SPIRIT XP
#-----------------------------------------------------------------------------

## A second of following pays spirit_xp_per_cycle over cycle_duration.
func test_spirit_xp_per_second() -> void:
	var cases: Array[Dictionary] = [
		{"path": "res://resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres", "expected": 2.6},
		{"path": "res://resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres", "expected": 52.0 / 15.0},
		{"path": "res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres", "expected": 3.5},
	]
	for case: Dictionary in cases:
		var technique: CyclingTechniqueData = load(case.path)
		assert_almost_eq(technique.get_spirit_xp_per_second(), case.expected, 0.0001, technique.id)

func test_a_cycle_of_no_length_pays_no_spirit_xp_per_second() -> void:
	var technique := CyclingTechniqueData.new()
	technique.spirit_xp_per_cycle = 12.0
	technique.cycle_duration = 0.0
	assert_eq(technique.get_spirit_xp_per_second(), 0.0)

#-----------------------------------------------------------------------------
# XP PER CYCLE
#-----------------------------------------------------------------------------

## A zone paying `perfect` at PERFECT.
func _zone(perfect: int) -> CyclingZoneData:
	var zone := CyclingZoneData.new()
	zone.perfect_xp = perfect
	return zone

## A cycle at its best pays each stat: Spirit its spirit_xp_per_cycle, the
## technique's other stat every zone at PERFECT and every seal opened, any
## other stat nothing.
func test_xp_per_cycle() -> void:
	var spirit_only := CyclingTechniqueData.new()
	spirit_only.spirit_xp_per_cycle = 12.0
	var zones := CyclingTechniqueData.new()
	zones.spirit_xp_per_cycle = 30.0
	zones.minor_stat = CharacterAttributesData.AttributeType.CONTROL
	zones.cycling_zones = [_zone(6), _zone(6), _zone(12), _zone(6)]
	var seals := CyclingTechniqueData.new()
	seals.spirit_xp_per_cycle = 16.0
	seals.minor_stat = CharacterAttributesData.AttributeType.MIND
	seals.seal_seconds = [2.0, 4.5, 7.0]
	seals.seal_xp = 5.0
	var spirit := CharacterAttributesData.AttributeType.SPIRIT
	var mind := CharacterAttributesData.AttributeType.MIND
	var control := CharacterAttributesData.AttributeType.CONTROL
	var strength := CharacterAttributesData.AttributeType.STRENGTH
	var cases: Array[Dictionary] = [
		{"name": "Spirit only: Spirit", "technique": spirit_only, "stat": spirit, "expected": 12.0},
		{"name": "Spirit only: Mind", "technique": spirit_only, "stat": mind, "expected": 0.0},
		{"name": "Spirit only: Control", "technique": spirit_only, "stat": control, "expected": 0.0},
		{"name": "zones: Spirit", "technique": zones, "stat": spirit, "expected": 30.0},
		{"name": "zones: Control, every zone PERFECT", "technique": zones, "stat": control, "expected": 30.0},
		{"name": "zones: Mind", "technique": zones, "stat": mind, "expected": 0.0},
		{"name": "seals: Mind, every seal opened", "technique": seals, "stat": mind, "expected": 15.0},
		{"name": "seals: Control", "technique": seals, "stat": control, "expected": 0.0},
		{"name": "zones: Strength", "technique": zones, "stat": strength, "expected": 0.0},
		{"name": "seals: Strength", "technique": seals, "stat": strength, "expected": 0.0},
	]
	for case: Dictionary in cases:
		var technique: CyclingTechniqueData = case.technique
		assert_almost_eq(technique.get_xp_per_cycle(case.stat), case.expected, 0.0001, case.name)

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
