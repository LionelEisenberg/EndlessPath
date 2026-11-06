extends GutTest

## Integration tests for the adventure's end card: its Madra line shows what
## the pool kept over its max, and its Health line reads as the vitals plate's
## (VitalsText), so a run shows one Health number.

const EndCardScene := preload("res://scenes/adventure/adventure_end_card/adventure_end_card.tscn")

var _card: AdventureEndCard

func before_each() -> void:
	_card = EndCardScene.instantiate() as AdventureEndCard
	add_child_autofree(_card)

## A retreat's result: 90.9 of 100 Health and 46 of 100 Madra.
func _retreat() -> AdventureResultData:
	var result := AdventureResultData.new()
	result.defeat_reason = "You retreated from the adventure"
	result.health_remaining = 90.9
	result.health_max = 100.0
	result.madra_left = 46.0
	result.madra_max = 100.0
	return result

func _value(label_name: String) -> String:
	return (_card.get_node("%" + label_name) as Label).text

func test_the_madra_line_shows_what_the_pool_kept() -> void:
	await _card.show_results(_retreat())
	assert_eq(_value("MadraValueLabel"), "46 / 100")

func test_the_health_line_reads_as_the_vitals_plate() -> void:
	var result: AdventureResultData = _retreat()
	await _card.show_results(result)
	assert_eq(_value("HealthValueLabel"), VitalsText.health_pair(result.health_remaining, result.health_max), "the plate's rule")
	assert_eq(_value("HealthValueLabel"), "91 / 100", "90.9 rounds up, as the plate shows it")
