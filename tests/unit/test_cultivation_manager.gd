extends GutTest

## Unit tests for CultivationManager: the real add_core_density_xp() level-up
## loop (single and multi-level gains, XP carry-over), its signals, the path
## point milestone awards it hands to PathManager (each paid once per stage,
## even when a failed breakthrough takes the levels back), the Core Density cap
## (levels and XP stop at the stage's cap, core_filled, the full-core log line,
## losing levels), the breakthrough (advance_to_next_stage(): the stage, level
## and XP it sets, its signals and log line, the new stage's own Madra cap and
## milestones), what loading a save does (a level past the cap is clamped to
## it, a save with no milestone ledger is seeded from its level), the stage-name
## lookups, and the AdvancementStageResource XP curve it reads.
##
## Each test runs on a fresh SaveGameData that every manager is re-bound to,
## with CultivationManager's stage list swapped for deterministic test stages.
## Both are restored in after_each().

const Stage := CultivationManager.AdvancementStage
const TMP_SAVE_PATH: String = "user://test_cultivation_manager_save.tres"

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_stage_resources: Array[AdvancementStageResource]
var _save: SaveGameData
## Foundation test curve: 10 XP for level 1, then x1.5 per level
## (10, 15, 22.5, 33.75, ...), all exact in floating point.
var _stage_resource: AdvancementStageResource

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_stage_resources = CultivationManager.advancement_stage_resources

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_save = PersistenceManager.save_game_data
	_save.path_points = 0

	_stage_resource = _make_stage(Stage.FOUNDATION, "Test Foundation", 10.0, 1.5)
	_use_stages([_stage_resource])

func after_each() -> void:
	CultivationManager.advancement_stage_resources = _original_stage_resources
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	if FileAccess.file_exists(TMP_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE_PATH))

## Makes `save` the live save, as if it had just been loaded: `save_data_reset`
## re-binds every manager, and CultivationManager checks the save against its
## stage (the level clamp and the milestone seed), as its `_ready()` does on a
## real boot.
func _load(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	_save = save

func _make_stage(stage: Stage, stage_name: String, base_cost: float, scaling: float) -> AdvancementStageResource:
	var res := AdvancementStageResource.new()
	res.stage_id = stage
	res.stage_name = stage_name
	res.core_density_base_xp_cost = base_cost
	res.core_xp_scaling_factor = scaling
	return res

## Every stage the save can be on must have a resource here: with none,
## get_xp_for_next_level() returns 0, so add_core_density_xp() logs an error and
## levels nothing.
func _use_stages(stages: Array[AdvancementStageResource]) -> void:
	CultivationManager.advancement_stage_resources = stages

## Swaps in a flat curve where every level costs 1 XP, so N XP gives N levels.
func _use_flat_curve() -> void:
	_use_stages([_make_stage(Stage.FOUNDATION, "Flat Foundation", 1.0, 1.0)])

## Makes the fixture's Foundation lead to a flat "Test Copper" stage (1 XP a level,
## 600 Madra plus 10 a level) and lists both stages. Returns Copper.
func _with_copper() -> AdvancementStageResource:
	var copper := _make_stage(Stage.COPPER, "Test Copper", 1.0, 1.0)
	copper.max_madra_base = 600.0
	copper.max_madra_per_core_density_level = 10.0
	_stage_resource.next_stage = copper
	_use_stages([_stage_resource, copper])
	return copper

## The lines LogManager announced since watch_signals(LogManager) that contain `text`.
func _logged_lines_with(text: String) -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		if line.contains(text):
			lines.append(line)
	return lines

#-----------------------------------------------------------------------------
# NEW SAVE
#-----------------------------------------------------------------------------

func test_new_save_starts_at_foundation_level_zero() -> void:
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION)
	assert_eq(CultivationManager.get_core_density_level(), 0.0)
	assert_eq(CultivationManager.get_core_density_xp(), 0.0)

#-----------------------------------------------------------------------------
# XP AND LEVEL PROGRESSION
#-----------------------------------------------------------------------------

## One award from level 0 on the fixture's curve (10, 15, 22.5): the levels it
## buys and the XP it leaves, from an award short of level 1, through the exact
## cost and an overflow, to awards that buy two and three levels.
func test_one_award_buys_levels_and_keeps_the_remainder() -> void:
	var cases: Array[Dictionary] = [
		{"name": "5 of 10 XP, short of level 1", "xp": 5.0, "level": 0.0, "left": 5.0},
		{"name": "the exact cost of level 1", "xp": 10.0, "level": 1.0, "left": 0.0},
		{"name": "10 spent on level 1, 3 left over", "xp": 13.0, "level": 1.0, "left": 3.0},
		{"name": "14.9 left, short of level 2's 15", "xp": 24.9, "level": 1.0, "left": 14.9},
		{"name": "two levels (10 + 15), 5 left over", "xp": 30.0, "level": 2.0, "left": 5.0},
		{"name": "three levels exactly (10 + 15 + 22.5)", "xp": 47.5, "level": 3.0, "left": 0.0},
	]
	for case: Dictionary in cases:
		_save.core_density_level = 0.0
		_save.core_density_xp = 0.0
		CultivationManager.add_core_density_xp(case.xp)
		assert_eq(CultivationManager.get_core_density_level(), case.level, "%s: level" % case.name)
		assert_almost_eq(CultivationManager.get_core_density_xp(), case.left, 0.001, "%s: XP left" % case.name)

func test_xp_accumulates_across_calls_until_level_up() -> void:
	CultivationManager.add_core_density_xp(4.0)
	CultivationManager.add_core_density_xp(5.5)
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "9.5 of 10 XP should not level")
	assert_almost_eq(CultivationManager.get_core_density_xp(), 9.5, 0.001)

	CultivationManager.add_core_density_xp(0.5)
	assert_eq(CultivationManager.get_core_density_level(), 1.0, "the call that reaches 10 XP should level")
	assert_almost_eq(CultivationManager.get_core_density_xp(), 0.0, 0.001)

func test_cost_is_based_on_current_level() -> void:
	_save.core_density_level = 2.0
	# Level 3 costs 10 * 1.5^2 = 22.5, not level 1's 10.
	CultivationManager.add_core_density_xp(22.0)
	assert_eq(CultivationManager.get_core_density_level(), 2.0, "22 XP is short of level 3's 22.5")
	CultivationManager.add_core_density_xp(0.5)
	assert_eq(CultivationManager.get_core_density_level(), 3.0)
	assert_almost_eq(CultivationManager.get_core_density_xp(), 0.0, 0.001)

func test_xp_for_next_level_follows_stage_curve() -> void:
	assert_eq(CultivationManager.get_xp_for_next_level(), 10.0, "level 0 -> 1")
	CultivationManager.add_core_density_xp(25.0)
	assert_eq(CultivationManager.get_xp_for_next_level(), 22.5, "level 2 -> 3")

func test_uses_current_stage_resource() -> void:
	var copper := _make_stage(Stage.COPPER, "Test Copper", 100.0, 1.0)
	_use_stages([_stage_resource, copper])
	_save.current_advancement_stage = Stage.COPPER
	assert_eq(CultivationManager.get_xp_for_next_level(), 100.0, "Copper's curve, not Foundation's")
	CultivationManager.add_core_density_xp(50.0)
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "50 XP is enough at Foundation but not at Copper")

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

func test_xp_updated_emitted_once_with_final_values() -> void:
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(30.0)
	assert_signal_emit_count(CultivationManager, "core_density_xp_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_xp_updated", [5.0, 2.0])

func test_xp_updated_emitted_without_level_up() -> void:
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(5.0)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_xp_updated", [5.0, 0.0])
	assert_signal_not_emitted(CultivationManager, "core_density_level_updated")

func test_level_updated_emitted_for_each_level_gained() -> void:
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(30.0)
	assert_signal_emit_count(CultivationManager, "core_density_level_updated", 2)
	# Each emission carries the XP left after paying for that level.
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [20.0, 1.0], 0)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [5.0, 2.0], 1)

#-----------------------------------------------------------------------------
# PATH POINT MILESTONES
#-----------------------------------------------------------------------------

## One award on the flat curve, from a level the save stands at, with nothing
## paid yet: a Foundation point for each multiple of 10 the award reaches,
## counted by absolute level, not by levels gained. The cases run up to level 9
## and then to 10, cross 10 from level 5, cross 10 and 20 at once, and reach
## level 100, the level that fills the core.
func test_an_award_pays_each_milestone_it_reaches() -> void:
	_use_flat_curve()
	var cases: Array[Dictionary] = [
		{"name": "no point before level 10", "from": 0.0, "xp": 9.0, "level": 9.0, "points": 0},
		{"name": "level 10 is a milestone", "from": 9.0, "xp": 1.0, "level": 10.0, "points": 1},
		{"name": "levels 6-15 cross only the level-10 milestone", "from": 5.0, "xp": 10.0, "level": 15.0, "points": 1},
		{"name": "levels 10 and 20 in one award", "from": 0.0, "xp": 25.0, "level": 25.0, "points": 2},
		{"name": "level 100 fills the core and is a milestone like any other", "from": 99.0, "xp": 1.0, "level": 100.0, "points": 1},
	]
	for case: Dictionary in cases:
		_save.core_density_level = case.from
		_save.core_density_xp = 0.0
		_save.core_density_milestones.clear()
		_save.path_points = 0
		CultivationManager.add_core_density_xp(case.xp)
		assert_eq(CultivationManager.get_core_density_level(), case.level, "%s: level" % case.name)
		assert_eq(PathManager.get_point_balance(), case.points, "%s: points" % case.name)

func test_milestone_points_scale_with_stage() -> void:
	var expected_points: Dictionary = {
		Stage.FOUNDATION: 1,
		Stage.COPPER: 2,
		Stage.IRON: 3,
		Stage.JADE: 4,
	}
	var stages: Array[AdvancementStageResource] = []
	for stage: Stage in expected_points:
		stages.append(_make_stage(stage, "Flat %d" % stage, 1.0, 1.0))
	_use_stages(stages)

	for stage: Stage in expected_points:
		_save.current_advancement_stage = stage
		_save.core_density_level = 0.0
		_save.core_density_xp = 0.0
		_save.path_points = 0
		CultivationManager.add_core_density_xp(10.0)
		assert_eq(PathManager.get_point_balance(), expected_points[stage],
			"level 10 at %s" % Stage.keys()[stage])

## A failed breakthrough takes 5 levels back; climbing them again must not pay
## the level-100 point a second time.
func test_regaining_a_paid_milestone_pays_nothing() -> void:
	_use_flat_curve()
	CultivationManager.add_core_density_xp(100.0)
	assert_eq(PathManager.get_point_balance(), 10, "levels 10 to 100 pay a point each")

	CultivationManager.lose_core_density_levels(5)
	CultivationManager.add_core_density_xp(5.0)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "the five levels are back")
	assert_eq(PathManager.get_point_balance(), 10, "level 100 was paid the first time")

func test_new_milestones_still_pay_after_a_loss() -> void:
	_use_flat_curve()
	CultivationManager.add_core_density_xp(20.0)
	assert_eq(PathManager.get_point_balance(), 2, "levels 10 and 20")

	CultivationManager.lose_core_density_levels(5)
	assert_eq(CultivationManager.get_core_density_level(), 15.0)
	CultivationManager.add_core_density_xp(15.0)
	assert_eq(CultivationManager.get_core_density_level(), 30.0)
	assert_eq(PathManager.get_point_balance(), 3, "level 20 was paid before; only level 30 is new")

#-----------------------------------------------------------------------------
# CORE DENSITY CAP
#-----------------------------------------------------------------------------

func test_levels_stop_at_the_cap() -> void:
	_use_flat_curve()
	CultivationManager.add_core_density_xp(150.0)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "100 of the 150 XP buy levels 1 to 100")
	assert_eq(CultivationManager.get_core_density_xp(), 0.0, "the other 50 are lost, not kept")

## A save from before the cap can stand at it with XP in hand: the next award
## drops that too.
func test_xp_at_the_cap_is_lost() -> void:
	_save.core_density_level = 100.0
	_save.core_density_xp = 3.0
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(50.0)
	assert_eq(CultivationManager.get_core_density_level(), 100.0)
	assert_eq(CultivationManager.get_core_density_xp(), 0.0, "the 3 held and the 50 earned are both lost")
	assert_signal_not_emitted(CultivationManager, "core_density_level_updated")
	assert_signal_emit_count(CultivationManager, "core_density_xp_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_xp_updated", [0.0, 100.0])

func test_cap_comes_from_the_stage() -> void:
	var short_stage := _make_stage(Stage.FOUNDATION, "Short Foundation", 1.0, 1.0)
	short_stage.max_core_density_level = 20
	_use_stages([short_stage])
	assert_eq(CultivationManager.get_core_density_cap(), 20)
	CultivationManager.add_core_density_xp(50.0)
	assert_eq(CultivationManager.get_core_density_level(), 20.0, "the stage's cap, not the default 100")

func test_is_core_full() -> void:
	_save.core_density_level = 99.0
	assert_false(CultivationManager.is_core_full(), "one level short")
	_save.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full())

func test_core_filled_once_at_the_cap() -> void:
	_use_flat_curve()
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(150.0)
	assert_signal_emit_count(CultivationManager, "core_filled", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_filled", [Stage.FOUNDATION])
	CultivationManager.add_core_density_xp(10.0)
	assert_signal_emit_count(CultivationManager, "core_filled", 1, "a full core does not fill again")

func test_full_core_log_line_needs_a_next_stage() -> void:
	var flat := _make_stage(Stage.FOUNDATION, "Flat Foundation", 1.0, 1.0)
	_use_stages([flat])
	watch_signals(LogManager)

	CultivationManager.add_core_density_xp(100.0)
	assert_eq(_logged_lines_with(CultivationManager.CORE_FULL_LOG).size(), 0, "no stage waits, so a full core says nothing")

	_save.core_density_level = 0.0
	flat.next_stage = _make_stage(Stage.COPPER, "Test Copper", 10.0, 1.0)
	CultivationManager.add_core_density_xp(100.0)
	var said: Array[String] = _logged_lines_with(CultivationManager.CORE_FULL_LOG)
	assert_eq(said.size(), 1, "a stage waits, so the full core says so once")
	assert_eq(said.front(), CultivationManager.CORE_FULL_LOG, "as plain text, with no colour tag")

## A cost of 0 passes every XP check. The guard stops there; without it the
## call would climb to the cap for nothing.
func test_a_free_level_does_not_level() -> void:
	_use_stages([_make_stage(Stage.FOUNDATION, "Free", 0.0, 1.0)])
	CultivationManager.add_core_density_xp(5.0)
	assert_eq(CultivationManager.get_core_density_level(), 0.0)

func test_no_stage_resource_does_not_level() -> void:
	var no_stages: Array[AdvancementStageResource] = []
	_use_stages(no_stages)
	CultivationManager.add_core_density_xp(5.0)
	assert_eq(CultivationManager.get_core_density_level(), 0.0)
	assert_eq(CultivationManager.get_core_density_cap(), 0, "no stage resource, no cap")
	assert_false(CultivationManager.is_core_full(), "and a cap of 0 is not a full core")

## The level that fills the core drops the spare XP before it announces itself,
## so the cabinet never sees a full core holding XP.
func test_the_filling_level_up_announces_an_empty_core() -> void:
	_use_flat_curve()
	watch_signals(CultivationManager)
	CultivationManager.add_core_density_xp(150.0)
	assert_signal_emit_count(CultivationManager, "core_density_level_updated", 100)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [51.0, 99.0], 98)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [0.0, 100.0], 99)

func test_losing_levels() -> void:
	_save.core_density_level = 100.0
	watch_signals(CultivationManager)
	CultivationManager.lose_core_density_levels(5)
	assert_eq(CultivationManager.get_core_density_level(), 95.0)
	assert_eq(CultivationManager.get_core_density_xp(), 0.0)
	assert_signal_emit_count(CultivationManager, "core_density_level_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [0.0, 95.0])
	assert_signal_emit_count(CultivationManager, "core_density_xp_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_xp_updated", [0.0, 95.0])

func test_losing_more_levels_than_held_stops_at_zero() -> void:
	_save.core_density_level = 3.0
	_save.core_density_xp = 4.0
	CultivationManager.lose_core_density_levels(5)
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "never below level 0")
	assert_eq(CultivationManager.get_core_density_xp(), 0.0, "the partial level goes with the levels")

func test_losing_levels_keeps_path_points() -> void:
	_save.core_density_level = 100.0
	_save.path_points = 7
	CultivationManager.lose_core_density_levels(5)
	assert_eq(PathManager.get_point_balance(), 7, "the points were earned; losing the levels does not take them back")

func test_has_next_stage() -> void:
	assert_false(CultivationManager.has_next_stage(), "the fixture's Foundation leads nowhere")
	_stage_resource.next_stage = _make_stage(Stage.COPPER, "Test Copper", 10.0, 1.0)
	assert_true(CultivationManager.has_next_stage())

#-----------------------------------------------------------------------------
# BREAKTHROUGH
#-----------------------------------------------------------------------------

## The core holds 3 XP, which a full core never does in play: the breakthrough
## must reset the XP itself, not rely on it being 0 already.
func test_breakthrough_moves_to_the_next_stage() -> void:
	_with_copper()
	_save.core_density_level = 100.0
	_save.core_density_xp = 3.0
	assert_true(CultivationManager.advance_to_next_stage())
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER)
	assert_eq(CultivationManager.get_core_density_level(), 0.0, "Copper starts with an empty core")
	assert_eq(CultivationManager.get_core_density_xp(), 0.0)

func test_breakthrough_signals() -> void:
	_with_copper()
	_save.core_density_level = 100.0
	watch_signals(CultivationManager)
	CultivationManager.advance_to_next_stage()
	assert_signal_emit_count(CultivationManager, "advancement_stage_changed", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "advancement_stage_changed", [Stage.COPPER])
	assert_signal_emit_count(CultivationManager, "core_density_level_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_level_updated", [0.0, 0.0])
	assert_signal_emit_count(CultivationManager, "core_density_xp_updated", 1)
	assert_signal_emitted_with_parameters(CultivationManager, "core_density_xp_updated", [0.0, 0.0])

func test_breakthrough_logs() -> void:
	_with_copper()
	_save.core_density_level = 100.0
	watch_signals(LogManager)
	CultivationManager.advance_to_next_stage()
	assert_eq(_logged_lines_with("You break through to Test Copper.").size(), 1, "the line names the new stage")

func test_no_breakthrough_without_a_next_stage() -> void:
	_save.core_density_level = 100.0
	watch_signals(CultivationManager)
	watch_signals(LogManager)
	assert_false(CultivationManager.advance_to_next_stage(), "the fixture's Foundation leads nowhere")
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.FOUNDATION)
	assert_eq(CultivationManager.get_core_density_level(), 100.0)
	assert_signal_not_emitted(CultivationManager, "advancement_stage_changed")
	assert_eq(_logged_lines_with("You break through").size(), 0, "a refused breakthrough says nothing")

func test_madra_cap_follows_the_new_stage() -> void:
	_with_copper()
	_save.core_density_level = 100.0
	CultivationManager.advance_to_next_stage()
	assert_eq(CultivationManager.get_max_madra(), 600.0, "Test Copper's base, at its level 0")

## Foundation's ledger already stands at 100 for a player who paid it all. Copper
## keeps its own, so it still pays from its level 10.
func test_the_new_stage_pays_its_own_milestones() -> void:
	_with_copper()
	_save.core_density_level = 100.0
	_save.core_density_milestones[Stage.FOUNDATION] = 100
	CultivationManager.advance_to_next_stage()
	CultivationManager.add_core_density_xp(10.0)
	assert_eq(CultivationManager.get_core_density_level(), 10.0)
	assert_eq(PathManager.get_point_balance(), 2, "level 10 at Copper is worth 2 points")

#-----------------------------------------------------------------------------
# SAVE DATA
#-----------------------------------------------------------------------------

## Under the old rule a save paid every milestone up to its level, so a save from
## before the ledger must not pay them again when it loads.
func test_an_old_save_is_seeded_from_its_level() -> void:
	_use_flat_curve()
	var old_save := SaveGameData.new()
	old_save.core_density_level = 45.0
	_load(old_save)
	assert_eq(_save.core_density_milestones.get(Stage.FOUNDATION, -1), 40, "levels 10 to 40 were paid; 45 rounds down to 40")

	CultivationManager.add_core_density_xp(5.0)
	assert_eq(CultivationManager.get_core_density_level(), 50.0)
	assert_eq(PathManager.get_point_balance(), 1, "only level 50 is new")

## A save from before the cap can stand past it. It loads at the cap with no XP
## and keeps the path points it earned on the way up.
func test_a_save_past_the_cap_loads_at_the_cap() -> void:
	var long_save := SaveGameData.new()
	long_save.core_density_level = 130.0
	long_save.core_density_xp = 12.5
	long_save.path_points = 13
	_load(long_save)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "the stage's cap, not the 130 it was saved at")
	assert_eq(CultivationManager.get_core_density_xp(), 0.0, "a full core holds no XP")
	assert_eq(PathManager.get_point_balance(), 13, "the points were earned; the clamp does not take them back")
	assert_eq(_save.core_density_milestones.get(Stage.FOUNDATION, -1), 100, "seeded from the clamped level, not the saved one")

func test_no_clamp_without_a_stage() -> void:
	var no_stages: Array[AdvancementStageResource] = []
	_use_stages(no_stages)
	var long_save := SaveGameData.new()
	long_save.core_density_level = 130.0
	_load(long_save)
	assert_eq(CultivationManager.get_core_density_level(), 130.0, "no stage resource, no cap to clamp to")

## The flow the ledger exists for: a failed breakthrough, a restart, then the
## levels climbed again. The ledger must reach the save file, and the load must
## keep it instead of seeding it from level 95, or level 100 would pay twice.
func test_the_ledger_survives_a_restart() -> void:
	_use_flat_curve()
	CultivationManager.add_core_density_xp(100.0)
	CultivationManager.lose_core_density_levels(5)
	assert_eq(ResourceSaver.save(_save, TMP_SAVE_PATH), OK)

	_load(ResourceLoader.load(TMP_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData)
	assert_eq(CultivationManager.get_core_density_level(), 95.0)
	assert_eq(_save.core_density_milestones.get(Stage.FOUNDATION, -1), 100, "saved with the level, and not seeded again from level 95")

	CultivationManager.add_core_density_xp(5.0)
	assert_eq(CultivationManager.get_core_density_level(), 100.0)
	assert_eq(PathManager.get_point_balance(), 10, "level 100 was paid before the restart")

func test_reset_clears_the_milestones() -> void:
	var data := SaveGameData.new()
	data.core_density_milestones[Stage.FOUNDATION] = 40
	data.reset()
	assert_true(data.core_density_milestones.is_empty(), "a new game has paid nothing")

#-----------------------------------------------------------------------------
# STAGE NAMES
#-----------------------------------------------------------------------------

func test_current_stage_name_comes_from_stage_resource() -> void:
	assert_eq(CultivationManager.get_current_advancement_stage_name(), "Test Foundation")

func test_stage_name_lookup_by_stage() -> void:
	_use_stages([_stage_resource, _make_stage(Stage.COPPER, "Test Copper", 10.0, 1.0)])
	assert_eq(CultivationManager.get_advancement_stage_name(Stage.COPPER), "Test Copper")
	assert_eq(CultivationManager.get_advancement_stage_name(Stage.IRON), "Unknown", "no Iron resource")

#-----------------------------------------------------------------------------
# ADVANCEMENT STAGE ENUM
#-----------------------------------------------------------------------------

func test_advancement_stage_enum_values() -> void:
	# Saves store the stage as an int, so reordering the enum would break them.
	assert_eq(Stage.FOUNDATION, 0)
	assert_eq(Stage.COPPER, 1)
	assert_eq(Stage.IRON, 2)
	assert_eq(Stage.JADE, 3)
	assert_eq(Stage.SILVER, 4)

#-----------------------------------------------------------------------------
# ADVANCEMENT STAGE RESOURCE: XP CURVE
#-----------------------------------------------------------------------------

## get_xp_for_level() is base x scaling^(level - 1): level 1 costs the base.
## The cases cover the fixture's x1.5 curve at levels 1 to 5 (each costing more
## than the last), a flat x1.0 curve where every level costs the base, and a
## steep x2.0 curve.
func test_xp_for_level_follows_base_times_scaling() -> void:
	var cases: Array[Dictionary] = [
		{"name": "x1.5 level 1", "base": 10.0, "scaling": 1.5, "level": 1, "xp": 10.0},
		{"name": "x1.5 level 2", "base": 10.0, "scaling": 1.5, "level": 2, "xp": 15.0},
		{"name": "x1.5 level 3", "base": 10.0, "scaling": 1.5, "level": 3, "xp": 22.5},
		{"name": "x1.5 level 4", "base": 10.0, "scaling": 1.5, "level": 4, "xp": 33.75},
		{"name": "x1.5 level 5", "base": 10.0, "scaling": 1.5, "level": 5, "xp": 50.625},
		{"name": "x1.0 level 1", "base": 20.0, "scaling": 1.0, "level": 1, "xp": 20.0},
		{"name": "x1.0 level 5", "base": 20.0, "scaling": 1.0, "level": 5, "xp": 20.0},
		{"name": "x1.0 level 10", "base": 20.0, "scaling": 1.0, "level": 10, "xp": 20.0},
		{"name": "x2.0 level 1", "base": 5.0, "scaling": 2.0, "level": 1, "xp": 5.0},
		{"name": "x2.0 level 2", "base": 5.0, "scaling": 2.0, "level": 2, "xp": 10.0},
		{"name": "x2.0 level 3", "base": 5.0, "scaling": 2.0, "level": 3, "xp": 20.0},
	]
	for case: Dictionary in cases:
		var stage := _make_stage(Stage.FOUNDATION, case.name, case.base, case.scaling)
		assert_almost_eq(stage.get_xp_for_level(case.level), case.xp, 0.001, case.name)
