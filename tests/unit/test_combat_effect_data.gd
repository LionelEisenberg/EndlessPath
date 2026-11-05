extends GutTest

## Unit tests for CombatEffectData.get_scaling and get_scaling_contribution,
## which the menu books use to show what an ability scales with and how its
## value adds up.

## No other stat has a scaling field, so no technique file can set one.
func test_only_the_main_stats_have_a_scaling() -> void:
	var effect := CombatEffectData.new()
	for property: String in ["body_scaling", "agility_scaling", "mind_scaling", "control_scaling"]:
		assert_false(property in effect, "%s is gone" % property)
	assert_true("strength_scaling" in effect, "Strength scales Physical techniques")
	assert_true("spirit_scaling" in effect, "Spirit scales Spirit techniques")

## get_scaling() reads Strength's and Spirit's scaling. Every other stat scales nothing.
func test_get_scaling_reads_strength_and_spirit_only() -> void:
	var effect := CombatEffectData.new()
	effect.strength_scaling = 1.5
	effect.spirit_scaling = 2.0
	var cases: Array[Dictionary] = [
		{"stat": CharacterAttributesData.AttributeType.STRENGTH, "scaling": 1.5},
		{"stat": CharacterAttributesData.AttributeType.BODY, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.AGILITY, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.SPIRIT, "scaling": 2.0},
		{"stat": CharacterAttributesData.AttributeType.MIND, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.CONTROL, "scaling": 0.0},
	]
	for case: Dictionary in cases:
		assert_eq(effect.get_scaling(case["stat"]), case["scaling"], CharacterAttributesData.AttributeType.keys()[case["stat"]])

## calculate_value() counts Strength and Spirit only, however high the other four are.
func test_value_ignores_the_other_stats() -> void:
	var effect := CombatEffectData.new()
	effect.base_value = 10.0
	effect.strength_scaling = 1.5
	effect.spirit_scaling = 2.0
	var mains := CharacterAttributesData.make({&"strength": 12.0, &"spirit": 14.0})
	var all_high := CharacterAttributesData.make({&"strength": 12.0, &"spirit": 14.0,
		&"body": 99.0, &"agility": 99.0, &"mind": 99.0, &"control": 99.0})
	assert_eq(effect.calculate_value(mains), 56.0, "10 + 12 x 1.5 + 14 x 2")
	assert_eq(effect.calculate_value(all_high), 56.0, "Body, Agility, Mind and Control add nothing")

func test_contribution_is_the_attribute_times_its_scaling() -> void:
	var effect := CombatEffectData.new()
	effect.spirit_scaling = 1.5
	var attrs := CharacterAttributesData.new()
	attrs.spirit = 11.0
	assert_eq(effect.get_scaling_contribution(CharacterAttributesData.AttributeType.SPIRIT, attrs), 16.5)

func test_base_plus_contributions_is_the_calculated_value() -> void:
	# The Abilities book shows the breakdown; it must add up to the real value.
	var effect := CombatEffectData.new()
	effect.base_value = 30.0
	effect.spirit_scaling = 1.5
	effect.strength_scaling = 0.25
	var attrs := CharacterAttributesData.make({
		&"strength": 17.0, &"body": 16.0, &"agility": 14.0, &"spirit": 11.0, &"mind": 12.0, &"control": 12.0,
	})
	var total: float = effect.base_value
	for attribute: int in CharacterAttributesData.AttributeType.values():
		total += effect.get_scaling_contribution(attribute as CharacterAttributesData.AttributeType, attrs)
	assert_almost_eq(total, effect.calculate_value(attrs), 0.0001)
