extends GutTest

## Integration tests for the adventure's end card: its Madra line shows what
## the pool kept over its max, its Health line reads as the vitals plate's
## (VitalsText), so a run shows one Health number, and its Core Density row shows
## the core's stars with the run's part in jade and the XP the run paid.

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

## The steps the Core Density stars show, 0 (empty) to 10 (lit).
func _star_steps() -> Array[int]:
	var row: LacquerStarRow = _card.get_node("%CoreDensityStars") as LacquerStarRow
	var steps: Array[int] = []
	for index: int in row.get_star_count():
		steps.append(row.get_star_step(index))
	return steps

## The core went from 34 to 52: the stars stand at 52, the fourth and fifth
## (filled this run) and the sixth (started) in jade, and the line reads the XP.
func test_the_core_density_row_shows_the_runs_gain() -> void:
	var result: AdventureResultData = _retreat()
	result.core_density_xp_earned = 140.0
	result.core_density_level_before = 34
	result.core_density_level_after = 52
	await _card.show_results(result)
	assert_eq(_star_steps(), [10, 10, 10, 10, 10, 2, 0, 0, 0, 0] as Array[int])
	var row: LacquerStarRow = _card.get_node("%CoreDensityStars") as LacquerStarRow
	var gained: Array[bool] = []
	for index: int in row.get_star_count():
		gained.append(row.is_star_gained(index))
	assert_eq(gained, [false, false, false, true, true, true, false, false, false, false] as Array[bool], "the run's stars in jade")
	assert_eq(_value("CoreDensityValueLabel"), "+140")

## The line for each way a run can leave the core: a gain, nothing, the core
## filled during the run, and a core full all run (a full core takes nothing).
func test_the_core_density_line() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a gain", "xp": 60.0, "before": 34, "after": 41, "text": "+60"},
		{"name": "nothing", "xp": 0.0, "before": 34, "after": 34, "text": "none this run"},
		{"name": "filled", "xp": 200.0, "before": 88, "after": 100, "text": "+200 · Core full"},
		{"name": "full all run", "xp": 0.0, "before": 100, "after": 100, "text": "Core full"},
	]
	for case: Dictionary in cases:
		var result := AdventureResultData.new()
		result.core_density_xp_earned = case.xp
		result.core_density_level_before = case.before
		result.core_density_level_after = case.after
		assert_eq(AdventureEndCard.core_density_text(result), case.text, case.name)
