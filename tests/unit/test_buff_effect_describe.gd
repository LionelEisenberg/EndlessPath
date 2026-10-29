extends GutTest

## Unit tests for BuffEffectData.describe(): the effect line a buff tooltip
## shows, built from the buff's type and numbers. The text moved here from the
## old CombatBuffTooltip, which now asks the buff for it.

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

## Each buff type names its own number; attribute modifiers get one entry per
## attribute, joined with commas.
func test_describe_names_each_type_and_its_number() -> void:
	var one_attribute: BuffEffectData = _make_buff(BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE)
	one_attribute.attribute_modifiers = {CharacterAttributesData.AttributeType.STRENGTH: 1.5}
	var two_attributes: BuffEffectData = _make_buff(BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE)
	two_attributes.attribute_modifiers = {
		CharacterAttributesData.AttributeType.STRENGTH: 1.5,
		CharacterAttributesData.AttributeType.SPIRIT: 2.0,
	}
	var dot: BuffEffectData = _make_buff(BuffEffectData.BuffType.DAMAGE_OVER_TIME)
	dot.dot_damage_per_tick = 2.0
	var outgoing: BuffEffectData = _make_buff(BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER)
	outgoing.damage_multiplier = 1.5
	var incoming: BuffEffectData = _make_buff(BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER)
	incoming.damage_multiplier = 0.8
	var cases: Array[Array] = [
		["one attribute", one_attribute, "Strength x1.5"],
		["two attributes", two_attributes, "Strength x1.5, Spirit x2.0"],
		["damage over time", dot, "2.0 damage per second"],
		["outgoing damage", outgoing, "Outgoing damage x1.5"],
		["incoming damage", incoming, "Incoming damage x0.8"],
	]
	for case: Array in cases:
		assert_eq((case[1] as BuffEffectData).describe(), case[2], case[0])

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
