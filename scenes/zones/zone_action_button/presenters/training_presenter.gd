class_name TrainingPresenter
extends ZoneActionPresenter
## Presenter for TRAIN_STATS cards: the Madra the action trickles per second
## on the left ("+1.5 Madra / s") and the attribute each level grants in the
## right column ("+1 Spirit / level", from the first AwardAttributeEffectData
## in effects_on_level). An action with only one of the two shows it on the
## left. While the Madra pool is full, an action that trickles Madra and grants
## nothing per level (the Aura Well) says "Madra full" in the right column, since
## its trickle adds nothing there. Progress lives in the Now strip, not on the
## card. The decimal point is set in Yatra One, and a part wider than its room
## wraps (ZoneActionButton.set_detail_right, set_detail_rich_text).

## The right column while the pool is full and the trickle adds nothing.
const MADRA_FULL: String = "Madra full"

@onready var _detail_text: RichTextLabel = %DetailText

## The detail line as last shown: a Madra change redraws the card only when it
## changes the text.
var _shown: bool = false
var _shown_left: String = ""
var _shown_right: String = ""

## Moves the detail into the card, fills it, and follows the Madra pool and its
## max (stats move the max).
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_text.reparent(button.get_detail_slot(), false)
	ResourceManager.madra_changed.connect(_on_madra_changed)
	CharacterManager.stats_changed.connect(_update_detail)
	_update_detail()

## Disconnects from the managers.
func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_madra_changed):
		ResourceManager.madra_changed.disconnect(_on_madra_changed)
	if CharacterManager.stats_changed.is_connected(_update_detail):
		CharacterManager.stats_changed.disconnect(_update_detail)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Fills the detail line, redrawing the card only when its text changes.
func _update_detail() -> void:
	var parts: Array[String] = _detail_parts()
	var left: String = parts[0] if not parts.is_empty() else ""
	var right: String = parts[1] if parts.size() > 1 else _madra_full_text()
	if _shown and left == _shown_left and right == _shown_right:
		return
	_shown = true
	_shown_left = left
	_shown_right = right
	button.set_detail_right(right)
	button.set_detail_rich_text(_detail_text, left)

## "Madra full" while the pool is full, for an action whose Madra trickle is
## all it gives; "" otherwise.
func _madra_full_text() -> String:
	var training := action_data as TrainingActionData
	if training == null or training.get_madra_per_second() <= 0.0 or _find_attribute_effect(training) != null:
		return ""
	return MADRA_FULL if ResourceManager.get_madra() >= ResourceManager.get_max_madra() else ""

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

func _on_madra_changed(_new_amount: float) -> void:
	_update_detail()
