extends GutTest

## Unit tests for CharacterAttributesData derived stats.

func test_get_max_madra_scales_with_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 100.0, "foundation 10 should give max madra 100")

func test_get_max_madra_zero_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 0.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 0.0, "foundation 0 should give max madra 0")

func test_get_max_madra_high_foundation() -> void:
	var attrs := CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 25.0, 10.0, 10.0, 10.0)
	assert_eq(attrs.get_max_madra(), 250.0, "foundation 25 should give max madra 250")
