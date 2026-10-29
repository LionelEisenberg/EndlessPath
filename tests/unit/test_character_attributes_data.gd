extends GutTest

## Unit tests for CharacterAttributesData derived stats: the max Health,
## Stamina and Madra formulas every VitalsManager and the character sheet use.

## Max Madra is Foundation x 10, at Foundation 10, 0 and 25.
func test_get_max_madra_scales_with_foundation() -> void:
	var cases: Array[Array] = [
		[10.0, 100.0],
		[0.0, 0.0],
		[25.0, 250.0],
	]
	for case: Array in cases:
		var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, case[0], 10.0, 10.0, 10.0)
		assert_eq(attrs.get_max_madra(), case[1], "foundation %d should give max madra %d" % [case[0], case[1]])

func test_get_max_health_is_body_times_ten() -> void:
	var attrs := CharacterAttributesData.new(99.0, 12.0, 99.0, 99.0, 99.0, 99.0, 99.0, 99.0)
	assert_eq(attrs.get_max_health(), 120.0, "Body 12 is 120 Health, whatever the rest is")

func test_get_max_stamina_is_body_times_five() -> void:
	var attrs := CharacterAttributesData.new(99.0, 12.0, 99.0, 99.0, 99.0, 99.0, 99.0, 99.0)
	assert_eq(attrs.get_max_stamina(), 60.0, "Body 12 is 60 Stamina, whatever the rest is")
