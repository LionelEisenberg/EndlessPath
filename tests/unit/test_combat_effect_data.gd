extends GutTest

## Unit tests for CombatEffectData.get_scaling and get_scaling_contribution,
## which the menu books use to show what an ability scales with and how its
## value adds up.

func test_get_scaling_reads_each_attribute_field() -> void:
	var effect := CombatEffectData.new()
	effect.strength_scaling = 1.0
	effect.body_scaling = 2.0
	effect.agility_scaling = 3.0
	effect.spirit_scaling = 4.0
	effect.foundation_scaling = 5.0
	effect.control_scaling = 6.0
	effect.resilience_scaling = 7.0
	effect.willpower_scaling = 8.0
	var attribute_names: Array = CharacterAttributesData.AttributeType.keys()
	for attribute: int in CharacterAttributesData.AttributeType.values():
		assert_eq(effect.get_scaling(attribute as CharacterAttributesData.AttributeType), float(attribute + 1),
			attribute_names[attribute])

func test_get_scaling_is_zero_when_unset() -> void:
	var effect := CombatEffectData.new()
	assert_eq(effect.get_scaling(CharacterAttributesData.AttributeType.WILLPOWER), 0.0)

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
	effect.foundation_scaling = 0.5
	effect.strength_scaling = 0.25
	var attrs := CharacterAttributesData.new(17.0, 16.0, 14.0, 11.0, 12.0, 12.0, 12.0, 13.0)
	var total: float = effect.base_value
	for attribute: int in CharacterAttributesData.AttributeType.values():
		total += effect.get_scaling_contribution(attribute as CharacterAttributesData.AttributeType, attrs)
	assert_almost_eq(total, effect.calculate_value(attrs), 0.0001)
