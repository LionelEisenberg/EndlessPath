extends GutTest

## BookText: the pressed pages' number, effect-line and bonus-line helpers.

#-----------------------------------------------------------------------------
# NUMBERS
#-----------------------------------------------------------------------------

func test_thousands_groups_exactly_at_each_boundary_and_keeps_the_sign() -> void:
	assert_eq(BookText.thousands(0), "0")
	assert_eq(BookText.thousands(999), "999")
	assert_eq(BookText.thousands(1000), "1,000")
	assert_eq(BookText.thousands(99999), "99,999")
	assert_eq(BookText.thousands(100000), "100,000")
	assert_eq(BookText.thousands(-4600), "-4,600")

func test_seconds_keep_whole_numbers_whole() -> void:
	assert_eq(BookText.seconds(10.0), "10 s")
	assert_eq(BookText.seconds(2.5), "2.5 s")

#-----------------------------------------------------------------------------
# EFFECT LINES
#-----------------------------------------------------------------------------

func test_effect_line_without_cooldown_has_no_tail() -> void:
	var tonic := ConsumableDefinitionData.new()
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 30.0
	tonic.effects = [heal]
	assert_eq(BookText.effect_line(tonic), "+30 Health")

func test_effect_line_of_only_a_cooldown_has_no_leading_separator() -> void:
	var inert := ConsumableDefinitionData.new()
	inert.cooldown_seconds = 10.0
	assert_eq(BookText.effect_line(inert), "10 s cooldown")

#-----------------------------------------------------------------------------
# EQUIPMENT
#-----------------------------------------------------------------------------

func test_bonus_lines_skip_zero_and_set_fractions_to_one_decimal() -> void:
	var charm := EquipmentDefinitionData.new()
	# Written out of attribute order on purpose: the lines must still come
	# back Strength, Body, Willpower.
	charm.attribute_bonuses = {
		CharacterAttributesData.AttributeType.WILLPOWER: 1.5,
		CharacterAttributesData.AttributeType.SPIRIT: 0.0,
		CharacterAttributesData.AttributeType.BODY: -2.0,
		CharacterAttributesData.AttributeType.STRENGTH: 4.0,
	}
	assert_eq(BookText.bonus_lines(charm), ["+4 Strength", "-2 Body", "+1.5 Willpower"] as Array[String])
