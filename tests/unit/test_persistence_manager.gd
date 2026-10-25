extends GutTest

## Unit tests for PersistenceManager's sessions: boot (the launch options and the
## boot backup), opening a save file (load, migrate, check, repair), swapping a
## save in, and writing (save_data(), the autosave tick, the save on quit). Each
## test builds its own PersistenceManager (never the autoload) pointed at
## temporary user:// files and a temporary backup folder, so the developer's real
## save.tres and backups are never read or written. The last test reads the
## autoload's state, to show this GUT run plays a save in memory.
##
## The rule under test: PersistenceManager never replaces a save file it could
## not read or check. A save that fails to load (for example because a stale
## import cache is missing a texture an item .tres references) is copied aside
## and left untouched, and nothing writes to it for the rest of the session. A
## save written by a newer build is played in memory and never written either.

const PersistenceManagerScript: GDScript = preload("res://singletons/persistence_manager/persistence_manager.gd")

const TMP_PREFIX: String = "__test_persistence_"

## Where the test managers keep their backups. after_each() deletes it.
const BACKUP_DIR: String = "user://__test_persistence_backups/"

## A SaveGameData that uses a res:// resource which cannot load, the way a save
## looks when an item .tres it names cannot load. (An ext_resource the save
## never uses would only print an error; using it makes the whole load fail.)
const UNREADABLE_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]
[ext_resource type="Resource" path="res://__missing_for_test_persistence/missing_item.tres" id="2_missing"]

[resource]
script = ExtResource("1_save")
gold = 235.0
character_attributes = ExtResource("2_missing")
"""

const READABLE_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
gold = 42.0
current_selected_zone_id = "%s"
"""

## A save written by a build that knows save version 99, standing in the zone
## the %s names. Test Zone shows whether it was migrated (this build's migrate()
## moves it to Spirit Valley); a zone this build does not know shows the repair.
const NEWER_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
save_version = 99
gold = 42.0
current_selected_zone_id = "%s"
"""

## A PersistenceManager whose verify() dependencies (ZoneManager's zone list)
## failed to load, as they do when the zone action icons are not imported.
class UnverifiablePersistenceManager extends "res://singletons/persistence_manager/persistence_manager.gd":
	func _can_verify() -> bool:
		return false

var _manager: Node = null

func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.free()
	_manager = null
	for file_name in DirAccess.get_files_at("user://"):
		if file_name.begins_with(TMP_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)):
		for file_name in DirAccess.get_files_at(BACKUP_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_DIR.path_join(file_name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_DIR))

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _path(test_name: String) -> String:
	return "user://%s%s.tres" % [TMP_PREFIX, test_name]

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

## A bare PersistenceManager that plays `path`. Its main save is another temp
## file and its backups go to BACKUP_DIR, so nothing it does reaches the real
## save or its backups.
func _make_manager(path: String, script: Variant = PersistenceManagerScript) -> Node:
	_manager = script.new()
	_manager.save_path = path
	_manager.main_save_path = _path("main_save")
	_manager.backup_dir = BACKUP_DIR
	return _manager

## Boots `manager` as a launch with no options does, whatever this GUT run was
## launched with, so no option on the command line can point a test at another
## file.
func _boot(manager: Node) -> void:
	manager.boot(LaunchOptions.new())

## Files next to `path` that start with its name plus `.<reason>.`.
func _backups_of(path: String, reason: String) -> Array[String]:
	var stem: String = path.get_file().get_basename() + "." + reason + "."
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at("user://"):
		if file_name.begins_with(stem):
			found.append("user://" + file_name)
	return found

## The gold of the save on disk at `path`, read again from the file, or -1.0
## when nothing there loads.
func _gold_in_file(path: String) -> float:
	var loaded: SaveGameData = SaveFiles.load_save(path)
	return -1.0 if loaded == null else loaded.gold

## Loading an unreadable save makes the engine print parse errors. They are the
## point of these tests, so they are marked expected.
func _expect_load_errors() -> void:
	for error in get_errors():
		error.handled = true

#-----------------------------------------------------------------------------
# UNREADABLE SAVE
#-----------------------------------------------------------------------------

func test_unreadable_save_is_never_overwritten() -> void:
	var path := _path("unreadable_kept")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	_boot(manager)
	_expect_load_errors()
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "boot() must not write over a save it could not read")
	assert_not_null(manager.save_game_data, "the session still runs on a default save in memory")

func test_unreadable_save_blocks_later_saves() -> void:
	var path := _path("unreadable_blocked")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	_boot(manager)
	_expect_load_errors()
	assert_true(manager.is_save_blocked())
	assert_ne(manager.save_data(), OK, "the SaveTimer's save_data() must refuse to write")
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "the file is still the original after a save attempt")

func test_unreadable_save_is_copied_aside() -> void:
	var path := _path("unreadable_copy")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	_boot(manager)
	_expect_load_errors()
	var backups := _backups_of(path, "unreadable")
	assert_eq(backups.size(), 1, "one copy of the unreadable save is kept")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), UNREADABLE_SAVE_TEXT)

## The boot backup copies the file as it is, so even a main save that will not
## load is backed up before the session starts.
func test_boot_leaves_an_unreadable_save_alone() -> void:
	var path := _path("unreadable_boot")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	manager.main_save_path = path
	_boot(manager)
	_expect_load_errors()
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "boot() neither resets nor verifies a save it could not read")
	var backups: PackedStringArray = manager.list_backups()
	assert_eq(backups.size(), 1, "the main save is backed up even when it will not load")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), UNREADABLE_SAVE_TEXT)

## A first save cut short can leave only its temp file, half-written. It is
## copied aside, kept, and never replaced by a new game.
func test_an_unreadable_temp_file_is_copied_aside_and_kept() -> void:
	var path := _path("temp_unreadable")
	var temp_path := SaveFiles.temp_path_for(path)
	_write(temp_path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	_boot(manager)
	_expect_load_errors()
	assert_true(manager.is_save_blocked(), "a temp file that will not load blocks saving, as a save that will not load does")
	assert_eq(_read(temp_path), UNREADABLE_SAVE_TEXT, "the temp file is left as it was")
	assert_false(FileAccess.file_exists(path), "no new save is written in its place")
	var copies := _backups_of(temp_path, "unreadable")
	assert_eq(copies.size(), 1, "the copy aside is of the file that was read: the temp file")
	if copies.size() == 1:
		assert_eq(_read(copies[0]), UNREADABLE_SAVE_TEXT)

#-----------------------------------------------------------------------------
# MISSING AND READABLE SAVES
#-----------------------------------------------------------------------------

func test_missing_save_is_created() -> void:
	var path := _path("missing")
	var manager := _make_manager(path)
	_boot(manager)
	assert_true(FileAccess.file_exists(path), "a first launch writes a default save")
	assert_false(manager.is_save_blocked())
	assert_eq(manager.save_game_data.gold, 0.0)
	var written: SaveGameData = SaveFiles.load_save(path)
	assert_not_null(written, "the new save loads back")
	if written != null:
		assert_eq(written.save_version, SaveGameData.CURRENT_VERSION, "a new save is written at the current version")

func test_readable_save_loads_without_a_backup() -> void:
	var path := _path("readable")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	assert_false(manager.is_save_blocked())
	assert_eq(manager.save_game_data.gold, 42.0)
	assert_eq(_backups_of(path, "unreadable").size(), 0)
	assert_eq(manager.save_data(), OK, "a readable save can be written back")

## A crash inside the rename that ends a write can leave only the temp file,
## whole. That is the save: it loads, and is not replaced by a new game.
func test_a_save_left_only_in_its_temp_file_loads() -> void:
	var path := _path("temp_only")
	_write(SaveFiles.temp_path_for(path), READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	assert_false(manager.is_save_blocked())
	assert_eq(manager.save_game_data.gold, 42.0, "the temp file's save is played, not a new game")
	assert_eq(manager.save_data(), OK)
	assert_eq(_gold_in_file(path), 42.0, "the next write puts the save back at its own path")

#-----------------------------------------------------------------------------
# MIGRATE, VERIFY AND REPAIR
#-----------------------------------------------------------------------------

func test_boot_migrates_the_loaded_save() -> void:
	var path := _path("migrate")
	_write(path, READABLE_SAVE_TEXT % "TestZone")
	var manager := _make_manager(path)
	_boot(manager)
	assert_eq(manager.save_game_data.current_selected_zone_id, "SpiritValley",
		"boot() runs migrate() on the loaded save, so it never stands in the hidden Test Zone")
	assert_eq(manager.save_game_data.gold, 42.0, "a migrated save is not reset")

func test_an_unknown_zone_is_repaired_not_wiped() -> void:
	var path := _path("invalid")
	var original := READABLE_SAVE_TEXT % "NoSuchZoneForPersistenceTest"
	_write(path, original)
	var manager := _make_manager(path)
	_boot(manager)
	assert_eq(manager.save_game_data.gold, 42.0, "the rest of the save stays")
	assert_eq(manager.save_game_data.current_selected_zone_id, "", "only the unknown zone is cleared")
	var backups := _backups_of(path, "invalid")
	assert_eq(backups.size(), 1, "the file as it was is copied aside before a write keeps the repair")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original)

func test_unverifiable_save_is_not_reset() -> void:
	var path := _path("unverifiable")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path, UnverifiablePersistenceManager)
	_boot(manager)
	assert_eq(_read(path), original, "a save that cannot be checked is left as it is")
	assert_eq(manager.save_game_data.gold, 42.0, "the loaded save is kept in memory")
	assert_true(manager.is_save_blocked(), "nothing writes a save that could not be checked")

func test_a_newer_save_is_never_written() -> void:
	var path := _path("newer")
	var original := NEWER_SAVE_TEXT % "TestZone"
	_write(path, original)
	var manager := _make_manager(path)
	_boot(manager)
	assert_true(manager.is_save_blocked(), "a save from a newer build is never written")
	assert_string_contains(manager.get_block_reason(), "newer")
	assert_eq(manager.save_data(), ERR_LOCKED)
	assert_eq(_read(path), original, "the file is still the newer build's")
	assert_eq(manager.save_game_data.gold, 42.0, "the session plays the newer save in memory")
	assert_eq(manager.save_game_data.current_selected_zone_id, "TestZone", "this build does not migrate a newer save")
	assert_eq(manager.save_game_data.save_version, 99, "nor stamps it with its own version")

## A newer build can add a zone and save there. The session repairs it in memory,
## so it never stands in a zone this build does not know. The file is never
## written, so nothing is copied aside.
func test_a_newer_save_in_an_unknown_zone_is_repaired_in_memory() -> void:
	var path := _path("newer_unknown_zone")
	var original := NEWER_SAVE_TEXT % "NoSuchZone"
	_write(path, original)
	var manager := _make_manager(path)
	_boot(manager)
	assert_true(manager.is_save_blocked(), "a save from a newer build is still never written")
	assert_string_contains(manager.get_block_reason(), "newer")
	assert_eq(manager.save_game_data.current_selected_zone_id, "", "the unknown zone is cleared in memory")
	assert_eq(manager.save_game_data.gold, 42.0, "the rest of the save stays")
	assert_eq(_read(path), original, "the file is still the newer build's")
	assert_eq(_backups_of(path, "invalid").size(), 0, "nothing is copied aside: the file is not changed")

## The repair asks ZoneManager, so a session that cannot check the save does not
## repair it either. Saving stays blocked for the newer build's reason.
func test_a_newer_save_that_cannot_be_checked_is_not_repaired() -> void:
	var path := _path("newer_unverifiable")
	_write(path, NEWER_SAVE_TEXT % "NoSuchZone")
	var manager := _make_manager(path, UnverifiablePersistenceManager)
	_boot(manager)
	assert_string_contains(manager.get_block_reason(), "newer")
	assert_eq(manager.save_game_data.current_selected_zone_id, "NoSuchZone", "no repair runs without the check")

#-----------------------------------------------------------------------------
# BOOT BACKUP AND LAUNCH OPTIONS
#-----------------------------------------------------------------------------

func test_boot_backs_up_the_main_save() -> void:
	var path := _path("main_backup")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path)
	manager.main_save_path = path
	_boot(manager)
	var backups: PackedStringArray = manager.list_backups()
	assert_eq(backups.size(), 1, "a launch on the main save backs it up first")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original, "the backup holds the save as it was at launch")

## The temp file a cut-short write left may be the only copy of the save.
func test_boot_backs_up_the_temp_file_when_only_it_is_left() -> void:
	var path := _path("main_temp_backup")
	var temp_path := SaveFiles.temp_path_for(path)
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(temp_path, original)
	var manager := _make_manager(path)
	manager.main_save_path = path
	_boot(manager)
	var backups := SaveFiles.list_backups(temp_path, BACKUP_DIR)
	assert_eq(backups.size(), 1, "the temp file is backed up when the save itself is missing")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original)

func test_boot_backs_up_nothing_for_another_file() -> void:
	var path := _path("other_file")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	assert_eq(SaveFiles.list_backups(path, BACKUP_DIR).size(), 0, "only the main save is backed up at launch")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)), "nothing was backed up at all")

func test_save_option_opens_that_file() -> void:
	var path := _path("default_file")
	var option_path := _path("option_file")
	var manager := _make_manager(path)
	var options := LaunchOptions.new()
	options.save_path = option_path
	manager.boot(options)
	assert_eq(manager.save_path, option_path, "--save=<path> chooses the file the session plays")
	assert_true(FileAccess.file_exists(option_path), "a --save file that is missing is created")
	assert_false(FileAccess.file_exists(path), "the file the manager would have played is not touched")

func test_no_autosave_turns_off_the_tick() -> void:
	var path := _path("no_autosave")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	manager.boot(LaunchOptions.parse(PackedStringArray(["--no-autosave"])))
	assert_false(manager.autosave_enabled)
	manager.save_game_data.gold = 99.0
	manager.tick()
	assert_eq(_gold_in_file(path), 42.0, "with --no-autosave the tick writes nothing")

#-----------------------------------------------------------------------------
# AUTOSAVE
#-----------------------------------------------------------------------------

func test_tick_autosaves() -> void:
	var path := _path("tick")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	manager.save_game_data.gold = 99.0
	manager.tick()
	assert_eq(_gold_in_file(path), 99.0, "the SaveTimer's tick writes the session")

func test_close_request_autosaves() -> void:
	var path := _path("close")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	manager.save_game_data.gold = 99.0
	manager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_gold_in_file(path), 99.0, "closing the window saves what the last tick missed")

#-----------------------------------------------------------------------------
# USE SAVE
#-----------------------------------------------------------------------------

func test_in_memory_session_writes_nothing() -> void:
	var path := _path("in_memory")
	var manager := _make_manager(path)
	manager.use_save(SaveGameData.new_current(), "")
	assert_true(manager.is_in_memory())
	assert_false(manager.can_write())
	assert_eq(manager.save_data(), ERR_UNAVAILABLE, "an in-memory session has no file to write")
	assert_false(FileAccess.file_exists(path), "the file the manager played before is not written")

func test_use_save_swaps_and_re_binds() -> void:
	var path := _path("use_save")
	var manager := _make_manager(path)
	var save := SaveGameData.new_current()
	watch_signals(manager)
	manager.use_save(save, path)
	assert_same(manager.save_game_data, save, "the session plays the save object it was given")
	assert_eq(manager.save_path, path)
	assert_signal_emit_count(manager, "save_data_reset", 1, "the managers re-bind once")

func test_use_save_clears_the_block() -> void:
	var path := _path("use_save_blocked")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path, UnverifiablePersistenceManager)
	_boot(manager)
	assert_true(manager.is_save_blocked(), "precondition: the save could not be checked")
	var other_path := _path("use_save_other")
	manager.use_save(SaveGameData.new_current(), other_path)
	assert_false(manager.is_save_blocked())
	assert_eq(manager.get_block_reason(), "")
	assert_eq(manager.save_data(), OK, "the new session writes its own file")
	assert_eq(_read(path), original, "the file that could not be checked is still not written")

func test_save_data_stamps_the_version() -> void:
	var path := _path("stamp")
	var manager := _make_manager(path)
	var save := SaveGameData.new()
	assert_eq(save.save_version, 0, "precondition: a save made with new() is unversioned")
	manager.use_save(save, path)
	assert_eq(manager.save_data(), OK)
	var written: SaveGameData = SaveFiles.load_save(path)
	assert_not_null(written, "the written save loads back")
	if written != null:
		assert_eq(written.save_version, SaveGameData.CURRENT_VERSION, "every write stamps the current version")

#-----------------------------------------------------------------------------
# THIS RUN
#-----------------------------------------------------------------------------

## The autoload, not a bare instance: a GUT run boots on a save in memory with
## no main save and no autosave, so no test can read or write the real save.
func test_this_run_never_touches_the_real_save() -> void:
	assert_true(PersistenceManager.is_in_memory(), "a GUT run plays a save in memory")
	assert_eq(PersistenceManager.main_save_path, "", "a GUT run has no main save to open or back up")
	assert_false(PersistenceManager.autosave_enabled, "a GUT run never autosaves")
