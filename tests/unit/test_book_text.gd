extends GutTest

## BookText: the pressed pages' number, effect-line and gear bonus-line helpers.

const AttributeType = CharacterAttributesData.AttributeType
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")

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

func test_gear_bonus_lines_word_each_bonus_with_its_value_now() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a stat at its floor", "item": GearFixture.item({&"strength": 0.1}, 2),
			"trained": {AttributeType.STRENGTH: 10.0}, "lines": ["+10% Strength\u00a0(+2)"]},
		{"name": "stats in stat order, then armor, then Ward",
			"item": GearFixture.item({&"control": 0.2, &"strength": 0.5}, 1, 6.0, 4.0),
			"trained": {AttributeType.STRENGTH: 10.0, AttributeType.CONTROL: 15.0},
			"lines": ["+50% Strength\u00a0(+5)", "+20% Control\u00a0(+3)", "Armor 6", "Ward 4"]},
		{"name": "a fractional percent", "item": GearFixture.item({&"spirit": 0.125}),
			"trained": {AttributeType.SPIRIT: 16.0}, "lines": ["+12.5% Spirit\u00a0(+2)"]},
		{"name": "no bonuses", "item": GearFixture.item({}), "trained": {}, "lines": []},
	]
	for case: Dictionary in cases:
		var expected: Array[String] = []
		expected.assign(case.lines)
		assert_eq(BookText.gear_bonus_lines(case.item, case.trained), expected, case.name)
