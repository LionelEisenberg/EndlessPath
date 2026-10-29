extends GutTest

func _make_data(ticks_per_level: Array[int] = [60, 300, 600, 1200], tail: float = 2.0) -> TrainingActionData:
	var data := TrainingActionData.new()
	data.ticks_per_level = ticks_per_level
	data.tail_growth_multiplier = tail
	return data

#-----------------------------------------------------------------------------
# get_ticks_required_for_level — incremental cost per level
#-----------------------------------------------------------------------------

## Each level's own cost with [60, 300, 600, 1200] and a tail of 2.0: none for
## level 0, the array's entries for levels 1 to 4, and past the array the last
## entry times the tail once per level beyond it.
func test_ticks_required_for_level() -> void:
	var data := _make_data()
	var cases: Array[Dictionary] = [
		{"name": "level 0 is zero", "level": 0, "ticks": 0},
		{"name": "level 1 reads the array's first entry", "level": 1, "ticks": 60},
		{"name": "level 4 reads the array's last entry", "level": 4, "ticks": 1200},
		{"name": "level 5, one beyond the array: 1200*2.0", "level": 5, "ticks": 2400},
		{"name": "level 6, two beyond the array: 1200*2^2", "level": 6, "ticks": 4800},
	]
	for case: Dictionary in cases:
		assert_eq(data.get_ticks_required_for_level(case.level), case.ticks, case.name)

func test_ticks_required_tail_multiplier_1_is_linear() -> void:
	# With multiplier 1.0, level N beyond array equals the last array value.
	var data := _make_data([10, 20], 1.0)
	assert_eq(data.get_ticks_required_for_level(3), 20)
	assert_eq(data.get_ticks_required_for_level(10), 20)

#-----------------------------------------------------------------------------
# get_current_level — cumulative tick count -> current level
#-----------------------------------------------------------------------------

## The level a cumulative tick count has reached with [60, 300, 600, 1200] and
## a tail of 2.0, on each side of the level 1 and level 2 thresholds (60, and
## 60 + 300 = 360) and of level 5, the first past the array (60+300+600+1200 =
## 2160 to level 4, plus 2400 = 4560).
func test_current_level() -> void:
	var data := _make_data()
	var cases: Array[Dictionary] = [
		{"name": "zero ticks", "ticks": 0, "level": 0},
		{"name": "just before the first threshold", "ticks": 59, "level": 0},
		{"name": "exactly the first threshold", "ticks": 60, "level": 1},
		{"name": "mid second tier", "ticks": 359, "level": 1},
		{"name": "exactly the second threshold", "ticks": 360, "level": 2},
		{"name": "just before level 5, beyond the array", "ticks": 4559, "level": 4},
		{"name": "exactly level 5, from the tail", "ticks": 4560, "level": 5},
	]
	for case: Dictionary in cases:
		assert_eq(data.get_current_level(case.ticks), case.level, case.name)

#-----------------------------------------------------------------------------
# get_progress_within_level — fraction toward next level
#-----------------------------------------------------------------------------

## The fraction of the way to the next level with [60, 300, 600, 1200]: from
## the start of a tier, through it, to the threshold, where it starts over.
func test_progress_within_level() -> void:
	var data := _make_data()
	var cases: Array[Dictionary] = [
		{"name": "tier start is zero", "ticks": 0, "progress": 0.0},
		{"name": "mid first tier: 30 of 60", "ticks": 30, "progress": 0.5},
		{"name": "just before the threshold: 59 of 60", "ticks": 59, "progress": 59.0 / 60.0},
		{"name": "the threshold resets to zero: 0 ticks into level 2", "ticks": 60, "progress": 0.0},
		{"name": "mid second tier: 60 + 150, 150 of 300", "ticks": 210, "progress": 0.5},
	]
	for case: Dictionary in cases:
		assert_almost_eq(data.get_progress_within_level(case.ticks), case.progress, 0.001, case.name)

#-----------------------------------------------------------------------------
# action_type is set in _init
#-----------------------------------------------------------------------------

func test_action_type_defaults_to_train_stats() -> void:
	var data := TrainingActionData.new()
	assert_eq(data.action_type, ZoneActionData.ActionType.TRAIN_STATS)
