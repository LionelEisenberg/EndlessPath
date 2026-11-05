extends GutTest

## STAT+N% is a fraction, ARMOR+N and WARD+N flat, FLOOR+N the floor. A case
## leaves out a field at its default (floor 1, armor 0, Ward 0).
func test_parse_stats_reads_each_token() -> void:
	var cases: Array[Dictionary] = [
		{"name": "one percent", "text": "STRENGTH+30%", "percents": {&"strength": 0.3}},
		{"name": "two percents and a floor", "text": "STRENGTH+30%, AGILITY+10%, FLOOR+2",
			"percents": {&"strength": 0.3, &"agility": 0.1}, "floor": 2},
		{"name": "a percent and armor", "text": "BODY+40%, ARMOR+6", "percents": {&"body": 0.4}, "armor": 6.0},
		{"name": "a percent and Ward", "text": "SPIRIT+15%, WARD+4", "percents": {&"spirit": 0.15}, "ward": 4.0},
		{"name": "Mind and Control", "text": "MIND+20%, CONTROL+20%", "percents": {&"mind": 0.2, &"control": 0.2}},
		{"name": "a fractional percent", "text": "SPIRIT+12.5%", "percents": {&"spirit": 0.125}},
		{"name": "empty", "text": "", "percents": {}},
		{"name": "spaces only", "text": "   ", "percents": {}},
	]
	for case: Dictionary in cases:
		var stats: EquipmentDefinitionData = ItemsMdParser.parse_stats(case.text)
		assert_not_null(stats, case.name)
		if stats == null:
			continue
		assert_eq(stats.stat_percent_bonuses, case.percents, "%s: percents" % case.name)
		assert_eq(stats.stat_bonus_floor, case.get("floor", 1), "%s: floor" % case.name)
		assert_eq(stats.armor, case.get("armor", 0.0), "%s: armor" % case.name)
		assert_eq(stats.ward, case.get("ward", 0.0), "%s: Ward" % case.name)

func test_parse_stats_refuses_a_bad_token() -> void:
	var cases: Array[Dictionary] = [
		{"name": "unknown word", "text": "BOGUS+5%", "error": "unknown stat word 'BOGUS'"},
		{"name": "no sign", "text": "STRENGTH30%", "error": "missing + in 'STRENGTH30%'"},
		{"name": "a negative bonus", "text": "AGILITY-10%", "error": "no negative bonuses: 'AGILITY-10%'"},
		{"name": "a stat without %", "text": "STRENGTH+3", "error": "'STRENGTH+3' needs a %"},
		{"name": "armor with %", "text": "ARMOR+6%", "error": "'ARMOR+6%' is flat"},
		{"name": "not a number", "text": "SPIRIT+ten%", "error": "'SPIRIT+ten%' has no number"},
		{"name": "a zero percent", "text": "SPIRIT+0%", "error": "'SPIRIT+0%' must be above 0"},
		{"name": "a floor below 1", "text": "BODY+20%, FLOOR+0", "error": "'FLOOR+0' must be a whole number of at least 1"},
		{"name": "a fractional floor", "text": "BODY+20%, FLOOR+1.5", "error": "'FLOOR+1.5' must be a whole number of at least 1"},
		{"name": "a word twice", "text": "BODY+20%, BODY+10%", "error": "'BODY' appears twice"},
	]
	for case: Dictionary in cases:
		assert_null(ItemsMdParser.parse_stats(case.text), case.name)
		assert_push_error(case.error, case.name)

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
| E1 | other_item | Other Item | HEAD | MIND+1 | Copper | 5 | Hat | Drop | A hat. |

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
		"stats": "STRENGTH+30%, AGILITY+10%, FLOOR+2",
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
	assert_eq(eq.stat_percent_bonuses, {&"strength": 0.3, &"agility": 0.1})
	assert_eq(eq.stat_bonus_floor, 2)
	assert_eq(eq.base_value, 0.0)
	assert_eq(eq.item_type, ItemDefinitionData.ItemType.EQUIPMENT)

func test_build_equipment_empty_stats_yields_empty_bonuses() -> void:
	var row = {
		"id": "naked_ring", "name": "Naked Ring", "slot": "ACCESSORY",
		"stats": "", "tier": "Foundation", "cost": "0",
		"description": "Nothing here."
	}
	var eq: EquipmentDefinitionData = ItemsMdParser.build_equipment(row)
	assert_eq(eq.stat_percent_bonuses.size(), 0, "no stat percents")
	assert_eq(eq.stat_bonus_floor, 1, "the default floor")

func test_build_equipment_refuses_a_bad_stats_cell() -> void:
	var row: Dictionary = {
		"id": "flat_dagger", "name": "Flat Dagger", "slot": "MAIN_HAND",
		"stats": "STRENGTH+3", "cost": "0", "description": "Old notation.",
	}
	assert_null(ItemsMdParser.build_equipment(row))
	assert_push_error("needs a %")

## The generator rewrites a file only when a generated field differs.
func test_generated_fields_equal_notices_each_stat_field() -> void:
	var base_cell: String = "STRENGTH+30%, ARMOR+6, WARD+4, FLOOR+2"
	var base: EquipmentDefinitionData = ItemsMdParser.parse_stats(base_cell)
	assert_true(ItemsMdParser.generated_fields_equal(base, ItemsMdParser.parse_stats(base_cell)), "the same cell")
	var cases: Array[Dictionary] = [
		{"name": "a percent", "text": "STRENGTH+50%, ARMOR+6, WARD+4, FLOOR+2"},
		{"name": "the floor", "text": "STRENGTH+30%, ARMOR+6, WARD+4, FLOOR+3"},
		{"name": "armor", "text": "STRENGTH+30%, ARMOR+5, WARD+4, FLOOR+2"},
		{"name": "Ward", "text": "STRENGTH+30%, ARMOR+6, WARD+5, FLOOR+2"},
	]
	for case: Dictionary in cases:
		assert_false(ItemsMdParser.generated_fields_equal(base, ItemsMdParser.parse_stats(case.text)), case.name)

#-----------------------------------------------------------------------------
# THE SHIPPED GEAR
#-----------------------------------------------------------------------------

## Catches a row edited without a generator run, and a class default changing
## under a value the saver left out of a file.
func test_the_shipped_gear_matches_items_md() -> void:
	var sections: Dictionary = ItemsMdParser.parse_equipment_sections(FileAccess.get_file_as_string("res://docs/inventory/ITEMS.md"))
	var rows: Array = sections.get("Spirit Valley", [])
	assert_gt(rows.size(), 0, "precondition: ITEMS.md lists Spirit Valley gear")
	for row: Dictionary in rows:
		var built: EquipmentDefinitionData = ItemsMdParser.build_equipment(row)
		var shipped := load("res://resources/items/equipment/spirit_valley/%s.tres" % row["id"]) as EquipmentDefinitionData
		assert_not_null(built, "%s builds" % row["id"])
		assert_not_null(shipped, "%s has a file" % row["id"])
		if built == null or shipped == null:
			continue
		built.icon = shipped.icon  # the generator takes the icon from the PNG, not from the row
		assert_true(ItemsMdParser.generated_fields_equal(built, shipped), "%s matches its row" % row["id"])
