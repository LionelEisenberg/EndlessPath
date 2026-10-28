extends GutTest

## BookText: the pressed pages' number, effect and drop-cap helpers.

#-----------------------------------------------------------------------------
# NUMBERS
#-----------------------------------------------------------------------------

func test_count_marks_a_stack() -> void:
	assert_eq(BookText.count(7), "×7")
	assert_eq(BookText.count(4600), "×4600")

func test_thousands_groups_digits() -> void:
	assert_eq(BookText.thousands(12), "12")
	assert_eq(BookText.thousands(4600), "4,600")
	assert_eq(BookText.thousands(1234567), "1,234,567")

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

func test_color_madra_marks_only_madra_amounts() -> void:
	assert_eq(BookText.color_madra("+30 Health, +20 Madra"), "+30 Health, [color=#1c2f60]+20 Madra[/color]")
	assert_eq(BookText.color_madra("+7.5 Madra"), "[color=#1c2f60]+7.5 Madra[/color]")

func test_color_madra_marks_every_amount() -> void:
	assert_eq(
		BookText.color_madra("+20 Madra, -5 Madra"),
		"[color=#1c2f60]+20 Madra[/color], [color=#1c2f60]-5 Madra[/color]"
	)

func test_effect_line_for_crude_scale() -> void:
	var crude: ConsumableDefinitionData = load("res://resources/items/consumables/crude_scale.tres")
	assert_eq(BookText.effect_line(crude), "[color=#1c2f60]+20 Madra[/color] · 10 s cooldown")

func test_effect_line_without_cooldown_has_no_tail() -> void:
	var tonic := ConsumableDefinitionData.new()
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 30.0
	tonic.effects = [heal]
	assert_eq(BookText.effect_line(tonic), "+30 Health")

func test_effect_line_joins_effects_and_the_cooldown_with_middle_dots() -> void:
	var tonic := ConsumableDefinitionData.new()
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 30.0
	var madra := ChangeVitalsEffectData.new()
	madra.madra_change = 20.0
	tonic.effects = [heal, madra]
	tonic.cooldown_seconds = 5.0
	assert_eq(BookText.effect_line(tonic), "+30 Health · [color=#1c2f60]+20 Madra[/color] · 5 s cooldown")

func test_effect_line_of_only_a_cooldown_has_no_leading_separator() -> void:
	var inert := ConsumableDefinitionData.new()
	inert.cooldown_seconds = 10.0
	assert_eq(BookText.effect_line(inert), "10 s cooldown")

func test_effect_line_sets_madra_decimals_inside_madra_ink() -> void:
	var tonic := ConsumableDefinitionData.new()
	var madra := ChangeVitalsEffectData.new()
	madra.madra_change = 7.5
	tonic.effects = [madra]
	assert_eq(BookText.effect_line(tonic), "[color=#1c2f60]+7" + LacquerText.DECIMAL_POINT_BBCODE + "5 Madra[/color]")

func test_effect_labels() -> void:
	assert_eq(BookText.effect_label(ChangeVitalsEffectData.new()), "RESTORES")
	assert_eq(BookText.effect_label(AwardPathPointEffectData.new()), "EFFECT")

#-----------------------------------------------------------------------------
# EQUIPMENT
#-----------------------------------------------------------------------------

func test_slot_names() -> void:
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND), "MAIN HAND")
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.ARMOR), "BODY")
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.ACCESSORY), "ACCESSORY")

func test_slot_names_of_the_off_hand_and_head() -> void:
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.OFF_HAND), "OFF HAND")
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.HEAD), "HEAD")

func test_bonus_lines_follow_attribute_order() -> void:
	var dagger: EquipmentDefinitionData = load("res://resources/items/equipment/spirit_valley/makeshift_dagger.tres")
	assert_eq(BookText.bonus_lines(dagger), ["+3 Strength", "+2 Agility"] as Array[String])

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
