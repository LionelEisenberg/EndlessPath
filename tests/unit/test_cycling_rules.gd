extends GutTest

## Unit tests for CyclingRules and CycleResult, the cycling mini-game's pure
## rules: a hit's tier from the ball's distance to the zone's centre, each
## tier's XP and pellet count, and the lines that sum up a cycle.

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

## `result` with the Spirit XP it paid, and whether the cap took some.
func _with_spirit(result: CycleResult, spirit_xp: float, capped: bool) -> CycleResult:
	result.record_stat_xp(CharacterAttributesData.AttributeType.SPIRIT, spirit_xp, capped)
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

#-----------------------------------------------------------------------------
# FOLLOWING
#-----------------------------------------------------------------------------

## Following starts once the ball has gone 8 px and the cursor's place on it
## shifted under half of that; it keeps going while the shift stays under 16 px
## or under half the ball's travel; off the ball it never holds.
func test_is_following() -> void:
	var cases: Array[Dictionary] = [
		{"name": "off the ball", "on": false, "was": true, "travel": 40.0, "drift": 0.0, "follows": false},
		{"name": "keeps on a still ball", "on": true, "was": true, "travel": 0.0, "drift": 10.0, "follows": true},
		{"name": "keeps at speed", "on": true, "was": true, "travel": 60.0, "drift": 25.0, "follows": true},
		{"name": "loses at speed", "on": true, "was": true, "travel": 60.0, "drift": 31.0, "follows": false},
		{"name": "a resting cursor loses once the ball goes 16 px", "on": true, "was": true, "travel": 20.0, "drift": 20.0, "follows": false},
		{"name": "a hand held still on a creeping ball keeps", "on": true, "was": true, "travel": 12.0, "drift": 12.0, "follows": true},
		{"name": "starts moving with the ball", "on": true, "was": false, "travel": 8.0, "drift": 3.9, "follows": true},
		{"name": "no start on a creeping ball", "on": true, "was": false, "travel": 7.9, "drift": 0.0, "follows": false},
		{"name": "no start resting", "on": true, "was": false, "travel": 40.0, "drift": 40.0, "follows": false},
		{"name": "no start loosely", "on": true, "was": false, "travel": 40.0, "drift": 20.0, "follows": false},
	]
	for case: Dictionary in cases:
		assert_eq(CyclingRules.is_following(case.on, case.was, case.travel, case.drift), case.follows, case.name)

#-----------------------------------------------------------------------------
# CYCLE RESULT
#-----------------------------------------------------------------------------

## The PERFECT part is left out when there were none, the Core XP part when no
## zone scored, and the zones part reads "zone" for a technique with just one and
## "no zones" for one with none.
func test_result_lines() -> void:
	assert_eq(_result(186.4, 3, 4, 1, 75).result_line(), "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 Core XP", "a full cycle")
	assert_eq(_result(120.0, 2, 4, 0, 30).result_line(), "Last cycle · +120 Madra · 2 / 4 zones · +30 Core XP", "no PERFECT")
	assert_eq(_result(90.0, 0, 4, 0, 0).result_line(), "Last cycle · +90 Madra · 0 / 4 zones", "no zone scored")
	assert_eq(_result(250.0, 1, 1, 1, 30).result_line(), "Last cycle · +250 Madra · 1 / 1 zone · 1 PERFECT · +30 Core XP", "a technique with one zone")
	assert_eq(_result(50.0, 0, 0, 0, 0).result_line(), "Last cycle · +50 Madra · no zones", "a technique with no zones")

## The log board shows one line a message and trims what runs past it (RL-05), so
## the log keeps what the cycle paid and leaves the zones and PERFECTs to the chest.
func test_log_line() -> void:
	assert_eq(_result(186.4, 3, 4, 1, 75).log_line(), "Cycle · +186 Madra · +75 Core XP")
	assert_eq(_result(50.0, 0, 0, 0, 0).log_line(), "Cycle · +50 Madra", "a technique with no zones")

## A full core takes no XP, so both lines say so where they would give the figure.
func test_a_full_core_line_says_so() -> void:
	var result: CycleResult = _result(186.4, 3, 4, 1, 75)
	result.core_full = true
	assert_eq(result.log_line(), "Cycle · +186 Madra · Core full")
	assert_eq(result.result_line(), "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · Core full")

## The Spirit XP follows the Madra, the two things following pays, rounded to a
## whole XP. At the cap the line says so instead, and a cycle that paid less than
## half an XP shows none.
func test_the_lines_show_the_spirit_xp() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the Foundational, followed through", "result": _with_spirit(_result(30.0, 0, 0, 0, 0), 12.0, false),
			"chest": "Last cycle · +30 Madra · +12 Spirit XP · no zones", "log": "Cycle · +30 Madra · +12 Spirit XP"},
		{"name": "Smooth Flow with zones scored", "result": _with_spirit(_result(80.0, 3, 4, 1, 75), 30.0, false),
			"chest": "Last cycle · +80 Madra · +30 Spirit XP · 3 / 4 zones · 1 PERFECT · +75 Core XP", "log": "Cycle · +80 Madra · +30 Spirit XP · +75 Core XP"},
		{"name": "Spirit at the cap", "result": _with_spirit(_result(57.0, 0, 0, 0, 0), 0.0, true),
			"chest": "Last cycle · +57 Madra · Spirit capped · no zones", "log": "Cycle · +57 Madra · Spirit capped"},
		{"name": "the cap reached mid-cycle", "result": _with_spirit(_result(57.0, 0, 0, 0, 0), 5.0, true),
			"chest": "Last cycle · +57 Madra · Spirit capped · no zones", "log": "Cycle · +57 Madra · Spirit capped"},
		{"name": "less than half an XP", "result": _with_spirit(_result(30.0, 0, 0, 0, 0), 0.4, false),
			"chest": "Last cycle · +30 Madra · no zones", "log": "Cycle · +30 Madra"},
	]
	for case: Dictionary in cases:
		var result: CycleResult = case.result
		assert_eq(result.result_line(), case.chest, "%s: the chest's line" % case.name)
		assert_eq(result.log_line(), case.log, "%s: the log's line" % case.name)
