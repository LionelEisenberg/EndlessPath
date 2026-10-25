extends Node

## DevManager
## Keeps the dev session and builds save presets. It is the last autoload. A preset
## (SavePresetData) is a starting point for a dev session: build_preset() binds a
## fresh save, or a copy of the preset's snapshot, then plays the story route
## through the preset's beat and the preset's own steps on it, each step through
## DevCommands, the one command API. A launch with --preset=<id>, or with a preset
## pinned for the checkout (LaunchOptions), builds that preset in _ready(): after
## every other autoload is ready and before the main scene's own _ready(), so no
## view hears the build. Such a session lives in memory, or in the --save file: the
## user's own save is never read or written.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the session has changed: at launch, once the launch options have
## set it up.
signal session_changed

#-----------------------------------------------------------------------------
# ENUMS AND CONSTANTS
#-----------------------------------------------------------------------------

## What the session plays: the user's own save, a preset, or a --save file.
enum SessionKind { YOUR_SAVE, PRESET, FILE }

## The story route, which a recipe preset plays through its beat.
const ROUTE_PATH: String = "res://resources/dev/story_route.tres"

## The presets kept in the repository.
const PRESET_DIR: String = "res://resources/dev/save_presets/"

## The presets an exported build keeps: its res:// is read-only.
const EXPORT_PRESET_DIR: String = "user://dev/save_presets/"

## The prefix of the line a session's start logs, the one DevCommands' lines have.
const _DEV_TAG: String = "[color=magenta][DEV][/color]"

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## For tests only: the one folder to read presets from, in place of both
## PRESET_DIR and EXPORT_PRESET_DIR. Empty reads those two.
var preset_dir_override: String = ""

## What the session plays. A GUT run keeps the default: its tests set up their own.
var _session_kind: SessionKind = SessionKind.YOUR_SAVE

## The preset the session was built from, or null.
var _session_preset: SavePresetData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# A GUT run plays a save in memory, and builds only what its tests ask for.
	if LaunchOptions.is_test_run():
		return
	start_from_launch_options(LaunchOptions.current())

#-----------------------------------------------------------------------------
# SESSION
#-----------------------------------------------------------------------------

## What the session plays: a preset, a --save file, or the user's own save.
func get_session_kind() -> SessionKind:
	return _session_kind

## The preset the session was built from. Null outside a preset session, and after
## a launch whose preset did not start: that session plays a fresh save instead.
func get_session_preset() -> SavePresetData:
	return _session_preset

## Sets the session up from the launch options, as _ready() does at launch. The kind
## is PRESET when options.preset_id is set, FILE when only options.save_path is,
## and YOUR_SAVE otherwise. PersistenceManager.boot() has already opened a file
## session, so only a preset has more to do here: it is built at once
## (build_preset(), written to the --save path when one was given), then the
## player's log is cleared and gets one [DEV] line, "Started preset '<title>'", with
## " (pinned)" when the pin chose it. A preset id no folder has, or a preset that
## does not build, is logged with Log.critical and the session falls back to a fresh
## save in memory, never the user's save; the [DEV] line then says why. Emits
## session_changed.
func start_from_launch_options(options: LaunchOptions) -> void:
	_session_preset = null
	if options.preset_id == "":
		_session_kind = SessionKind.FILE if options.save_path != "" else SessionKind.YOUR_SAVE
		session_changed.emit()
		return

	_session_kind = SessionKind.PRESET
	var pinned: String = " (pinned)" if options.preset_from_pin else ""
	var preset: SavePresetData = find_preset(options.preset_id)
	var failure: String = "no preset has that id"
	if preset != null:
		failure = build_preset(preset, options.save_path)
	if failure != "":
		Log.critical("DevManager: Could not start preset %s%s: %s. Playing a fresh game in memory instead" % [options.preset_id, pinned, failure])
		PersistenceManager.use_save(SaveGameData.new_current(), "")
	# After the build and any fallback, so the log holds none of the build's lines.
	LogManager.clear_history()
	if failure == "":
		_session_preset = preset
		_log_dev_line("Started preset '%s'%s" % [preset.title, pinned])
	else:
		_log_dev_line("Could not start preset '%s'%s: %s. Playing a fresh game in memory instead" % [options.preset_id, pinned, failure])
	session_changed.emit()

#-----------------------------------------------------------------------------
# PRESETS AND THE ROUTE
#-----------------------------------------------------------------------------

## The story route, from ROUTE_PATH.
func get_route() -> StoryRouteData:
	return load(ROUTE_PATH) as StoryRouteData

## Every .tres file in the preset folders that loads as a SavePresetData, sorted by
## title: PRESET_DIR's and EXPORT_PRESET_DIR's, or only preset_dir_override's when a
## test set it. A missing folder holds none.
func get_presets() -> Array[SavePresetData]:
	var presets: Array[SavePresetData] = []
	for folder: String in _preset_folders():
		for file_name: String in ResourceLoader.list_directory(folder):
			if not file_name.ends_with(".tres"):
				continue
			var preset: SavePresetData = load(folder.path_join(file_name)) as SavePresetData
			if preset != null:
				presets.append(preset)
	presets.sort_custom(_is_listed_before)
	return presets

## The preset with this id, or null when no preset folder has one.
func find_preset(preset_id: String) -> SavePresetData:
	if preset_id == "":
		return null
	for preset: SavePresetData in get_presets():
		if preset.preset_id == preset_id:
			return preset
	return null

#-----------------------------------------------------------------------------
# BUILDING
#-----------------------------------------------------------------------------

## Builds the preset as the session's save, written to `save_path` ("" keeps it in
## memory). A preset that validate() finds anything wrong with is refused with the
## first error, before anything changes: a beat the route does not have would
## otherwise play no route steps at all. Otherwise:
## 1. the save is a copy of the preset's snapshot, migrated, or a fresh save, and
##    its play stats name the preset (built_from_preset);
## 2. PersistenceManager.use_save() makes it the session's, re-binding every
##    manager;
## 3. the route's steps through the preset's beat run in order, then the preset's
##    own;
## 4. every action available in every zone, and every unlocked technique, is
##    marked seen, as on a save played to that point, so no NEW seal shows.
## Nothing the build sets off counts as play. Returns "" once the preset is built,
## or "<step>: <reason>" for the first step that refused. That stops the build and
## leaves its save half-built: the caller decides which session comes next.
func build_preset(preset: SavePresetData, save_path: String = "") -> String:
	if preset == null:
		return "There is no preset to build"
	var route: StoryRouteData = get_route()
	var errors: PackedStringArray = preset.validate(route)
	if not errors.is_empty():
		return errors[0]

	var save: SaveGameData = _starting_save(preset)
	save.stats.built_from_preset = preset.preset_id
	# Paused before the save is bound: binding it re-checks the unlock conditions,
	# which would record their first times.
	save.stats.recording_paused = true
	PersistenceManager.use_save(save, save_path)
	var failure: String = _apply_steps(_steps_of(preset, route))
	if failure == "":
		_mark_everything_seen()
	save.stats.recording_paused = false
	return failure

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## The folders get_presets() reads.
func _preset_folders() -> PackedStringArray:
	if preset_dir_override != "":
		return PackedStringArray([preset_dir_override])
	return PackedStringArray([PRESET_DIR, EXPORT_PRESET_DIR])

## True when preset `a` is listed before `b`: by title, ignoring case, then by id,
## so two presets with one title keep one order.
func _is_listed_before(a: SavePresetData, b: SavePresetData) -> bool:
	var by_title: int = a.title.naturalnocasecmp_to(b.title)
	if by_title != 0:
		return by_title < 0
	return a.preset_id < b.preset_id

## The save a build starts from: a migrated copy of the preset's snapshot, so the
## snapshot itself is never changed, or a fresh save. The copy shares the item
## resources the inventory is keyed by and copies everything embedded.
func _starting_save(preset: SavePresetData) -> SaveGameData:
	if preset.snapshot == null:
		return SaveGameData.new_current()
	var save: SaveGameData = preset.snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as SaveGameData
	save.migrate()
	return save

## The steps a build applies: the route's through the preset's beat, then the
## preset's own.
func _steps_of(preset: SavePresetData, route: StoryRouteData) -> Array[DevStepData]:
	var steps: Array[DevStepData] = []
	if route != null:
		steps.append_array(route.steps_through(preset.story_through))
	steps.append_array(preset.steps)
	return steps

## Applies the steps in order. Returns "" when every one applied, or
## "<describe()>: <reason>" for the first that refused; the rest are not applied.
func _apply_steps(steps: Array[DevStepData]) -> String:
	for step: DevStepData in steps:
		var refusal: String = step.apply()
		if refusal != "":
			return "%s: %s" % [step.describe(), refusal]
	return ""

## Marks every action available in every zone, and every unlocked technique, as
## seen by the player.
func _mark_everything_seen() -> void:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			ZoneManager.mark_action_seen(action.action_id)
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		CyclingManager.mark_technique_seen(technique.id)

## Logs the line as a [DEV] line in the player's log.
func _log_dev_line(what: String) -> void:
	LogManager.log_message("%s %s" % [_DEV_TAG, what])
