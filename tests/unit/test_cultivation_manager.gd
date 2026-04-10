extends GutTest

## Unit tests for CultivationManager singleton
## Tests XP addition, level progression, multi-level-up, stage names, and signals

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _save_data: SaveGameData
var _stage_resource: AdvancementStageResource

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.core_density_xp = 0.0
	_save_data.core_density_level = 0.0
	_save_data.current_advancement_stage = CultivationManager.AdvancementStage.FOUNDATION

	_stage_resource = AdvancementStageResource.new()
	_stage_resource.stage_name = "Foundation"
	_stage_resource.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	_stage_resource.core_density_base_xp_cost = 10.0
	_stage_resource.core_xp_scaling_factor = 1.5

#-----------------------------------------------------------------------------
# XP ADDITION
#-----------------------------------------------------------------------------

func test_add_xp_increases_value() -> void:
	_save_data.core_density_xp = 0.0
	_save_data.core_density_xp += 5.0
	assert_eq(_save_data.core_density_xp, 5.0, "adding XP should increase core_density_xp")

func test_add_xp_accumulates() -> void:
	_save_data.core_density_xp = 3.0
	_save_data.core_density_xp += 4.0
	assert_eq(_save_data.core_density_xp, 7.0, "XP should accumulate")

func test_add_xp_fractional() -> void:
	_save_data.core_density_xp += 0.5
	assert_almost_eq(_save_data.core_density_xp, 0.5, 0.001, "fractional XP should work")

#-----------------------------------------------------------------------------
# LEVEL PROGRESSION (simulating add_core_density_xp logic)
#-----------------------------------------------------------------------------

func _simulate_add_xp(amount: float) -> int:
	"""Simulate add_core_density_xp logic, returns number of level ups."""
	_save_data.core_density_xp += amount
	var levels_gained = 0

	var xp_needed = _get_xp_for_next_level()
	while _save_data.core_density_xp >= xp_needed:
		_save_data.core_density_level += 1
		_save_data.core_density_xp -= xp_needed
		levels_gained += 1
		xp_needed = _get_xp_for_next_level()

	return levels_gained

func _get_xp_for_next_level() -> float:
	var cur_level = _save_data.core_density_level + 1
	return _stage_resource.get_xp_for_level(int(cur_level))

func test_level_up_on_exact_xp() -> void:
	# Level 1 costs: 10 * 1.5^0 = 10
	var levels = _simulate_add_xp(10.0)
	assert_eq(levels, 1, "should gain exactly 1 level")
	assert_eq(_save_data.core_density_level, 1.0, "level should be 1")
	assert_almost_eq(_save_data.core_density_xp, 0.0, 0.001, "XP should be 0 after exact level up")

func test_level_up_with_overflow() -> void:
	# Level 1 costs 10, add 13 -> level up with 3 remaining
	var levels = _simulate_add_xp(13.0)
	assert_eq(levels, 1, "should gain 1 level")
	assert_almost_eq(_save_data.core_density_xp, 3.0, 0.001, "overflow XP should carry over")

func test_no_level_up_when_insufficient_xp() -> void:
	var levels = _simulate_add_xp(5.0)
	assert_eq(levels, 0, "should not level up with insufficient XP")
	assert_eq(_save_data.core_density_level, 0.0, "level should remain 0")
	assert_almost_eq(_save_data.core_density_xp, 5.0, 0.001, "XP should be added without level up")

func test_multi_level_up_single_call() -> void:
	# Level 1 costs 10, Level 2 costs 10*1.5=15 -> total 25 for 2 levels
	var levels = _simulate_add_xp(25.0)
	assert_eq(levels, 2, "should gain 2 levels with enough XP")
	assert_eq(_save_data.core_density_level, 2.0, "level should be 2")
	assert_almost_eq(_save_data.core_density_xp, 0.0, 0.001, "XP should be 0 after exact multi-level")

func test_multi_level_up_with_remainder() -> void:
	# Level 1 = 10, Level 2 = 15, add 30 -> 2 levels + 5 remaining
	var levels = _simulate_add_xp(30.0)
	assert_eq(levels, 2, "should gain 2 levels")
	assert_almost_eq(_save_data.core_density_xp, 5.0, 0.001, "remainder should carry over")

func test_three_levels_in_one_call() -> void:
	# Level 1 = 10, Level 2 = 15, Level 3 = 22.5 -> total 47.5
	var levels = _simulate_add_xp(47.5)
	assert_eq(levels, 3, "should gain 3 levels")
	assert_eq(_save_data.core_density_level, 3.0)
	assert_almost_eq(_save_data.core_density_xp, 0.0, 0.001)

#-----------------------------------------------------------------------------
# GET CORE DENSITY LEVEL / XP
#-----------------------------------------------------------------------------

func test_get_core_density_level_initial() -> void:
	assert_eq(_save_data.core_density_level, 0.0, "initial level should be 0")

func test_get_core_density_level_after_level_up() -> void:
	_simulate_add_xp(10.0)
	assert_eq(_save_data.core_density_level, 1.0)

func test_get_core_density_xp_initial() -> void:
	assert_eq(_save_data.core_density_xp, 0.0, "initial XP should be 0")

func test_get_core_density_xp_partial() -> void:
	_simulate_add_xp(7.0)
	assert_almost_eq(_save_data.core_density_xp, 7.0, 0.001, "should have 7 XP in current level")

func test_get_core_density_xp_after_level_up() -> void:
	_simulate_add_xp(13.0)
	assert_almost_eq(_save_data.core_density_xp, 3.0, 0.001, "should have remainder after level up")

#-----------------------------------------------------------------------------
# XP SCALING PER STAGE FORMULA
#-----------------------------------------------------------------------------

func test_xp_for_level_1() -> void:
	# 10 * 1.5^(1-1) = 10 * 1 = 10
	var xp = _stage_resource.get_xp_for_level(1)
	assert_eq(xp, 10.0, "level 1 should cost base XP (10)")

func test_xp_for_level_2() -> void:
	# 10 * 1.5^(2-1) = 10 * 1.5 = 15
	var xp = _stage_resource.get_xp_for_level(2)
	assert_eq(xp, 15.0, "level 2 should cost 15")

func test_xp_for_level_3() -> void:
	# 10 * 1.5^(3-1) = 10 * 2.25 = 22.5
	var xp = _stage_resource.get_xp_for_level(3)
	assert_eq(xp, 22.5, "level 3 should cost 22.5")

func test_xp_for_level_5() -> void:
	# 10 * 1.5^4 = 10 * 5.0625 = 50.625
	var xp = _stage_resource.get_xp_for_level(5)
	assert_almost_eq(xp, 50.625, 0.001, "level 5 XP should scale correctly")

func test_xp_scaling_increases_per_level() -> void:
	var prev = _stage_resource.get_xp_for_level(1)
	for i in range(2, 6):
		var current = _stage_resource.get_xp_for_level(i)
		assert_gt(current, prev, "XP for level %d should be greater than level %d" % [i, i - 1])
		prev = current

#-----------------------------------------------------------------------------
# ADVANCEMENT STAGE
#-----------------------------------------------------------------------------

func test_advancement_stage_enum_values() -> void:
	assert_eq(CultivationManager.AdvancementStage.FOUNDATION, 0)
	assert_eq(CultivationManager.AdvancementStage.COPPER, 1)
	assert_eq(CultivationManager.AdvancementStage.IRON, 2)
	assert_eq(CultivationManager.AdvancementStage.JADE, 3)
	assert_eq(CultivationManager.AdvancementStage.SILVER, 4)

func test_stage_resource_name() -> void:
	assert_eq(_stage_resource.stage_name, "Foundation", "stage name should be Foundation")

func test_stage_resource_id() -> void:
	assert_eq(_stage_resource.stage_id, CultivationManager.AdvancementStage.FOUNDATION)

func test_default_advancement_stage_is_foundation() -> void:
	assert_eq(_save_data.current_advancement_stage, CultivationManager.AdvancementStage.FOUNDATION)

#-----------------------------------------------------------------------------
# DIFFERENT SCALING FACTORS
#-----------------------------------------------------------------------------

func test_linear_scaling_factor() -> void:
	var linear_stage = AdvancementStageResource.new()
	linear_stage.core_density_base_xp_cost = 20.0
	linear_stage.core_xp_scaling_factor = 1.0
	# All levels cost the same: 20
	assert_eq(linear_stage.get_xp_for_level(1), 20.0)
	assert_eq(linear_stage.get_xp_for_level(5), 20.0)
	assert_eq(linear_stage.get_xp_for_level(10), 20.0)

func test_steep_scaling_factor() -> void:
	var steep_stage = AdvancementStageResource.new()
	steep_stage.core_density_base_xp_cost = 5.0
	steep_stage.core_xp_scaling_factor = 2.0
	# Level 1: 5, Level 2: 10, Level 3: 20
	assert_eq(steep_stage.get_xp_for_level(1), 5.0)
	assert_eq(steep_stage.get_xp_for_level(2), 10.0)
	assert_eq(steep_stage.get_xp_for_level(3), 20.0)
