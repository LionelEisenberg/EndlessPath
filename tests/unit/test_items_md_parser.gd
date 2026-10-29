extends GutTest

const AT = CharacterAttributesData.AttributeType

## parse_stats() reads each ATTRIBUTE+N or ATTRIBUTE-N into a bonus: one pair,
## two pairs, a negative value, and blank text (empty or spaces) as none.
func test_parse_stats_reads_each_pair() -> void:
	var cases: Array[Dictionary] = [
		{"name": "one pair", "text": "STRENGTH+3", "expected": {AT.STRENGTH: 3.0}},
		{"name": "two pairs", "text": "STRENGTH+3, AGILITY+1", "expected": {AT.STRENGTH: 3.0, AT.AGILITY: 1.0}},
		{"name": "negative value", "text": "WILLPOWER-2", "expected": {AT.WILLPOWER: -2.0}},
		{"name": "empty", "text": "", "expected": {}},
		{"name": "spaces only", "text": "   ", "expected": {}},
	]
	for case: Dictionary in cases:
		assert_eq(ItemsMdParser.parse_stats(case.text), case.expected, case.name)

func test_parse_stats_unknown_attr_returns_empty() -> void:
	# Invalid input -> push_error + empty dict (caller decides whether to abort)
	var result = ItemsMdParser.parse_stats("BOGUS+5")
	assert_eq(result.size(), 0)
	assert_push_error("unknown attribute 'BOGUS'")

const ES = EquipmentDefinitionData.EquipmentSlot

## parse_slot() maps a slot name to its EquipmentSlot, trimming whitespace.
func test_parse_slot_maps_names() -> void:
	var cases: Array[Dictionary] = [
		{"name": "MAIN_HAND", "text": "MAIN_HAND", "expected": ES.MAIN_HAND},
		{"name": "OFF_HAND", "text": "OFF_HAND", "expected": ES.OFF_HAND},
		{"name": "padded HEAD", "text": "  HEAD  ", "expected": ES.HEAD},
	]
	for case: Dictionary in cases:
		assert_eq(ItemsMdParser.parse_slot(case.text), case.expected, case.name)

func test_parse_slot_unknown_returns_negative_one() -> void:
	assert_eq(ItemsMdParser.parse_slot("BOGUS"), -1)
	assert_push_error("unknown slot 'BOGUS'")

## parse_table_header() returns the columns in order, stripped of whitespace
## and of backticks (a header may write `id` as markdown inline code).
func test_parse_table_header_returns_columns_in_order() -> void:
	var cases: Array[Dictionary] = [
		{"name": "plain header", "line": "| # | id | name | slot | stats |", "expected": ["#", "id", "name", "slot", "stats"]},
		{"name": "padded and backticked header", "line": "| ` # ` | `id` | name |", "expected": ["#", "id", "name"]},
	]
	for case: Dictionary in cases:
		assert_eq(ItemsMdParser.parse_table_header(case.line), case.expected, case.name)

func test_is_separator_line() -> void:
	assert_true(ItemsMdParser.is_separator_line("|---|---|---|"))
	assert_true(ItemsMdParser.is_separator_line("| --- | :--: | ---: |"))
	assert_false(ItemsMdParser.is_separator_line("| id | name |"))

## parse_table_row() maps each column to its cell, and a column past the
## row's last cell to an empty string.
func test_parse_table_row_maps_columns_to_cells() -> void:
	var cases: Array[Dictionary] = [
		{"name": "full row", "cols": ["#", "id", "name", "slot"],
			"line": "| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND |",
			"expected": {"#": "E1", "id": "makeshift_dagger", "name": "Makeshift Dagger", "slot": "MAIN_HAND"}},
		{"name": "missing columns", "cols": ["a", "b", "c"], "line": "| x | y |",
			"expected": {"a": "x", "b": "y", "c": ""}},
	]
	for case: Dictionary in cases:
		var row = ItemsMdParser.parse_table_row(case.line, case.cols)
		for column: String in case.expected:
			assert_eq(row[column], case.expected[column], "%s: column %s" % [case.name, column])

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

func test_build_equipment_populates_all_fields() -> void:
	var row = {
		"#": "E1",
		"id": "makeshift_dagger",
		"name": "Makeshift Dagger",
		"slot": "MAIN_HAND",
		"stats": "STRENGTH+3, AGILITY+2",
		"tier": "Foundation",
		"cost": "0",
		"identity": "Starter weapon",
		"source": "NPC reward (Beat 1)",
		"description": "A simple iron blade, well-balanced for a beginner."
	}
	var eq: EquipmentDefinitionData = ItemsMdParser.build_equipment(row)
	assert_not_null(eq)
	assert_eq(eq.item_id, "makeshift_dagger")
	assert_eq(eq.item_name, "Makeshift Dagger")
	assert_eq(eq.description, "A simple iron blade, well-balanced for a beginner.")
	assert_eq(eq.slot_type, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	assert_eq(eq.attribute_bonuses[AT.STRENGTH], 3.0)
	assert_eq(eq.attribute_bonuses[AT.AGILITY], 2.0)
	assert_eq(eq.base_value, 0.0)
	assert_eq(eq.item_type, ItemDefinitionData.ItemType.EQUIPMENT)

func test_build_equipment_empty_stats_yields_empty_bonuses() -> void:
	var row = {
		"id": "naked_ring", "name": "Naked Ring", "slot": "ACCESSORY",
		"stats": "", "tier": "Foundation", "cost": "0",
		"description": "Nothing here."
	}
	var eq = ItemsMdParser.build_equipment(row)
	assert_eq(eq.attribute_bonuses.size(), 0)
