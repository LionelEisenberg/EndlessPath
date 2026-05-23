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

## Parses a slot literal like "MAIN_HAND" into EquipmentSlot.
## Returns -1 (and push_error) for unknown values.
static func parse_slot(s: String) -> int:
	var trimmed := s.strip_edges()
	if not EquipmentDefinitionData.EquipmentSlot.has(trimmed):
		push_error("ItemsMdParser.parse_slot: unknown slot '%s'" % trimmed)
		return -1
	return EquipmentDefinitionData.EquipmentSlot[trimmed]
