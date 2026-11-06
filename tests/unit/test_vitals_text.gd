extends GutTest

## Unit tests for VitalsText, the one Health rounding rule the vitals plate and
## the end card share: the figure rounds up and the max rounds down.

func test_health_rounds_up_over_a_max_rounded_down() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a sliver of Health still reads 1", "health": 0.4, "max": 100.0, "pair": "1 / 100"},
		{"name": "no Health reads 0", "health": 0.0, "max": 100.0, "pair": "0 / 100"},
		{"name": "90.9 reads as the plate's 91", "health": 90.9, "max": 100.0, "pair": "91 / 100"},
		{"name": "a fractional max rounds down", "health": 141.2, "max": 160.7, "pair": "142 / 160"},
		{"name": "full", "health": 100.0, "max": 100.0, "pair": "100 / 100"},
	]
	for case: Dictionary in cases:
		assert_eq(VitalsText.health_pair(case.health, case.max), case.pair, case.name)
