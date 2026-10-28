extends GutTest

## Unit tests for PersistenceManager's sessions: boot (the launch options, the
## backup of the main save, and a run of another scene, which reads its save into
## memory), opening a save file (the backup, load, migrate, check, repair),
## swapping a save in, writing (save_data(), the autosave, the save on quit) and
## two sessions on one save. Each test builds its own PersistenceManager (never the
## autoload) pointed at temporary user:// files and a temporary backup folder, so
## the developer's real save.tres and its backups are never read or written. The
## last test reads the autoload's state, to show this GUT run plays a save in
## memory.
##
## The rule under test: PersistenceManager never replaces a save file it could
## not read or check. A save that fails to load (for example because a stale
## import cache is missing a texture an item .tres references) is copied aside
## and left untouched, and nothing writes to it for the rest of the session. A
## save written by a newer build is played in memory and never written either.
## Nothing else stops a session from writing its save: two sessions on one save,
## two bare managers here, both write it, and the last write wins.

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
	func can_verify() -> bool:
		return false

## Every manager _make_manager() built in this test. after_each() frees them.
var _managers: Array[Node] = []

func after_each() -> void:
	for manager: Node in _managers:
		if is_instance_valid(manager):
			manager.free()
	_managers.clear()
	# The temp saves, their temp files and the copies aside all start with the prefix.
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
	var manager: Node = script.new()
	manager.save_path = path
	manager.main_save_path = _path("main_save")
	manager.backup_dir = BACKUP_DIR
	_managers.append(manager)
	return manager

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
	assert_ne(manager.save_data(), OK, "save_data() must refuse to write while saving is blocked")
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

## A dev switch that goes back to the main save opens it as a launch does, and
## backs it up first: with a preset pinned, every launch plays a preset, and this is
## the only time the main save is opened before the session writes it every 5 s.
func test_opening_the_main_save_backs_it_up_first() -> void:
	var path := _path("open_main")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(_path("open_main_elsewhere"))
	manager.main_save_path = path
	_boot(manager)
	assert_eq(manager.list_backups().size(), 0, "precondition: the session on another file backed nothing up")
	manager.open_save_file(path)
	var backups: PackedStringArray = manager.list_backups()
	assert_eq(backups.size(), 1, "opening the main save backs it up once")
	manager.save_game_data.gold = 99.0
	assert_eq(manager.save_data(), OK, "precondition: the session writes the main save")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original, "the backup holds the save as the session found it")

## A restore backs up the save it replaces before it writes the backup's bytes over
## it, then opens the file: that open takes no second backup.
func test_opening_the_main_save_can_skip_the_backup() -> void:
	var path := _path("open_main_no_backup")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(_path("open_main_no_backup_elsewhere"))
	manager.main_save_path = path
	_boot(manager)
	manager.open_save_file(path, false)
	assert_eq(manager.save_game_data.gold, 42.0, "the main save is the session")
	assert_eq(manager.list_backups().size(), 0, "and nothing was backed up")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)), "not even the backup folder is made")

## A dev switch backs the main save up through backup_main_save() before it writes
## over it. When a cut-short write left only the temp file, that file is the save,
## and may be its only copy, so it is the one backed up.
func test_backup_main_save_copies_the_temp_file_when_only_it_is_left() -> void:
	var path := _path("backup_temp_only")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	manager.main_save_path = path
	_boot(manager)
	var temp_path := SaveFiles.temp_path_for(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_write(temp_path, (READABLE_SAVE_TEXT % "SpiritValley").replace("gold = 42.0", "gold = 7.0"))
	assert_true(manager.has_main_save_on_disk(), "the temp file counts as the main save on disk")
	var copy: String = manager.backup_main_save()
	assert_ne(copy, "", "the temp file is backed up")
	assert_eq(SaveFiles.list_backups(temp_path, BACKUP_DIR), PackedStringArray([copy]), "under the temp file's own name")
	assert_eq(_gold_in_file(copy), 7.0, "holding what the temp file held")

func test_with_no_main_save_on_disk_nothing_is_backed_up() -> void:
	var path := _path("backup_none")
	var manager := _make_manager(_path("backup_none_elsewhere"))
	manager.main_save_path = path
	_boot(manager)
	assert_false(manager.has_main_save_on_disk())
	assert_eq(manager.backup_main_save(), "")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)), "not even the backup folder is made")

## The one way the main save is backed up copies it whenever it is on disk: from a
## session on another file, as a dev switch that writes over the main save runs
## from a preset, and while another session plays the main save.
func test_backup_main_save_copies_it_whenever_it_is_on_disk() -> void:
	var path := _path("backup_any_session")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var switching := _make_manager(_path("backup_any_session_elsewhere"))
	switching.main_save_path = path
	_boot(switching)
	var copy: String = switching.backup_main_save()
	assert_ne(copy, "", "a session on another file backs the main save up")
	assert_eq(_gold_in_file(copy), 42.0, "holding what the main save holds")
	var playing := _make_manager(path)
	playing.main_save_path = path
	_boot(playing)
	playing.save_game_data.gold = 55.0
	assert_eq(playing.save_data(), OK, "precondition: another session plays the main save and has written it")
	var second_copy: String = switching.backup_main_save()
	assert_ne(second_copy, "", "a main save another session plays is backed up too")
	assert_eq(_gold_in_file(second_copy), 55.0, "as that session last wrote it")

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

## A preset session starts on a fresh save that DevManager builds on next, so
## boot reads no file and backs nothing up. Here the main save is the file a plain
## boot would play.
func test_boot_with_a_preset_reads_no_file() -> void:
	var path := _path("preset_boot")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path)
	manager.main_save_path = path
	var options := LaunchOptions.new()
	options.preset_id = "merchant_open"
	manager.boot(options)
	assert_true(manager.is_in_memory(), "a preset session lives in memory when no --save is given")
	assert_eq(manager.save_game_data.gold, 0.0, "the session plays a fresh save, not the file's")
	assert_eq(manager.save_game_data.save_version, SaveGameData.CURRENT_VERSION, "the fresh save is stamped")
	assert_eq(_read(path), original, "the file is left as it was")
	assert_eq(manager.list_backups().size(), 0, "no backup is taken")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)), "not even the backup folder is made")

## With --save as well, the preset session writes that file, but still starts on a
## fresh save and reads nothing from it.
func test_a_preset_with_a_save_option_plays_a_fresh_save_there() -> void:
	var path := _path("preset_default")
	var option_path := _path("preset_option")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(option_path, original)
	var manager := _make_manager(path)
	var options := LaunchOptions.parse(PackedStringArray(["--preset=merchant_open", "--save=" + option_path, "--no-autosave"]))
	manager.boot(options)
	assert_eq(manager.save_path, option_path, "the session writes the --save file")
	assert_eq(manager.save_game_data.gold, 0.0, "the session plays a fresh save, not the file's")
	assert_false(manager.autosave_enabled, "--no-autosave still turns autosave off")
	assert_eq(_read(option_path), original, "nothing is written at boot")
	assert_false(FileAccess.file_exists(path), "the file the manager would have played is not touched")

## A preset written over the user's save may be meant, so it is allowed, but never
## without a backup: the save is backed up first, as a launch on it is. The session
## still reads nothing from it, and writes nothing yet.
func test_a_preset_session_on_the_main_save_backs_it_up_first() -> void:
	var path := _path("preset_main")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path)
	manager.main_save_path = path
	var options := LaunchOptions.new()
	options.preset_id = "merchant_open"
	options.save_path = path
	manager.boot(options)
	var backups: PackedStringArray = manager.list_backups()
	assert_eq(backups.size(), 1, "the main save is backed up before the preset session can write it")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original, "the backup holds the save as it was at launch")
	assert_eq(manager.save_path, path, "the preset session writes the main save")
	assert_eq(manager.save_game_data.gold, 0.0, "it plays a fresh save, not the file's")
	assert_eq(_read(path), original, "nothing is written until the session saves")

func test_no_autosave_turns_autosave_off() -> void:
	var path := _path("no_autosave")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	manager.boot(LaunchOptions.parse(PackedStringArray(["--no-autosave"])))
	assert_false(manager.autosave_enabled)
	manager.save_game_data.gold = 99.0
	manager.autosave()
	assert_eq(_gold_in_file(path), 42.0, "with --no-autosave the SaveTimer's autosave writes nothing")

#-----------------------------------------------------------------------------
# AUTOSAVE
#-----------------------------------------------------------------------------

func test_autosave_writes_the_session() -> void:
	var path := _path("autosave")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	manager.save_game_data.gold = 99.0
	manager.autosave()
	assert_eq(_gold_in_file(path), 99.0, "the SaveTimer's autosave writes the session")

func test_close_request_autosaves() -> void:
	var path := _path("close")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	manager.save_game_data.gold = 99.0
	manager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_gold_in_file(path), 99.0, "closing the window saves what the last tick missed")

#-----------------------------------------------------------------------------
# A RUN OF ANOTHER SCENE
#-----------------------------------------------------------------------------
# _ready() tells boot() whether the run plays the main scene. Only such a run
# saves by itself: a run of another scene (the editor's Run Current Scene, a scene
# named on the command line) or of none (a script run) reads its save into memory,
# and only the dev panel, in a scene that hosts it, writes there.

## The main save is the file here, which a plain launch would back up.
func test_a_run_of_another_scene_reads_the_save_into_memory() -> void:
	var path := _path("scene_run")
	var original := READABLE_SAVE_TEXT % "TestZone"
	_write(path, original)
	var manager := _make_manager(path)
	manager.main_save_path = path
	manager.boot(LaunchOptions.new(), false)
	assert_true(manager.is_in_memory(), "the session lives in memory")
	assert_false(manager.is_save_blocked(), "which is not a block: nothing is wrong with the save")
	assert_eq(manager.save_game_data.gold, 42.0, "it plays the save on disk")
	assert_eq(manager.save_game_data.current_selected_zone_id, "SpiritValley", "migrated, as a launch's save is")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP_DIR)), "it backs nothing up")
	manager.save_game_data.gold = 99.0
	manager.autosave()
	manager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_read(path), original, "it writes nothing, on a tick or on close")

## A save that will not load is left for the next launch of the game, which copies
## it aside: this run copies and writes nothing, and plays a new game in memory.
func test_a_run_of_another_scene_leaves_an_unreadable_save_alone() -> void:
	var path := _path("scene_run_unreadable")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	manager.main_save_path = path
	manager.boot(LaunchOptions.new(), false)
	_expect_load_errors()
	assert_true(manager.is_in_memory())
	assert_eq(manager.save_game_data.gold, 0.0, "a new game in memory")
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "the file is left as it was")
	assert_eq(_backups_of(path, "unreadable").size(), 0, "and not copied aside")

## A preset session keeps its own rules in any run, so one given a --save file
## plays that file. Only a run of the main scene saves on quit, though.
func test_a_run_of_another_scene_saves_nothing_on_close() -> void:
	var path := _path("scene_run_close")
	var manager := _make_manager(_path("scene_run_close_default"))
	manager.boot(LaunchOptions.parse(PackedStringArray(["--preset=merchant_open", "--save=" + path])), false)
	assert_eq(manager.save_path, path, "precondition: the preset session writes the --save file")
	manager.save_game_data.gold = 99.0
	manager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_false(FileAccess.file_exists(path), "closing the window writes nothing")

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
# TWO SESSIONS ON ONE SAVE
#-----------------------------------------------------------------------------
# Nothing stops a second session on a save: two windows of one checkout both play
# its save, both write it, and the last write wins. Two bare managers pointed at
# one temp save stand in for the two windows.

## The second window plays the save as the first does: it is not blocked, takes a
## boot backup of its own, and both windows' writes land, the last one winning, the
## first window's save as it closes included.
func test_a_second_session_on_the_main_save_is_not_blocked() -> void:
	var path := _path("two_sessions")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var first := _make_manager(path)
	first.main_save_path = path
	_boot(first)
	var second := _make_manager(path)
	second.main_save_path = path
	_boot(second)
	assert_false(second.is_save_blocked(), "a session on a save another session plays is not blocked")
	assert_eq(second.save_game_data.gold, 42.0, "it plays the save on disk")
	var backups: PackedStringArray = second.list_backups()
	assert_eq(backups.size(), 2, "each launch on the main save backs it up")
	for backup: String in backups:
		assert_eq(_read(backup), original, "as it was on disk")
	first.save_game_data.gold = 10.0
	assert_eq(first.save_data(), OK, "the first session writes the save")
	second.save_game_data.gold = 20.0
	assert_eq(second.save_data(), OK, "and so does the second")
	assert_eq(_gold_in_file(path), 20.0, "the last write wins")
	first.save_game_data.gold = 30.0
	first._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_gold_in_file(path), 30.0, "the first window saves as it closes")
	second.save_game_data.gold = 40.0
	assert_eq(second.save_data(), OK, "the second goes on writing after it")
	assert_false(second.is_save_blocked())
	assert_eq(_gold_in_file(path), 40.0, "and its write is the last")

## A preset written over the main save (--preset=<id> --save=<main save>) backs it up
## before it can write it, also while another session plays that save. The build
## binds the save again (DevManager.build_preset() calls use_save()) and takes no
## second backup; then both sessions write the save, the last one winning.
func test_a_preset_on_the_main_save_another_session_plays_is_backed_up_first() -> void:
	var path := _path("preset_main_shared")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var playing := _make_manager(path)
	playing.main_save_path = path
	_boot(playing)
	playing.save_game_data.gold = 55.0
	assert_eq(playing.save_data(), OK, "precondition: the other session has written the save")
	var preset := _make_manager(path)
	preset.main_save_path = path
	var options := LaunchOptions.new()
	options.preset_id = "merchant_open"
	options.save_path = path
	preset.boot(options)
	assert_false(preset.is_save_blocked(), "the preset session is not blocked")
	var backups: PackedStringArray = preset.list_backups()
	assert_eq(backups.size(), 2, "the preset session backed the main save up, as the other session's launch did")
	if backups.size() == 2:
		assert_eq(_gold_in_file(backups[0]), 55.0, "the newest backup holds the save as the other session left it")
	preset.use_save(SaveGameData.new_current(), path)
	assert_eq(preset.list_backups().size(), 2, "the build binds the save again and takes no second backup")
	preset.save_game_data.gold = 700.0
	assert_eq(preset.save_data(), OK, "the preset session writes the save")
	assert_eq(_gold_in_file(path), 700.0)
	playing.save_game_data.gold = 66.0
	assert_eq(playing.save_data(), OK, "and so does the other session, whose write is now the last")
	assert_eq(_gold_in_file(path), 66.0)

#-----------------------------------------------------------------------------
# THE BLOCK SIGNAL
#-----------------------------------------------------------------------------
# The dev panel shows "Not saving: <reason>" while saving is blocked, with the
# panel closed too, so save_block_changed fires at every change: a block, and a
# block cleared.

func test_a_block_is_signalled() -> void:
	var path := _path("signal_block")
	_write(path, NEWER_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	watch_signals(manager)
	_boot(manager)
	assert_true(manager.is_save_blocked(), "precondition: a newer build's save blocks saving")
	assert_signal_emit_count(manager, "save_block_changed", 1)

func test_a_cleared_block_is_signalled() -> void:
	var path := _path("signal_clear")
	_write(path, NEWER_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	_boot(manager)
	assert_true(manager.is_save_blocked(), "precondition: saving is blocked")
	watch_signals(manager)
	manager.use_save(SaveGameData.new_current(), _path("signal_clear_free"))
	assert_false(manager.is_save_blocked(), "precondition: the new session can save")
	assert_signal_emit_count(manager, "save_block_changed", 1)

## A session that can save, and goes on to another that can, changes nothing the
## panel shows.
func test_nothing_is_signalled_while_saving_stays_on() -> void:
	var path := _path("signal_none")
	var manager := _make_manager(path)
	watch_signals(manager)
	_boot(manager)
	manager.autosave()
	manager.use_save(SaveGameData.new_current(), _path("signal_none_other"))
	assert_false(manager.is_save_blocked(), "precondition: saving was never blocked")
	assert_signal_not_emitted(manager, "save_block_changed")

#-----------------------------------------------------------------------------
# THIS RUN
#-----------------------------------------------------------------------------

## The autoload, not a bare instance: a GUT run boots on a save in memory with
## no main save and no autosave, so no test can read or write the real save.
func test_this_run_never_touches_the_real_save() -> void:
	assert_true(PersistenceManager.is_in_memory(), "a GUT run plays a save in memory")
	assert_eq(PersistenceManager.main_save_path, "", "a GUT run has no main save to open or back up")
	assert_false(PersistenceManager.autosave_enabled, "a GUT run never autosaves")
