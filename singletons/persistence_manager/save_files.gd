class_name SaveFiles extends RefCounted

## SaveFiles
## How a save file is written, loaded and backed up. A write goes to a temp file
## next to the save and then replaces it, so a crash mid-write leaves the old
## save whole, and a load falls back to that temp file when a crash inside the
## replace left no save. Statics only. Every path comes from the caller: no save
## location is known here, so a test can point any of it at a temp folder.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## What sits between "<stem>." and ".<extension>" in a backup's file name: a UTC
## timestamp, then "-2", "-3", ... for copies made in the same second. Group 1 is
## the timestamp and group 2 the number after the dash, when there is one.
const _BACKUP_STAMP_PATTERN: String = "^(\\d{8}-\\d{6})(?:-(\\d+))?$"

#-----------------------------------------------------------------------------
# WRITE AND LOAD
#-----------------------------------------------------------------------------

## The temp file a write goes through before it replaces `path`: "user://save.tres"
## gives "user://save.tmp.tres". It keeps the extension because ResourceSaver
## picks the file format from it and refuses one it does not know.
static func temp_path_for(path: String) -> String:
	return "%s.tmp.%s" % [path.get_basename(), path.get_extension()]

## Saves `resource` to `path` without ever leaving a half-written file there: it
## makes the parent folder, saves to temp_path_for(path), then renames the temp
## over `path`. Returns the first error it meets, OK when the file is replaced.
## A save that fails leaves `path` as it was. Windows deletes the old file before
## it moves the temp in, so a crash inside that rename can leave only the temp,
## whole, which load_save() reads.
static func write_atomically(resource: Resource, path: String) -> Error:
	var folder_error: Error = _make_folder_for(path)
	if folder_error != OK:
		return folder_error
	var save_error: Error = ResourceSaver.save(resource, temp_path_for(path))
	if save_error != OK:
		return save_error
	return _replace_with_temp(path)

## Writes `bytes` to `path` the way write_atomically() writes a resource: to
## temp_path_for(path), which then replaces `path`. It puts a copy of a save file in
## place of another, byte for byte, so nothing this build does not know is lost.
## Returns the first error it meets, OK when the file is replaced.
static func write_bytes_atomically(bytes: PackedByteArray, path: String) -> Error:
	var folder_error: Error = _make_folder_for(path)
	if folder_error != OK:
		return folder_error
	var file: FileAccess = FileAccess.open(temp_path_for(path), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_buffer(bytes)
	file.close()
	if not stored:
		return ERR_FILE_CANT_WRITE
	return _replace_with_temp(path)

## Loads the save at `path`, or returns null when nothing there loads as a
## SaveGameData. When `path` is missing but its temp file is there, it loads the
## temp: a crash inside the rename that ends a write leaves exactly that, and the
## temp was whole before the rename began. A temp next to a save that exists is
## never read, since a crash while saving it can leave it half-written. Loading
## only reads: nothing is moved or written.
##
## It always ignores the resource cache, so every call reads the file again and
## returns its own object. That is CACHE_MODE_IGNORE and not
## CACHE_MODE_IGNORE_DEEP: the inventory's dictionaries are keyed by the item
## resources the whole game shares, and a deep reload would key them by copies
## that no lookup finds.
static func load_save(path: String) -> SaveGameData:
	var load_path: String = path
	if not FileAccess.file_exists(path):
		var temp_path: String = temp_path_for(path)
		if not FileAccess.file_exists(temp_path):
			return null
		Log.warn("SaveFiles: %s is missing, so its temp file %s is loaded instead (a write was cut short)" % [path, temp_path])
		load_path = temp_path
	return ResourceLoader.load(load_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData

#-----------------------------------------------------------------------------
# COPIES AND BACKUPS
#-----------------------------------------------------------------------------

## Copies the file at `path` next to it as <name>.<reason>.<unix time>.<extension>
## and returns the copy's path ("" when the copy failed).
static func copy_aside(path: String, reason: String) -> String:
	var copy_path: String = "%s.%s.%d.%s" % [path.get_basename(), reason, int(Time.get_unix_time_from_system()), path.get_extension()]
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy_path))
	if error != OK:
		Log.critical("SaveFiles: Could not copy %s to %s (error %d)" % [path, copy_path, error])
		return ""
	return copy_path

## Copies the save at `path` into `backup_dir` as
## <stem>.<YYYYMMDD-HHMMSS>.<extension>. The time is UTC, so a clock change or a
## trip across time zones cannot sort a new copy below an older one. A copy made
## in the same second as an earlier one gets "-2", "-3", ... after the time. Then
## it deletes this save's oldest backups until `keep` are left, the new copy among
## them (a `keep` below 1 counts as 1). Another save's backups, and files that are
## not named like a backup, are never touched. Returns the copy's path, or "" when
## `path` does not exist or the copy failed.
static func backup(path: String, backup_dir: String, keep: int) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir))
	if folder_error != OK:
		Log.error("SaveFiles: Could not make the backup folder %s (error %d)" % [backup_dir, folder_error])
		return ""

	var stamp: String = _utc_stamp()
	# One past the highest number already in use this second, not the first free
	# one: a rotation deletes the lowest names first, and a new copy that took one
	# of them would sort below the copies it should outlive.
	var sequence: int = 1
	for entry: Dictionary in _backup_entries(path, backup_dir):
		if entry["stamp"] == stamp:
			sequence = maxi(sequence, int(entry["sequence"]) + 1)
	var number: String = "" if sequence == 1 else "-%d" % sequence
	var copy_path: String = backup_dir.path_join("%s.%s%s.%s" % [path.get_file().get_basename(), stamp, number, path.get_extension()])
	var copy_error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy_path))
	if copy_error != OK:
		Log.error("SaveFiles: Could not back up %s to %s (error %d)" % [path, copy_path, copy_error])
		return ""

	var backups: PackedStringArray = list_backups(path, backup_dir)
	for index: int in range(maxi(keep, 1), backups.size()):
		var delete_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(backups[index]))
		if delete_error != OK:
			Log.warn("SaveFiles: Could not delete the old backup %s (error %d)" % [backups[index], delete_error])
	return copy_path

## The paths of `path`'s backups in `backup_dir`, newest first. A backup is a
## file named like backup() names one for this save, so another save's backups
## and anything else in the folder are left out.
static func list_backups(path: String, backup_dir: String) -> PackedStringArray:
	var entries: Array[Dictionary] = _backup_entries(path, backup_dir)
	entries.sort_custom(_is_newer_backup)
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		found.append(backup_dir.path_join(entry["file_name"]))
	return found

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Makes the folder `path` goes in, with its parents.
static func _make_folder_for(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))

## Renames temp_path_for(path) over `path`, the last step of a write. Windows
## deletes the old file before it moves the temp in, so a crash in between leaves
## only the temp, whole, which load_save() reads.
static func _replace_with_temp(path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path_for(path)), ProjectSettings.globalize_path(path))

## The current UTC time as YYYYMMDD-HHMMSS.
static func _utc_stamp() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d-%02d%02d%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]

## The files in `backup_dir` named like a backup of `path`, in no order. Each is
## a dictionary with its "file_name", its "stamp" and its "sequence" (1 for a copy
## with no "-N" after the timestamp). A missing folder holds none.
static func _backup_entries(path: String, backup_dir: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup_dir)):
		return entries
	var prefix: String = path.get_file().get_basename() + "."
	var suffix: String = "." + path.get_extension()
	var stamp_pattern: RegEx = RegEx.create_from_string(_BACKUP_STAMP_PATTERN)
	for file_name: String in DirAccess.get_files_at(backup_dir):
		if not file_name.begins_with(prefix) or not file_name.ends_with(suffix):
			continue
		var stamp_match: RegExMatch = stamp_pattern.search(file_name.trim_prefix(prefix).trim_suffix(suffix))
		if stamp_match == null:
			continue
		entries.append({
			"file_name": file_name,
			"stamp": stamp_match.get_string(1),
			"sequence": maxi(stamp_match.get_string(2).to_int(), 1),
		})
	return entries

## True when backup entry `a` is newer than `b`: a later timestamp, or the same
## second and a higher number.
static func _is_newer_backup(a: Dictionary, b: Dictionary) -> bool:
	if a["stamp"] != b["stamp"]:
		return a["stamp"] > b["stamp"]
	return a["sequence"] > b["sequence"]
