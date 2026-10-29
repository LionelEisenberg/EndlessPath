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


## A zero or negative amount (a malformed .tres) leaves the balance alone.
func test_process_with_a_non_positive_amount_is_noop() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var starting_points: int = PathManager.get_point_balance()

	var amounts: Array[int] = [0, -5]
	for amount: int in amounts:
		var effect := AwardPathPointEffectData.new()
		effect.amount = amount
		effect.process()
		assert_eq(PathManager.get_point_balance(), starting_points,
			"an amount of %d should not change balance" % amount)


func test_effect_type_is_award_path_point() -> void:
	var effect := AwardPathPointEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_PATH_POINT,
		"effect_type should be set to AWARD_PATH_POINT by _init")
