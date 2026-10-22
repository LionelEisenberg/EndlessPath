class_name TrainingPresenter
extends ZoneActionPresenter
## Presenter for TRAIN_STATS cards: "+1.5 Madra / s · each level +1 Spirit",
## the Madra the action trickles per second and the attribute each level
## grants (the first AwardAttributeEffectData in effects_on_level). Progress
## toward the next level lives in the Now strip, not on the card. The decimal
## point is set in Yatra One, and a line wider than 316 px ends in an
## ellipsis (ZoneActionButton.fit_detail_rich_text).

const SEPARATOR: String = " · "

@onready var _detail_text: RichTextLabel = %DetailText

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_text.reparent(button.get_detail_slot(), false)
	button.fit_detail_rich_text(_detail_text, _detail_line())

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _detail_line() -> String:
	var training := action_data as TrainingActionData
	if training == null:
		return ""
	var parts: Array[String] = []
	var madra_per_second: float = training.get_madra_per_second()
	if madra_per_second > 0.0:
		parts.append("%s Madra / s" % LacquerText.rate(madra_per_second))
	var attribute_effect: AwardAttributeEffectData = _find_attribute_effect(training)
	if attribute_effect != null:
		var attribute_name: String = CharacterManager.get_attribute_display_name(attribute_effect.attribute_type)
		parts.append("each level %s %s" % [LacquerText.rate(attribute_effect.amount), attribute_name])
	return SEPARATOR.join(parts)

func _find_attribute_effect(training: TrainingActionData) -> AwardAttributeEffectData:
	for effect: EffectData in training.effects_on_level:
		if effect is AwardAttributeEffectData:
			return effect as AwardAttributeEffectData
	return null
