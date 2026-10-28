extends GutTest

## Unit tests for LaunchOptions: the options after `--` on the command line
## (`--save=<path>`, `--no-autosave` and `--preset=<id>`), the checkout's pinned
## preset, the detection of a GUT test run, and the two checks of the main scene:
## whether a scene is the project's main scene (is_main_scene()), and whether a run
## plays it (plays_main_scene()). parse() and plays_main_scene() take their
## arguments as parameters, so their tests do not depend on how this process was
## started. The pin tests point pin_path_override at a temp file, so the checkout's
## own pin file is never written. is_test_run() reads the real command line, which
## in this suite is always a GUT run.

## The pin file the pin tests write. after_each() deletes it.
const PIN_PATH: String = "user://__test_launch_options_pin.cfg"

## A scene that is not the main scene.
const OTHER_SCENE: String = "res://scenes/ui/dev_panel/dev_panel.tscn"

## The engine arguments of a launch of the game from the command line, which names
## no script.
const LAUNCH_ARGS: PackedStringArray = ["--path", "."]

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

## A run that names its own save file is a file session. The pinned preset would be
## built over that file, which a scripted run does not expect.
func test_a_save_option_beats_the_pin() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--save=user://a.tres"], "x")
	assert_eq(options.preset_id, "", "--save makes a file session, not the pinned preset")
	assert_false(options.preset_from_pin)
	assert_eq(options.save_path, "user://a.tres", "the --save path is kept")

## --no-autosave names no save, so a plain launch that turns autosave off still starts
## in the pinned preset.
func test_no_autosave_keeps_the_pin() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--no-autosave"], "x")
	assert_eq(options.preset_id, "x", "--no-autosave alone still starts the pinned preset")
	assert_true(options.preset_from_pin)
	assert_true(options.no_autosave)

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

#-----------------------------------------------------------------------------
# THE MAIN SCENE
#-----------------------------------------------------------------------------

func test_the_main_scene_path_is_the_project_main_scene() -> void:
	assert_eq(LaunchOptions.main_scene_path(), "res://scenes/main/main_game/main_game.tscn", "the setting's uid, as a res:// path")

## DevManager's question: only the main scene is freed and loaded again by a session
## switch, so another scene, a node that is no scene and no scene at all are not the
## main scene. A script run (-s) starts no scene, so its current scene is null.
func test_only_the_main_scene_is_the_main_scene() -> void:
	var main_scene: Node = autofree(Node.new())
	main_scene.scene_file_path = LaunchOptions.main_scene_path()
	var other_scene: Node = autofree(Node.new())
	other_scene.scene_file_path = OTHER_SCENE
	assert_true(LaunchOptions.is_main_scene(main_scene))
	assert_false(LaunchOptions.is_main_scene(other_scene), "another scene, as the editor's Run Current Scene plays")
	assert_false(LaunchOptions.is_main_scene(autofree(Node.new())), "a node that is no scene")
	assert_false(LaunchOptions.is_main_scene(null), "no scene at all, as in a script run")

#-----------------------------------------------------------------------------
# PLAYS THE MAIN SCENE
#-----------------------------------------------------------------------------
# PersistenceManager's question at boot: only a run of the main scene writes a save.
# The answer is no only on positive evidence. Each test passes the engine arguments,
# since this GUT run's own contain -s, and the main scene's path.

func test_a_run_of_the_main_scene_plays_it() -> void:
	var main_scene: Node = autofree(Node.new())
	main_scene.scene_file_path = LaunchOptions.main_scene_path()
	assert_true(LaunchOptions.plays_main_scene(main_scene, LAUNCH_ARGS, LaunchOptions.main_scene_path()))
	assert_true(LaunchOptions.plays_main_scene(main_scene, LAUNCH_ARGS), "the main scene's path defaults to the project's")

func test_a_run_of_another_scene_does_not_play_it() -> void:
	var other_scene: Node = autofree(Node.new())
	other_scene.scene_file_path = OTHER_SCENE
	assert_false(LaunchOptions.plays_main_scene(other_scene, LAUNCH_ARGS, LaunchOptions.main_scene_path()), "the editor's Run Current Scene, or a scene named on the command line")

## A run with no current scene that is no script run cannot be told apart, so it
## counts as the main scene: it writes its save (the user's own after the boot
## backup), where the other answer would lose a real launch's whole session.
func test_a_run_with_no_scene_and_no_script_plays_it() -> void:
	assert_true(LaunchOptions.plays_main_scene(null, LAUNCH_ARGS, LaunchOptions.main_scene_path()))

## A script run starts no scene.
func test_a_script_run_does_not_play_it() -> void:
	var main_path: String = LaunchOptions.main_scene_path()
	assert_false(LaunchOptions.plays_main_scene(null, PackedStringArray(["--headless", "-s", "res://tools/a_script.gd"]), main_path), "-s")
	assert_false(LaunchOptions.plays_main_scene(null, PackedStringArray(["--headless", "--script", "res://tools/a_script.gd"]), main_path), "--script")

## A main scene whose uid does not resolve (a checkout with no uid cache, say) gives
## an empty path, so no scene can be told apart from it: the run counts as the main
## scene's. The path is passed in: an unknown uid in the project setting can push an
## engine error.
func test_a_run_whose_main_scene_is_not_known_plays_it() -> void:
	var other_scene: Node = autofree(Node.new())
	other_scene.scene_file_path = OTHER_SCENE
	assert_true(LaunchOptions.plays_main_scene(other_scene, LAUNCH_ARGS, ""))
