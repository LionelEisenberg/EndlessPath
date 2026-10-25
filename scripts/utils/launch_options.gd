class_name LaunchOptions extends RefCounted

## LaunchOptions
## What this run was launched with: the options after `--` on the command line
## (`--save=<path>` and `--no-autosave`), and whether the process is a GUT test
## run. Code reads the options through current(). parse() takes the argument
## list as a parameter, so a test can feed it any list.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _SAVE_OPTION_PREFIX: String = "--save="
const _NO_AUTOSAVE_OPTION: String = "--no-autosave"

## Both ways a GUT run starts put this in the engine arguments, once
## backslashes are slashes: the CLI's `-s res://addons/gut/gut_cmdln.gd` (typed
## as `addons\gut\...` on Windows) and the editor panel's
## `--scene res://addons/gut/gui/run_from_editor.tscn`.
const _GUT_PATH_MARKER: String = "addons/gut/"

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The save file to play on instead of the user's own, from `--save=<path>`.
## Empty when the option was not given.
var save_path: String = ""

## True when `--no-autosave` was given.
var no_autosave: bool = false

## What current() parsed on its first call.
static var _current: LaunchOptions = null

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Reads `--save=<path>` and `--no-autosave` from the arguments. Anything else
## is ignored, a `--save` without an `=` included.
static func parse(user_args: PackedStringArray) -> LaunchOptions:
	var options: LaunchOptions = LaunchOptions.new()
	for arg: String in user_args:
		if arg.begins_with(_SAVE_OPTION_PREFIX):
			options.save_path = arg.trim_prefix(_SAVE_OPTION_PREFIX)
		elif arg == _NO_AUTOSAVE_OPTION:
			options.no_autosave = true
	return options

## The options this process was launched with: the user arguments after `--`,
## parsed on the first call and the same object on every call after it.
static func current() -> LaunchOptions:
	if _current == null:
		_current = parse(OS.get_cmdline_user_args())
	return _current

## True when this process is a GUT run, from the command line or from the
## editor's GUT panel. The engine arguments do not include the user arguments
## after `--`, so a `--save=` path cannot make a normal launch look like one.
static func is_test_run() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.replace("\\", "/").contains(_GUT_PATH_MARKER):
			return true
	return false
