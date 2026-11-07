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

## A screen that names a whole side by an icon (the Cycling and Riverbank
## Training cards) shows the side's first stat's icon: Strength's for the Physical
## side and Spirit's for the Spiritual side, the user's call on #145 until the
## sides have icons of their own.
func test_each_side_shows_its_first_stats_icon() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Physical", "side": StatDisplay.StatSide.PHYSICAL, "stat": Attribute.STRENGTH},
		{"name": "Spiritual", "side": StatDisplay.StatSide.SPIRITUAL, "stat": Attribute.SPIRIT},
	]
	for case: Dictionary in cases:
		assert_eq(StatDisplay.side_icon(case.side), StatDisplay.icon_of(case.stat), "%s: %s's icon" % [case.name, StatDisplay.name_of(case.stat)])

## Each Physical stat, the ones the drills train, has a 16 px mini of its icon for
## the lines that name it beside a figure: the body refining board, its card, its
## floaters and its drill drawers. Each is its own, and none is the Health heart.
func test_every_physical_stat_has_a_mini_icon() -> void:
	var seen: Array[Texture2D] = [preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")]
	for stat: Attribute in StatDisplay.PHYSICAL:
		var mini: Texture2D = StatDisplay.mini_icon_of(stat)
		assert_not_null(mini, "%s has a mini icon" % StatDisplay.name_of(stat))
		if mini == null:
			continue
		assert_eq(mini.get_size(), Vector2(16, 16), "%s's: 16 px, as the other mini icons" % StatDisplay.name_of(stat))
		assert_ne(mini, StatDisplay.icon_of(stat), "%s's is not the full icon" % StatDisplay.name_of(stat))
		assert_does_not_have(seen, mini, "%s's is its own" % StatDisplay.name_of(stat))
		seen.append(mini)

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
