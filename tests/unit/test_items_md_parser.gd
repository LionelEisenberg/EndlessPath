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

const ES = EquipmentDefinitionData.EquipmentSlot

func test_parse_slot_main_hand() -> void:
	assert_eq(ItemsMdParser.parse_slot("MAIN_HAND"), ES.MAIN_HAND)

func test_parse_slot_off_hand() -> void:
	assert_eq(ItemsMdParser.parse_slot("OFF_HAND"), ES.OFF_HAND)

func test_parse_slot_trims_whitespace() -> void:
	assert_eq(ItemsMdParser.parse_slot("  HEAD  "), ES.HEAD)

func test_parse_slot_unknown_returns_negative_one() -> void:
	assert_eq(ItemsMdParser.parse_slot("BOGUS"), -1)
	assert_push_error("unknown slot 'BOGUS'")

func test_parse_table_header_returns_columns_in_order() -> void:
	var line = "| # | id | name | slot | stats |"
	var cols = ItemsMdParser.parse_table_header(line)
	assert_eq(cols, ["#", "id", "name", "slot", "stats"])

func test_parse_table_header_strips_whitespace_and_backticks() -> void:
	# Allow `id` (markdown inline-code) in header
	var line = "| ` # ` | `id` | name |"
	var cols = ItemsMdParser.parse_table_header(line)
	assert_eq(cols, ["#", "id", "name"])

func test_is_separator_line() -> void:
	assert_true(ItemsMdParser.is_separator_line("|---|---|---|"))
	assert_true(ItemsMdParser.is_separator_line("| --- | :--: | ---: |"))
	assert_false(ItemsMdParser.is_separator_line("| id | name |"))

func test_parse_table_row_maps_columns_to_cells() -> void:
	var cols = ["#", "id", "name", "slot"]
	var line = "| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND |"
	var row = ItemsMdParser.parse_table_row(line, cols)
	assert_eq(row["#"], "E1")
	assert_eq(row["id"], "makeshift_dagger")
	assert_eq(row["name"], "Makeshift Dagger")
	assert_eq(row["slot"], "MAIN_HAND")

func test_parse_table_row_handles_missing_columns_with_empty_string() -> void:
	var cols = ["a", "b", "c"]
	var line = "| x | y |"
	var row = ItemsMdParser.parse_table_row(line, cols)
	assert_eq(row["a"], "x")
	assert_eq(row["b"], "y")
	assert_eq(row["c"], "")

func test_is_roster_header_true_for_equipment_columns() -> void:
	var cols: Array[String] = ["#", "id", "name", "slot", "stats", "tier", "cost", "identity", "source", "description"]
	assert_true(ItemsMdParser.is_roster_header(cols))

func test_is_roster_header_false_for_schema_table() -> void:
	# The Schema sub-section has columns "Column | Maps to | Notes" — not a roster.
	var cols: Array[String] = ["Column", "Maps to", "Notes"]
	assert_false(ItemsMdParser.is_roster_header(cols))

func test_parse_equipment_sections_groups_by_zone() -> void:
	var md = """
## Equipment

### Schema

| Column | Maps to | Notes |
|---|---|---|
| id | item_id | snake_case |

### Spirit Valley

| # | id | name | slot | stats | tier | cost | identity | source | description |
|---|---|---|---|---|---|---|---|---|---|
| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND | STRENGTH+3 | Foundation | 0 | Starter | NPC | A blade. |

### Other Zone

| # | id | name | slot | stats | tier | cost | identity | source | description |
|---|---|---|---|---|---|---|---|---|---|
| E1 | other_item | Other Item | HEAD | WILLPOWER+1 | Copper | 5 | Hat | Drop | A hat. |

## Materials
"""
	var sections = ItemsMdParser.parse_equipment_sections(md)
	assert_eq(sections.size(), 2)
	assert_true(sections.has("Spirit Valley"))
	assert_true(sections.has("Other Zone"))
	assert_eq(sections["Spirit Valley"].size(), 1)
	assert_eq(sections["Spirit Valley"][0]["id"], "makeshift_dagger")
	assert_eq(sections["Other Zone"][0]["id"], "other_item")

func test_parse_equipment_sections_ignores_schema_table() -> void:
	# The Schema sub-section's table must NOT appear as a roster row.
	var md = """
## Equipment

### Schema

| Column | Maps to | Notes |
|---|---|---|
| id | item_id | snake_case |
"""
	var sections = ItemsMdParser.parse_equipment_sections(md)
	assert_eq(sections.size(), 0)
