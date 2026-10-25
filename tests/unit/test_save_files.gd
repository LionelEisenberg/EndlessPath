extends GutTest

## Unit tests for SaveFiles: writing a save through a temp file, loading it (and
## falling back to the temp file when a crash left no save), copying a save
## aside, and the rotating backups. Every file lives under one temp folder in
## user://, removed around each test, so the developer's real save and backups
## are never read or written.

const ROOT: String = "user://__test_save_files"

## What backup() names a copy of `save.tres`: the stem, a UTC timestamp, then
## "-2", "-3", ... for copies made in the same second.
const BACKUP_NAME_PATTERN: String = "^save\\.(\\d{8}-\\d{6})(-\\d+)?\\.tres$"

func before_each() -> void:
	_remove_tree(ROOT)

func after_each() -> void:
	_remove_tree(ROOT)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _path(relative_path: String) -> String:
	return ROOT.path_join(relative_path)

func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)

## Deletes `dir_path` and everything under it.
func _remove_tree(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(_global(dir_path)):
		return
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(_global(dir_path.path_join(file_name)))
	for folder_name: String in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path.path_join(folder_name))
	DirAccess.remove_absolute(_global(dir_path))

func _gold_save(gold: float) -> SaveGameData:
	var save: SaveGameData = SaveGameData.new()
	save.gold = gold
	return save

## Writes a save holding this gold to `path` through SaveFiles.
func _write_gold(path: String, gold: float) -> void:
	assert_eq(SaveFiles.write_atomically(_gold_save(gold), path), OK, "writing %s" % path)

## The gold of the save SaveFiles loads at `path`, or -1.0 when nothing loads.
func _gold_at(path: String) -> float:
	var loaded: SaveGameData = SaveFiles.load_save(path)
	return -1.0 if loaded == null else loaded.gold

## Writes `text` to `path`, making its folder first.
func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_global(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

## The unix time of a "YYYYMMDD-HHMMSS" stamp, read as UTC.
func _unix_of_stamp(stamp: String) -> int:
	return Time.get_unix_time_from_datetime_dict({
		"year": stamp.substr(0, 4).to_int(),
		"month": stamp.substr(4, 2).to_int(),
		"day": stamp.substr(6, 2).to_int(),
		"hour": stamp.substr(9, 2).to_int(),
		"minute": stamp.substr(11, 2).to_int(),
		"second": stamp.substr(13, 2).to_int(),
	})

#-----------------------------------------------------------------------------
# TEMP PATH
#-----------------------------------------------------------------------------

func test_temp_path_keeps_the_extension() -> void:
	assert_eq(SaveFiles.temp_path_for("user://save.tres"), "user://save.tmp.tres")
	assert_eq(SaveFiles.temp_path_for("user://a.b/x.tres"), "user://a.b/x.tmp.tres",
		"a dot in a folder name is not taken for the extension")

#-----------------------------------------------------------------------------
# WRITE
#-----------------------------------------------------------------------------

func test_write_leaves_the_file_and_no_temp() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 1.0)
	assert_file_exists(path)
	assert_file_does_not_exist(SaveFiles.temp_path_for(path))
	assert_eq(DirAccess.get_files_at(ROOT), PackedStringArray(["save.tres"]), "the folder holds the save and nothing else")

func test_write_replaces_the_old_file() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 1.0)
	_write_gold(path, 2.0)
	assert_eq(_gold_at(path), 2.0)
	assert_file_does_not_exist(SaveFiles.temp_path_for(path))

func test_write_creates_missing_folders() -> void:
	var path: String = _path("a/b/save.tres")
	_write_gold(path, 1.0)
	assert_file_exists(path)
	assert_eq(_gold_at(path), 1.0)

func test_a_failed_write_leaves_the_old_file_alone() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 1.0)
	# A folder where the temp file goes makes the save to it fail.
	DirAccess.make_dir_recursive_absolute(_global(SaveFiles.temp_path_for(path)))
	var error: Error = SaveFiles.write_atomically(_gold_save(2.0), path)
	assert_engine_error("Cannot save file", "the engine reports the save it could not make")
	assert_ne(error, OK, "the failed save is reported")
	assert_eq(_gold_at(path), 1.0, "the save on disk is the old one")

#-----------------------------------------------------------------------------
# LOAD
#-----------------------------------------------------------------------------

func test_load_falls_back_to_the_temp_file() -> void:
	var path: String = _path("x.tres")
	# What a crash inside the rename leaves: a whole temp file and no save.
	DirAccess.make_dir_recursive_absolute(_global(ROOT))
	assert_eq(ResourceSaver.save(_gold_save(7.0), SaveFiles.temp_path_for(path)), OK)
	assert_file_does_not_exist(path)
	assert_eq(_gold_at(path), 7.0)
	# Loading only reads: the temp is not moved into place.
	assert_file_does_not_exist(path)
	assert_file_exists(SaveFiles.temp_path_for(path))

func test_load_prefers_the_file_over_its_temp() -> void:
	# A crash while saving the temp can leave a half-written temp next to a save
	# that is whole, and the save is the one to read.
	var path: String = _path("x.tres")
	_write_gold(path, 1.0)
	assert_eq(ResourceSaver.save(_gold_save(7.0), SaveFiles.temp_path_for(path)), OK)
	assert_eq(_gold_at(path), 1.0)

func test_load_ignores_the_cache() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 7.0)
	var first: SaveGameData = SaveFiles.load_save(path)
	var second: SaveGameData = SaveFiles.load_save(path)
	assert_not_null(first)
	assert_not_null(second)
	assert_not_same(first, second, "each load reads the file again")
	assert_false(ResourceLoader.has_cached(path), "a load is not stored in the cache")
	first.gold = 99.0
	assert_eq(second.gold, 7.0, "changing one leaves the other")

func test_load_keeps_shared_item_resources_shared() -> void:
	# The game loads each item resource once and shares it, and the inventory's
	# dictionaries are keyed by those instances. A load that also ignored the
	# cache for the resources the save points at would key them by copies that no
	# lookup finds.
	var item_path: String = _path("test_fern.tres")
	var fern: MaterialDefinitionData = MaterialDefinitionData.new()
	fern.item_id = "test_fern"
	DirAccess.make_dir_recursive_absolute(_global(ROOT))
	assert_eq(ResourceSaver.save(fern, item_path), OK)
	var shared: MaterialDefinitionData = load(item_path)
	var save: SaveGameData = SaveGameData.new()
	save.inventory.materials[shared] = 3
	var path: String = _path("save.tres")
	assert_eq(SaveFiles.write_atomically(save, path), OK)

	var loaded: SaveGameData = SaveFiles.load_save(path)
	assert_not_null(loaded)
	if loaded != null:
		assert_true(loaded.inventory.materials.has(shared), "the save's item is the shared instance")
		assert_eq(loaded.inventory.materials.get(shared), 3)

func test_load_of_a_missing_file_is_null() -> void:
	assert_null(SaveFiles.load_save(_path("nothing.tres")))

func test_load_of_another_kind_of_resource_is_null() -> void:
	var path: String = _path("not_a_save.tres")
	DirAccess.make_dir_recursive_absolute(_global(ROOT))
	assert_eq(ResourceSaver.save(Resource.new(), path), OK)
	assert_null(SaveFiles.load_save(path))

#-----------------------------------------------------------------------------
# COPY ASIDE
#-----------------------------------------------------------------------------

func test_copy_aside_names_the_copy_after_the_reason() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 3.0)
	var copy: String = SaveFiles.copy_aside(path, "unreadable")
	assert_eq(copy.get_base_dir(), ROOT, "the copy sits next to the save")
	var named: RegExMatch = RegEx.create_from_string("^save\\.unreadable\\.\\d+\\.tres$").search(copy.get_file())
	assert_not_null(named, "%s is named <stem>.<reason>.<unix time>.tres" % copy.get_file())
	assert_eq(_read_text(copy), _read_text(path), "the copy is identical")
	assert_file_exists(path)

#-----------------------------------------------------------------------------
# BACKUP
#-----------------------------------------------------------------------------

func test_backup_copies_with_a_timestamp() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 5.0)
	var backup_dir: String = _path("backups")
	var before: int = int(Time.get_unix_time_from_system())
	var copy: String = SaveFiles.backup(path, backup_dir, 10)
	var after: int = int(Time.get_unix_time_from_system())
	assert_ne(copy, "", "the copy was made")
	assert_eq(copy.get_base_dir(), backup_dir, "in the backup folder, which did not exist yet")
	var named: RegExMatch = RegEx.create_from_string(BACKUP_NAME_PATTERN).search(copy.get_file())
	assert_not_null(named, "%s is named <stem>.<YYYYMMDD-HHMMSS>[-N].tres" % copy.get_file())
	if named != null:
		assert_between(_unix_of_stamp(named.get_string(1)), before, after, "the stamp is the UTC time of the copy")
	assert_eq(_read_text(copy), _read_text(path), "the copy is identical")
	assert_file_exists(path)

func test_backup_of_a_missing_file_is_empty() -> void:
	var backup_dir: String = _path("backups")
	assert_eq(SaveFiles.backup(_path("save.tres"), backup_dir, 10), "")
	assert_eq(SaveFiles.list_backups(_path("save.tres"), backup_dir).size(), 0, "nothing was copied")

func test_backups_made_in_one_second_do_not_overwrite_each_other() -> void:
	var path: String = _path("save.tres")
	var backup_dir: String = _path("backups")
	_write_gold(path, 1.0)
	var first: String = SaveFiles.backup(path, backup_dir, 10)
	var second: String = SaveFiles.backup(path, backup_dir, 10)
	assert_ne(first, second, "the second copy has a name of its own")
	assert_file_exists(first)
	assert_file_exists(second)
	assert_eq(SaveFiles.list_backups(path, backup_dir), PackedStringArray([second, first]))

func test_backup_always_keeps_the_copy_it_just_made() -> void:
	var path: String = _path("save.tres")
	_write_gold(path, 1.0)
	var copy: String = SaveFiles.backup(path, _path("backups"), 0)
	assert_file_exists(copy)

func test_backup_keeps_the_newest_of_its_own_stem() -> void:
	var save_path: String = _path("save.tres")
	var other_path: String = _path("other.tres")
	var backup_dir: String = _path("backups")
	_write_gold(save_path, 1.0)
	_write_gold(other_path, 2.0)
	# The other stem's backups are the oldest files in the folder, so a rotation
	# that counted every stem together would take them first.
	var other_copies: Array[String] = []
	for _n: int in 2:
		other_copies.append(SaveFiles.backup(other_path, backup_dir, 10))
	# These come fast enough to share a second, which is when a naive "first free
	# name" would hand a new copy the name a rotation just freed and rotate it away.
	var save_copies: Array[String] = []
	for _n: int in 12:
		save_copies.append(SaveFiles.backup(save_path, backup_dir, 10))

	var kept: PackedStringArray = SaveFiles.list_backups(save_path, backup_dir)
	assert_eq(kept.size(), 10, "10 of the 12 are kept")
	assert_eq(SaveFiles.list_backups(other_path, backup_dir).size(), 2, "the other stem's two are untouched")
	var newest_first: Array[String] = save_copies.slice(2)
	newest_first.reverse()
	assert_eq(kept, PackedStringArray(newest_first), "the 10 newest are the ones kept")
	for copy: String in save_copies.slice(0, 2):
		assert_file_does_not_exist(copy)
	for copy: String in other_copies:
		assert_file_exists(copy)

func test_backup_leaves_files_it_did_not_make_alone() -> void:
	var path: String = _path("save.tres")
	var backup_dir: String = _path("backups")
	_write_gold(path, 1.0)
	var not_backups: Array[String] = [
		"save.manual.tres", # a copy someone made by hand
		"save.old.20260101-000000.tres", # another stem that starts with "save."
		"other.20260101-000000.tres",
		"save.20260101-000000.txt", # not a save file
	]
	for file_name: String in not_backups:
		_write_text(backup_dir.path_join(file_name), "not a backup")
	SaveFiles.backup(path, backup_dir, 1)
	var newest: String = SaveFiles.backup(path, backup_dir, 1)
	assert_eq(SaveFiles.list_backups(path, backup_dir), PackedStringArray([newest]), "keep 1 leaves only the newest backup")
	for file_name: String in not_backups:
		assert_file_exists(backup_dir.path_join(file_name))

#-----------------------------------------------------------------------------
# LIST BACKUPS
#-----------------------------------------------------------------------------

func test_list_backups_is_newest_first() -> void:
	var path: String = _path("save.tres")
	var backup_dir: String = _path("backups")
	# Oldest first, with copies that share a second: "-10" is newer than "-2", and
	# the copy with no suffix is the first of its second.
	var oldest_first: Array[String] = [
		"save.20260101-000000.tres",
		"save.20261024-101500.tres",
		"save.20261024-101500-2.tres",
		"save.20261024-101500-10.tres",
		"save.20261024-101501.tres",
	]
	var expected: PackedStringArray = PackedStringArray()
	for file_name: String in oldest_first:
		_write_text(backup_dir.path_join(file_name), file_name)
		expected.insert(0, backup_dir.path_join(file_name))
	# Another stem's backup sits among them and is not listed.
	_write_text(backup_dir.path_join("other.20261024-101500.tres"), "other")
	assert_eq(SaveFiles.list_backups(path, backup_dir), expected)

func test_list_backups_of_a_folder_that_is_not_there_is_empty() -> void:
	assert_eq(SaveFiles.list_backups(_path("save.tres"), _path("no_backups_yet")).size(), 0)
