extends GutTest

## Unit tests for the TrainingActionData helpers the Now strip, the plate's
## rate and the adventure card's "ready in ~N s" read: Madra per second from
## the per-tick effects, and the tick counts within the current level.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _resource_effect(type: ResourceManager.ResourceType, amount: float) -> AwardResourceEffectData:
	var effect := AwardResourceEffectData.new()
	effect.resource_type = type
	effect.amount = amount
	return effect

func _training(effects: Array[EffectData], interval: float) -> TrainingActionData:
	var data := TrainingActionData.new()
	data.effects_per_tick = effects
	data.tick_interval_seconds = interval
	return data

func _levels(ticks_per_level: Array[int]) -> TrainingActionData:
	var data := TrainingActionData.new()
	data.ticks_per_level = ticks_per_level
	data.tail_growth_multiplier = 2.0
	return data

#-----------------------------------------------------------------------------
# MADRA PER SECOND
#-----------------------------------------------------------------------------

func test_madra_per_second_sums_madra_effects() -> void:
	var effects: Array[EffectData] = [
		_resource_effect(ResourceManager.ResourceType.MADRA, 1.5),
		_resource_effect(ResourceManager.ResourceType.GOLD, 2.0),
	]
	assert_eq(_training(effects, 1.0).get_madra_per_second(), 1.5, "gold is not Madra")
	assert_eq(_training(effects, 0.5).get_madra_per_second(), 3.0, "two ticks a second")

func test_madra_per_second_adds_several_madra_effects() -> void:
	var effects: Array[EffectData] = [
		_resource_effect(ResourceManager.ResourceType.MADRA, 1.5),
		_resource_effect(ResourceManager.ResourceType.MADRA, 0.5),
	]
	assert_eq(_training(effects, 1.0).get_madra_per_second(), 2.0)

func test_madra_per_second_ignores_other_effects() -> void:
	var attribute := AwardAttributeEffectData.new()
	attribute.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	attribute.amount = 4.0
	var effects: Array[EffectData] = [attribute]
	assert_eq(_training(effects, 1.0).get_madra_per_second(), 0.0)

func test_madra_per_second_with_zero_interval_is_zero() -> void:
	var effects: Array[EffectData] = [_resource_effect(ResourceManager.ResourceType.MADRA, 1.5)]
	assert_eq(_training(effects, 0.0).get_madra_per_second(), 0.0)

func test_aura_well_makes_one_and_a_half_madra_per_second() -> void:
	var aura_well: TrainingActionData = load("res://resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres")
	assert_eq(aura_well.get_madra_per_second(), 1.5)

#-----------------------------------------------------------------------------
# TICKS WITHIN THE LEVEL
#-----------------------------------------------------------------------------

func test_ticks_in_level() -> void:
	var data := _levels([3, 5] as Array[int])
	assert_eq(data.get_ticks_in_level(0), 0, "level 0, nothing done")
	assert_eq(data.get_ticks_in_level(2), 2, "level 0, 2 of 3")
	assert_eq(data.get_ticks_in_level(3), 0, "level 1 just reached")
	assert_eq(data.get_ticks_in_level(7), 4, "level 1, 4 of 5")
	assert_eq(data.get_ticks_in_level(8), 0, "level 2 just reached")

func test_ticks_for_next_level() -> void:
	var data := _levels([3, 5] as Array[int])
	assert_eq(data.get_ticks_for_next_level(0), 3)
	assert_eq(data.get_ticks_for_next_level(2), 3)
	assert_eq(data.get_ticks_for_next_level(3), 5)
	assert_eq(data.get_ticks_for_next_level(7), 5)
	assert_eq(data.get_ticks_for_next_level(8), 10, "beyond the array: 5 x 2")
