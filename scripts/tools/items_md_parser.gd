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
