extends GutTest

## Unit tests for CharacterAttributesData, a combatant's stat block: the ints
## AttributeType is stored as, the stat keys, make(), and the derived formulas
## (Health, Stamina, regen, Madra, dodge, Control's cuts, cycling's Madra
## multiplier) the game reads.

const AttributeType = CharacterAttributesData.AttributeType
const KEYS: Array[StringName] = [&"strength", &"body", &"agility", &"spirit", &"mind", &"control"]

## The block's eight derived values, by name.
func _derived(block: CharacterAttributesData) -> Dictionary:
	return {
		"max_health": block.get_max_health(),
		"max_stamina": block.get_max_stamina(),
		"stamina_regen": block.get_stamina_regen(),
		"max_madra": block.get_max_madra(),
		"dodge_chance": block.get_dodge_chance(),
		"madra_cost_cut": block.get_madra_cost_cut(),
		"cooldown_cut": block.get_cooldown_cut(),
		"cycling_madra_multiplier": block.get_cycling_madra_multiplier(),
	}

#-----------------------------------------------------------------------------
# STAT IDENTITY
#-----------------------------------------------------------------------------

func test_attribute_type_ints_never_change() -> void:
	assert_eq(AttributeType, {"STRENGTH": 0, "BODY": 1, "AGILITY": 2, "SPIRIT": 3, "MIND": 4, "CONTROL": 5},
		"a stat is stored as an int: append only")

func test_each_stat_has_a_key() -> void:
	for stat: int in AttributeType.values():
		assert_eq(CharacterAttributesData.stat_key(stat), KEYS[stat], "the key of %s" % AttributeType.keys()[stat])
		assert_eq(CharacterAttributesData.stat_from_key(KEYS[stat]), stat, "the stat of %s" % KEYS[stat])
	for key: StringName in [&"foundation", &"armor", &""]:
		assert_eq(CharacterAttributesData.stat_from_key(key), -1, "'%s' is no stat's key" % key)

#-----------------------------------------------------------------------------
# MAKE AND SET
#-----------------------------------------------------------------------------

func test_make_sets_each_named_stat() -> void:
	for stat: int in AttributeType.values():
		var block := CharacterAttributesData.make({KEYS[stat]: 15.0})
		for other: int in AttributeType.values():
			var expected: float = 15.0 if other == stat else CharacterAttributesData.STAT_BASELINE
			assert_eq(block.get_attribute(other), expected, "make({%s: 15}) reads %s" % [KEYS[stat], KEYS[other]])

func test_armor_and_ward_start_at_zero_and_make_sets_them() -> void:
	var plain := CharacterAttributesData.make()
	assert_eq(plain.armor, 0.0, "armor starts at 0")
	assert_eq(plain.ward, 0.0, "Ward starts at 0")
	var geared := CharacterAttributesData.make({&"armor": 6.0, &"ward": 4.0})
	assert_eq(geared.armor, 6.0, "make() sets armor")
	assert_eq(geared.ward, 4.0, "make() sets Ward")

func test_make_skips_an_unknown_key() -> void:
	assert_eq(CharacterAttributesData.make({&"foundation": 50.0}).mind, CharacterAttributesData.STAT_BASELINE,
		"the old Foundation key sets nothing")

func test_set_attribute_writes_the_stat() -> void:
	var block := CharacterAttributesData.make()
	block.set_attribute(AttributeType.MIND, 14.0)
	assert_eq(block.mind, 14.0, "set_attribute(MIND) writes mind")

#-----------------------------------------------------------------------------
# DERIVED VALUES
#-----------------------------------------------------------------------------

func test_a_level_one_block_keeps_todays_numbers() -> void:
	var expected: Dictionary = {
		"max_health": 100.0,
		"max_stamina": 50.0,
		"stamina_regen": 1.0,
		"max_madra": 100.0,
		"dodge_chance": 0.0,
		"madra_cost_cut": 0.0,
		"cooldown_cut": 0.0,
		"cycling_madra_multiplier": 1.0,
	}
	var derived: Dictionary = _derived(CharacterAttributesData.make())
	for value_name: String in expected:
		assert_eq(derived[value_name], expected[value_name], "%s at Lv 1" % value_name)

## One stat at 15 raises the derived values it feeds and leaves every other one
## at its Lv 1 number.
func test_each_derived_value_reads_only_its_stat() -> void:
	var cases: Array[Dictionary] = [
		{"key": &"body", "raises": ["max_health"]},
		{"key": &"agility", "raises": ["max_stamina", "stamina_regen", "dodge_chance"]},
		{"key": &"mind", "raises": ["max_madra"]},
		{"key": &"control", "raises": ["madra_cost_cut", "cooldown_cut"]},
		{"key": &"strength", "raises": []},
		{"key": &"spirit", "raises": ["cycling_madra_multiplier"]},
	]
	var baseline: Dictionary = _derived(CharacterAttributesData.make())
	for case: Dictionary in cases:
		var derived: Dictionary = _derived(CharacterAttributesData.make({case.key: 15.0}))
		for value_name: String in baseline:
			if value_name in case.raises:
				assert_gt(derived[value_name], baseline[value_name], "%s 15 raises %s" % [case.key, value_name])
			else:
				assert_eq(derived[value_name], baseline[value_name], "%s 15 leaves %s" % [case.key, value_name])

## The cycling Madra multiplier is 1.0 at the baseline and grows by
## CYCLING_MADRA_PER_SPIRIT for each point of Spirit above it, with points below
## the baseline counting as none.
func test_cycling_madra_multiplier() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Lv 1", "spirit": 10.0, "expected": 1.0},
		{"name": "one point of gear", "spirit": 11.0, "expected": 1.1},
		{"name": "Spirit 15", "spirit": 15.0, "expected": 1.5},
		{"name": "Foundation's cap, Lv 10", "spirit": 19.0, "expected": 1.9},
		{"name": "a fractional total", "spirit": 12.5, "expected": 1.25},
		{"name": "below the baseline", "spirit": 6.0, "expected": 1.0},
	]
	for case: Dictionary in cases:
		var block := CharacterAttributesData.make({&"spirit": case.spirit})
		assert_almost_eq(block.get_cycling_madra_multiplier(), case.expected, 0.000001, case.name)

## flattening_curve() is ceiling x points / (points + half_point), with points
## below the baseline counting as none.
func test_flattening_curve() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no points", "points": 0.0, "ceiling": 0.35, "half_point": 15.0, "expected": 0.0},
		{"name": "below the baseline", "points": -5.0, "ceiling": 0.35, "half_point": 15.0, "expected": 0.0},
		{"name": "a third of the half point", "points": 5.0, "ceiling": 0.35, "half_point": 15.0, "expected": 0.0875},
		{"name": "the half point gives half", "points": 15.0, "ceiling": 0.35, "half_point": 15.0, "expected": 0.175},
		{"name": "far past it, just under", "points": 1000000.0, "ceiling": 0.4, "half_point": 20.0, "expected": 0.399992},
	]
	for case: Dictionary in cases:
		assert_almost_eq(CharacterAttributesData.flattening_curve(case.points, case.ceiling, case.half_point),
			case.expected, 0.000001, case.name)

func test_curves_stay_under_their_ceilings() -> void:
	var block := CharacterAttributesData.make({&"agility": 100000.0, &"control": 100000.0})
	var cases: Array[Dictionary] = [
		{"name": "dodge", "value": block.get_dodge_chance(), "ceiling": CharacterAttributesData.DODGE_CEILING},
		{"name": "the Madra cost cut", "value": block.get_madra_cost_cut(),
			"ceiling": CharacterAttributesData.MADRA_COST_CUT_CEILING},
		{"name": "the cooldown cut", "value": block.get_cooldown_cut(),
			"ceiling": CharacterAttributesData.COOLDOWN_CUT_CEILING},
	]
	for case: Dictionary in cases:
		assert_lt(case.value, case.ceiling, "%s stays under its ceiling" % case.name)
		assert_gt(case.value, 0.99 * case.ceiling, "%s comes close" % case.name)
