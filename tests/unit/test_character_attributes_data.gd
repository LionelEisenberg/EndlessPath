extends GutTest

## Unit tests for CharacterAttributesData derived stats: the max Health,
## Stamina and Madra formulas every VitalsManager and the character sheet use.

func test_get_max_madra_scales_with_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 100.0, "foundation 10 should give max madra 100")

func test_get_max_madra_zero_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 0.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 0.0, "foundation 0 should give max madra 0")

func test_get_max_madra_high_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 25.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 250.0, "foundation 25 should give max madra 250")

func test_get_max_health_is_body_times_ten() -> void:
	var attrs := CharacterAttributesData.new(99.0, 12.0, 99.0, 99.0, 99.0, 99.0, 99.0, 99.0)
	assert_eq(attrs.get_max_health(), 120.0, "Body 12 is 120 Health, whatever the rest is")

func test_get_max_stamina_is_body_times_five() -> void:
	var attrs := CharacterAttributesData.new(99.0, 12.0, 99.0, 99.0, 99.0, 99.0, 99.0, 99.0)
	assert_eq(attrs.get_max_stamina(), 60.0, "Body 12 is 60 Stamina, whatever the rest is")
