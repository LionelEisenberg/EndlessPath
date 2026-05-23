extends GutTest

func test_parser_class_loads() -> void:
	assert_not_null(ItemsMdParser)

const AT = CharacterAttributesData.AttributeType

func test_parse_stats_single_attr() -> void:
	var result = ItemsMdParser.parse_stats("STRENGTH+3")
	assert_eq(result, { AT.STRENGTH: 3.0 })

func test_parse_stats_multi_attr() -> void:
	var result = ItemsMdParser.parse_stats("STRENGTH+3, AGILITY+1")
	assert_eq(result.size(), 2)
	assert_eq(result[AT.STRENGTH], 3.0)
	assert_eq(result[AT.AGILITY], 1.0)

func test_parse_stats_empty_returns_empty() -> void:
	assert_eq(ItemsMdParser.parse_stats("").size(), 0)
	assert_eq(ItemsMdParser.parse_stats("   ").size(), 0)

func test_parse_stats_negative_value() -> void:
	var result = ItemsMdParser.parse_stats("WILLPOWER-2")
	assert_eq(result[AT.WILLPOWER], -2.0)

func test_parse_stats_unknown_attr_returns_empty() -> void:
	# Invalid input -> push_error + empty dict (caller decides whether to abort)
	var result = ItemsMdParser.parse_stats("BOGUS+5")
	assert_eq(result.size(), 0)
	assert_push_error("unknown attribute 'BOGUS'")
