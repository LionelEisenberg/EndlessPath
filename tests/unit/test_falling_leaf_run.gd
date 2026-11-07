extends GutTest

## Unit tests for FallingLeafRun, the judge of one set of Falling Leaf: each leaf
## hangs on the branch until a press away from every falling leaf shakes it down
## (#143), at most two falling at once; it sways down to the ground in 3.6 s, and a
## click catches the nearest leaf in reach, judged by how close to its middle it
## came. A leaf nobody catches lands. Every time is on the set's own clock in
## microseconds, from the press that started it, and every point is in the stage's
## px. The leaves here are built in each test, most of them falling straight down,
## so every distance is exact.

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
## A point far from every leaf: a press there shakes the branch.
const FAR: Vector2 = Vector2(-1000, -1000)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drill of ten reps with a 2 s Auto pace, as Falling Leaf's.
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

## A leaf hanging from (x, TOP) until shaken down, falling straight down unless
## swayed.
func _leaf(x: float, sway: float = 0.0) -> Leaf:
	return Leaf.new(x, TOP, sway, 2 * S, 0.0)

## A run of the given leaves.
func _run(leaves: Array) -> FallingLeafRun:
	var typed: Array[Leaf] = []
	for leaf: Leaf in leaves:
		typed.append(leaf)
	return FallingLeafRun.new(_drill(), typed)

## A run of ten leaves at x 200.
func _ten() -> FallingLeafRun:
	var leaves: Array = []
	for rep: int in 10:
		leaves.append(_leaf(200.0))
	return _run(leaves)

## A run of one leaf at x 200, shaken down at 0.
func _one_dropped() -> FallingLeafRun:
	var run: FallingLeafRun = _run([_leaf(200.0)])
	assert_eq(run.press_at(0, FAR).size(), 0, "precondition: the first press shakes, judging nothing")
	return run

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
		var run: FallingLeafRun = _one_dropped()
		assert_eq(run.leaf_position(0, HALF), Vector2(200.0, HALF_Y), "precondition: half way down")
		var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(200.0 + case["off"], HALF_Y))
		assert_eq(judged.size(), 1, "%.1f px off: one judgement" % case["off"])
		if judged.size() != 1:
			continue
		assert_eq(judged[0].rep, 0, "the first leaf")
		assert_eq(judged[0].tier, case["tier"], "%.1f px off: the tier" % case["off"])
		assert_eq(judged[0].miss, case["miss"], "%.1f px off: the reason" % case["off"])
		assert_eq(judged[0].at_usec, HALF, "judged at the click")
		assert_eq(judged[0].point, Vector2(200.0 + case["off"], HALF_Y), "where the click came")

## A press further than 48 px from every falling leaf shakes the branch: the next
## leaf drops then, from where it hung.
func test_a_press_away_from_the_leaves_drops_the_next() -> void:
	var run: FallingLeafRun = _run([_leaf(200.0), _leaf(300.0)])
	run.press_at(0, FAR)
	assert_eq(run.press_at(HALF, Vector2(200.0 + 49.0, HALF_Y)).size(), 0, "49 px off the leaf catches nothing")
	assert_true(run.is_dropped(1), "and shakes down the next leaf")
	assert_eq(run.leaf_position(1, HALF), Vector2(300.0, TOP), "from the branch, at that press")
	assert_true(run.is_airborne(1, HALF + 1))

## Review Focus 2: one try a leaf. A near miss loses it.
func test_a_near_miss_loses_the_leaf() -> void:
	var run: FallingLeafRun = _one_dropped()
	var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(240.0, HALF_Y))
	assert_eq(judged.size(), 1, "40 px off misses the leaf")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.TOO_FAR)
	assert_eq(run.press_at(HALF + 1, Vector2(200.0, HALF_Y)).size(), 0, "the leaf has slipped away")
	assert_eq(run.advance(4 * S).size(), 0, "and does not land a second time")

func test_the_nearest_leaf_is_caught() -> void:
	var run: FallingLeafRun = _run([_leaf(100.0), _leaf(140.0)])
	run.press_at(0, FAR)
	run.press_at(0, FAR)
	var judged: Array[DrillRun.Judgement] = run.press_at(HALF, Vector2(124.0, HALF_Y))
	assert_eq(judged.size(), 1)
	if judged.size() == 1:
		assert_eq(judged[0].rep, 1, "16 px from the second leaf, 24 from the first")
		assert_eq(judged[0].tier, Tier.GOOD)

## A press with no point catches nothing: it shakes the branch.
func test_a_press_with_no_aim_shakes_the_branch() -> void:
	var run: FallingLeafRun = _run([_leaf(200.0)])
	assert_eq(run.press(0).size(), 0)
	assert_true(run.is_dropped(0))

#-----------------------------------------------------------------------------
# THE BRANCH
#-----------------------------------------------------------------------------

## The press that starts a set shakes down the first leaf.
func test_the_first_press_shakes_down_the_first_leaf() -> void:
	var run: FallingLeafRun = _run([_leaf(200.0), _leaf(300.0)])
	assert_false(run.is_dropped(0), "it hangs before the first press")
	run.press_at(0, FAR)
	assert_true(run.is_dropped(0))
	assert_false(run.is_dropped(1), "one leaf a shake")

## Two leaves fall at most: a shake while two fall drops nothing, and the next
## leaf hangs again once one is caught or lands.
func test_at_most_two_leaves_fall_at_once() -> void:
	var run: FallingLeafRun = _run([_leaf(100.0), _leaf(200.0), _leaf(300.0)])
	run.press_at(0, FAR)
	run.press_at(500_000, FAR)
	assert_eq(run.hanging_leaf_at(S), -1, "two in the air: no leaf hangs to shake")
	run.press_at(S, FAR)
	assert_false(run.is_dropped(2), "the shake drops nothing")
	run.advance(FallingLeafRun.FALL_USEC)
	assert_eq(run.hanging_leaf_at(FallingLeafRun.FALL_USEC), 2, "the first landed: the third hangs ready")
	run.press_at(3_700_000, FAR)
	assert_true(run.is_dropped(2))

## Review Focus 2: no leaf drops on its own, however long the player waits.
func test_no_leaf_drops_on_its_own() -> void:
	var run: FallingLeafRun = _ten()
	run.press_at(0, FAR)
	var judged: Array[DrillRun.Judgement] = run.advance(60 * S)
	assert_eq(judged.size(), 1, "the first leaf lands")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.LANDED)
	assert_false(run.is_dropped(1), "and nothing else falls")

## The next leaf hangs under the branch where it will drop until it is shaken.
func test_the_next_leaf_hangs_until_shaken() -> void:
	var run: FallingLeafRun = _run([_leaf(200.0), _leaf(300.0)])
	assert_eq(run.hanging_leaf_at(0), 0, "before the set, the first leaf hangs")
	assert_eq(run.leaf_position(0, 5 * S), Vector2(200.0, TOP), "on the branch")
	run.press_at(S, FAR)
	assert_eq(run.hanging_leaf_at(S), 1, "then the second")
	assert_eq(run.leaf_position(1, S), Vector2(300.0, TOP))

## The rep in play's motion is the oldest falling leaf's fall; 0 with none.
func test_rep_progress_follows_the_oldest_falling_leaf() -> void:
	var run: FallingLeafRun = _run([_leaf(100.0), _leaf(300.0)])
	assert_eq(run.rep_progress_at(0), 0.0, "nothing falls yet")
	run.press_at(0, FAR)
	run.advance(900_000)
	assert_almost_eq(run.rep_progress_at(900_000), 0.25, EPS, "a quarter of its fall")
	run.press_at(S, FAR)
	run.press_at(HALF, run.leaf_position(0, HALF))
	assert_almost_eq(run.rep_progress_at(HALF), 0.8 / 3.6, EPS, "the second, once the first is caught")

#-----------------------------------------------------------------------------
# A LEAF'S FALL
#-----------------------------------------------------------------------------

func test_a_leaf_nobody_catches_lands() -> void:
	var run: FallingLeafRun = _one_dropped()
	assert_eq(run.advance(FallingLeafRun.FALL_USEC - 1).size(), 0, "still in the air")
	var judged: Array[DrillRun.Judgement] = run.advance(FallingLeafRun.FALL_USEC)
	assert_eq(judged.size(), 1, "it lands 3.6 s after its drop")
	if judged.size() == 1:
		assert_eq(judged[0].miss, Miss.LANDED)
		assert_eq(judged[0].at_usec, FallingLeafRun.FALL_USEC)
		assert_eq(judged[0].point, Vector2(200.0, FallingLeafRun.GROUND_Y), "on the ground line")
	assert_false(run.is_airborne(0, 4 * S), "and stays there")

func test_a_leaf_falls_and_sways_along_its_path() -> void:
	var run: FallingLeafRun = _run([_leaf(200.0, 20.0)])
	run.press_at(S, FAR)
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
	run.press_at(0, FAR)
	run.press_at(500_000, FAR)
	var judged: Array[DrillRun.Judgement] = run.advance(25 * S)
	assert_eq(judged.size(), 2, "the two leaves shaken down")
	for index: int in judged.size():
		assert_eq(judged[index].rep, index, "in order")
		assert_eq(judged[index].miss, Miss.LANDED)
		assert_eq(judged[index].at_usec, index * 500_000 + FallingLeafRun.FALL_USEC, "as its own leaf landed")

## The set ends the moment its tenth leaf is caught or lands.
func test_a_set_ends_with_its_tenth_leaf() -> void:
	var run: FallingLeafRun = _ten()
	var judged: Array[DrillRun.Judgement] = []
	for rep: int in 10:
		judged.append_array(run.press_at(rep * 2 * S, FAR))
		judged.append_array(run.press_at(rep * 2 * S + HALF, Vector2(200.0, HALF_Y)))
		if rep < 9:
			assert_eq(run.get_end_usec(), -1, "no end before the tenth")
	assert_eq(judged.size(), 10, "ten catches")
	for judgement: DrillRun.Judgement in judged:
		assert_eq(judgement.tier, Tier.PERFECT)
	assert_eq(run.get_end_usec(), 18 * S + HALF, "at the tenth catch")

func test_catches_come_out_of_turn() -> void:
	var run: FallingLeafRun = _run([_leaf(100.0), _leaf(300.0)])
	run.press_at(0, FAR)
	run.press_at(2 * S, FAR)
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
	assert_eq(run.get_end_usec(), FallingLeafRun.FALL_USEC, "every leaf judged: the set ends with the last")

#-----------------------------------------------------------------------------
# THE LEAVES' PATHS
#-----------------------------------------------------------------------------

## The leaves a set drops: one a rep, hanging from the branch until shaken, the
## first at the branch's middle and the rest between the drop range's ends,
## swaying 16 to 32 px over 1.4 to 2 s. A seed always makes the same leaves.
func test_the_leaf_paths_stay_on_the_board() -> void:
	var leaves: Array[Leaf] = FallingLeafRun.leaf_paths(7, _drill())
	assert_eq(leaves.size(), 10, "a leaf a rep")
	assert_eq(leaves[0].x, FallingLeafRun.FIRST_DROP_X, "the first hangs at the branch's middle")
	for index: int in leaves.size():
		var leaf: Leaf = leaves[index]
		assert_eq(leaf.drop_usec, -1, "leaf %d waits to be shaken" % index)
		assert_between(leaf.x, FallingLeafRun.DROP_X_MIN, FallingLeafRun.DROP_X_MAX, "leaf %d's x" % index)
		assert_almost_eq(leaf.top_y, FallingLeafRun.BRANCH_Y_AT_0 + leaf.x * FallingLeafRun.BRANCH_SLOPE, EPS, "leaf %d hangs from the branch" % index)
		assert_between(leaf.sway_px, FallingLeafRun.SWAY_MIN_PX, FallingLeafRun.SWAY_MAX_PX, "leaf %d's sway" % index)
		assert_between(leaf.sway_period_usec, FallingLeafRun.SWAY_MIN_USEC, FallingLeafRun.SWAY_MAX_USEC, "leaf %d's swing" % index)
	assert_eq(_describe(FallingLeafRun.leaf_paths(7, _drill())), _describe(leaves), "the same seed, the same leaves")
	assert_ne(_describe(FallingLeafRun.leaf_paths(8, _drill())), _describe(leaves), "another seed, other leaves")

func _describe(leaves: Array[Leaf]) -> Array:
	var rows: Array = []
	for leaf: Leaf in leaves:
		rows.append([leaf.x, leaf.top_y, leaf.sway_px, leaf.sway_period_usec, leaf.sway_phase])
	return rows
