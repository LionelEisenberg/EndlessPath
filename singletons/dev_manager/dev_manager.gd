extends Node

## DevManager
## Keeps the dev session, builds save presets and switches sessions while the game
## runs. It is the last autoload. A preset (SavePresetData) is a starting point for
## a dev session: build_preset() binds a fresh save, or a copy of the preset's
## snapshot, then plays the story route through the preset's beat and the preset's
## own steps on it, each step through DevCommands, the one command API. A launch
## with --preset=<id>, or a plain launch with a preset pinned for the checkout
## (LaunchOptions), builds that preset in _ready(): after every other autoload is
## ready and before the main scene's own _ready(), so no view hears the build. Such
## a session lives in memory, or in the --save file: the user's own save is never
## read, and is written only when --save names it, after PersistenceManager backs
## it up. "Save this game as a preset" writes the session's save into a preset
## file, a snapshot.
##
## In game, a switch (play a preset, jump through a story beat, restart the preset,
## back to your save, a new game, keep the session as your save, restore a backup)
## runs on the next frame: the panel button that asks for it lives in the main
## scene the switch frees. The switch saves the session it leaves when autosave is
## on, tears down what lives outside the save, frees the main scene, binds the new
## session and loads the main scene again, so the game comes up as a launch on that
## save would. A switch that is refused changes nothing; one that fails midway
## brings back the session it left.
##
## The time speed is the game's base Engine.time_scale, which GameSpeed keeps: one of
## TIME_SPEEDS, set with set_time_speed(). A switch keeps it.
##
## The dev panel's open state, place and tab live here too (panel_open,
## panel_position, panel_tab): the panel lives in the main scene a switch frees, and
## the panel built next comes back as the last one was.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the session has changed: at launch, once the launch options have
## set it up, and at the end of each switch in game, a failed one included (the
## session that came back is the new one).
signal session_changed

## Emitted when a switch in game is refused or fails, with the reason, which
## get_last_switch_failure() keeps. A refused switch changes nothing. A failed one
## has brought back the session it left by then, and session_changed follows.
signal session_switch_failed(reason: String)

## Emitted when set_time_speed() has made a speed the time speed, with that speed.
signal time_speed_changed(speed: float)

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

## The id of the preset a session falls back to when nothing else can be played: a
## launch whose own preset is unknown or does not build, or a failed switch whose
## session cannot come back. A fresh start in memory, which no preset folder holds.
const FALLBACK_PRESET_ID: String = "fresh_fallback"

## What the panel calls the fallback preset.
const _FALLBACK_PRESET_TITLE: String = "Fresh start (the preset could not be built)"

## The time speeds the dev tools offer, as multiples of normal speed. set_time_speed()
## accepts only these.
const TIME_SPEEDS: Array[float] = [1.0, 2.0, 5.0, 10.0]

## The prefix of the line a session's start logs, the one DevCommands' lines have.
const _DEV_TAG: String = "[color=magenta][DEV][/color]"

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## For tests only: the one folder to read presets from, in place of both
## PRESET_DIR and EXPORT_PRESET_DIR. Empty reads those two.
var preset_dir_override: String = ""

## Whether the dev panel is open. The panel writes it when it opens or closes, and
## reads it when it is built.
var panel_open: bool = false

## Where the dev panel's body stands: its top-left corner, in screen pixels. The
## panel writes it when its title bar is dragged, and reads it when it is built.
var panel_position: Vector2 = Vector2(24, 24)

## The index of the dev panel's tab. The panel writes it when the tab changes, and
## reads it when it is built.
var panel_tab: int = 0

## What the session plays. A GUT run keeps the default: its tests set up their own.
var _session_kind: SessionKind = SessionKind.YOUR_SAVE

## The preset the session was built from, or null.
var _session_preset: SavePresetData = null

## Why the last switch was refused or failed, or "" once a switch has worked.
var _last_switch_failure: String = ""

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

## The preset the session was built from, or null outside a preset session. A
## launch whose preset did not start plays the fresh fallback preset
## (FALLBACK_PRESET_ID), so a preset session always has one.
func get_session_preset() -> SavePresetData:
	return _session_preset

## Why the last switch in game was refused or failed, or "" when the last switch
## worked (or none has run). A switch that fails midway emits
## session_switch_failed while the main scene, and the dev panel in it, is freed, so
## the panel built next reads the reason here.
func get_last_switch_failure() -> String:
	return _last_switch_failure

## Sets the session up from the launch options, as _ready() does at launch. The kind
## is PRESET when options.preset_id is set, FILE when only options.save_path is,
## and YOUR_SAVE otherwise. PersistenceManager.boot() has already opened a file
## session, so only a preset has more to do here: it is built at once
## (build_preset(), written to the --save path when one was given), then the
## player's log is cleared and gets one [DEV] line, "Started preset '<title>'", with
## " (pinned)" when the pin chose it. A preset id no folder has, or a preset that
## does not build, is logged with Log.critical, and the session falls back to the
## fresh fallback preset (FALLBACK_PRESET_ID), built in memory, never on the user's
## save; the [DEV] line then says why the preset did not start. Emits
## session_changed.
func start_from_launch_options(options: LaunchOptions) -> void:
	if options.preset_id == "":
		_set_session(SessionKind.FILE if options.save_path != "" else SessionKind.YOUR_SAVE, null)
		session_changed.emit()
		return

	var pinned: String = " (pinned)" if options.preset_from_pin else ""
	var preset: SavePresetData = find_preset(options.preset_id)
	var failure: String = "no preset has that id"
	if preset != null:
		failure = build_preset(preset, options.save_path)
	if failure == "":
		_set_session(SessionKind.PRESET, preset)
	else:
		Log.critical("DevManager: Could not start preset %s%s: %s. Playing a fresh game in memory instead" % [options.preset_id, pinned, failure])
		_start_fallback_session()
	# After the build and any fallback, so the log holds none of the build's lines.
	LogManager.clear_history()
	if failure == "":
		_log_dev_line("Started preset '%s'%s" % [preset.title, pinned])
	else:
		_log_dev_line("Could not start preset '%s'%s: %s. Playing a fresh game in memory instead" % [options.preset_id, pinned, failure])
	session_changed.emit()

#-----------------------------------------------------------------------------
# SWITCHING SESSIONS
#-----------------------------------------------------------------------------

## Plays the preset in memory, on the next frame (see the class doc). A preset
## build_preset() refuses before it changes anything (validate() finds something
## wrong with it) is refused at once, and nothing changes. A build that fails
## midway brings back the session it left. Either emits session_switch_failed.
func play_preset(preset: SavePresetData) -> void:
	var title: String = preset.title if preset != null else ""
	var what: String = "start preset '%s'" % title
	var refusal: String = _build_refusal(preset, get_route())
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_start_preset.bind(preset, ""), what, "Started preset '%s'" % title)

## Plays the story route through the beat on a fresh save, as an unnamed preset
## (play_preset()) whose preset_id is "story_through_<beat_id>" and whose title is
## "Story through <the beat's title>", so a restart plays it again. A beat the
## route does not have is refused at once.
func play_story_through(beat_id: String) -> void:
	var route: StoryRouteData = get_route()
	var beat: StoryBeatData = route.find_beat(beat_id) if route != null else null
	var preset := SavePresetData.new()
	preset.preset_id = "story_through_%s" % beat_id
	preset.title = "Story through %s" % (beat.title if beat != null else beat_id)
	preset.story_through = beat_id
	play_preset(preset)

## Builds the session's preset again from the start, on the next frame, written
## where the session writes: in memory for a preset played in game and for the
## fallback, the --save file for a launch that named one. Does nothing outside a
## preset session.
func restart_preset() -> void:
	if _session_kind != SessionKind.PRESET or _session_preset == null:
		return
	var preset: SavePresetData = _session_preset
	var what: String = "restart preset '%s'" % preset.title
	var refusal: String = _build_refusal(preset, get_route())
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_start_preset.bind(preset, PersistenceManager.save_path), what, "Restarted preset '%s'" % preset.title)

## Goes back to the user's own save, on the next frame: the file is opened again
## from disk (PersistenceManager.open_save_file()). Refused at once in a run with no
## main save.
func back_to_my_save() -> void:
	var what: String = "go back to your save"
	var refusal: String = _main_save_refusal()
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_open_your_save, what, "Back to your save")

## Starts a new game on the user's own save, on the next frame: the save is backed
## up, then a fresh save takes its place and is written at once. Refused at once in
## a run with no main save, and while another live run holds the save's lock.
func new_game() -> void:
	var what: String = "start a new game on your save"
	var refusal: String = _main_save_refusal()
	if refusal == "":
		refusal = _take_your_save_lock()
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_start_new_game, what, "Started a new game on your save")

## Makes the session's save the user's own, on the next frame: the user's save is
## backed up, then a copy of the session's save takes its place, is written at once
## and plays on as your save. Refused at once in a run with no main save, and while
## another live run holds the save's lock.
func keep_as_my_save() -> void:
	var what: String = "keep this game as your save"
	var refusal: String = _main_save_refusal()
	if refusal == "":
		refusal = _take_your_save_lock()
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_keep_as_your_save, what, "Kept this game as your save")

## Puts a backup (PersistenceManager.list_backups()) back as the user's own save,
## on the next frame: the backup is read, the save is backed up, the backup takes
## its place byte for byte, and the file is opened again. Refused at once in a run
## with no main save, for a backup that is not there, and while another live run
## holds the save's lock.
func restore_backup(backup_path: String) -> void:
	var what: String = "restore your save from %s" % backup_path.get_file()
	var refusal: String = _main_save_refusal()
	if refusal == "" and not FileAccess.file_exists(backup_path):
		refusal = "There is no backup at %s" % backup_path
	if refusal == "":
		refusal = _take_your_save_lock()
	if refusal != "":
		_refuse(what, refusal)
		return
	_schedule_switch(_restore_backup.bind(backup_path), what, "Restored your save from %s" % backup_path.get_file())

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
# SNAPSHOTS AND THE PIN
#-----------------------------------------------------------------------------

## Saves this game as a preset: a snapshot preset that embeds a copy of the session's
## save, written as <id>.tres to the folder _preset_save_folder() names, where
## get_presets() finds it. A run from the editor binary writes the repository's folder,
## so the new file shows in git status. The id is the title lowercased, each run of
## characters outside a-z and 0-9 turned into "_", and "_" trimmed from both ends:
## "Weird State #2!" is "weird_state_2". The copy shares the item resources the
## inventory is keyed by and copies everything else; a copy has no file of its own,
## so the preset's file embeds it. Returns "" once the file is written, or why it was
## not: an empty title, a title with no letter or digit to make an id from, an id a
## preset already has (that preset is never overwritten), or the write failed. The
## session is left as it was.
func save_as_preset(title: String, description: String) -> String:
	var clean_title: String = title.strip_edges()
	if clean_title == "":
		return "The title is empty"
	var preset_id: String = _preset_id_for(clean_title)
	if preset_id == "":
		return "The title needs a letter or a digit to make an id from"
	if find_preset(preset_id) != null:
		return "A preset with the id %s already exists" % preset_id

	var preset := SavePresetData.new()
	preset.preset_id = preset_id
	preset.title = clean_title
	preset.description = description.strip_edges()
	preset.snapshot = PersistenceManager.save_game_data.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as SaveGameData
	var path: String = _preset_save_folder().path_join("%s.tres" % preset_id)
	var error: Error = SaveFiles.write_atomically(preset, path)
	if error != OK:
		return "Could not write %s (error %d)" % [path, error]
	_log_dev_line("Saved this game as the preset '%s' (%s)" % [clean_title, path])
	return ""

## Pins the preset with this id, so every plain launch from this checkout starts in it
## (LaunchOptions.parse() says which launches are plain); "" unpins. Returns OK once the
## pin file is written, or the error of writing it. The id is not looked up: a pin whose
## preset is gone starts a fresh game in memory at launch, with a critical log line.
func pin_preset(preset_id: String) -> Error:
	return LaunchOptions.write_pin(preset_id)

## The id of the preset pinned for this checkout, or "" when none is.
func get_pinned_preset_id() -> String:
	return LaunchOptions.read_pin()

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
	var route: StoryRouteData = get_route()
	var refusal: String = _build_refusal(preset, route)
	if refusal != "":
		return refusal

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
# TIME SPEED
#-----------------------------------------------------------------------------

## Makes `speed` the time speed: the base Engine.time_scale (GameSpeed.base_scale),
## which a moment that slows time, a boss hit-stop, comes back to, and which a session
## switch keeps. Returns "" once it is set, after emitting time_speed_changed and
## logging a [DEV] line ("Time speed ×5"). Refuses a speed TIME_SPEEDS does not have,
## with a reason that names the speeds it does: nothing changes, and nothing is
## emitted or logged.
func set_time_speed(speed: float) -> String:
	if not TIME_SPEEDS.has(speed):
		return "Time speed %s is not one of %s" % [time_speed_label(speed), _time_speed_labels()]
	GameSpeed.set_base_scale(speed)
	time_speed_changed.emit(speed)
	_log_dev_line("Time speed %s" % time_speed_label(speed))
	return ""

## The time speed: GameSpeed.base_scale, 1.0 until set_time_speed() sets another.
func get_time_speed() -> float:
	return GameSpeed.base_scale

## How a time speed is written for the player, in the [DEV] lines and in the dev
## panel's speed picker and badge: "×5", "×2.5". A whole number loses the ".0"
## String.num() leaves on it.
func time_speed_label(speed: float) -> String:
	return "×%s" % String.num(speed).trim_suffix(".0")

#-----------------------------------------------------------------------------
# THE SWITCH
#-----------------------------------------------------------------------------

## Runs `start_session` as a switch on the next frame, once. By then the caller, a
## panel button's handler in the main scene the switch frees, has returned:
## SceneTree.unload_current_scene() deletes that scene at once. `what` names the
## switch in a failure ("start preset 'X'"); `started` is the player's log line
## once it worked.
func _schedule_switch(start_session: Callable, what: String, started: String) -> void:
	_run_switch.call_deferred(start_session, what, started)

## The switch, in order:
## 1. the session it leaves is saved, when autosave is on and the session writes a
##    file (PersistenceManager.autosave());
## 2. what lives outside the save is torn down (_tear_down());
## 3. the main scene is freed, when it is the current scene. Under GUT the runner
##    is, so no scene is freed or loaded again;
## 4. `start_session` binds the new session and returns "", or returns why it could
##    not. The session it left then comes back (_come_back()), and
##    session_switch_failed is emitted with the reason, which
##    get_last_switch_failure() keeps until a switch works;
## 5. the player's log is cleared and gets one [DEV] line naming the new session;
## 6. the main scene loads again if step 3 freed it, then session_changed is
##    emitted.
func _run_switch(start_session: Callable, what: String, started: String) -> void:
	var left_kind: SessionKind = _session_kind
	var left_preset: SavePresetData = _session_preset
	var left_save_path: String = PersistenceManager.save_path
	PersistenceManager.autosave()
	_tear_down()
	var unloaded: bool = _unload_main_scene()
	var line: String = started
	var failure: String = start_session.call()
	_last_switch_failure = failure
	if failure != "":
		Log.error("DevManager: Could not %s: %s" % [what, failure])
		line = "Could not %s: %s. %s" % [what, failure, _come_back(left_kind, left_preset, left_save_path)]
		session_switch_failed.emit(failure)
	LogManager.clear_history()
	_log_dev_line(line)
	if unloaded:
		_load_main_scene()
	session_changed.emit()

## Stops what lives outside the save, which a launch never starts with: the running
## action, without counting it or running its effects, and any dialogue, one an
## adventure encounter started included, which would otherwise play on over the
## next session; the cycle session and the last cycle's result; the player's
## vitals; and the time scale, back to the game's base speed at once, rather than
## leaving up to 0.15 s of a boss hit-stop's slowed time running into the next
## session.
func _tear_down() -> void:
	ActionManager.cancel_current_action()
	DialogueManager.end_dialogue_now()
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	PlayerManager.reset_vitals()
	Engine.time_scale = GameSpeed.base_scale

## Frees the main scene when it is the current scene, and returns true when it did.
## Any other current scene (GUT's runner, a scene run on its own) stays.
func _unload_main_scene() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != _main_scene_path():
		return false
	get_tree().unload_current_scene()
	return true

## Loads the main scene again. Its nodes are ready at the end of the frame, and read
## the new session then.
func _load_main_scene() -> void:
	var error: Error = get_tree().change_scene_to_file(_main_scene_path())
	if error != OK:
		Log.error("DevManager: Could not load the main scene again (error %d)" % error)

## The res:// path of the project's main scene. The setting holds its uid.
func _main_scene_path() -> String:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	return ResourceUID.ensure_path(main_scene)

## Brings back the session a failed switch left, the way a launch on it comes up:
## your save opens again from disk, a preset is built again where it was written,
## a file opens again. When that fails too, the session is the fresh fallback
## preset in memory. Returns what the player's log says about it.
func _come_back(kind: SessionKind, preset: SavePresetData, save_path: String) -> String:
	var failure: String = ""
	match kind:
		SessionKind.YOUR_SAVE:
			failure = _open_your_save()
			if failure == "":
				return "Back to your save"
		SessionKind.FILE:
			failure = _open_file(save_path)
			if failure == "":
				return "Back to %s" % save_path
		SessionKind.PRESET:
			failure = _start_preset(preset, save_path)
			if failure == "":
				return "Rebuilt preset '%s'" % preset.title
	Log.error("DevManager: Could not bring back the session a switch left: %s. Playing a fresh game in memory instead" % failure)
	_start_fallback_session()
	return "Could not go back either: %s. Playing a fresh game in memory instead" % failure

## Refuses a switch before anything changes: logs why, keeps it for
## get_last_switch_failure() and emits session_switch_failed.
func _refuse(what: String, reason: String) -> void:
	Log.error("DevManager: Could not %s: %s" % [what, reason])
	_last_switch_failure = reason
	session_switch_failed.emit(reason)

## Why a switch that needs the user's own save is refused, or "": the run has no
## main save (every test run, unless the test points main_save_path at a file).
func _main_save_refusal() -> String:
	return "This run has no main save" if PersistenceManager.main_save_path == "" else ""

## Takes the lock on the user's own save for a switch that writes it, and returns
## "", or why it could not: another live run holds it, and a run never writes a
## save under another. The switch then binds the save, and the session keeps the
## lock as its own; a switch that fails before that gives it back
## (_release_unused_lock()).
func _take_your_save_lock() -> String:
	var main_save: String = PersistenceManager.main_save_path
	if SaveLock.acquire(main_save):
		return ""
	return "Your save is in use by another run (pid %d)" % SaveLock.holder_pid(main_save)

## Gives back the lock on the user's save that _take_your_save_lock() took for a
## switch that then failed before it bound the save. Kept, the lock would keep the
## user's other runs off the save until it goes stale. A session that plays the
## user's save holds that lock as its own, so it keeps it; and SaveLock.release()
## deletes only a lock that is this run's, never another run's.
func _release_unused_lock() -> void:
	var main_save: String = PersistenceManager.main_save_path
	if PersistenceManager.save_path != main_save:
		SaveLock.release(main_save)

#-----------------------------------------------------------------------------
# SESSION STEPS
#-----------------------------------------------------------------------------
# The steps that make a session DevManager's, and their helpers. A step returns ""
# once the session is its own, or why it could not be.

## Records what the session plays.
func _set_session(kind: SessionKind, preset: SavePresetData) -> void:
	_session_kind = kind
	_session_preset = preset

## Builds the preset as the session, written to `save_path` ("" keeps it in memory).
## A build that fails has bound its half-built save, which the caller replaces.
func _start_preset(preset: SavePresetData, save_path: String) -> String:
	var failure: String = build_preset(preset, save_path)
	if failure == "":
		_set_session(SessionKind.PRESET, preset)
	return failure

## Makes the fresh fallback preset the session, built in memory. A preset with no
## beat, no steps and no snapshot always builds. Were it ever refused, the session
## plays a new save in memory instead, so a half-built save never stays bound (to
## a --save file, say).
func _start_fallback_session() -> void:
	var preset: SavePresetData = _fallback_preset()
	var failure: String = build_preset(preset, "")
	if failure != "":
		Log.error("DevManager: Could not build the fresh fallback preset: %s. Playing a new save in memory" % failure)
		PersistenceManager.use_save(SaveGameData.new_current(), "")
	_set_session(SessionKind.PRESET, preset)

## Opens the user's own save from disk as the session. Never in a run with no main
## save: open_save_file("") would play an empty path as a file.
func _open_your_save() -> String:
	var refusal: String = _main_save_refusal()
	if refusal != "":
		return refusal
	PersistenceManager.open_save_file(PersistenceManager.main_save_path)
	_set_session(SessionKind.YOUR_SAVE, null)
	return ""

## Opens the save file at `path` as the session.
func _open_file(path: String) -> String:
	if path == "":
		return "The session had no file to open"
	PersistenceManager.open_save_file(path)
	_set_session(SessionKind.FILE, null)
	return ""

## Backs up the user's save, then plays a fresh save as it and writes it at once.
func _start_new_game() -> String:
	var refusal: String = _back_up_your_save()
	if refusal != "":
		_release_unused_lock()
		return refusal
	PersistenceManager.use_save(SaveGameData.new_current(), PersistenceManager.main_save_path)
	return _write_your_save()

## Backs up the user's save, then plays a copy of the session's save as it and
## writes it at once. The copy shares the item resources the inventory is keyed by
## and copies everything embedded, so the session it leaves is never changed.
func _keep_as_your_save() -> String:
	var refusal: String = _back_up_your_save()
	if refusal != "":
		_release_unused_lock()
		return refusal
	var kept: SaveGameData = PersistenceManager.save_game_data.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as SaveGameData
	PersistenceManager.use_save(kept, PersistenceManager.main_save_path)
	return _write_your_save()

## Reads the backup, backs up the user's save, puts the backup in its place byte
## for byte, then opens it from disk. The backup is read first: backing up the
## user's save rotates the oldest backups away once BACKUPS_KEPT are kept, and the
## chosen one can be the oldest.
func _restore_backup(backup_path: String) -> String:
	var restored: PackedByteArray = FileAccess.get_file_as_bytes(backup_path)
	if restored.is_empty():
		_release_unused_lock()
		return "Could not read %s" % backup_path
	var refusal: String = _back_up_your_save()
	if refusal != "":
		_release_unused_lock()
		return refusal
	var error: Error = SaveFiles.write_bytes_atomically(restored, PersistenceManager.main_save_path)
	if error != OK:
		_release_unused_lock()
		return "Could not write %s over your save (error %d)" % [backup_path, error]
	return _open_your_save()

## Writes the session's save, which the user's save now holds, and makes it the
## session. Returns why when the write failed.
func _write_your_save() -> String:
	var error: Error = PersistenceManager.save_data()
	if error != OK:
		return "Could not write your save (error %d)" % error
	_set_session(SessionKind.YOUR_SAVE, null)
	return ""

## Backs up the user's save before a switch writes over it. Returns "" once it is
## backed up, or when there is no file yet to back up; otherwise why not, and the
## switch writes nothing.
func _back_up_your_save() -> String:
	if FileAccess.file_exists(PersistenceManager.main_save_path) and PersistenceManager.backup_main_save() == "":
		return "Could not back up your save, so it was left as it was"
	return ""

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## The preset a session falls back to (FALLBACK_PRESET_ID): a fresh start with no
## beat and no steps, named so that the session still has a preset to show and to
## restart.
func _fallback_preset() -> SavePresetData:
	var preset := SavePresetData.new()
	preset.preset_id = FALLBACK_PRESET_ID
	preset.title = _FALLBACK_PRESET_TITLE
	return preset

## The folders get_presets() reads.
func _preset_folders() -> PackedStringArray:
	if preset_dir_override != "":
		return PackedStringArray([preset_dir_override])
	return PackedStringArray([PRESET_DIR, EXPORT_PRESET_DIR])

## The folder save_as_preset() writes to: preset_dir_override when a test set it.
## Otherwise PRESET_DIR for a run from the editor binary (OS.has_feature("editor"),
## true for every run the editor starts), and EXPORT_PRESET_DIR for an exported build,
## whose res:// is read-only.
func _preset_save_folder() -> String:
	if preset_dir_override != "":
		return preset_dir_override
	if OS.has_feature("editor"):
		return PRESET_DIR
	return EXPORT_PRESET_DIR

## The id a preset saved under this title gets: the title lowercased, each run of
## characters outside a-z and 0-9 turned into "_", and "_" trimmed from both ends. ""
## when the title has no letter or digit.
func _preset_id_for(title: String) -> String:
	var outside_the_alphabet: RegEx = RegEx.create_from_string("[^a-z0-9]+")
	return outside_the_alphabet.sub(title.to_lower(), "_", true).lstrip("_").rstrip("_")

## True when preset `a` is listed before `b`: by title, ignoring case, then by id,
## so two presets with one title keep one order.
func _is_listed_before(a: SavePresetData, b: SavePresetData) -> bool:
	var by_title: int = a.title.naturalnocasecmp_to(b.title)
	if by_title != 0:
		return by_title < 0
	return a.preset_id < b.preset_id

## Why build_preset() refuses the preset before it changes anything, or "" when it
## builds: there is no preset, or validate() finds something wrong with it (the
## first error), `route` being where its beat is looked up.
func _build_refusal(preset: SavePresetData, route: StoryRouteData) -> String:
	if preset == null:
		return "There is no preset to build"
	var errors: PackedStringArray = preset.validate(route)
	return "" if errors.is_empty() else errors[0]

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

## The speeds in TIME_SPEEDS, written as time_speed_label() does: "×1, ×2, ×5, ×10".
func _time_speed_labels() -> String:
	var labels := PackedStringArray()
	for speed: float in TIME_SPEEDS:
		labels.append(time_speed_label(speed))
	return ", ".join(labels)
