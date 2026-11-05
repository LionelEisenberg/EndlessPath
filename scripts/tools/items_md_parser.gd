class_name ItemsMdParser
extends RefCounted

## Static parser primitives for docs/inventory/ITEMS.md.
## See the doc itself for the canonical schema.

## The fields a roster row writes into its .tres. The generator copies exactly
## these, and rewrites a file only when one of them differs.
const GENERATED_FIELDS: Array[StringName] = [
	&"item_id", &"item_name", &"description", &"slot_type", &"stat_percent_bonuses",
	&"stat_bonus_floor", &"armor", &"ward", &"base_value", &"icon",
]

## Parses a stats cell like "STRENGTH+30%, AGILITY+10%, FLOOR+2" into an
## EquipmentDefinitionData with only its four stat fields set: a stat word's
## N% stores N / 100 under the stat's key, ARMOR+N and WARD+N store N, and
## FLOOR+N stores the floor (1 when absent). Every word matches in any case.
## Blank text gives no bonuses. The first bad token pushes an error naming it,
## and the result is null.
static func parse_stats(s: String) -> EquipmentDefinitionData:
	var stats := EquipmentDefinitionData.new()
	# Set here rather than left to the class defaults, so the shipped-gear test
	# notices a default changing under a value the saver left out of a file.
	stats.stat_bonus_floor = 1
	stats.armor = 0.0
	stats.ward = 0.0
	var seen_words: Dictionary = {}
	for token: String in s.split(","):
		var t := token.strip_edges()
		if t.is_empty():
			continue
		var refusal := _read_stats_token(t, stats, seen_words)
		if not refusal.is_empty():
			push_error("ItemsMdParser.parse_stats: " + refusal)
			return null
	return stats

## Builds an EquipmentDefinitionData (no icon resolution — caller assigns icon).
## Returns null if a required field is missing, the slot is unknown, or the
## stats cell holds a bad token.
static func build_equipment(row: Dictionary) -> EquipmentDefinitionData:
	var required := ["id", "name", "slot", "stats", "description"]
	for key in required:
		if not row.has(key) or str(row[key]).strip_edges().is_empty() and key != "stats":
			push_error("ItemsMdParser.build_equipment: missing required field '%s' in row %s" % [key, row])
			return null

	var slot := parse_slot(row["slot"])
	if slot < 0:
		return null

	# parse_stats() has already named the bad token.
	var eq := parse_stats(row["stats"])
	if eq == null:
		return null
	eq.item_id = row["id"]
	eq.item_name = row["name"]
	eq.description = row["description"]
	eq.slot_type = slot
	eq.base_value = float(row.get("cost", "0"))
	# item_type is set to EQUIPMENT by EquipmentDefinitionData._init().
	return eq

## True when a and b hold the same value in every GENERATED_FIELDS field.
static func generated_fields_equal(a: EquipmentDefinitionData, b: EquipmentDefinitionData) -> bool:
	for field: StringName in GENERATED_FIELDS:
		if a.get(field) != b.get(field):
			return false
	return true

## Writes one stats token into stats, or returns why the token is refused
## ("" when it was read). seen_words collects the words read so far.
static func _read_stats_token(t: String, stats: EquipmentDefinitionData, seen_words: Dictionary) -> String:
	var sign_idx := _find_sign_index(t)
	if sign_idx < 0:
		return "missing + in '%s'" % t
	if t[sign_idx] == "-":
		return "no negative bonuses: '%s'" % t
	var word := t.substr(0, sign_idx).strip_edges()
	# Every word matches in any case (the stat words through stat_from_key()
	# below, FLOOR, ARMOR and WARD through this upper-cased copy), so two
	# spellings of one word would write the same field.
	var keyword := word.to_upper()
	if seen_words.has(keyword):
		return "'%s' appears twice" % word
	seen_words[keyword] = true
	var number_text := t.substr(sign_idx + 1).strip_edges()
	var has_percent := number_text.contains("%")
	if keyword == "FLOOR":
		if has_percent or not number_text.is_valid_int() or number_text.to_int() < 1:
			return "'%s' must be a whole number of at least 1" % t
		stats.stat_bonus_floor = number_text.to_int()
		return ""
	var stat: int = -1
	if keyword == "ARMOR" or keyword == "WARD":
		if has_percent:
			return "'%s' is flat: drop the %%" % t
	else:
		stat = CharacterAttributesData.stat_from_key(StringName(word.to_lower()))
		if stat == -1:
			return "unknown stat word '%s'" % word
		if not has_percent:
			return "'%s' needs a %%: stat bonuses are percents" % t
	var number := number_text.trim_suffix("%").strip_edges()
	if not number.is_valid_float():
		return "'%s' has no number" % t
	var value := number.to_float()
	if value <= 0.0:
		return "'%s' must be above 0" % t
	match keyword:
		"ARMOR":
			stats.armor = value
		"WARD":
			stats.ward = value
		_:
			var key := CharacterAttributesData.stat_key(stat as CharacterAttributesData.AttributeType)
			stats.stat_percent_bonuses[key] = value / 100.0
	return ""

static func _find_sign_index(token: String) -> int:
	# Locate the first + or - sign (skip index 0 — attribute names don't begin with signs).
	var plus := token.find("+", 1)
	var minus := token.find("-", 1)
	if plus < 0:
		return minus
	if minus < 0:
		return plus
	return min(plus, minus)

## Parses a markdown table header row "| # | id | name |" into ["#", "id", "name"].
## Strips whitespace and surrounding backticks from each cell.
static func parse_table_header(line: String) -> Array[String]:
	return _parse_table_cells(line)

## Parses a markdown table data row into a Dictionary keyed by the column names.
## Missing trailing cells get empty-string values.
static func parse_table_row(line: String, columns: Array) -> Dictionary:
	var cells := _parse_table_cells(line)
	var row: Dictionary = {}
	for i in range(columns.size()):
		row[columns[i]] = cells[i] if i < cells.size() else ""
	return row

## Returns true if the line is a markdown table separator like "|---|---|".
static func is_separator_line(line: String) -> bool:
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("|"):
		return false
	for c in trimmed:
		if c not in "|-: \t":
			return false
	return true

static func _parse_table_cells(line: String) -> Array[String]:
	var trimmed := line.strip_edges()
	# Drop leading/trailing pipe so split() doesn't produce empty fencepost cells.
	if trimmed.begins_with("|"):
		trimmed = trimmed.substr(1)
	if trimmed.ends_with("|"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	var raw := trimmed.split("|")
	var out: Array[String] = []
	for r in raw:
		out.append(r.strip_edges().trim_prefix("`").trim_suffix("`").strip_edges())
	return out

## Returns Dictionary[String, Array[Dictionary]] mapping zone name -> rows.
## Each row is a Dictionary keyed by the table's column names (from parse_table_row).
## Only tables under "## Equipment" with a roster-shaped header are included.
## Tables under other H2 sections, the Schema table, and non-table prose are skipped.
static func parse_equipment_sections(markdown: String) -> Dictionary:
	var result: Dictionary = {}
	var lines := markdown.split("\n")
	var in_equipment := false
	var current_zone := ""
	var pending_header: Array[String] = []
	var in_table := false

	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		var trimmed := line.strip_edges()

		if trimmed.begins_with("## "):
			in_equipment = (trimmed.substr(3).strip_edges() == "Equipment")
			current_zone = ""
			in_table = false
			pending_header.clear()
		elif in_equipment and trimmed.begins_with("### "):
			current_zone = trimmed.substr(4).strip_edges()
			in_table = false
			pending_header.clear()
		elif in_equipment and trimmed.begins_with("|") and current_zone != "":
			if pending_header.is_empty():
				# Candidate header line.
				var cols := parse_table_header(line)
				if is_roster_header(cols):
					pending_header = cols
					# Next line should be the separator; skip it.
					if i + 1 < lines.size() and is_separator_line(lines[i + 1]):
						i += 1
					in_table = true
			elif is_separator_line(line):
				# Defensive — shouldn't happen because we consumed it above.
				pass
			elif in_table:
				var row := parse_table_row(line, pending_header)
				if not result.has(current_zone):
					result[current_zone] = []
				result[current_zone].append(row)
		elif in_equipment and trimmed.is_empty():
			# Blank line terminates a table.
			in_table = false
			pending_header.clear()
		i += 1
	return result

## A header counts as a roster header if it has both `id` and `slot` columns.
## The Schema table (Column | Maps to | Notes) and Stats DSL text sections fail this.
static func is_roster_header(columns: Array[String]) -> bool:
	return columns.has("id") and columns.has("slot")

## Parses a slot literal like "MAIN_HAND" into EquipmentSlot.
## Returns -1 (and push_error) for unknown values.
static func parse_slot(s: String) -> int:
	var trimmed := s.strip_edges()
	if not EquipmentDefinitionData.EquipmentSlot.has(trimmed):
		push_error("ItemsMdParser.parse_slot: unknown slot '%s'" % trimmed)
		return -1
	return EquipmentDefinitionData.EquipmentSlot[trimmed]
