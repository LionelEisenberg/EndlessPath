class_name ItemsMdParser
extends RefCounted

## Static parser primitives for docs/inventory/ITEMS.md.
## See the doc itself for the canonical schema.

## Parses inline stats DSL like "STRENGTH+3, AGILITY+1" into a Dictionary
## keyed by CharacterAttributesData.AttributeType (int enum values).
## Empty input -> empty dict. Unknown attribute name -> push_error + empty dict.
static func parse_stats(s: String) -> Dictionary:
	var result: Dictionary = {}
	var trimmed := s.strip_edges()
	if trimmed.is_empty():
		return result
	var tokens := trimmed.split(",")
	for token in tokens:
		var t := token.strip_edges()
		if t.is_empty():
			continue
		var sign_idx := _find_sign_index(t)
		if sign_idx <= 0:
			push_error("ItemsMdParser.parse_stats: missing +/- in token '%s'" % t)
			return {}
		var attr_name := t.substr(0, sign_idx).strip_edges()
		var num_str := t.substr(sign_idx).strip_edges()
		if not CharacterAttributesData.AttributeType.has(attr_name):
			push_error("ItemsMdParser.parse_stats: unknown attribute '%s'" % attr_name)
			return {}
		result[CharacterAttributesData.AttributeType[attr_name]] = float(num_str)
	return result

## Builds an EquipmentDefinitionData (no icon resolution — caller assigns icon).
## Returns null if any required field is missing or invalid.
static func build_equipment(row: Dictionary) -> EquipmentDefinitionData:
	var required := ["id", "name", "slot", "stats", "description"]
	for key in required:
		if not row.has(key) or str(row[key]).strip_edges().is_empty() and key != "stats":
			push_error("ItemsMdParser.build_equipment: missing required field '%s' in row %s" % [key, row])
			return null

	var slot := parse_slot(row["slot"])
	if slot < 0:
		return null

	var bonuses := parse_stats(row["stats"])

	var eq := EquipmentDefinitionData.new()
	eq.item_id = row["id"]
	eq.item_name = row["name"]
	eq.description = row["description"]
	eq.slot_type = slot
	eq.attribute_bonuses = bonuses
	eq.base_value = float(row.get("cost", "0"))
	# item_type is set to EQUIPMENT by EquipmentDefinitionData._init().
	return eq

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
