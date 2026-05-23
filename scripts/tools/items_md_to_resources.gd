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
	if sections.is_empty():
		push_error("ItemsMdGenerator: no equipment zones found in %s" % ITEMS_MD_PATH)
		return 1

	# Pre-flight: check for duplicate ids across the whole document.
	var seen_ids: Dictionary = {}
	for zone in sections:
		for row in sections[zone]:
			var id: String = row["id"]
			if seen_ids.has(id):
				push_error("ItemsMdGenerator: duplicate id '%s' in zones '%s' and '%s'" % [id, seen_ids[id], zone])
				return 1
			seen_ids[id] = zone

	# Pre-flight: check every icon exists before writing anything.
	for zone in sections:
		for row in sections[zone]:
			var icon_path := _icon_path_for(row["id"])
			if not ResourceLoader.exists(icon_path) and not FileAccess.file_exists(icon_path):
				push_error("ItemsMdGenerator: missing icon for id '%s' at %s" % [row["id"], icon_path])
				return 1

	var created := 0
	var updated := 0
	var skipped := 0
	var written_paths: Array[String] = []

	for zone in sections:
		var zone_folder := "%s/%s" % [EQUIPMENT_OUTPUT_ROOT, _slugify(zone)]
		_ensure_dir(zone_folder)
		for row in sections[zone]:
			var target_path := "%s/%s.tres" % [zone_folder, row["id"]]
			var status := _write_one(row, target_path)
			match status:
				"created": created += 1
				"updated": updated += 1
				"skipped": skipped += 1
				"error":
					push_error("ItemsMdGenerator: failed to write %s" % target_path)
					return 1
			written_paths.append(target_path)

	# Orphan detection: list .tres files in target folders not in written_paths.
	var orphans := _find_orphans(written_paths)
	print("ItemsMdGenerator: created=%d updated=%d skipped=%d orphans=%d" % [created, updated, skipped, orphans.size()])
	for o in orphans:
		print("  orphan: %s" % o)
	return 0

func _icon_path_for(id: String) -> String:
	return "%s/%s.png" % [ICON_ROOT, id]

func _slugify(zone: String) -> String:
	# "Spirit Valley" -> "spirit_valley"
	return zone.to_lower().replace(" ", "_")

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _write_one(row: Dictionary, target_path: String) -> String:
	# Load existing resource (if any) so ResourceSaver preserves its UID.
	var existing := ResourceLoader.load(target_path) if ResourceLoader.exists(target_path) else null
	var eq: EquipmentDefinitionData = ItemsMdParser.build_equipment(row)
	if eq == null:
		return "error"
	var icon := load(_icon_path_for(row["id"])) as Texture2D
	if icon == null:
		push_error("ItemsMdGenerator: failed to load icon %s" % _icon_path_for(row["id"]))
		return "error"
	eq.icon = icon

	var status := "created"
	if existing is EquipmentDefinitionData:
		if _resources_equal(existing, eq):
			return "skipped"
		# Re-use the existing resource instance so its UID and resource_path stay intact.
		existing.item_id = eq.item_id
		existing.item_name = eq.item_name
		existing.description = eq.description
		existing.slot_type = eq.slot_type
		existing.attribute_bonuses = eq.attribute_bonuses
		existing.base_value = eq.base_value
		existing.icon = eq.icon
		eq = existing
		status = "updated"
	var uid_str := ""
	if status == "created":
		# Generating a fresh UID string for the new resource.
		var uid_int := ResourceUID.create_id()
		uid_str = ResourceUID.id_to_text(uid_int)

	var err := ResourceSaver.save(eq, target_path)
	if err != OK:
		push_error("ItemsMdGenerator: ResourceSaver.save returned %s for %s" % [err, target_path])
		return "error"

	# ResourceSaver does not embed a uid= in the header for newly-created resources.
	# Inject it manually into the [gd_resource ...] header line now.
	if status == "created" and not uid_str.is_empty():
		_inject_uid_into_tres(target_path, uid_str)

	return status

## Reads the saved .tres file and rewrites its first line to include uid="<uid_str>".
func _inject_uid_into_tres(path: String, uid_str: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ItemsMdGenerator._inject_uid_into_tres: cannot read %s" % path)
		return
	var content := f.get_as_text()
	f.close()

	# Replace the first line's closing ] to insert uid="..."  before it.
	# Pattern: [gd_resource ... format=3]  →  [gd_resource ... format=3 uid="uid://..."]
	var first_newline := content.find("\n")
	var header_line := content.substr(0, first_newline) if first_newline >= 0 else content
	if "uid=" in header_line:
		return  # Already has a UID — nothing to do.
	var new_header := header_line.trim_suffix("]") + " uid=\"" + uid_str + "\"]"
	var new_content := new_header + content.substr(first_newline)

	var fw := FileAccess.open(path, FileAccess.WRITE)
	if fw == null:
		push_error("ItemsMdGenerator._inject_uid_into_tres: cannot write %s" % path)
		return
	fw.store_string(new_content)
	fw.close()

func _resources_equal(a: EquipmentDefinitionData, b: EquipmentDefinitionData) -> bool:
	return (
		a.item_id == b.item_id
		and a.item_name == b.item_name
		and a.description == b.description
		and a.slot_type == b.slot_type
		and a.attribute_bonuses == b.attribute_bonuses
		and is_equal_approx(a.base_value, b.base_value)
		and a.icon == b.icon
	)

func _find_orphans(written_paths: Array[String]) -> Array[String]:
	var orphans: Array[String] = []
	var written_set: Dictionary = {}
	for p in written_paths:
		written_set[p] = true
	var root_abs := ProjectSettings.globalize_path(EQUIPMENT_OUTPUT_ROOT)
	if not DirAccess.dir_exists_absolute(root_abs):
		return orphans
	var zones := DirAccess.get_directories_at(EQUIPMENT_OUTPUT_ROOT)
	for zone in zones:
		var folder := "%s/%s" % [EQUIPMENT_OUTPUT_ROOT, zone]
		var files := DirAccess.get_files_at(folder)
		for f in files:
			if not f.ends_with(".tres"):
				continue
			var full_path := "%s/%s" % [folder, f]
			if not written_set.has(full_path):
				orphans.append(full_path)
	return orphans

func _read_markdown() -> String:
	var f := FileAccess.open(ITEMS_MD_PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
