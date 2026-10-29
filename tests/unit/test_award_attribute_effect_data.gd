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

## process() adds the amount to the attribute's base 10: a whole +1.0 to
## Spirit and a fractional +2.5 to Body.
func test_process_adds_amount_to_the_attribute() -> void:
	var cases: Array[Array] = [
		[CharacterAttributesData.AttributeType.SPIRIT, 1.0, 11.0],
		[CharacterAttributesData.AttributeType.BODY, 2.5, 12.5],
	]
	for case: Array in cases:
		var effect := AwardAttributeEffectData.new()
		effect.attribute_type = case[0]
		effect.amount = case[1]
		effect.process()
		assert_eq(_save_data.character_attributes.get_attribute(case[0]), case[2],
			"%s should go from 10.0 to %.1f after a +%.1f award" % [CharacterAttributesData.AttributeType.keys()[case[0]], case[2], case[1]])

func test_process_sets_effect_type() -> void:
	var effect := AwardAttributeEffectData.new()
	assert_eq(effect.effect_type, EffectData.EffectType.AWARD_ATTRIBUTE)
