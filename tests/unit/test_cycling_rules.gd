extends GutTest

## Unit tests for CyclingRules and CycleResult, the cycling mini-game's pure
## rules: a hit's tier from the ball's distance to the zone's centre, each
## tier's XP, pellet count, name and colour, and the lines that sum up a cycle.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A cycle's result: Madra added, zones scored, zones in the technique,
## PERFECT hits and XP.
func _result(madra: float, scored: int, total: int, perfect: int, xp: int) -> CycleResult:
	var result: CycleResult = CycleResult.new()
	result.madra_added = madra
	result.zones_scored = scored
	result.zones_total = total
	result.perfect_count = perfect
	result.xp = xp
	return result

#-----------------------------------------------------------------------------
# TIERS
#-----------------------------------------------------------------------------

## The zone is 20 px in radius: under 0.3 of it (6 px) is PERFECT, under 0.7 of
## it (14 px) is GOOD, and a click anywhere else on the zone is OK.
func test_tiers_at_the_thresholds() -> void:
	assert_eq(CyclingRules.tier_for_distance(0.0), CyclingRules.Tier.PERFECT, "dead centre")
	assert_eq(CyclingRules.tier_for_distance(5.9), CyclingRules.Tier.PERFECT, "just inside 6 px")
	assert_eq(CyclingRules.tier_for_distance(6.0), CyclingRules.Tier.GOOD, "6 px is the first GOOD")
	assert_eq(CyclingRules.tier_for_distance(13.9), CyclingRules.Tier.GOOD, "just inside 14 px")
	assert_eq(CyclingRules.tier_for_distance(14.0), CyclingRules.Tier.OK, "14 px is the first OK")
	assert_eq(CyclingRules.tier_for_distance(49.0), CyclingRules.Tier.OK, "far past the zone's edge")

func test_xp_per_tier() -> void:
	var zone: CyclingZoneData = CyclingZoneData.new()
	zone.perfect_xp = 50
	zone.good_xp = 25
	zone.ok_xp = 10
	assert_eq(CyclingRules.xp_for_tier(zone, CyclingRules.Tier.PERFECT), 50, "PERFECT pays perfect_xp")
	assert_eq(CyclingRules.xp_for_tier(zone, CyclingRules.Tier.GOOD), 25, "GOOD pays good_xp")
	assert_eq(CyclingRules.xp_for_tier(zone, CyclingRules.Tier.OK), 10, "OK pays ok_xp")

func test_pellet_counts() -> void:
	assert_eq(CyclingRules.pellet_count(CyclingRules.Tier.PERFECT), 8, "PERFECT sends 8 pellets")
	assert_eq(CyclingRules.pellet_count(CyclingRules.Tier.GOOD), 5, "GOOD sends 5")
	assert_eq(CyclingRules.pellet_count(CyclingRules.Tier.OK), 3, "OK sends 3")

func test_tier_names_and_colours() -> void:
	assert_eq(CyclingRules.tier_name(CyclingRules.Tier.PERFECT), "PERFECT")
	assert_eq(CyclingRules.tier_name(CyclingRules.Tier.GOOD), "GOOD")
	assert_eq(CyclingRules.tier_name(CyclingRules.Tier.OK), "OK")
	assert_eq(CyclingRules.tier_color(CyclingRules.Tier.PERFECT), ThemeConstants.LACQUER_BRASS, "PERFECT is brass")
	assert_eq(CyclingRules.tier_color(CyclingRules.Tier.GOOD), ThemeConstants.LACQUER_CREAM, "GOOD is cream")
	assert_eq(CyclingRules.tier_color(CyclingRules.Tier.OK), ThemeConstants.LACQUER_TAN, "OK is tan")

#-----------------------------------------------------------------------------
# CYCLE RESULT
#-----------------------------------------------------------------------------

## The PERFECT part is left out when there were none, the XP part when no zone
## scored, and the zones part reads "zone" for a technique with just one and
## "no zones" for one with none.
func test_result_lines() -> void:
	assert_eq(_result(186.4, 3, 4, 1, 75).result_line(), "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP", "a full cycle")
	assert_eq(_result(120.0, 2, 4, 0, 30).result_line(), "Last cycle · +120 Madra · 2 / 4 zones · +30 XP", "no PERFECT")
	assert_eq(_result(90.0, 0, 4, 0, 0).result_line(), "Last cycle · +90 Madra · 0 / 4 zones", "no zone scored")
	assert_eq(_result(250.0, 1, 1, 1, 30).result_line(), "Last cycle · +250 Madra · 1 / 1 zone · 1 PERFECT · +30 XP", "a technique with one zone")
	assert_eq(_result(50.0, 0, 0, 0, 0).result_line(), "Last cycle · +50 Madra · no zones", "a technique with no zones")

func test_log_line() -> void:
	assert_eq(_result(186.4, 3, 4, 1, 75).log_line(), "Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP")

## The parts are joined by a space, U+00B7 (a middle dot) and a space. The
## codepoint is built here, so a look-alike dot typed into both CycleResult and
## the lines asserted above would still fail.
func test_lines_are_joined_by_a_spaced_middle_dot() -> void:
	var separator: String = " " + char(0xB7) + " "
	var parts: PackedStringArray = _result(186.4, 3, 4, 1, 75).result_line().split(separator)
	assert_eq(parts, PackedStringArray(["Last cycle", "+186 Madra", "3 / 4 zones", "1 PERFECT", "+75 XP"]))
