class_name LaunchOptions extends RefCounted

## LaunchOptions
## What this run was launched with: the options after `--` on the command line
## (`--save=<path>`, `--no-autosave` and `--preset=<id>`), the preset pinned for
## this checkout, whether the process is a GUT test run, whether the run plays the
## project's main scene, and whether a scene is that scene. Code reads the options
## through current(). parse() takes the argument list and the pin as parameters, so
## a test can feed it any of them.
##
## The pin is one preset id kept in a ConfigFile per checkout: every plain launch
## from the checkout starts in that preset until it is unpinned. A launch that
## names a preset (--preset) or a save file (--save) is not plain: --preset beats
## the pin, and a --save run is a file session, which the pinned preset would
## otherwise be built over.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _SAVE_OPTION_PREFIX: String = "--save="
const _NO_AUTOSAVE_OPTION: String = "--no-autosave"
const _PRESET_OPTION_PREFIX: String = "--preset="

## Both ways a GUT run starts put this in the engine arguments, once
## backslashes are slashes: the CLI's `-s res://addons/gut/gut_cmdln.gd` (typed
## as `addons\gut\...` on Windows) and the editor panel's
## `--scene res://addons/gut/gui/run_from_editor.tscn`.
const _GUT_PATH_MARKER: String = "addons/gut/"

## The pin file of a run from the editor binary: in the checkout's own folder, so
## each worktree has its own pin. .gitignore keeps it out of commits, and the
## editor skips files whose names start with a dot.
const _EDITOR_PIN_PATH: String = "res://.dev_settings.cfg"

## The pin file of an exported build, whose res:// is read-only.
const _EXPORT_PIN_PATH: String = "user://dev_settings.cfg"

## Where the pin is kept in the pin file.
const _PIN_SECTION: String = "dev"
const _PIN_KEY: String = "pinned_preset"

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The save file to play on instead of the user's own, from `--save=<path>`.
## Empty when the option was not given.
var save_path: String = ""

## True when `--no-autosave` was given.
var no_autosave: bool = false

## The preset to start in: from `--preset=<id>`, or the pinned preset when neither
## `--preset` nor `--save` was given. Empty for none.
var preset_id: String = ""

## True when preset_id came from the pin, not from `--preset`.
var preset_from_pin: bool = false

## What current() parsed on its first call.
static var _current: LaunchOptions = null

## For tests only: the pin file to read and write instead of this checkout's.
## Empty uses the checkout's (pin_file_path()).
static var pin_path_override: String = ""

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Reads `--save=<path>`, `--no-autosave` and `--preset=<id>` from the
## arguments. Anything else is ignored, a `--save` without an `=` included, and
## an option given twice keeps its last value. When neither a `--preset` id nor a
## `--save` path is given, the preset is `pinned_preset_id` and preset_from_pin
## is set: a run that names its own save file is a file session, and the pinned
## preset would be built over that file. `--no-autosave` names no save, so it
## leaves the pin on.
static func parse(user_args: PackedStringArray, pinned_preset_id: String = "") -> LaunchOptions:
	var options: LaunchOptions = LaunchOptions.new()
	for arg: String in user_args:
		if arg.begins_with(_SAVE_OPTION_PREFIX):
			options.save_path = arg.trim_prefix(_SAVE_OPTION_PREFIX)
		elif arg.begins_with(_PRESET_OPTION_PREFIX):
			options.preset_id = arg.trim_prefix(_PRESET_OPTION_PREFIX)
		elif arg == _NO_AUTOSAVE_OPTION:
			options.no_autosave = true
	if options.preset_id == "" and options.save_path == "" and pinned_preset_id != "":
		options.preset_id = pinned_preset_id
		options.preset_from_pin = true
	return options

## The options this process was launched with: the user arguments after `--`
## and the checkout's pin (read_pin()), parsed on the first call and the same
## object on every call after it.
static func current() -> LaunchOptions:
	if _current == null:
		_current = parse(OS.get_cmdline_user_args(), read_pin())
	return _current

## True when this process is a GUT run, from the command line or from the
## editor's GUT panel. The engine arguments do not include the user arguments
## after `--`, so a `--save=` path cannot make a normal launch look like one.
static func is_test_run() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.replace("\\", "/").contains(_GUT_PATH_MARKER):
			return true
	return false

#-----------------------------------------------------------------------------
# THE MAIN SCENE
#-----------------------------------------------------------------------------

## The res:// path of the project's main scene, the one a launch of the game
## plays. The setting holds its uid.
static func main_scene_path() -> String:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	return ResourceUID.ensure_path(main_scene)

## True when `scene` is the project's main scene, as the current scene of every
## launch of the game is. False for null and for any other scene: the editor's Run
## Current Scene, a scene named on the command line, and a script run (-s), which
## starts none. It answers DevManager's question before a switch frees the current
## scene: is it the main scene, so free it? plays_main_scene() answers
## PersistenceManager's question at boot instead, whether the run plays the main
## scene, where a run it cannot tell counts as the main scene's.
static func is_main_scene(scene: Node) -> bool:
	return scene != null and scene.scene_file_path == main_scene_path()

## True when this run plays the main scene, as every launch of the game does:
## PersistenceManager asks it at boot, with the current scene (the engine makes the
## run's scene the current scene before the autoloads' _ready()), and only such a
## run writes a save. It answers false only on positive evidence: a current `scene`
## that is not the main scene, when the main scene's path (`main_path`) is known, or
## a script run, with -s or --script in `engine_args`, which starts no scene.
## Anything else counts as the main scene: no current scene in a run that is no
## script run, or a main scene whose uid does not resolve (`main_path` ""). The two
## mistakes are not equal: a launch of the game counted as another scene would play
## its whole session in memory and lose it, while another scene counted as the main
## one writes its save, the user's own only after the boot backup, taken under the
## lock, which can undo the write. `engine_args` and `main_path` default to this
## process's own, so a test can feed it each case. is_main_scene() answers the
## strict question.
static func plays_main_scene(scene: Node, engine_args: PackedStringArray = OS.get_cmdline_args(), main_path: String = main_scene_path()) -> bool:
	if engine_args.has("-s") or engine_args.has("--script"):
		return false
	if scene == null or main_path == "":
		return true
	return scene.scene_file_path == main_path

#-----------------------------------------------------------------------------
# THE PIN
#-----------------------------------------------------------------------------

## The file the pin is kept in: pin_path_override when a test set it. Otherwise
## res://.dev_settings.cfg, in the checkout, for a run from the editor binary
## (OS.has_feature("editor"), true for every run the editor starts), and
## user://dev_settings.cfg for an exported build.
static func pin_file_path() -> String:
	if pin_path_override != "":
		return pin_path_override
	if OS.has_feature("editor"):
		return _EDITOR_PIN_PATH
	return _EXPORT_PIN_PATH

## The pinned preset's id, or "" when nothing is pinned or the pin file is
## missing or will not load. Reading never writes.
static func read_pin() -> String:
	var path: String = pin_file_path()
	if not FileAccess.file_exists(path):
		return ""
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	return str(config.get_value(_PIN_SECTION, _PIN_KEY, ""))

## Pins the preset with this id, so every plain launch from this checkout (one with
## neither --preset nor --save, see parse()) starts in it; "" unpins, erasing the
## key. Anything else in the pin file is kept.
## Returns the error of the load or the save, OK when the pin is written.
static func write_pin(preset_id: String) -> Error:
	var path: String = pin_file_path()
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		var load_error: Error = config.load(path)
		if load_error != OK:
			return load_error
	if preset_id == "":
		# A null value erases the key, and the section once it is empty.
		config.set_value(_PIN_SECTION, _PIN_KEY, null)
	else:
		config.set_value(_PIN_SECTION, _PIN_KEY, preset_id)
	return config.save(path)
