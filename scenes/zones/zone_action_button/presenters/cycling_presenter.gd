class_name CyclingPresenter
extends ZoneActionPresenter
## Presenter for CYCLING cards: what cycling trains, a row of words with each
## stat's 16 px icon before its name: "Madra and [icon] Spirit XP" on a new
## save, then the other stat of each technique the player knows after Spirit,
## in the screens' order ("Madra, [icon] Spirit, [icon] Mind and [icon] Control
## XP"). The row follows each technique unlock, and a row too long for its line
## moves its entries down rather than cutting them. The equipped technique is
## the cycling board's and the technique drawers' to name, not the card's (the
## user's review, 2026-10-24).

const MADRA_WORD: String = "Madra"
const XP_SUFFIX: String = " XP"

@onready var _reward_row: HFlowContainer = %RewardRow
@onready var _madra_label: Label = %MadraLabel
## Each stat's entry in the row, its icon and its word.
@onready var _entries: Dictionary = {
	CharacterAttributesData.AttributeType.SPIRIT: %SpiritEntry,
	CharacterAttributesData.AttributeType.MIND: %MindEntry,
	CharacterAttributesData.AttributeType.CONTROL: %ControlEntry,
}
@onready var _icons: Dictionary = {
	CharacterAttributesData.AttributeType.SPIRIT: %SpiritIcon,
	CharacterAttributesData.AttributeType.MIND: %MindIcon,
	CharacterAttributesData.AttributeType.CONTROL: %ControlIcon,
}
@onready var _names: Dictionary = {
	CharacterAttributesData.AttributeType.SPIRIT: %SpiritName,
	CharacterAttributesData.AttributeType.MIND: %MindName,
	CharacterAttributesData.AttributeType.CONTROL: %ControlName,
}

## Moves the reward row into the card, fills it, and follows technique unlocks.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_reward_row.reparent(button.get_detail_slot(), false)
	CyclingManager.technique_unlocked.connect(_on_technique_unlocked)
	_fill()

## Stops following technique unlocks.
func teardown() -> void:
	if CyclingManager.technique_unlocked.is_connected(_on_technique_unlocked):
		CyclingManager.technique_unlocked.disconnect(_on_technique_unlocked)

## Returns the stats cycling trains with the techniques the player knows:
## Spirit, which following trains, then each unlocked technique's other stat,
## in the screens' order (StatDisplay.SPIRITUAL), each once.
static func reward_stats() -> Array[CharacterAttributesData.AttributeType]:
	var trained: Array[int] = [CharacterAttributesData.AttributeType.SPIRIT]
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		if technique.minor_stat >= 0:
			trained.append(technique.minor_stat)
	var stats: Array[CharacterAttributesData.AttributeType] = []
	for stat: CharacterAttributesData.AttributeType in StatDisplay.SPIRITUAL:
		if trained.has(stat):
			stats.append(stat)
	return stats

## Returns the row's words for `stats`: "Madra" and each stat's name as a list
## (LacquerText.list_words()), with " XP" after the last ("Madra,", "Spirit
## and", "Control XP").
static func reward_words(stats: Array) -> PackedStringArray:
	var names: PackedStringArray = [MADRA_WORD]
	for stat: CharacterAttributesData.AttributeType in stats:
		names.append(StatDisplay.name_of(stat))
	var words: PackedStringArray = LacquerText.list_words(names)
	words[words.size() - 1] += XP_SUFFIX
	return words

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Shows what cycling trains now: the Madra's word on its label, and each
## trained stat's icon and word on its entry, the other entries hidden. Then
## lays the card out again.
func _fill() -> void:
	var stats: Array[CharacterAttributesData.AttributeType] = reward_stats()
	var words: PackedStringArray = reward_words(stats)
	_madra_label.text = words[0]
	for stat: CharacterAttributesData.AttributeType in _entries:
		var index: int = stats.find(stat)
		(_entries[stat] as Control).visible = index >= 0
		if index >= 0:
			(_icons[stat] as TextureRect).texture = StatDisplay.icon_of(stat)
			(_names[stat] as Label).text = words[index + 1]
	button.relayout()

func _on_technique_unlocked(_technique: CyclingTechniqueData) -> void:
	_fill()
