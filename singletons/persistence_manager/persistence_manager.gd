extends Node

## PersistenceManager
## Owns the session's save: the SaveGameData every manager holds, and the file
## it is written to. A run plays one session: the user's own save
## (main_save_path), a --save file, a preset DevManager builds on a fresh save
## (in memory, or written to the --save file), or a save in memory that nothing
## writes (every GUT run). Writes go through SaveFiles, which writes a temp file
## and renames it over the save, so a crash mid-write never leaves a half-written
## save.
##
## It never replaces a save it could not read or check. A save that fails to load
## (for example because a stale import cache is missing a texture an item .tres
## references) is copied aside, left untouched, and saving is blocked for the
## session. A save a newer build wrote is left untouched too, with saving blocked,
## since this build would write it back without what it does not know; it is
## played as it loads, and nothing copies it aside, since it is never written. A
## save that names a zone the game no longer has is repaired, after a copy of the
## file is put aside.
##
## The user's save is backed up (backup_main_save()) whenever a session takes it
## on, at launch or when a switch opens it, and before a dev switch writes over it,
## so nothing writes it without a copy of it as it was.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when a save becomes the session's, so every manager re-binds to it.
## At boot it reaches no one: the managers read the save in their own _ready().
signal save_data_reset

## Emitted whenever saving becomes blocked or is unblocked: a session that opens a
## save it must not write, and a new session that clears a block. Listeners read
## is_save_blocked() and get_block_reason(). The dev panel shows "Not saving:
## <reason>" from it. At boot it reaches no one: the panel reads the block when it
## is built.
signal save_block_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The user's own save.
const SAVE_PATH: String = "user://save.tres"

## Where the user's save is backed up (backup_main_save()).
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
## save_data() still writes when it is called. The dev panel's Saves tab turns it
## on and off for the session; a session switch puts back the run's launch value
## (restore_launch_autosave()).
var autosave_enabled: bool = true

## What autosave_enabled was at launch: false after --no-autosave and in a GUT run.
var _autosave_at_launch: bool = true

## True when the run plays the main scene, as every launch of the game does
## (boot()). Only such a run saves when its window closes.
var _plays_main_scene: bool = true

## Set when the session's save will not load, a newer build wrote it, or the
## managers verify() needs did not load, so it cannot be checked. Nothing writes it
## until another save becomes the session's.
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
		_autosave_at_launch = false
		use_save(SaveGameData.new_current(), "")
		return
	# The engine has made the run's scene the current scene already: it adds the
	# scene to the tree with the autoloads, and runs their _ready() first.
	boot(null, LaunchOptions.plays_main_scene(get_tree().current_scene))

func _notification(what: int) -> void:
	# Only a run of the main scene saves on quit, as only its SaveTimer saves.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _plays_main_scene:
		autosave()

#-----------------------------------------------------------------------------
# SESSIONS
#-----------------------------------------------------------------------------

## Starts the run's session from its launch options (null reads this process's
## own, LaunchOptions.current()). --no-autosave turns autosave off.
## A preset session (--preset=<id>, or the pinned preset) reads no file: it plays
## a fresh save, written to the --save path when one was given and kept in memory
## otherwise, which DevManager builds the preset on once every autoload is ready.
## It backs nothing up, unless its --save path is the main save: a preset written
## over the user's save backs it up first, as a launch on the main save does.
## Any other session: --save=<path> replaces save_path, then open_save_file() makes
## save_path the session, backing the main save up when that is the file.
## `plays_main_scene` false is a run of another scene (the editor's Run Current
## Scene, a scene named on the command line) or of none (a script run): such a run
## writes no save. A session other than a preset's plays save_path in memory
## (_play_in_memory()), with no backup, and no run of another scene saves when its
## window closes.
func boot(options: LaunchOptions = null, plays_main_scene: bool = true) -> void:
	var launch: LaunchOptions = options if options != null else LaunchOptions.current()
	autosave_enabled = not launch.no_autosave
	_autosave_at_launch = autosave_enabled
	_plays_main_scene = plays_main_scene
	if launch.preset_id != "":
		use_save(SaveGameData.new_current(), launch.save_path)
		# Before DevManager builds the preset, and anything can write the save.
		_back_up_if_main(launch.save_path)
		return
	if launch.save_path != "":
		save_path = launch.save_path
	if not plays_main_scene:
		_play_in_memory(save_path)
		return
	open_save_file(save_path)

## Makes the save file at `path` the session: the one way a file becomes it, at
## boot and when a session goes back to a file. It clears any block. When `path` is
## the main save, the save is backed up as it is on disk, before anything can write
## it: a launch on it, Back to my save, any switch that comes back to it. `back_up`
## false skips that for a caller that backed the save up itself before writing over
## it (a restore), so the switch takes one backup. Then:
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
func open_save_file(path: String, back_up: bool = true) -> void:
	save_path = path
	_clear_block()
	if back_up:
		_back_up_if_main(path)
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
## write that fails. The SaveTimer's tick, every 5 seconds, and the window's close
## call it.
func autosave() -> void:
	if not autosave_enabled or not can_write():
		return
	var error: Error = save_data()
	if error != OK:
		Log.error("PersistenceManager: Could not save to %s (error %d)" % [save_path, error])

## Puts autosave_enabled back to what the run was launched with (off after
## --no-autosave and in a GUT run), whatever the session turned it to. DevManager
## calls it at every switch, after the session it leaves is saved and before the
## next one binds, so a session comes up as a launch on its save would.
func restore_launch_autosave() -> void:
	autosave_enabled = _autosave_at_launch

#-----------------------------------------------------------------------------
# STATUS
#-----------------------------------------------------------------------------

## True when save_data() writes: the session has a file and saving is not blocked.
func can_write() -> bool:
	return not is_in_memory() and not _save_blocked

## True when the session's save lives only in memory, with no file to write.
func is_in_memory() -> bool:
	return save_path == ""

## True when the session's save will not load, a newer build wrote it, or the
## managers verify() needs did not load, so it cannot be checked: nothing writes it.
func is_save_blocked() -> bool:
	return _save_blocked

## Why saving is blocked, or "" when it is not.
func get_block_reason() -> String:
	return _block_reason

## False when a manager verify() and repair() ask is missing, e.g. ZoneManager after
## its zone list failed to load from a stale import cache. Such a save is played but
## never checked, repaired or written. DevManager asks it before it repairs a
## snapshot preset's copy.
func can_verify() -> bool:
	return is_instance_valid(ZoneManager)

#-----------------------------------------------------------------------------
# BACKUPS
#-----------------------------------------------------------------------------

## Copies the main save into backup_dir, keeping its newest BACKUPS_KEPT backups:
## the one way the main save is backed up, when a session takes it on (a launch,
## a switch that opens it) and before a dev switch writes over it (DevManager).
## When only the temp file a cut-short write left is there, that file may be the
## only copy of the save, so it is the one copied, under its own stem
## (<name>.tmp.<stamp>.<extension>), which list_backups() does not list. Returns the
## copy's path, or "" when nothing is on disk to copy (has_main_save_on_disk()) or
## the copy failed (SaveFiles logs it).
func backup_main_save() -> String:
	var source: String = _main_save_on_disk()
	if source == "":
		return ""
	return SaveFiles.backup(source, backup_dir, BACKUPS_KEPT)

## True when the main save is on disk: its file, or the temp file a cut-short write
## left in its place, which load_save() reads.
func has_main_save_on_disk() -> bool:
	return _main_save_on_disk() != ""

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
		if can_verify():
			var repaired_in_memory: PackedStringArray = loaded.repair()
			if not repaired_in_memory.is_empty():
				Log.warn("PersistenceManager: Repaired %s in memory only; %s stays as the newer build wrote it" % [", ".join(repaired_in_memory), read_path])
		return
	loaded.migrate()

	if not can_verify():
		_block_saving("the managers verify() needs did not load, so the save cannot be checked")
		return
	var repaired: PackedStringArray = loaded.repair()
	if not repaired.is_empty():
		var invalid_copy: String = SaveFiles.copy_aside(read_path, "invalid")
		Log.warn("PersistenceManager: Repaired %s in %s. The file as it was is at %s" % [", ".join(repaired), path, invalid_copy])

## Plays the save at `path` in memory, for a run that does not play the main scene
## (boot()): it is loaded, migrated and repaired in memory as open_save_file() does,
## but nothing is backed up, copied aside or written, so the file stays as it is for
## the next launch of the game. A save that is missing, or will not load, gives a
## new game in memory.
func _play_in_memory(path: String) -> void:
	var loaded: SaveGameData = SaveFiles.load_save(path)
	if loaded == null:
		loaded = SaveGameData.new_current()
	# Does nothing to a save a newer build wrote, which is played as it is.
	loaded.migrate()
	if can_verify():
		loaded.repair()
	use_save(loaded, "")
	Log.info("PersistenceManager: This run does not play the main scene, so %s is read into memory and never written" % path)

## Backs the main save up (backup_main_save()) when `path` is it: the save as the
## session found it, before anything can write it. A session in memory ("") has no
## file to back up, and in a run with no main save main_save_path is "" too.
func _back_up_if_main(path: String) -> void:
	if path != "" and path == main_save_path:
		backup_main_save()

## The file a backup of the main save copies: the main save, or the temp file a
## cut-short write left when only that is there; "" when neither is, or in a run
## with no main save.
func _main_save_on_disk() -> String:
	if main_save_path == "":
		return ""
	if FileAccess.file_exists(main_save_path):
		return main_save_path
	var temp_path: String = SaveFiles.temp_path_for(main_save_path)
	return temp_path if FileAccess.file_exists(temp_path) else ""

## Blocks saving for the session, for `reason`, and says so (save_block_changed)
## unless it was blocked for that reason already.
func _block_saving(reason: String) -> void:
	var changed: bool = not _save_blocked or _block_reason != reason
	_save_blocked = true
	_block_reason = reason
	Log.critical("PersistenceManager: Saving is off for this session: %s" % reason)
	if changed:
		save_block_changed.emit()

## Clears a block, and says so (save_block_changed) when there was one.
func _clear_block() -> void:
	if not _save_blocked:
		return
	_save_blocked = false
	_block_reason = ""
	save_block_changed.emit()
