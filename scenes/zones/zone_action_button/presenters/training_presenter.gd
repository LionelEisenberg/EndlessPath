class_name TrainingPresenter
extends ZoneActionPresenter
## Presenter for TRAIN_STATS cards: the Madra the action trickles per second
## on the left ("+1.5 Madra / s") and the attribute each level grants in the
## right column ("+1 Spirit / level", from the first AwardAttributeEffectData
## in effects_on_level). An action with only one of the two shows it on the
## left. Progress toward the next level lives in the Now strip, not on the
## card. The decimal point is set in Yatra One, and a part wider than its room
## ends in an ellipsis (ZoneActionButton.fit_detail_rich_text).

@onready var _detail_text: RichTextLabel = %DetailText

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_text.reparent(button.get_detail_slot(), false)
	var parts: Array[String] = _detail_parts()
	button.set_detail_right(parts[1] if parts.size() > 1 else "")
	button.fit_detail_rich_text(_detail_text, parts[0] if not parts.is_empty() else "")

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## "+1.5 Madra / s" and "+1 Spirit / level", each only when the action has it.
func _detail_parts() -> Array[String]:
	var training := action_data as TrainingActionData
	var parts: Array[String] = []
	if training == null:
		return parts
	var madra_per_second: float = training.get_madra_per_second()
	if madra_per_second > 0.0:
		parts.append("%s Madra / s" % LacquerText.rate(madra_per_second))
	var attribute_effect: AwardAttributeEffectData = _find_attribute_effect(training)
	if attribute_effect != null:
		var attribute_name: String = CharacterManager.get_attribute_display_name(attribute_effect.attribute_type)
		parts.append("%s %s / level" % [LacquerText.rate(attribute_effect.amount), attribute_name])
	return parts

func _find_attribute_effect(training: TrainingActionData) -> AwardAttributeEffectData:
	for effect: EffectData in training.effects_on_level:
		if effect is AwardAttributeEffectData:
			return effect as AwardAttributeEffectData
	return null
