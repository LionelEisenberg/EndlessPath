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

## The Madra effects per tick, summed and divided by the tick interval: gold
## and attribute awards are not Madra, a half-second tick doubles the rate,
## and several Madra effects add up.
func test_madra_per_second_sums_madra_effects() -> void:
	var madra_and_gold: Array[EffectData] = [
		_resource_effect(ResourceManager.ResourceType.MADRA, 1.5),
		_resource_effect(ResourceManager.ResourceType.GOLD, 2.0),
	]
	var two_madra: Array[EffectData] = [
		_resource_effect(ResourceManager.ResourceType.MADRA, 1.5),
		_resource_effect(ResourceManager.ResourceType.MADRA, 0.5),
	]
	var attribute := AwardAttributeEffectData.new()
	attribute.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	attribute.amount = 4.0
	var attribute_only: Array[EffectData] = [attribute]
	var cases: Array[Dictionary] = [
		{"name": "gold is not Madra", "effects": madra_and_gold, "interval": 1.0, "rate": 1.5},
		{"name": "two ticks a second", "effects": madra_and_gold, "interval": 0.5, "rate": 3.0},
		{"name": "several Madra effects add", "effects": two_madra, "interval": 1.0, "rate": 2.0},
		{"name": "an attribute award is not Madra", "effects": attribute_only, "interval": 1.0, "rate": 0.0},
	]
	for case: Dictionary in cases:
		assert_eq(_training(case.effects, case.interval).get_madra_per_second(), case.rate, case.name)

func test_madra_per_second_with_zero_interval_is_zero() -> void:
	var effects: Array[EffectData] = [_resource_effect(ResourceManager.ResourceType.MADRA, 1.5)]
	assert_eq(_training(effects, 0.0).get_madra_per_second(), 0.0)

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
