extends GutTest

## AwardCoreDensityXpEffectData: a reward of Core Density XP that any choice can
## carry in its effects (a fight's, as its loot is, or an event's). Each test
## runs on a fresh save at Core Density 0, where Foundation's level 1 costs 10.

var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# A save reset starts the zone's idle action: stop what it started.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func test_process_pays_its_amount_into_the_core() -> void:
	var effect := AwardCoreDensityXpEffectData.new()
	effect.amount = 7.0

	effect.process()

	assert_eq(CultivationManager.get_core_density_xp(), 7.0, "the amount, under the level-1 cost")
	assert_eq(CultivationManager.get_core_density_level(), 0.0)

## A zero or negative amount (a malformed .tres) changes nothing.
func test_process_with_a_non_positive_amount_is_noop() -> void:
	var amounts: Array[float] = [0.0, -5.0]
	for amount: float in amounts:
		var effect := AwardCoreDensityXpEffectData.new()
		effect.amount = amount
		effect.process()
		assert_eq(CultivationManager.get_core_density_xp(), 0.0, "an amount of %s pays nothing" % amount)

## EffectData.EffectType only grows at the end: this one's number is pinned.
func test_effect_type_is_award_core_density_xp() -> void:
	var effect := AwardCoreDensityXpEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_CORE_DENSITY_XP, "set by _init")
	assert_eq(EffectData.EffectType.AWARD_CORE_DENSITY_XP, 9, "appended after CHANGE_VITALS")
