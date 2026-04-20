extends GutTest

func test_process_calls_path_manager_add_points() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var starting_points: int = PathManager.get_point_balance()

	var effect := AwardPathPointEffectData.new()
	effect.amount = 3
	effect.process()

	assert_eq(PathManager.get_point_balance(), starting_points + 3,
		"AwardPathPointEffect should add its amount to PathManager")


func test_process_with_zero_amount_is_noop() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var starting_points: int = PathManager.get_point_balance()

	var effect := AwardPathPointEffectData.new()
	effect.amount = 0
	effect.process()

	assert_eq(PathManager.get_point_balance(), starting_points,
		"Zero amount should not change balance")


func test_effect_type_is_award_path_point() -> void:
	var effect := AwardPathPointEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_PATH_POINT,
		"effect_type should be set to AWARD_PATH_POINT by _init")
