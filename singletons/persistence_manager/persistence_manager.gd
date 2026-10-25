extends Node

## PersistenceManager
## Owns the session's save: the SaveGameData every manager holds, and the file
## it is written to. A run plays one session: the user's own save
## (main_save_path), a --save file, or a save in memory that nothing writes (every
## GUT run). Writes go through SaveFiles, which writes a temp file and renames it
## over the save, so a crash mid-write never leaves a half-written save.
##
## It never replaces a save it could not read or check. A save that fails to load
## (for example because a stale import cache is missing a texture an item .tres
## references) is copied aside, left untouched, and saving is blocked for the
## session. So is a save a newer build wrote, which this build would write back
## without what it does not know. A save that names a zone the game no longer has
## is repaired, after a copy of the file is put aside.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when a save becomes the session's, so every manager re-binds to it.
## At boot it reaches no one: the managers read the save in their own _ready().
signal save_data_reset

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The user's own save.
const SAVE_PATH: String = "user://save.tres"

## Where the user's save is backed up when a launch plays it.
const BACKUP_DIR: String = "user://backups"

## How many backups of a save are kept.
const BACKUPS_KEPT: int = 10

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The live save every manager holds.
var save_game_data: SaveGameData

## Where the session writes. "" is a session in memory, which nothing writes.
var save_path: String = SAVE_PATH

## The user's own save ("Your save"). "" in a GUT run, which has none.
var main_save_path: String = SAVE_PATH

## Where the main save's backups go.
var backup_dir: String = BACKUP_DIR

## False when the session must not save on its own (--no-autosave, and every GUT
## run): the SaveTimer's tick and the window's close then write nothing.
## save_data() still writes when it is called.
var autosave_enabled: bool = true

## Set when the session's save could not be read or checked, or a newer build
## wrote it. Nothing writes it until another save becomes the session's.
var _save_blocked: bool = false

## Why saving is blocked, or "" when it is not.
var _block_reason: String = ""

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Checked here and not in boot(): the bare instances in
	# test_persistence_manager.gd call boot() and keep their own save_path.
	if LaunchOptions.is_test_run():
		main_save_path = ""
		autosave_enabled = false
		use_save(SaveGameData.new_current(), "")
		return
	boot()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave()

#-----------------------------------------------------------------------------
# SESSIONS
#-----------------------------------------------------------------------------

## Starts the run's session from its launch options (null reads this process's
## own, LaunchOptions.current()). --no-autosave turns autosave off and
## --save=<path> replaces save_path. A session on the main save backs it up
## before anything can write it. Then open_save_file() makes save_path the
## session.
func boot(options: LaunchOptions = null) -> void:
	var launch: LaunchOptions = options if options != null else LaunchOptions.current()
	autosave_enabled = not launch.no_autosave
	if launch.save_path != "":
		save_path = launch.save_path
	if save_path == main_save_path:
		_back_up_at_boot()
	open_save_file(save_path)

## Makes the save file at `path` the session: the one way a file becomes it, at
## boot and when a session goes back to a file. It clears any block, then:
## - no file there, and no temp file a cut-short write left: a new save, written
##   at once;
## - a file that will not load: copied aside and kept, and the session runs on a
##   new save in memory with saving blocked;
## - a save from a newer build: played in memory, unmigrated, with saving blocked;
## - any other save: migrated, then checked. Saving is blocked when the check
##   cannot run, and a save that fails it is repaired after the file is copied
##   aside.
## Every path ends with save_data_reset, which re-binds the managers (at boot it
## reaches no one).
func open_save_file(path: String) -> void:
	save_path = path
	_clear_block()
	_load_session_save(path)
	save_data_reset.emit()

## Makes `save` the session's save, written to `path` ("" keeps it in memory),
## then re-binds every manager through save_data_reset. It swaps the object in
## and never resets the old one in place, so ActionManager's stale-save guard
## stops an action still running on the old save without counting it. Any block
## clears.
func use_save(save: SaveGameData, path: String) -> void:
	save_game_data = save
	save_path = path
	_clear_block()
	save_data_reset.emit()

#-----------------------------------------------------------------------------
# WRITING
#-----------------------------------------------------------------------------

## Writes the session's save to save_path, stamped with the current version.
## Returns ERR_UNAVAILABLE for a session in memory and ERR_LOCKED while saving is
## blocked, writing nothing; otherwise what SaveFiles.write_atomically() returns.
func save_data() -> Error:
	if is_in_memory():
		return ERR_UNAVAILABLE
	if _save_blocked:
		return ERR_LOCKED
	save_game_data.save_version = SaveGameData.CURRENT_VERSION
	return SaveFiles.write_atomically(save_game_data, save_path)

## Saves the session when autosave is on and the session can write, and logs a
## write that fails. The SaveTimer's tick and the window's close call it.
func autosave() -> void:
	if not autosave_enabled or not can_write():
		return
	var error: Error = save_data()
	if error != OK:
		Log.error("PersistenceManager: Could not save to %s (error %d)" % [save_path, error])

## The SaveTimer's tick, every 5 seconds.
func tick() -> void:
	autosave()

#-----------------------------------------------------------------------------
# STATUS
#-----------------------------------------------------------------------------

## True when save_data() writes: the session has a file and saving is not blocked.
func can_write() -> bool:
	return not is_in_memory() and not _save_blocked

## True when the session's save lives only in memory, with no file to write.
func is_in_memory() -> bool:
	return save_path == ""

## True when the session's save could not be read or checked, or a newer build
## wrote it, so nothing writes it.
func is_save_blocked() -> bool:
	return _save_blocked

## Why saving is blocked, or "" when it is not.
func get_block_reason() -> String:
	return _block_reason

#-----------------------------------------------------------------------------
# BACKUPS
#-----------------------------------------------------------------------------

## Copies the main save into backup_dir, keeping its newest BACKUPS_KEPT
## backups. Returns the copy's path, or "" when there is no main save file or the
## copy failed.
func backup_main_save() -> String:
	return SaveFiles.backup(main_save_path, backup_dir, BACKUPS_KEPT)

## The main save's backups in backup_dir, newest first.
func list_backups() -> PackedStringArray:
	return SaveFiles.list_backups(main_save_path, backup_dir)

#-----------------------------------------------------------------------------
# SAVE SAFETY
#-----------------------------------------------------------------------------

## Loads the save at `path` into save_game_data, then migrates, checks and
## repairs it, blocking saving where open_save_file() says.
func _load_session_save(path: String) -> void:
	var temp_path: String = SaveFiles.temp_path_for(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(temp_path):
		save_game_data = SaveGameData.new_current()
		var error: Error = save_data()
		if error == OK:
			Log.info("PersistenceManager: No save at %s, so a new one was written" % path)
		else:
			Log.error("PersistenceManager: No save at %s, and the new one could not be written (error %d)" % [path, error])
		return

	# The file load_save() reads: the temp file only when the save is missing.
	# Copies are made of that file, never of a path that is not there.
	var read_path: String = path if FileAccess.file_exists(path) else temp_path
	var loaded: SaveGameData = SaveFiles.load_save(path)
	if loaded == null:
		save_game_data = SaveGameData.new_current()
		var unreadable_copy: String = SaveFiles.copy_aside(read_path, "unreadable")
		_block_saving("%s could not be loaded (run --headless --import if new art was just pulled). A copy is at %s" % [read_path, unreadable_copy])
		return

	save_game_data = loaded
	if loaded.is_from_newer_build():
		_block_saving("%s was written by a newer build (version %d; this build knows %d)" % [read_path, loaded.save_version, SaveGameData.CURRENT_VERSION])
		return
	loaded.migrate()

	if not _can_verify():
		_block_saving("the managers verify() needs did not load, so the save cannot be checked")
		return
	var repaired: PackedStringArray = loaded.repair()
	if not repaired.is_empty():
		var invalid_copy: String = SaveFiles.copy_aside(read_path, "invalid")
		Log.warn("PersistenceManager: Repaired %s in %s. The file as it was is at %s" % [", ".join(repaired), path, invalid_copy])

## The backup a launch on the main save makes before anything writes it. When
## only the temp file a cut-short write left is there, that file may be the only
## copy of the save, so it is the one backed up.
func _back_up_at_boot() -> void:
	var source: String = save_path
	if not FileAccess.file_exists(source):
		source = SaveFiles.temp_path_for(save_path)
	SaveFiles.backup(source, backup_dir, BACKUPS_KEPT)

## False when a manager verify() asks is missing, e.g. ZoneManager after its
## zone list failed to load from a stale import cache. Such a save is played but
## never checked, repaired or written.
func _can_verify() -> bool:
	return is_instance_valid(ZoneManager)

func _block_saving(reason: String) -> void:
	_save_blocked = true
	_block_reason = reason
	Log.critical("PersistenceManager: Saving is off for this session: %s" % reason)

func _clear_block() -> void:
	_save_blocked = false
	_block_reason = ""
