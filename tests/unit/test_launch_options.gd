extends GutTest

## Unit tests for LaunchOptions: the options after `--` on the command line
## (`--save=<path>` and `--no-autosave`) and the detection of a GUT test run.
## parse() takes its arguments as a parameter, so its tests do not depend on how
## this process was started. is_test_run() reads the real command line, which in
## this suite is always a GUT run.

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
# CURRENT
#-----------------------------------------------------------------------------

func test_current_is_computed_once() -> void:
	assert_same(LaunchOptions.current(), LaunchOptions.current())

#-----------------------------------------------------------------------------
# TEST RUN
#-----------------------------------------------------------------------------

func test_this_suite_is_a_test_run() -> void:
	assert_true(LaunchOptions.is_test_run())
