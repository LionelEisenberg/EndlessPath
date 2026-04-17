extends GutTest

var _save_data: SaveGameData
var _original_live_save: SaveGameData

func before_each() -> void:
	_original_live_save = CharacterManager.live_save_data
	_save_data = SaveGameData.new()
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	CharacterManager.live_save_data = _save_data

func after_each() -> void:
	CharacterManager.live_save_data = _original_live_save

func test_process_adds_amount_to_spirit() -> void:
	var effect := AwardAttributeEffectData.new()
	effect.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	effect.amount = 1.0
	effect.process()
	assert_eq(
		_save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT),
		11.0,
		"Spirit should go from 10.0 -> 11.0 after +1.0 award"
	)

func test_process_adds_fractional_amount_to_body() -> void:
	var effect := AwardAttributeEffectData.new()
	effect.attribute_type = CharacterAttributesData.AttributeType.BODY
	effect.amount = 2.5
	effect.process()
	assert_eq(
		_save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY),
		12.5
	)

func test_process_sets_effect_type() -> void:
	var effect := AwardAttributeEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_ATTRIBUTE)
