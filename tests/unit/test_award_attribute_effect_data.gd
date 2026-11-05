extends GutTest

## process() raises a stat by whole levels, up to the stage's cap.
##
## Each test binds a new save through PersistenceManager, so CharacterManager
## and CultivationManager (whose save gives the stage the cap is read from)
## share it, on a test Foundation stage whose stat cap is 5. The original save
## and stages are restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType

var _original_save: SaveGameData
var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_stages = CultivationManager.advancement_stage_resources
	var stage := AdvancementStageResource.new()
	stage.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	stage.stat_level_cap = 5
	var stages: Array[AdvancementStageResource] = [stage]
	CultivationManager.advancement_stage_resources = stages
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## Each award adds its amount as whole levels to its stat's Lv 1.
func test_process_raises_the_stat_by_whole_levels() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the Aura Well's +1 Spirit", "stat": AttributeType.SPIRIT, "amount": 1.0, "level": 2},
		{"name": "+2 Body", "stat": AttributeType.BODY, "amount": 2.0, "level": 3},
	]
	for case: Dictionary in cases:
		var effect := AwardAttributeEffectData.new()
		effect.attribute_type = case.stat
		effect.amount = case.amount
		effect.process()
		assert_eq(CharacterManager.get_stat_level(case.stat), case.level, case.name)

func test_a_level_past_the_cap_is_lost() -> void:
	CharacterManager.set_stat_level(AttributeType.SPIRIT, 5)
	var effect := AwardAttributeEffectData.new()
	effect.attribute_type = AttributeType.SPIRIT
	effect.process()
	assert_eq(CharacterManager.get_stat_level(AttributeType.SPIRIT), 5, "the award past the cap of 5 is lost")

func test_process_sets_effect_type() -> void:
	var effect := AwardAttributeEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_ATTRIBUTE)
