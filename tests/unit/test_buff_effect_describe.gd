extends GutTest

## Unit tests for BuffEffectData.describe(): the effect line a buff tooltip
## shows ("Strength x1.5", "2.0 damage per second", "Outgoing damage x1.5",
## "Incoming damage x0.8"). The text moved here from the old CombatBuffTooltip,
## which now asks the buff for it.

const OLD_TOOLTIP_SCENE_PATH: String = "res://scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _make_buff(buff_type: BuffEffectData.BuffType) -> BuffEffectData:
	var buff := BuffEffectData.new()
	buff.buff_id = "test_buff"
	buff.duration = 10.0
	buff.buff_type = buff_type
	return buff

#-----------------------------------------------------------------------------
# DESCRIBE
#-----------------------------------------------------------------------------

func test_describe_attribute_modifier() -> void:
	var buff: BuffEffectData = _make_buff(BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE)
	buff.attribute_modifiers = {CharacterAttributesData.AttributeType.STRENGTH: 1.5}
	assert_eq(buff.describe(), "Strength x1.5")
	buff.attribute_modifiers = {
		CharacterAttributesData.AttributeType.STRENGTH: 1.5,
		CharacterAttributesData.AttributeType.SPIRIT: 2.0,
	}
	assert_eq(buff.describe(), "Strength x1.5, Spirit x2.0", "one entry per attribute, joined with commas")

func test_describe_damage_over_time() -> void:
	var buff: BuffEffectData = _make_buff(BuffEffectData.BuffType.DAMAGE_OVER_TIME)
	buff.dot_damage_per_tick = 2.0
	assert_eq(buff.describe(), "2.0 damage per second")

func test_describe_outgoing_and_incoming() -> void:
	var outgoing: BuffEffectData = _make_buff(BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER)
	outgoing.damage_multiplier = 1.5
	assert_eq(outgoing.describe(), "Outgoing damage x1.5")
	var incoming: BuffEffectData = _make_buff(BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER)
	incoming.damage_multiplier = 0.8
	assert_eq(incoming.describe(), "Incoming damage x0.8")

#-----------------------------------------------------------------------------
# THE OLD TOOLTIP (deleted in PR 2) KEEPS WORKING
#-----------------------------------------------------------------------------

## The floating enemy plate still shows its buffs through CombatBuffTooltip
## until PR 2 replaces it, so its description must stay the buff's describe().
func test_the_old_buff_tooltip_shows_describe() -> void:
	var buff: BuffEffectData = _make_buff(BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER)
	buff.damage_multiplier = 1.5
	var tooltip: CombatBuffTooltip = load(OLD_TOOLTIP_SCENE_PATH).instantiate()
	add_child_autofree(tooltip)
	tooltip.show_for_buff(ActiveBuff.new(buff))
	assert_eq((tooltip.get_node("%Description") as Label).text, buff.describe())
	assert_eq((tooltip.get_node("%Description") as Label).text, "Outgoing damage x1.5")
