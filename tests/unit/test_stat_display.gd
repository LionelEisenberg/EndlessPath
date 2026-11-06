extends GutTest

## StatDisplay: the two sides, and each stat's name, icon and side, the one map
## the Character book and the Abilities book read.

const Attribute := CharacterAttributesData.AttributeType

#-----------------------------------------------------------------------------
# SIDES
#-----------------------------------------------------------------------------

func test_each_side_holds_its_three_stats_in_order() -> void:
	assert_eq(StatDisplay.PHYSICAL,
		[Attribute.STRENGTH, Attribute.BODY, Attribute.AGILITY] as Array[CharacterAttributesData.AttributeType],
		"Physical holds Strength, Body and Agility, in that order")
	assert_eq(StatDisplay.SPIRITUAL,
		[Attribute.SPIRIT, Attribute.MIND, Attribute.CONTROL] as Array[CharacterAttributesData.AttributeType],
		"Spiritual holds Spirit, Mind and Control, in that order")

func test_every_stat_sits_on_exactly_one_side() -> void:
	for stat: CharacterAttributesData.AttributeType in Attribute.values():
		var sides: int = int(StatDisplay.PHYSICAL.has(stat)) + int(StatDisplay.SPIRITUAL.has(stat))
		assert_eq(sides, 1, "%s sits on exactly one side" % CharacterAttributesData.stat_key(stat))

#-----------------------------------------------------------------------------
# EACH STAT
#-----------------------------------------------------------------------------

func test_every_stat_has_a_name_an_icon_and_a_side() -> void:
	var cases: Array[Dictionary] = [
		{"stat": Attribute.STRENGTH, "name": "Strength", "side": "Physical"},
		{"stat": Attribute.BODY, "name": "Body", "side": "Physical"},
		{"stat": Attribute.AGILITY, "name": "Agility", "side": "Physical"},
		{"stat": Attribute.SPIRIT, "name": "Spirit", "side": "Spiritual"},
		{"stat": Attribute.MIND, "name": "Mind", "side": "Spiritual"},
		{"stat": Attribute.CONTROL, "name": "Control", "side": "Spiritual"},
	]
	for case: Dictionary in cases:
		assert_eq(StatDisplay.name_of(case.stat), case.name, "%s's name" % case.name)
		assert_eq(StatDisplay.side_name(case.stat), case.side, "%s is %s" % [case.name, case.side])
		assert_not_null(StatDisplay.icon_of(case.stat), "%s has an icon" % case.name)

## A stat the map has no icon for, one past the last, gets none (and the error is
## logged, not pushed).
func test_a_stat_with_no_icon_has_none() -> void:
	var unknown: int = CharacterAttributesData.AttributeType.size()
	assert_null(StatDisplay.icon_of(unknown as CharacterAttributesData.AttributeType))

func test_no_two_stats_share_an_icon() -> void:
	var seen: Array[Texture2D] = []
	for stat: CharacterAttributesData.AttributeType in Attribute.values():
		var icon: Texture2D = StatDisplay.icon_of(stat)
		assert_false(seen.has(icon), "%s's icon is no other stat's" % CharacterAttributesData.stat_key(stat))
		seen.append(icon)
