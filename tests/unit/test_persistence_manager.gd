extends GutTest

## Unit tests for PersistenceManager's boot path: load, migrate, verify, reset.
## Each test builds its own PersistenceManager (never the autoload) pointed at a
## temporary user:// file, so the developer's real save.tres is never read or
## written.
##
## The rule under test: PersistenceManager never replaces a save file it could
## not read or check. A save that fails to load (for example because a stale
## import cache is missing a texture an item .tres references) is copied aside
## and left untouched, and nothing writes to it for the rest of the session.

const PersistenceManagerScript: GDScript = preload("res://singletons/persistence_manager/persistence_manager.gd")

const TMP_PREFIX: String = "__test_persistence_"

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

func _make_manager(path: String, script: Variant = PersistenceManagerScript) -> Node:
	_manager = script.new()
	_manager.save_path = path
	return _manager

## Files next to `path` that start with its name plus `.<reason>.`.
func _backups_of(path: String, reason: String) -> Array[String]:
	var stem: String = path.get_file().get_basename() + "." + reason + "."
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at("user://"):
		if file_name.begins_with(stem):
			found.append("user://" + file_name)
	return found

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
	manager.load_data()
	_expect_load_errors()
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "load_data() must not write over a save it could not read")
	assert_not_null(manager.save_game_data, "the session still runs on a default save in memory")

func test_unreadable_save_blocks_later_saves() -> void:
	var path := _path("unreadable_blocked")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	manager.load_data()
	_expect_load_errors()
	assert_true(manager.is_save_blocked())
	assert_ne(manager.save_data(), OK, "the SaveTimer's save_data() must refuse to write")
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "the file is still the original after a save attempt")

func test_unreadable_save_is_copied_aside() -> void:
	var path := _path("unreadable_copy")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	manager.load_data()
	_expect_load_errors()
	var backups := _backups_of(path, "unreadable")
	assert_eq(backups.size(), 1, "one copy of the unreadable save is kept")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), UNREADABLE_SAVE_TEXT)

func test_boot_leaves_an_unreadable_save_alone() -> void:
	var path := _path("unreadable_boot")
	_write(path, UNREADABLE_SAVE_TEXT)
	var manager := _make_manager(path)
	manager.boot()
	_expect_load_errors()
	assert_eq(_read(path), UNREADABLE_SAVE_TEXT, "boot() neither resets nor verifies a save it could not read")

#-----------------------------------------------------------------------------
# MISSING AND READABLE SAVES
#-----------------------------------------------------------------------------

func test_missing_save_is_created() -> void:
	var path := _path("missing")
	var manager := _make_manager(path)
	manager.load_data()
	assert_true(FileAccess.file_exists(path), "a first launch writes a default save")
	assert_false(manager.is_save_blocked())
	assert_eq(manager.save_game_data.gold, 0.0)

func test_readable_save_loads_without_a_backup() -> void:
	var path := _path("readable")
	_write(path, READABLE_SAVE_TEXT % "SpiritValley")
	var manager := _make_manager(path)
	manager.load_data()
	assert_false(manager.is_save_blocked())
	assert_eq(manager.save_game_data.gold, 42.0)
	assert_eq(_backups_of(path, "unreadable").size(), 0)
	assert_eq(manager.save_data(), OK, "a readable save can be written back")

#-----------------------------------------------------------------------------
# MIGRATE AND VERIFY
#-----------------------------------------------------------------------------

func test_boot_migrates_the_loaded_save() -> void:
	var path := _path("migrate")
	_write(path, READABLE_SAVE_TEXT % "TestZone")
	var manager := _make_manager(path)
	manager.boot()
	assert_eq(manager.save_game_data.current_selected_zone_id, "SpiritValley",
		"boot() runs migrate() on the loaded save, so it never stands in the hidden Test Zone")
	assert_eq(manager.save_game_data.gold, 42.0, "a migrated save is not reset")

func test_invalid_save_is_copied_aside_before_its_reset() -> void:
	var path := _path("invalid")
	var original := READABLE_SAVE_TEXT % "NoSuchZoneForPersistenceTest"
	_write(path, original)
	var manager := _make_manager(path)
	manager.boot()
	assert_eq(manager.save_game_data.gold, 0.0, "a save that fails verify() is still reset")
	var backups := _backups_of(path, "invalid")
	assert_eq(backups.size(), 1, "the save is copied aside before the reset writes over it")
	if backups.size() == 1:
		assert_eq(_read(backups[0]), original)

func test_unverifiable_save_is_not_reset() -> void:
	var path := _path("unverifiable")
	var original := READABLE_SAVE_TEXT % "SpiritValley"
	_write(path, original)
	var manager := _make_manager(path, UnverifiablePersistenceManager)
	manager.boot()
	assert_eq(_read(path), original, "a save that cannot be checked is left as it is")
	assert_eq(manager.save_game_data.gold, 42.0, "the loaded save is kept in memory")
	assert_true(manager.is_save_blocked(), "nothing writes a save that could not be checked")
