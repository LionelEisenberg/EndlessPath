extends GutTest

## Unit tests for DrillRules (the judge, each tier's factor, XP and Health per
## rep, and a perfect set's XP) and DrillSetResult (what a set records, and when
## it is perfect).

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

## A drill that pays 8 Strength XP, 4 Body XP and 4 Health a PERFECT rep, in
## sets of 10.
func _body_drill() -> DrillData:
	var drill := DrillData.new()
	drill.id = "body_drill"
	drill.strength_xp_per_rep = 8.0
	drill.minor_stat = AttributeType.BODY
	drill.minor_xp_per_rep = 4.0
	drill.health_per_rep = 4.0
	drill.reps_per_set = 10
	return drill

#-----------------------------------------------------------------------------
# THE JUDGE
#-----------------------------------------------------------------------------

func test_judge_turns_a_share_into_a_tier() -> void:
	var cases: Array[Array] = [
		[1.0, Tier.PERFECT],
		[0.85, Tier.PERFECT],
		[0.849, Tier.GOOD],
		[0.6, Tier.GOOD],
		[0.599, Tier.OK],
		[0.3, Tier.OK],
		[0.299, Tier.MISS],
		[0.0, Tier.MISS],
	]
	for case: Array in cases:
		assert_eq(DrillRules.judge(case[0]), case[1], "a share of %s" % case[0])

func test_each_tier_pays_its_share() -> void:
	var cases: Array[Array] = [
		[Tier.PERFECT, 1.0],
		[Tier.GOOD, 0.75],
		[Tier.OK, 0.5],
		[Tier.MISS, 0.0],
		[Tier.AUTO, 0.4],
	]
	for case: Array in cases:
		var tier_name: String = Tier.keys()[case[0]]
		assert_eq(DrillRules.factor(case[0]), case[1], "%s's factor" % tier_name)
		assert_eq(DrillRules.xp_for_rep(8.0, case[0]), 8.0 * case[1], "%s's XP" % tier_name)

#-----------------------------------------------------------------------------
# HEALTH PER REP
#-----------------------------------------------------------------------------

## 1.0 at the baseline (Strength Lv 1, 10), +0.1 a point above it, and nothing
## taken away below it.
func test_strength_raises_the_health_a_rep_restores() -> void:
	var cases: Array[Array] = [
		[10.0, 1.0],
		[15.0, 1.5],
		[19.0, 1.9],
		[6.0, 1.0],
	]
	for case: Array in cases:
		assert_almost_eq(DrillRules.health_multiplier(case[0]), case[1], 0.0001, "Strength %s" % case[0])

func test_health_for_rep_is_the_drills_amount_times_the_tier_and_strength() -> void:
	var drill: DrillData = _body_drill()
	var cases: Array[Array] = [
		[Tier.PERFECT, 10.0, 4.0],
		[Tier.PERFECT, 19.0, 7.6],
		[Tier.GOOD, 10.0, 3.0],
		[Tier.OK, 15.0, 3.0],
		[Tier.MISS, 19.0, 0.0],
	]
	for case: Array in cases:
		var tier_name: String = Tier.keys()[case[0]]
		assert_almost_eq(DrillRules.health_for_rep(drill, case[0], case[1]), case[2], 0.0001, "%s at Strength %s" % [tier_name, case[1]])

#-----------------------------------------------------------------------------
# A PERFECT SET
#-----------------------------------------------------------------------------

func test_perfect_set_xp_counts_ten_perfect_reps_of_each_trained_stat() -> void:
	var drill: DrillData = _body_drill()
	assert_eq(DrillRules.perfect_set_xp(drill, AttributeType.STRENGTH), 80.0, "Strength")
	assert_eq(DrillRules.perfect_set_xp(drill, AttributeType.BODY), 40.0, "the drill's other stat")
	assert_eq(DrillRules.perfect_set_xp(drill, AttributeType.AGILITY), 0.0, "a stat it doesn't train")
	drill.minor_stat = -1
	assert_eq(DrillRules.perfect_set_xp(drill, AttributeType.BODY), 0.0, "no other stat: Body is not trained")

#-----------------------------------------------------------------------------
# THE SET RESULT
#-----------------------------------------------------------------------------

## A result holding `tiers`, one rep each, each restoring 1 Health.
func _result_of(tiers: Array) -> DrillSetResult:
	var result := DrillSetResult.new(_body_drill())
	for tier: Tier in tiers:
		result.add_rep(tier, 1.0)
	return result

func test_a_set_is_perfect_when_all_its_reps_are() -> void:
	var all_perfect: Array = []
	all_perfect.resize(10)
	all_perfect.fill(Tier.PERFECT)
	var one_good: Array = all_perfect.duplicate()
	one_good[4] = Tier.GOOD
	var all_auto: Array = []
	all_auto.resize(10)
	all_auto.fill(Tier.AUTO)
	var cases: Array[Dictionary] = [
		{"name": "ten PERFECT reps", "tiers": all_perfect, "complete": true, "perfect": true},
		{"name": "one GOOD rep among ten", "tiers": one_good, "complete": true, "perfect": false},
		{"name": "nine PERFECT reps, a set not finished", "tiers": all_perfect.slice(0, 9), "complete": false, "perfect": false},
		{"name": "no reps", "tiers": [], "complete": false, "perfect": false},
		{"name": "ten AUTO reps", "tiers": all_auto, "complete": true, "perfect": false},
	]
	for case: Dictionary in cases:
		var result: DrillSetResult = _result_of(case["tiers"])
		assert_eq(result.is_complete(), case["complete"], "%s: complete" % case["name"])
		assert_eq(result.is_perfect(), case["perfect"], "%s: perfect" % case["name"])

func test_a_set_counts_its_tiers_and_health() -> void:
	var result: DrillSetResult = _result_of([Tier.PERFECT, Tier.OK, Tier.MISS, Tier.PERFECT])
	assert_eq(result.get_rep_count(), 4)
	assert_eq(result.count_of(Tier.PERFECT), 2)
	assert_eq(result.count_of(Tier.OK), 1)
	assert_eq(result.count_of(Tier.MISS), 1)
	assert_eq(result.count_of(Tier.GOOD), 0)
	assert_eq(result.get_health_restored(), 4.0)

func test_a_set_of_no_drill_is_never_complete() -> void:
	var result := DrillSetResult.new()
	result.add_rep(Tier.PERFECT, 0.0)
	assert_false(result.is_complete())
	assert_false(result.is_perfect())

func test_a_set_keeps_each_reps_health() -> void:
	var result := DrillSetResult.new(_body_drill())
	result.add_rep(Tier.PERFECT, 4.0)
	result.add_rep(Tier.MISS, 0.0)
	result.add_rep(Tier.OK, 1.5)
	assert_eq(result.get_rep_health(0), 4.0)
	assert_eq(result.get_rep_health(1), 0.0)
	assert_eq(result.get_rep_health(2), 1.5)

## Health is full for the set's lines only when a scored rep restored nothing and
## the set restored nothing at all: a set that topped Health up restored some,
## and a set of misses paid none.
func test_health_full_needs_a_scored_rep_and_no_health() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a scored rep that restored nothing", "reps": [[Tier.PERFECT, 0.0]], "full": true},
		{"name": "a miss alone", "reps": [[Tier.MISS, 0.0]], "full": false},
		{"name": "a rep that topped Health up, then one at the max", "reps": [[Tier.PERFECT, 2.0], [Tier.PERFECT, 0.0]], "full": false},
		{"name": "no reps", "reps": [], "full": false},
	]
	for case: Dictionary in cases:
		var result := DrillSetResult.new(_body_drill())
		for rep: Array in case["reps"]:
			result.add_rep(rep[0], rep[1])
		assert_eq(result.is_health_full(), case["full"], case["name"])

## The stat XP the set's reps paid, as each stat took it, and whether the cap
## took any of it.
func test_a_set_records_the_xp_each_stat_took() -> void:
	var result := DrillSetResult.new(_body_drill())
	result.record_stat_xp(AttributeType.STRENGTH, 8.0, false)
	result.record_stat_xp(AttributeType.STRENGTH, 3.0, true)
	result.record_stat_xp(AttributeType.BODY, 4.0, false)
	assert_eq(result.get_stat_xp(AttributeType.STRENGTH), 11.0)
	assert_true(result.is_stat_capped(AttributeType.STRENGTH), "the cap took some of Strength's")
	assert_eq(result.get_stat_xp(AttributeType.BODY), 4.0)
	assert_false(result.is_stat_capped(AttributeType.BODY))
	assert_eq(result.get_stat_xp(AttributeType.AGILITY), 0.0, "a stat the set never paid")

## The log's one line gives what the set paid, in words: Strength's XP or that the
## cap took it, the drill's other stat's XP when it has one, then the Health or
## that the pool was full, each rounded to a whole number.
func test_log_line_reads_what_the_set_paid() -> void:
	var strength_only: DrillData = _body_drill()
	strength_only.minor_stat = -1
	var cases: Array[Dictionary] = [
		{"name": "XP and Health", "drill": strength_only, "xp": [[AttributeType.STRENGTH, 47.6, false]], "reps": [[Tier.PERFECT, 31.6]], "line": "Set · +48 Strength XP · +32 Health"},
		{"name": "the cap took it", "drill": strength_only, "xp": [[AttributeType.STRENGTH, 0.0, true]], "reps": [[Tier.PERFECT, 30.0]], "line": "Set · Strength capped · +30 Health"},
		{"name": "the pool was full", "drill": strength_only, "xp": [[AttributeType.STRENGTH, 60.0, false]], "reps": [[Tier.PERFECT, 0.0]], "line": "Set · +60 Strength XP · Health full"},
		{"name": "nothing but misses", "drill": strength_only, "xp": [], "reps": [[Tier.MISS, 0.0], [Tier.MISS, 0.0]], "line": "Set · +0 Strength XP · +0 Health"},
		{"name": "a drill with another stat", "drill": _body_drill(), "xp": [[AttributeType.STRENGTH, 80.0, false], [AttributeType.BODY, 40.0, false]], "reps": [[Tier.PERFECT, 40.0]], "line": "Set · +80 Strength XP · +40 Body XP · +40 Health"},
		{"name": "Auto played it", "drill": _body_drill(), "xp": [[AttributeType.STRENGTH, 32.0, false]], "reps": [[Tier.AUTO, 16.0]], "line": "Set · Auto · +32 Strength XP · +16 Health"},
		{"name": "Auto at the cap", "drill": _body_drill(), "xp": [[AttributeType.STRENGTH, 0.0, true]], "reps": [[Tier.AUTO, 16.0]], "line": "Set · Auto · Strength capped · +16 Health"},
	]
	for case: Dictionary in cases:
		var result := DrillSetResult.new(case["drill"])
		for paid: Array in case["xp"]:
			result.record_stat_xp(paid[0], paid[1], paid[2])
		for rep: Array in case["reps"]:
			result.add_rep(rep[0], rep[1])
		assert_eq(result.log_line(), case["line"], case["name"])
