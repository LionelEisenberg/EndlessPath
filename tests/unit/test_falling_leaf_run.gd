extends GutTest

## Unit tests for FallingLeafRun, the judge of one set of Falling Leaf: a leaf drops
## from the branch each 2 s rep and sways down to the ground in 3.6 s, and a click
## catches the nearest leaf in reach, judged by how close to its middle it came.
## A leaf nobody catches lands. Every time is on the set's own clock in
## microseconds, from the press that started it, and every point is in the
## stage's px. The leaves here are built in each test, most of them falling
## straight down, so every distance is exact.

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss
const Leaf = FallingLeafRun.Leaf

## One second on the set's clock.
const S: int = 1_000_000
const EPS: float = 0.000001
## Half way down: a leaf dropped from TOP is at HALF_Y 1.8 s after its drop.
const TOP: float = 50.0
const HALF: int = 1_800_000
const HALF_Y: float = 453.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of ten 2 s reps, as Falling Leaf's.
func _drill() -> DrillData:
	var drill := DrillData.new()
	drill.id = "test_leaf"
	drill.strength_xp_per_rep = 4.0
	drill.minor_stat = CharacterAttributesData.AttributeType.AGILITY
	drill.minor_xp_per_rep = 2.0
	drill.health_per_rep = 2.0
	drill.input_kind = DrillData.InputKind.CATCH
	drill.rep_seconds = 2.0
	drill.reps_per_set = 10
	return drill

## A leaf dropped at `drop` from (x, TOP), falling straight down unless swayed.
func _leaf(drop: int, x: float, sway: float = 0.0) -> Leaf:
	return Leaf.new(drop, x, TOP, sway, 2 * S, 0.0)

## A run of the given leaves.
func _run(leaves: Array) -> FallingLeafRun:
	var typed: Array[Leaf] = []
	for leaf: Leaf in leaves:
		typed.append(leaf)
	return FallingLeafRun.new(_drill(), typed)

## A run of ten leaves, one dropped every 2 s at x 200.
func _ten() -> FallingLeafRun:
	var leaves: Array = []
	for rep: int in 10:
		leaves.append(_leaf(rep * 2 * S, 200.0))
	return _run(leaves)

#-----------------------------------------------------------------------------
# A CATCH
#-----------------------------------------------------------------------------

## The canvas's windows: within 12 px of the leaf's middle Perfect (the palm),
## 24 Good (the fingers), 36 OK (a brush), each edge in the better tier; up to
## 48 px a Miss, too far.
func test_a_catch_is_judged_by_how_close_to_the_leaf() -> void:
	var cases: Array[Dictionary] = [
		{"off": 0.0, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"off": 12.0, "tier": Tier.PERFECT, "miss": Miss.NONE},
		{"off": 12.5, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"off": 24.0, "tier": Tier.GOOD, "miss": Miss.NONE},
		{"off": 36.0, "tier": Tier.OK, "miss": Miss.NONE},
		{"off": 40.0, "tier": Tier.MISS, "miss": Miss.TOO_FAR},
	]
	for case: Dictionary in cases:
		var run: FallingLeafRun = _run([_leaf(0, 200.0)])
		assert_eq(run.leaf_position(0, HALF), Vector2(200.0, HALF_Y), "precondition: half way down")
		var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(200.0 + case["off"], HALF_Y))
		assert_eq(judged.size(), 1, "%.1f px off: one judgement" % case["off"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "the first leaf")
		assert_eq(judged[0].tier, case["tier"], "%.1f px off: the tier" % case["off"])
		assert_eq(judged[0].miss, case["miss"], "%.1f px off: the reason" % case["off"])
		assert_eq(judged[0].at_usec, HALF, "judged at the click")
		assert_eq(judged[0].point, Vector2(200.0, HALF_Y), "where the leaf was")

func test_a_click_far_from_every_leaf_does_nothing() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 200.0)])
	assert_eq(run.press_at(HALF, Vector2(200.0 + 49.0, HALF_Y)).size(), 0, "49 px off is out of reach")
	assert_eq(run.press_at(HALF, Vector2(480.0, 60.0)).size(), 0, "nor anywhere else")
	assert_eq(run.get_judged_count(), 0)

## Review Focus 2: one try a leaf. A near miss loses it; a stray click costs nothing.
func test_a_near_miss_loses_the_leaf_and_a_far_click_does_nothing() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 200.0)])
	var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(240.0, HALF_Y))
	assert_eq(judged.size(), 1, "40 px off misses the leaf")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.TOO_FAR)
	assert_eq(run.press_at(HALF + 1, Vector2(200.0, HALF_Y)).size(), 0, "the leaf has slipped away")
	assert_eq(run.advance(4 * S).size(), 0, "and does not land a second time")

func test_the_nearest_leaf_is_caught() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 100.0), _leaf(0, 140.0)])
	var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(124.0, HALF_Y))
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1, "16 px from the second leaf, 24 from the first")
		assert_eq(judged[0].tier, Tier.GOOD)

func test_a_press_with_no_aim_catches_nothing() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 200.0)])
	assert_eq(run.press(HALF).size(), 0, "a catch needs a point")

#-----------------------------------------------------------------------------
# A LEAF'S FALL
#-----------------------------------------------------------------------------

func test_a_leaf_nobody_catches_lands() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 200.0)])
	assert_eq(run.advance(FallingLeafRun.FALL_USEC - 1).size(), 0, "still in the air")
	var judged: Array[DrillRun.Judgement] = run.advance(FallingLeafRun.FALL_USEC)
	assert_eq(judged.size(), 1, "it lands 3.6 s after its drop")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.LANDED)
		assert_eq(judged[0].at_usec, FallingLeafRun.FALL_USEC)
		assert_eq(judged[0].point, Vector2(200.0, FallingLeafRun.GROUND_Y), "on the ground line")
	assert_false(run.is_airborne(0, 4 * S), "and stays there")

func test_a_leaf_falls_and_sways_along_its_path() -> void:
	var run: FallingLeafRun = _run([_leaf(S, 200.0, 20.0)])
	assert_false(run.is_airborne(0, S - 1), "not dropped yet")
	assert_true(run.is_airborne(0, S), "dropped")
	assert_eq(run.leaf_position(0, S), Vector2(200.0, TOP), "from the branch")
	var quarter: Vector2 = run.leaf_position(0, S + 500_000)
	assert_almost_eq(quarter.x, 220.0, EPS, "a quarter of its sway later, at its widest")
	assert_almost_eq(run.leaf_position(0, S + HALF).y, HALF_Y, EPS, "half way down at 1.8 s")
	var landed: Vector2 = run.leaf_position(0, S + FallingLeafRun.FALL_USEC)
	assert_almost_eq(landed.y, FallingLeafRun.GROUND_Y, EPS, "on the ground at 3.6 s")
	assert_eq(run.leaf_position(0, 9 * S), landed, "where it stays")

#-----------------------------------------------------------------------------
# A SET
#-----------------------------------------------------------------------------

## Review Focus 1: a hitch never changes a result. Each leaf nobody caught lands
## at its own time, in order, however late the frame comes.
func test_a_long_gap_judges_each_rep_in_order() -> void:
	var run: FallingLeafRun = _ten()
	var judged: Array[DrillRun.Judgement] = run.advance(25 * S)
	assert_eq(judged.size(), 10, "ten leaves")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].miss, Miss.LANDED)
		assert_eq(judged[index].at_usec, index * 2 * S + FallingLeafRun.FALL_USEC, "as its own leaf landed")
	assert_eq(run.get_end_usec(), 18 * S + FallingLeafRun.FALL_USEC, "the set ends when the last leaf is down")

func test_catches_come_out_of_turn() -> void:
	var run: FallingLeafRun = _run([_leaf(0, 100.0), _leaf(2 * S, 300.0)])
	var at: int = 2 * S + 900_000
	var judged: Array[DrillRun.Judgement] = run.press_at(at, run.leaf_position(1, at))
	assert_eq(judged.size(), 1, "the second leaf caught first")
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1)
	judged = run.advance(FallingLeafRun.FALL_USEC)
	assert_eq(judged.size(), 1, "then the first one lands")
	if judged.size() == 1:
		assert_eq(judged[0].rep, 0)
		assert_eq(judged[0].miss, Miss.LANDED)
	assert_eq(run.get_end_usec(), 4 * S, "every leaf judged: the set ends with its last rep's slot")

#-----------------------------------------------------------------------------
# THE LEAVES' PATHS
#-----------------------------------------------------------------------------

## The leaves a set drops: one a rep at its slot's start, from the branch between
## the drop range's ends, swaying 16 to 32 px over 1.4 to 2 s. A seed always makes
## the same leaves.
func test_the_leaf_paths_stay_on_the_board() -> void:
	var leaves: Array[Leaf] = FallingLeafRun.leaf_paths(7, _drill())
	assert_eq(leaves.size(), 10, "a leaf a rep")
	for index: int in leaves.size():
		var leaf: Leaf = leaves[index]
		assert_eq(leaf.drop_usec, index * 2 * S, "leaf %d drops at its slot's start" % index)
		assert_between(leaf.x, FallingLeafRun.DROP_X_MIN, FallingLeafRun.DROP_X_MAX, "leaf %d's x" % index)
		assert_almost_eq(leaf.top_y, FallingLeafRun.BRANCH_Y_AT_0 + leaf.x * FallingLeafRun.BRANCH_SLOPE, EPS, "leaf %d hangs from the branch" % index)
		assert_between(leaf.sway_px, FallingLeafRun.SWAY_MIN_PX, FallingLeafRun.SWAY_MAX_PX, "leaf %d's sway" % index)
		assert_between(leaf.sway_period_usec, FallingLeafRun.SWAY_MIN_USEC, FallingLeafRun.SWAY_MAX_USEC, "leaf %d's swing" % index)
	assert_eq(_describe(FallingLeafRun.leaf_paths(7, _drill())), _describe(leaves), "the same seed, the same leaves")
	assert_ne(_describe(FallingLeafRun.leaf_paths(8, _drill())), _describe(leaves), "another seed, other leaves")

func _describe(leaves: Array[Leaf]) -> Array:
	var rows: Array = []
	for leaf: Leaf in leaves:
		rows.append([leaf.drop_usec, leaf.x, leaf.top_y, leaf.sway_px, leaf.sway_period_usec, leaf.sway_phase])
	return rows
