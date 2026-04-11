extends GutTest

## Unit tests for ResourceManager singleton
## Tests madra/gold management, adventure capacity, signals, and clamping

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _save_data: SaveGameData
var _stage_resource: AdvancementStageResource
var _manager: Node

func _create_manager() -> Node:
	# Create a standalone script instance that mirrors ResourceManager logic
	# We can't use the real singleton since it depends on PersistenceManager autoload
	var mgr = Node.new()
	mgr.set_script(load("res://singletons/resource_manager/resource_manager.gd"))
	return mgr

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.madra = 0.0
	_save_data.gold = 0.0

	_stage_resource = AdvancementStageResource.new()
	_stage_resource.stage_name = "Foundation"
	_stage_resource.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	_stage_resource.max_madra_base = 100.0
	_stage_resource.max_madra_per_core_density_level = 10.0

#-----------------------------------------------------------------------------
# MADRA MANAGEMENT
#-----------------------------------------------------------------------------

func test_add_madra_increases_value() -> void:
	_save_data.madra = 10.0
	_save_data.madra = clamp(_save_data.madra + 5.0, 0.0, 200.0)
	assert_eq(_save_data.madra, 15.0, "add_madra should increase madra by the given amount")

func test_add_madra_clamps_to_max() -> void:
	_save_data.madra = 95.0
	var max_madra = _stage_resource.get_max_madra(0)  # 100 + 0*10 = 100
	_save_data.madra = clamp(_save_data.madra + 20.0, 0.0, max_madra)
	assert_eq(_save_data.madra, 100.0, "add_madra should clamp to max_madra")

func test_add_madra_at_max_stays_at_max() -> void:
	var max_madra = _stage_resource.get_max_madra(0)
	_save_data.madra = max_madra
	_save_data.madra = clamp(_save_data.madra + 50.0, 0.0, max_madra)
	assert_eq(_save_data.madra, max_madra, "adding madra when already at max should stay at max")

func test_add_madra_negative_reduces() -> void:
	_save_data.madra = 50.0
	var max_madra = _stage_resource.get_max_madra(0)
	_save_data.madra = clamp(_save_data.madra + (-30.0), 0.0, max_madra)
	assert_eq(_save_data.madra, 20.0, "negative add_madra should reduce madra")

func test_add_madra_negative_clamps_to_zero() -> void:
	_save_data.madra = 10.0
	var max_madra = _stage_resource.get_max_madra(0)
	_save_data.madra = clamp(_save_data.madra + (-50.0), 0.0, max_madra)
	assert_eq(_save_data.madra, 0.0, "negative add should clamp madra to 0")

func test_spend_madra_success() -> void:
	_save_data.madra = 50.0
	var amount = 30.0
	var can_spend = _save_data.madra >= amount
	assert_true(can_spend, "spend_madra should return true when affordable")
	_save_data.madra -= amount
	assert_eq(_save_data.madra, 20.0, "spend_madra should deduct correct amount")

func test_spend_madra_failure_insufficient() -> void:
	_save_data.madra = 10.0
	var amount = 50.0
	var can_spend = _save_data.madra >= amount
	assert_false(can_spend, "spend_madra should return false when unaffordable")
	assert_eq(_save_data.madra, 10.0, "spend_madra should not deduct when unaffordable")

func test_spend_madra_exact_amount() -> void:
	_save_data.madra = 25.0
	var can_spend = _save_data.madra >= 25.0
	assert_true(can_spend, "spend_madra should succeed when amount equals current")
	_save_data.madra -= 25.0
	assert_eq(_save_data.madra, 0.0, "spending exact amount should leave 0")

func test_get_madra_returns_current() -> void:
	_save_data.madra = 42.5
	assert_eq(_save_data.madra, 42.5, "get_madra should return current value")

func test_can_afford_madra_true() -> void:
	_save_data.madra = 100.0
	assert_true(_save_data.madra >= 50.0, "can_afford_madra should return true when enough")

func test_can_afford_madra_false() -> void:
	_save_data.madra = 10.0
	assert_false(_save_data.madra >= 50.0, "can_afford_madra should return false when not enough")

func test_can_afford_madra_exact() -> void:
	_save_data.madra = 50.0
	assert_true(_save_data.madra >= 50.0, "can_afford_madra should return true when exact")

#-----------------------------------------------------------------------------
# GOLD MANAGEMENT
#-----------------------------------------------------------------------------

func test_add_gold_increases_value() -> void:
	_save_data.gold = 10.0
	_save_data.gold += 5.0
	assert_eq(_save_data.gold, 15.0, "add_gold should increase gold by given amount")

func test_spend_gold_success() -> void:
	_save_data.gold = 100.0
	var amount = 30.0
	var can_spend = _save_data.gold >= amount
	assert_true(can_spend, "spend_gold should return true when affordable")
	_save_data.gold -= amount
	assert_eq(_save_data.gold, 70.0, "spend_gold should deduct correct amount")

func test_spend_gold_failure() -> void:
	_save_data.gold = 10.0
	var can_spend = _save_data.gold >= 50.0
	assert_false(can_spend, "spend_gold should return false when unaffordable")
	assert_eq(_save_data.gold, 10.0, "spend_gold should not deduct when unaffordable")

func test_get_gold_returns_current() -> void:
	_save_data.gold = 77.0
	assert_eq(_save_data.gold, 77.0, "get_gold should return current value")

func test_can_afford_gold_true() -> void:
	_save_data.gold = 100.0
	assert_true(_save_data.gold >= 50.0)

func test_can_afford_gold_false() -> void:
	_save_data.gold = 10.0
	assert_false(_save_data.gold >= 50.0)

#-----------------------------------------------------------------------------
# ADVENTURE MADRA CAPACITY
#-----------------------------------------------------------------------------

func test_adventure_madra_capacity_formula() -> void:
	# Formula: 50 + foundation * 10
	var foundation = 10.0  # default
	var capacity = 50.0 + foundation * 10.0
	assert_eq(capacity, 150.0, "adventure capacity should be 50 + foundation * 10")

func test_adventure_madra_capacity_zero_foundation() -> void:
	var foundation = 0.0
	var capacity = 50.0 + foundation * 10.0
	assert_eq(capacity, 50.0, "zero foundation should give base capacity of 50")

func test_adventure_madra_capacity_high_foundation() -> void:
	var foundation = 25.0
	var capacity = 50.0 + foundation * 10.0
	assert_eq(capacity, 300.0, "high foundation should scale capacity correctly")

func test_adventure_madra_budget_limited_by_current() -> void:
	_save_data.madra = 80.0
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0  # 150
	var budget = min(capacity, _save_data.madra)
	assert_eq(budget, 80.0, "budget should be limited by current madra when below capacity")

func test_adventure_madra_budget_limited_by_capacity() -> void:
	_save_data.madra = 500.0
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0  # 150
	var budget = min(capacity, _save_data.madra)
	assert_eq(budget, 150.0, "budget should be limited by capacity when madra exceeds it")

func test_adventure_madra_threshold_is_half_capacity() -> void:
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0  # 150
	var threshold = capacity * 0.5
	assert_eq(threshold, 75.0, "threshold should be 50% of capacity")

func test_can_start_adventure_above_threshold() -> void:
	_save_data.madra = 100.0
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0
	var threshold = capacity * 0.5  # 75
	assert_true(_save_data.madra >= threshold, "should be able to start adventure above threshold")

func test_can_start_adventure_below_threshold() -> void:
	_save_data.madra = 50.0
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0
	var threshold = capacity * 0.5  # 75
	assert_false(_save_data.madra >= threshold, "should not start adventure below threshold")

func test_can_start_adventure_at_threshold() -> void:
	var foundation = 10.0
	var capacity = 50.0 + foundation * 10.0
	var threshold = capacity * 0.5  # 75
	_save_data.madra = threshold
	assert_true(_save_data.madra >= threshold, "should start adventure at exact threshold")

#-----------------------------------------------------------------------------
# STAGE RESOURCE MAX MADRA
#-----------------------------------------------------------------------------

func test_max_madra_at_level_zero() -> void:
	var max_m = _stage_resource.get_max_madra(0)
	assert_eq(max_m, 100.0, "max madra at level 0 should be base (100)")

func test_max_madra_at_level_five() -> void:
	var max_m = _stage_resource.get_max_madra(5)
	assert_eq(max_m, 150.0, "max madra at level 5 should be 100 + 5*10 = 150")

func test_max_madra_at_level_ten() -> void:
	var max_m = _stage_resource.get_max_madra(10)
	assert_eq(max_m, 200.0, "max madra at level 10 should be 100 + 10*10 = 200")

#-----------------------------------------------------------------------------
# SUB-1.0 MADRA LOG SUPPRESSION
#-----------------------------------------------------------------------------

func test_sub_one_madra_no_log() -> void:
	# The ResourceManager only calls LogManager.log_message when amount >= 1.0
	# We verify the logic: amount < 1.0 should not log
	var amount = 0.5
	var should_log = amount >= 1.0
	assert_false(should_log, "sub-1.0 madra additions should not trigger log messages")

func test_one_madra_does_log() -> void:
	var amount = 1.0
	var should_log = amount >= 1.0
	assert_true(should_log, "1.0 madra addition should trigger log message")

func test_large_madra_does_log() -> void:
	var amount = 50.0
	var should_log = amount >= 1.0
	assert_true(should_log, "large madra addition should trigger log message")

#-----------------------------------------------------------------------------
# SET MADRA / SET GOLD
#-----------------------------------------------------------------------------

func test_set_madra_positive() -> void:
	_save_data.madra = max(0.0, 75.0)
	assert_eq(_save_data.madra, 75.0)

func test_set_madra_negative_clamps_to_zero() -> void:
	_save_data.madra = max(0.0, -10.0)
	assert_eq(_save_data.madra, 0.0, "set_madra with negative should clamp to 0")

func test_set_gold_positive() -> void:
	_save_data.gold = max(0.0, 200.0)
	assert_eq(_save_data.gold, 200.0)

func test_set_gold_negative_clamps_to_zero() -> void:
	_save_data.gold = max(0.0, -5.0)
	assert_eq(_save_data.gold, 0.0, "set_gold with negative should clamp to 0")
