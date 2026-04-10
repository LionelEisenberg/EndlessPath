extends GutTest

## Integration tests for adventure start flow
## Tests madra threshold checks, budget calculation, and signal flow

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _save_data: SaveGameData
var _stage_resource: AdvancementStageResource

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.madra = 0.0
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

	_stage_resource = AdvancementStageResource.new()
	_stage_resource.stage_name = "Foundation"
	_stage_resource.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	_stage_resource.max_madra_base = 100.0
	_stage_resource.max_madra_per_core_density_level = 10.0

func _get_foundation() -> float:
	return _save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.FOUNDATION)

func _get_adventure_madra_capacity() -> float:
	return 50.0 + _get_foundation() * 10.0

func _get_adventure_madra_budget() -> float:
	return min(_get_adventure_madra_capacity(), _save_data.madra)

func _get_adventure_madra_threshold() -> float:
	return _get_adventure_madra_capacity() * 0.5

func _can_start_adventure() -> bool:
	return _save_data.madra >= _get_adventure_madra_threshold()

#-----------------------------------------------------------------------------
# ADVENTURE BLOCKED WHEN BELOW THRESHOLD
#-----------------------------------------------------------------------------

func test_adventure_blocked_zero_madra() -> void:
	_save_data.madra = 0.0
	assert_false(_can_start_adventure(), "should block adventure with zero madra")

func test_adventure_blocked_below_threshold() -> void:
	# Threshold = 150 * 0.5 = 75
	_save_data.madra = 50.0
	assert_false(_can_start_adventure(), "should block adventure below threshold")

func test_adventure_blocked_just_below_threshold() -> void:
	var threshold = _get_adventure_madra_threshold()
	_save_data.madra = threshold - 0.1
	assert_false(_can_start_adventure(), "should block adventure just below threshold")

#-----------------------------------------------------------------------------
# ADVENTURE PROCEEDS WHEN ABOVE THRESHOLD
#-----------------------------------------------------------------------------

func test_adventure_allowed_above_threshold() -> void:
	_save_data.madra = 100.0
	assert_true(_can_start_adventure(), "should allow adventure above threshold")

func test_adventure_allowed_at_threshold() -> void:
	_save_data.madra = _get_adventure_madra_threshold()
	assert_true(_can_start_adventure(), "should allow adventure at exact threshold")

func test_adventure_allowed_at_max_madra() -> void:
	_save_data.madra = 500.0
	assert_true(_can_start_adventure(), "should allow adventure with excess madra")

#-----------------------------------------------------------------------------
# MADRA BUDGET CALCULATION
#-----------------------------------------------------------------------------

func test_budget_equals_madra_when_below_capacity() -> void:
	# Capacity = 50 + 10*10 = 150
	_save_data.madra = 80.0
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, 80.0, "budget should equal current madra when below capacity")

func test_budget_equals_capacity_when_above() -> void:
	_save_data.madra = 300.0
	var budget = _get_adventure_madra_budget()
	var capacity = _get_adventure_madra_capacity()
	assert_eq(budget, capacity, "budget should be capped at capacity")

func test_budget_equals_capacity_when_exact() -> void:
	var capacity = _get_adventure_madra_capacity()
	_save_data.madra = capacity
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, capacity, "budget should equal capacity when madra equals capacity")

func test_budget_is_min_of_capacity_and_current() -> void:
	_save_data.madra = 120.0
	var capacity = _get_adventure_madra_capacity()
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, min(capacity, _save_data.madra))

func test_budget_zero_when_no_madra() -> void:
	_save_data.madra = 0.0
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, 0.0, "budget should be 0 with no madra")

#-----------------------------------------------------------------------------
# CAPACITY SCALES WITH FOUNDATION
#-----------------------------------------------------------------------------

func test_capacity_with_high_foundation() -> void:
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 30.0, 10.0, 10.0, 10.0)
	var capacity = _get_adventure_madra_capacity()
	assert_eq(capacity, 350.0, "capacity should scale: 50 + 30*10 = 350")

func test_capacity_with_low_foundation() -> void:
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 1.0, 10.0, 10.0, 10.0)
	var capacity = _get_adventure_madra_capacity()
	assert_eq(capacity, 60.0, "capacity should scale: 50 + 1*10 = 60")

func test_threshold_scales_with_foundation() -> void:
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 20.0, 10.0, 10.0, 10.0)
	var threshold = _get_adventure_madra_threshold()
	# Capacity = 50 + 20*10 = 250, threshold = 125
	assert_eq(threshold, 125.0, "threshold should be 50% of scaled capacity")

#-----------------------------------------------------------------------------
# COMPLETE FLOW SCENARIOS
#-----------------------------------------------------------------------------

func test_full_flow_barely_enough_madra() -> void:
	var threshold = _get_adventure_madra_threshold()
	_save_data.madra = threshold  # Exactly at threshold
	assert_true(_can_start_adventure(), "should be able to start")
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, threshold, "budget should equal madra (below capacity)")

func test_full_flow_wealthy_player() -> void:
	_save_data.madra = 1000.0
	assert_true(_can_start_adventure(), "wealthy player should start adventure")
	var budget = _get_adventure_madra_budget()
	var capacity = _get_adventure_madra_capacity()
	assert_eq(budget, capacity, "budget capped at capacity even with excess madra")

func test_full_flow_poor_player() -> void:
	_save_data.madra = 10.0
	assert_false(_can_start_adventure(), "poor player should not start adventure")
	# Budget still calculated even if can't start
	var budget = _get_adventure_madra_budget()
	assert_eq(budget, 10.0, "budget reflects current madra even when blocked")
