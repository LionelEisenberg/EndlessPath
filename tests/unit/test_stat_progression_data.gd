extends GutTest

## Unit tests for StatProgressionData: the XP each stat level costs and the
## value each level gives, on curves built here and on the shipped one.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SHIPPED_PATH: String = "res://resources/character/stat_progression.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A curve with the given numbers.
func _curve(xp_to_level_two: float, growth: float, value_per_level: float) -> StatProgressionData:
	var curve := StatProgressionData.new()
	curve.xp_to_level_two = xp_to_level_two
	curve.xp_growth = growth
	curve.value_per_level = value_per_level
	return curve

#-----------------------------------------------------------------------------
# XP COST
#-----------------------------------------------------------------------------

## Each cost is 1.25 times the last, rounded to a whole number: 156.25 is 156,
## 476.84 is 477.
func test_each_level_costs_more_than_the_last() -> void:
	var curve := _curve(100.0, 1.25, 1.0)
	var cases: Array[Dictionary] = [
		{"level": 1, "xp": 100.0},
		{"level": 2, "xp": 125.0},
		{"level": 3, "xp": 156.0},
		{"level": 4, "xp": 195.0},
		{"level": 8, "xp": 477.0},
		{"level": 9, "xp": 596.0},
	]
	for case: Dictionary in cases:
		assert_eq(curve.get_xp_to_next(case.level), case.xp, "Lv %d to %d" % [case.level, case.level + 1])

## Lv 1 to Foundation's cap, Lv 10, on the shipped numbers: the sum of nine
## whole costs.
func test_lv_1_to_10_costs_2579() -> void:
	var curve := _curve(100.0, 1.25, 1.0)
	var total: float = 0.0
	for level: int in range(1, 10):
		total += curve.get_xp_to_next(level)
	assert_eq(total, 2579.0)

#-----------------------------------------------------------------------------
# VALUE
#-----------------------------------------------------------------------------

func test_value_for_level() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Lv 1 is the baseline", "per_level": 1.0, "level": 1,
			"value": CharacterAttributesData.STAT_BASELINE},
		{"name": "Lv 6 at 1 a level", "per_level": 1.0, "level": 6,
			"value": CharacterAttributesData.STAT_BASELINE + 5.0},
		{"name": "Lv 3 at 2 a level", "per_level": 2.0, "level": 3,
			"value": CharacterAttributesData.STAT_BASELINE + 4.0},
	]
	for case: Dictionary in cases:
		assert_eq(_curve(100.0, 1.25, case.per_level).get_value_for_level(case.level), case.value, case.name)

#-----------------------------------------------------------------------------
# THE SHIPPED CURVE
#-----------------------------------------------------------------------------

func test_the_shipped_curve_starts_at_the_baseline_and_grows() -> void:
	var shipped: StatProgressionData = load(SHIPPED_PATH) as StatProgressionData
	assert_not_null(shipped, "%s loads as a StatProgressionData" % SHIPPED_PATH)
	if shipped == null:
		return
	assert_eq(shipped.get_value_for_level(1), CharacterAttributesData.STAT_BASELINE, "Lv 1 is the baseline")
	assert_gt(shipped.get_xp_to_next(2), shipped.get_xp_to_next(1), "each level costs more")

## The shipped numbers, the spec's. The class defaults are the same numbers, so
## an editor re-save that drops a line, then a change of that default, would
## retune the game with nothing else noticing.
func test_the_shipped_curve_holds_the_specs_numbers() -> void:
	var shipped: StatProgressionData = load(SHIPPED_PATH) as StatProgressionData
	assert_not_null(shipped, "%s loads as a StatProgressionData" % SHIPPED_PATH)
	if shipped == null:
		return
	assert_eq(shipped.xp_to_level_two, 100.0, "Lv 2 costs 100 XP")
	assert_eq(shipped.xp_growth, 1.25, "each later level costs 1.25 times the last")
	assert_eq(shipped.value_per_level, 1.0, "each level adds 1 point")
