extends GutTest

## Unit tests for CyclingRules and CycleResult, the cycling mini-game's pure
## rules: a hit's tier from the ball's distance to the zone's centre, each
## tier's XP and pellet count, the seals' keys, and what a cycle paid and the log
## line that sums it up.

const SPIRIT: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.SPIRIT
const MIND: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.MIND
const CONTROL: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.CONTROL

## The icons the log line draws, as its [img] tags.
const MADRA_ICON: String = "[img=16x16]res://assets/ui/lacquer/lacquer_mini_madra_ai.png[/img]"
const SPIRIT_ICON: String = "[img=16x16]res://assets/sprites/ui/attribute_icons/spirit_icon.png[/img]"
const MIND_ICON: String = "[img=16x16]res://assets/sprites/ui/attribute_icons/foundation_icon.png[/img]"
const CONTROL_ICON: String = "[img=16x16]res://assets/sprites/ui/attribute_icons/control_icon_ai.png[/img]"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A cycle's result: Madra added, zones scored, zones in the technique,
## PERFECT hits and the Control XP the zones paid.
func _result(madra: float, scored: int, total: int, perfect: int, control_xp: int) -> CycleResult:
	var result: CycleResult = CycleResult.new()
	result.madra_added = madra
	result.zones_scored = scored
	result.zones_total = total
	result.perfect_count = perfect
	if control_xp > 0:
		result.record_stat_xp(CharacterAttributesData.AttributeType.CONTROL, control_xp, false)
	return result

## `result` with the XP `stat` took, and whether the cap took some.
func _with_stat(result: CycleResult, stat: CharacterAttributesData.AttributeType, xp: float, capped: bool) -> CycleResult:
	result.record_stat_xp(stat, xp, capped)
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

## Anywhere in the gold circle keeps following. A cursor in it starts following
## once it has moved 4 px over the window, so a resting one never starts; off the
## ball nothing follows.
func test_is_following() -> void:
	var cases: Array[Dictionary] = [
		{"name": "off the ball", "on": false, "was": true, "moved": 40.0, "follows": false},
		{"name": "keeps anywhere on the ball, moving or not", "on": true, "was": true, "moved": 0.0, "follows": true},
		{"name": "starts once the cursor has moved 4 px", "on": true, "was": false, "moved": 4.0, "follows": true},
		{"name": "a twitch does not start it", "on": true, "was": false, "moved": 3.9, "follows": false},
		{"name": "a resting cursor never starts", "on": true, "was": false, "moved": 0.0, "follows": false},
	]
	for case: Dictionary in cases:
		assert_eq(CyclingRules.is_following(case.on, case.was, case.moved), case.follows, case.name)

#-----------------------------------------------------------------------------
# SEALS
#-----------------------------------------------------------------------------

## A right key lights the next arrow; a wrong one starts the seal over.
func test_seal_progress() -> void:
	var up := CyclingRules.Arrow.UP
	var left := CyclingRules.Arrow.LEFT
	var down := CyclingRules.Arrow.DOWN
	var right := CyclingRules.Arrow.RIGHT
	var seal: Array[int] = [up, right, down]
	var cases: Array[Dictionary] = [
		{"name": "the first arrow", "keyed": 0, "arrow": up, "after": 1},
		{"name": "the second arrow", "keyed": 1, "arrow": right, "after": 2},
		{"name": "the last arrow opens it", "keyed": 2, "arrow": down, "after": 3},
		{"name": "a wrong first key", "keyed": 0, "arrow": left, "after": 0},
		{"name": "a wrong last key starts it over", "keyed": 2, "arrow": up, "after": 0},
		{"name": "the first arrow again is wrong at the second", "keyed": 1, "arrow": up, "after": 0},
	]
	for case: Dictionary in cases:
		assert_eq(CyclingRules.seal_progress(seal, case.keyed, case.arrow), case.after, case.name)

## A seal is SEAL_LENGTH arrows, never one arrow three times, and the same seed
## draws the same seals.
func test_random_seal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var twin := RandomNumberGenerator.new()
	twin.seed = 7
	for i: int in 200:
		var seal: Array[int] = CyclingRules.random_seal(rng)
		assert_eq(seal.size(), CyclingRules.SEAL_LENGTH, "a seal has its three arrows")
		for arrow: int in seal:
			assert_true(arrow >= CyclingRules.Arrow.UP and arrow <= CyclingRules.Arrow.RIGHT, "each is an arrow")
		assert_false(seal[0] == seal[1] and seal[1] == seal[2], "never one arrow three times")
		assert_eq(CyclingRules.random_seal(twin), seal, "the same seed draws the same seal")

#-----------------------------------------------------------------------------
# CYCLE RESULT
#-----------------------------------------------------------------------------

## The log's line: what the cycle paid, each as its icon and its figure, three
## spaces apart: the Madra, then each Spiritual stat in the screens' order with
## the XP it took rounded to a whole XP, or "capped" when the cap took some. A
## stat that took less than half an XP is left out.
func test_log_line() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the Foundational, followed through", "result": _with_stat(_result(30.0, 0, 0, 0, 0), SPIRIT, 12.0, false),
			"line": "Cycle   %s +30   %s +12" % [MADRA_ICON, SPIRIT_ICON]},
		{"name": "Smooth Flow, zones scored", "result": _with_stat(_result(80.0, 3, 4, 1, 21), SPIRIT, 30.0, false),
			"line": "Cycle   %s +80   %s +30   %s +21" % [MADRA_ICON, SPIRIT_ICON, CONTROL_ICON]},
		{"name": "Torrential Flow, seals opened", "result": _with_stat(_with_stat(_result(50.0, 0, 0, 0, 0), SPIRIT, 24.0, false), MIND, 15.0, false),
			"line": "Cycle   %s +50   %s +24   %s +15" % [MADRA_ICON, SPIRIT_ICON, MIND_ICON]},
		{"name": "Spirit and Control capped", "result": _with_stat(_with_stat(_result(57.0, 2, 4, 0, 0), SPIRIT, 5.0, true), CONTROL, 0.0, true),
			"line": "Cycle   %s +57   %s capped   %s capped" % [MADRA_ICON, SPIRIT_ICON, CONTROL_ICON]},
		{"name": "nothing followed", "result": _result(0.0, 0, 4, 0, 0), "line": "Cycle   %s +0" % MADRA_ICON},
		{"name": "less than half an XP", "result": _with_stat(_result(30.0, 0, 0, 0, 0), SPIRIT, 0.4, false), "line": "Cycle   %s +30" % MADRA_ICON},
	]
	for case: Dictionary in cases:
		assert_eq((case.result as CycleResult).log_line(), case.line, case.name)

## The stats a cycle paid, in the screens' order: each that took XP rounding to
## a whole XP or more, and each the cap took XP from.
func test_paid_stats() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no stat", "result": _result(30.0, 0, 4, 0, 0),
			"stats": [] as Array[CharacterAttributesData.AttributeType]},
		{"name": "Spirit, then Control", "result": _with_stat(_result(80.0, 3, 4, 1, 21), SPIRIT, 30.0, false),
			"stats": [SPIRIT, CONTROL] as Array[CharacterAttributesData.AttributeType]},
		{"name": "Mind at the cap", "result": _with_stat(_result(50.0, 0, 0, 0, 0), MIND, 0.0, true),
			"stats": [MIND] as Array[CharacterAttributesData.AttributeType]},
		{"name": "less than half an XP", "result": _with_stat(_result(30.0, 0, 0, 0, 0), SPIRIT, 0.4, false),
			"stats": [] as Array[CharacterAttributesData.AttributeType]},
	]
	for case: Dictionary in cases:
		assert_eq((case.result as CycleResult).get_paid_stats(), case.stats, case.name)

#-----------------------------------------------------------------------------
# A PERFECT CYCLE
#-----------------------------------------------------------------------------

## A result followed throughout or not, with these zone and seal states.
func _played(followed: bool, zones: Array[int], seals: Array[int]) -> CycleResult:
	var result: CycleResult = CycleResult.new()
	result.followed_throughout = followed
	result.zone_states = zones
	result.seal_states = seals
	return result

func test_is_perfect() -> void:
	var p := CyclingZone.State.PERFECT
	var g := CyclingZone.State.GOOD
	var spent := CyclingZone.State.SPENT
	var open := SealNode.State.OPEN
	var missed := SealNode.State.SPENT
	var no_states: Array[int] = []
	var full_capped: CycleResult = _played(true, no_states, no_states)
	full_capped.record_stat_xp(SPIRIT, 0.0, true)
	var cases: Array[Dictionary] = [
		{"name": "zoneless, followed throughout", "result": _played(true, no_states, no_states), "perfect": true},
		{"name": "zoneless, a break", "result": _played(false, no_states, no_states), "perfect": false},
		{"name": "every zone PERFECT", "result": _played(true, [p, p, p, p] as Array[int], no_states), "perfect": true},
		{"name": "one zone GOOD", "result": _played(true, [p, p, g, p] as Array[int], no_states), "perfect": false},
		{"name": "one zone missed", "result": _played(true, [p, spent, p, p] as Array[int], no_states), "perfect": false},
		{"name": "every zone PERFECT but a break", "result": _played(false, [p, p, p, p] as Array[int], no_states), "perfect": false},
		{"name": "every seal opened", "result": _played(true, no_states, [open, open, open] as Array[int]), "perfect": true},
		{"name": "one seal missed", "result": _played(true, no_states, [open, missed, open] as Array[int]), "perfect": false},
		{"name": "a capped stat still counts", "result": full_capped, "perfect": true},
	]
	for case: Dictionary in cases:
		assert_eq((case.result as CycleResult).is_perfect(), case.perfect, case.name)

func test_a_new_result_is_not_perfect() -> void:
	assert_false(CycleResult.new().is_perfect(), "nothing was followed yet")
