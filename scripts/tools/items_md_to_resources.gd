# scripts/tools/items_md_to_resources.gd
extends SceneTree

## Headless CLI tool. Reads docs/inventory/ITEMS.md, parses Equipment tables,
## writes one .tres per row under resources/items/equipment/<zone>/.
##
## Invoke:
##   "<godot>" --headless -s scripts/tools/items_md_to_resources.gd

const ITEMS_MD_PATH := "res://docs/inventory/ITEMS.md"
const EQUIPMENT_OUTPUT_ROOT := "res://resources/items/equipment"
const ICON_ROOT := "res://assets/sprites/items/equipment"

func _initialize() -> void:
	var exit_code := run()
	quit(exit_code)

func run() -> int:
	var markdown := _read_markdown()
	if markdown.is_empty():
		push_error("ItemsMdGenerator: failed to read %s" % ITEMS_MD_PATH)
		return 1
	var sections := ItemsMdParser.parse_equipment_sections(markdown)
	var row_count := 0
	for zone in sections:
		row_count += (sections[zone] as Array).size()
	print("ItemsMdGenerator: parsed %d zones, %d total rows" % [sections.size(), row_count])
	return 0

func _read_markdown() -> String:
	var f := FileAccess.open(ITEMS_MD_PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
