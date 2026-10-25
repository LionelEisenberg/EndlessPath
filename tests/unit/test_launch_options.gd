extends GutTest

## Unit tests for LaunchOptions: the options after `--` on the command line
## (`--save=<path>`, `--no-autosave` and `--preset=<id>`), the checkout's pinned
## preset, and the detection of a GUT test run. parse() takes its arguments and
## the pin as parameters, so its tests do not depend on how this process was
## started. The pin tests point pin_path_override at a temp file, so the
## checkout's own pin file is never written. is_test_run() reads the real command
## line, which in this suite is always a GUT run.

## The pin file the pin tests write. after_each() deletes it.
const PIN_PATH: String = "user://__test_launch_options_pin.cfg"

func after_each() -> void:
	LaunchOptions.pin_path_override = ""
	if FileAccess.file_exists(PIN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PIN_PATH))

#-----------------------------------------------------------------------------
# PARSE
#-----------------------------------------------------------------------------

func test_no_args_gives_the_defaults() -> void:
	var options: LaunchOptions = LaunchOptions.parse([])
	assert_eq(options.save_path, "")
	assert_false(options.no_autosave)

func test_save_option_sets_the_path() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--save=user://dev/runs/a.tres"])
	assert_eq(options.save_path, "user://dev/runs/a.tres")

func test_no_autosave_flag() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--no-autosave"])
	assert_true(options.no_autosave)

func test_unknown_args_are_ignored() -> void:
	# A "--save" without an "=" names no path, so it is ignored like the rest.
	var options: LaunchOptions = LaunchOptions.parse(["--foo", "bar", "--save"])
	assert_eq(options.save_path, "")
	assert_false(options.no_autosave)

func test_the_options_combine() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--save=user://dev/runs/a.tres", "--no-autosave"])
	assert_eq(options.save_path, "user://dev/runs/a.tres")
	assert_true(options.no_autosave)

#-----------------------------------------------------------------------------
# PRESETS
#-----------------------------------------------------------------------------

func test_preset_option() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--preset=tribulation_ready", "--save=user://dev/runs/a.tres"])
	assert_eq(options.preset_id, "tribulation_ready")
	assert_false(options.preset_from_pin, "the id came from the command line")
	assert_eq(options.save_path, "user://dev/runs/a.tres", "--save still names the file the session writes")

func test_no_preset_and_no_pin_gives_none() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--no-autosave"])
	assert_eq(options.preset_id, "")
	assert_false(options.preset_from_pin)

func test_the_pin_starts_a_preset() -> void:
	var options: LaunchOptions = LaunchOptions.parse([], "x")
	assert_eq(options.preset_id, "x", "a launch with no --preset starts the pinned one")
	assert_true(options.preset_from_pin)

func test_an_option_beats_the_pin() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--preset=y"], "x")
	assert_eq(options.preset_id, "y", "--preset beats the pin")
	assert_false(options.preset_from_pin)

#-----------------------------------------------------------------------------
# THE PIN FILE
#-----------------------------------------------------------------------------

func test_write_and_read_the_pin() -> void:
	LaunchOptions.pin_path_override = PIN_PATH
	assert_eq(LaunchOptions.write_pin("merchant_open"), OK)
	assert_eq(LaunchOptions.read_pin(), "merchant_open")
	var config := ConfigFile.new()
	assert_eq(config.load(PIN_PATH), OK, "the pin is written to the override's file")
	assert_eq(config.get_value("dev", "pinned_preset", ""), "merchant_open", "in section dev, key pinned_preset")

func test_an_empty_pin_clears_it() -> void:
	LaunchOptions.pin_path_override = PIN_PATH
	assert_eq(LaunchOptions.write_pin("merchant_open"), OK, "precondition: a pin is written")
	assert_eq(LaunchOptions.write_pin(""), OK)
	assert_eq(LaunchOptions.read_pin(), "", "an empty id unpins")
	var config := ConfigFile.new()
	config.load(PIN_PATH)
	assert_false(config.has_section_key("dev", "pinned_preset"), "the key is erased, not set to an empty id")

func test_no_pin_file_reads_no_pin() -> void:
	LaunchOptions.pin_path_override = PIN_PATH
	assert_false(FileAccess.file_exists(PIN_PATH), "precondition: there is no pin file")
	assert_eq(LaunchOptions.read_pin(), "")

func test_the_override_is_the_pin_file() -> void:
	LaunchOptions.pin_path_override = PIN_PATH
	assert_eq(LaunchOptions.pin_file_path(), PIN_PATH)

## The suite runs on the editor binary, so without the override the pin is the
## checkout's own file. Only its path is read here: nothing writes it.
func test_an_editor_run_pins_in_the_checkout() -> void:
	assert_true(OS.has_feature("editor"), "precondition: the suite runs on the editor binary")
	assert_eq(LaunchOptions.pin_file_path(), "res://.dev_settings.cfg")

#-----------------------------------------------------------------------------
# CURRENT
#-----------------------------------------------------------------------------

func test_current_is_computed_once() -> void:
	assert_same(LaunchOptions.current(), LaunchOptions.current())

#-----------------------------------------------------------------------------
# TEST RUN
#-----------------------------------------------------------------------------

func test_this_suite_is_a_test_run() -> void:
	assert_true(LaunchOptions.is_test_run())
