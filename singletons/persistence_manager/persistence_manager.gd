extends Node
## Loads, checks and writes the single save (user://save.tres).
##
## It never replaces a save file it could not read or check. A save that fails
## to load (for example because a stale import cache is missing a texture that
## an item .tres references) is copied aside, left untouched, and save_data()
## refuses to write for the rest of the session. A save that loads but fails
## verify() is copied aside before the reset writes over it.

signal save_data_reset

@export var reset_save_data : bool = false

var save_game_data : SaveGameData

const SAVE_PATH : String = "user://save.tres"

## Where this manager reads and writes the save. Only tests point it elsewhere.
var save_path: String = SAVE_PATH

## Set when the save at save_path could not be read or checked this session.
var _save_blocked: bool = false

func _ready() -> void:
	boot()

## Loads the save, migrates it, then verifies it and resets it if it is
## invalid. A save that could not be read or checked is left as it is.
func boot() -> void:
	load_data()
	if _save_blocked:
		return
	# Migrate before verify(): a failed verify() wipes the whole save.
	save_game_data.migrate()
	if reset_save_data:
		load_new_save_data()

	if not _can_verify():
		_block_saving("the managers verify() needs did not load, so the save cannot be checked")
		return
	if not save_game_data.verify():
		var backup_path := _copy_save_aside("invalid")
		Log.critical("PersistenceManager: SaveGameData is invalid. Resetting to default. The old save was copied to %s" % backup_path)
		load_new_save_data()

## Resets the live save in place, writes it, and tells the managers to re-bind.
func load_new_save_data() -> void:
	save_game_data.reset()
	if save_data() != Error.OK:
		Log.critical("PersistenceManager: Error saving data.")
	save_data_reset.emit()

## Writes the live save to save_path. Returns ERR_LOCKED without writing when
## the save on disk could not be read or checked this session.
func save_data() -> Error :
	if _save_blocked:
		return ERR_LOCKED
	return ResourceSaver.save(save_game_data, save_path)

## Loads save_path into save_game_data, creating a default save when there is
## no file. A file that exists but does not load as a SaveGameData is copied
## aside and blocks saving; the session then runs on a default save in memory.
func load_data() -> void :
	if not ResourceLoader.exists(save_path) :
		save_game_data = SaveGameData.new()
		save_data()
		Log.info("PersistenceManager: No save file found. Initialized with default SaveGameData.")
	save_game_data = ResourceLoader.load(save_path) as SaveGameData

	if not save_game_data:
		save_game_data = SaveGameData.new()
		var backup_path := _copy_save_aside("unreadable")
		_block_saving("%s could not be loaded (run --headless --import if new art was just pulled). A copy is at %s" % [save_path, backup_path])

## True when the save on disk could not be read or checked, so nothing writes it.
func is_save_blocked() -> bool:
	return _save_blocked

func is_base_game_save() -> bool:
	var _base_game_save = SaveGameData.new()
	for property in  _base_game_save.get_property_list():
		if property["name"] == "resource_path":
			continue
		if _base_game_save.get(property["name"]) != save_game_data.get(property["name"]):
			return false

	return true

#-----------------------------------------------------------------------------
# SAVE SAFETY
#-----------------------------------------------------------------------------

## False when a manager verify() asks is missing, e.g. ZoneManager after its
## zone list failed to load from a stale import cache. Such a save is not reset.
func _can_verify() -> bool:
	return is_instance_valid(ZoneManager)

func _block_saving(reason: String) -> void:
	_save_blocked = true
	Log.critical("PersistenceManager: Saving is off for this session: %s" % reason)

## Copies the file at save_path next to it as <name>.<reason>.<unix time>.tres
## and returns the copy's path ("" when the copy failed).
func _copy_save_aside(reason: String) -> String:
	var backup_path := "%s.%s.%d.%s" % [save_path.get_basename(), reason, int(Time.get_unix_time_from_system()), save_path.get_extension()]
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
	if error != OK:
		Log.critical("PersistenceManager: Could not copy %s to %s (error %d)" % [save_path, backup_path, error])
		return ""
	return backup_path
