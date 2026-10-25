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
##
## One run at a time writes a save. A session on a file holds that save's lock
## (SaveLock): refreshed on every tick and every write, and released when the
## window closes. A save another live run holds the lock on is played in memory
## with saving blocked, so two runs never overwrite each other's progress.

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

## Set when the session's save could not be read or checked, a newer build wrote
## it, or another live run holds its lock. Nothing writes it until another save
## becomes the session's.
var _save_blocked: bool = false

## Why saving is blocked, or "" when it is not.
var _block_reason: String = ""

## The path of the save whose lock this session holds, or "" when it holds none: a
## session in memory, or a save another run held the lock on. The heartbeat and the
## release only ever touch this one, so a session never refreshes or deletes a
## lock it did not take.
var _lock_path: String = ""

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
		# After the last write, so the lock holds until it is done.
		_release_lock()

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
## boot and when a session goes back to a file. It clears any block and moves the
## session's lock to `path`. A save another live run holds the lock on is blocked
## ("in use by another run") but still loaded as below, into memory. Nothing below
## clears a block, so that one stands however the save loads: the file is never
## written. Then:
## - no file there, and no temp file a cut-short write left: a new save, written
##   at once;
## - a file that will not load: copied aside and kept, and the session runs on a
##   new save in memory with saving blocked;
## - a save from a newer build: played in memory, unmigrated, with saving
##   blocked. It is still repaired in memory when the check can run, so the
##   session never stands in a zone this build does not know; the file is never
##   written, so nothing is copied aside;
## - any other save: migrated, then checked. Saving is blocked when the check
##   cannot run, and a save that fails it is repaired after the file is copied
##   aside.
## Every path ends with save_data_reset, which re-binds the managers (at boot it
## reaches no one).
func open_save_file(path: String) -> void:
	save_path = path
	_clear_block()
	# Before the load, whose steps may write (a new save) or add a block of their own.
	_move_lock_to(path)
	_load_session_save(path)
	save_data_reset.emit()

## Makes `save` the session's save, written to `path` ("" keeps it in memory),
## then re-binds every manager through save_data_reset. It swaps the object in
## and never resets the old one in place, so ActionManager's stale-save guard
## stops an action still running on the old save without counting it. Any block
## clears, and the session's lock moves to `path` (a session in memory holds
## none): a save another live run holds the lock on blocks saving.
func use_save(save: SaveGameData, path: String) -> void:
	save_game_data = save
	save_path = path
	_clear_block()
	_move_lock_to(path)
	save_data_reset.emit()

#-----------------------------------------------------------------------------
# WRITING
#-----------------------------------------------------------------------------

## Writes the session's save to save_path, stamped with the current version, then
## refreshes the lock. Returns ERR_UNAVAILABLE for a session in memory and
## ERR_LOCKED while saving is blocked, writing nothing; otherwise what
## SaveFiles.write_atomically() returns.
func save_data() -> Error:
	if is_in_memory():
		return ERR_UNAVAILABLE
	if _save_blocked:
		return ERR_LOCKED
	save_game_data.save_version = SaveGameData.CURRENT_VERSION
	var error: Error = SaveFiles.write_atomically(save_game_data, save_path)
	_refresh_lock()
	return error

## Saves the session when autosave is on and the session can write, and logs a
## write that fails. The SaveTimer's tick and the window's close call it.
func autosave() -> void:
	if not autosave_enabled or not can_write():
		return
	var error: Error = save_data()
	if error != OK:
		Log.error("PersistenceManager: Could not save to %s (error %d)" % [save_path, error])

## The SaveTimer's tick, every 5 seconds: the lock's heartbeat, which beats with
## autosave off too, then the autosave.
func tick() -> void:
	_refresh_lock()
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

## True when the session's save could not be read or checked, a newer build wrote
## it, or another live run holds its lock, so nothing writes it.
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
		# Repaired in memory only, so the session never stands in a zone this build
		# does not know. Nothing writes the file, so nothing is copied aside.
		if _can_verify():
			var repaired_in_memory: PackedStringArray = loaded.repair()
			if not repaired_in_memory.is_empty():
				Log.warn("PersistenceManager: Repaired %s in memory only; %s stays as the newer build wrote it" % [", ".join(repaired_in_memory), read_path])
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

#-----------------------------------------------------------------------------
# SAVE LOCK
#-----------------------------------------------------------------------------

## Moves the lock this session holds to the save at `path`: the lock on the save it
## leaves is released, and the one on `path` is taken, unless `path` is "" (a
## session in memory has no file to guard). A save another live run holds the lock
## on blocks saving, so this session never writes under that run. Only a new
## session clears that block.
func _move_lock_to(path: String) -> void:
	if path != _lock_path:
		_release_lock()
	if path == "":
		return
	if SaveLock.acquire(path):
		_lock_path = path
		return
	_lock_path = ""
	_block_saving("in use by another run (pid %d)" % SaveLock.holder_pid(path))

## The lock's heartbeat: moves its time to now, when this session holds a lock.
func _refresh_lock() -> void:
	if _lock_path != "":
		SaveLock.refresh(_lock_path)

## Gives up the lock this session holds, if it holds one.
func _release_lock() -> void:
	if _lock_path != "":
		SaveLock.release(_lock_path)
		_lock_path = ""
