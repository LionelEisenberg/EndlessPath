extends GutTest

func _make_data(ticks_per_level: Array[int] = [60, 300, 600, 1200], tail: float = 2.0) -> TrainingActionData:
	var data := TrainingActionData.new()
	data.ticks_per_level = ticks_per_level
	data.tail_growth_multiplier = tail
	return data

#-----------------------------------------------------------------------------
# get_ticks_required_for_level — incremental cost per level
#-----------------------------------------------------------------------------

func test_ticks_required_level_0_is_zero() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(0), 0)

func test_ticks_required_level_1_reads_array_first_entry() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(1), 60)

func test_ticks_required_level_4_reads_array_last_entry() -> void:
	assert_eq(_make_data().get_ticks_required_for_level(4), 1200)

func test_ticks_required_beyond_array_applies_tail_multiplier() -> void:
	# Array size 4, tail 2.0 → level 5 = 1200*2.0 = 2400
	assert_eq(_make_data().get_ticks_required_for_level(5), 2400)

func test_ticks_required_two_levels_beyond_array() -> void:
	# level 6 = 1200*2^2 = 4800
	assert_eq(_make_data().get_ticks_required_for_level(6), 4800)

func test_ticks_required_tail_multiplier_1_is_linear() -> void:
	# With multiplier 1.0, level N beyond array equals the last array value.
	var data := _make_data([10, 20], 1.0)
	assert_eq(data.get_ticks_required_for_level(3), 20)
	assert_eq(data.get_ticks_required_for_level(10), 20)

#-----------------------------------------------------------------------------
# get_current_level — cumulative tick count -> current level
#-----------------------------------------------------------------------------

func test_current_level_zero_ticks_is_zero() -> void:
	assert_eq(_make_data().get_current_level(0), 0)

func test_current_level_just_before_first_threshold() -> void:
	assert_eq(_make_data().get_current_level(59), 0)

func test_current_level_exactly_first_threshold() -> void:
	assert_eq(_make_data().get_current_level(60), 1)

func test_current_level_mid_second_tier() -> void:
	assert_eq(_make_data().get_current_level(359), 1)

func test_current_level_exactly_second_threshold() -> void:
	# level 2 requires cumulative 60 + 300 = 360
	assert_eq(_make_data().get_current_level(360), 2)

func test_current_level_beyond_array_uses_tail() -> void:
	# cumulative to level 4 = 60+300+600+1200 = 2160; level 5 adds 2400 -> 4560
	assert_eq(_make_data().get_current_level(4559), 4)
	assert_eq(_make_data().get_current_level(4560), 5)

#-----------------------------------------------------------------------------
# get_progress_within_level — fraction toward next level
#-----------------------------------------------------------------------------

func test_progress_at_tier_start_is_zero() -> void:
	assert_almost_eq(_make_data().get_progress_within_level(0), 0.0, 0.001)

func test_progress_mid_first_tier() -> void:
	# 30 ticks of 60 required for level 1 -> 0.5
	assert_almost_eq(_make_data().get_progress_within_level(30), 0.5, 0.001)

func test_progress_just_before_threshold() -> void:
	# 59/60 -> ~0.983
	assert_almost_eq(_make_data().get_progress_within_level(59), 59.0 / 60.0, 0.001)

func test_progress_at_threshold_resets_to_zero() -> void:
	# 60 ticks = exactly level 1; 0 ticks into level 2
	assert_almost_eq(_make_data().get_progress_within_level(60), 0.0, 0.001)

func test_progress_mid_second_tier() -> void:
	# Cumulative 60 + 150 = 210; level 2 needs 300 -> 150/300 = 0.5
	assert_almost_eq(_make_data().get_progress_within_level(210), 0.5, 0.001)

#-----------------------------------------------------------------------------
# action_type is set in _init
#-----------------------------------------------------------------------------

func test_action_type_defaults_to_train_stats() -> void:
	var data := TrainingActionData.new()
	assert_eq(data.action_type, ZoneActionData.ActionType.TRAIN_STATS)
