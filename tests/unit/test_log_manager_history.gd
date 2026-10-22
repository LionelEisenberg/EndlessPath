extends GutTest

## Unit tests for LogManager's message history, which the five-line log board
## and the full log (L) read. Each test runs a fresh instance of the real
## LogManager script, so the autoload's history from other tests never leaks in.

const LOG_MANAGER_SCRIPT: GDScript = preload("res://singletons/log_manager/log_manager.gd")

var _log_manager: Node

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_log_manager = autofree(LOG_MANAGER_SCRIPT.new())

#-----------------------------------------------------------------------------
# HISTORY
#-----------------------------------------------------------------------------

func test_history_starts_empty() -> void:
	assert_eq(_log_manager.get_history(), [] as Array[String])

func test_history_keeps_order() -> void:
	_log_manager.log_message("first")
	_log_manager.log_message("second")
	_log_manager.log_message("third")
	assert_eq(_log_manager.get_history(), ["first", "second", "third"] as Array[String])

func test_history_trims_to_limit() -> void:
	var limit: int = _log_manager.HISTORY_LIMIT
	for i: int in range(limit + 5):
		_log_manager.log_message("line %d" % i)
	var history: Array[String] = _log_manager.get_history()
	assert_eq(history.size(), limit)
	assert_eq(history[0], "line 5", "the five oldest lines are dropped")
	assert_eq(history[-1], "line %d" % (limit + 4))

func test_history_is_a_copy() -> void:
	_log_manager.log_message("kept")
	var history: Array[String] = _log_manager.get_history()
	history.clear()
	assert_eq(_log_manager.get_history(), ["kept"] as Array[String])

func test_logging_still_emits() -> void:
	watch_signals(_log_manager)
	_log_manager.log_message("hello")
	assert_signal_emitted_with_parameters(_log_manager, "message_logged", ["hello"])
