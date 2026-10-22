extends Node

## specific log types can be handled by the caller constructing the bbcode string
## this keeps the manager simple and flexible

signal message_logged(bbcode_message: String)
signal visibility_toggled()

## Most messages get_history() keeps; older ones are dropped.
const HISTORY_LIMIT: int = 200

var _history: Array[String] = []

## Logs a message to the global log window.
func log_message(bbcode: String) -> void:
	_history.append(bbcode)
	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)
	message_logged.emit(bbcode)

## The logged messages, oldest first, up to HISTORY_LIMIT. A copy: changing it
## leaves the log as it is.
func get_history() -> Array[String]:
	return _history.duplicate()

## Opens or closes the full log: LogWindow answers visibility_toggled the way
## it answers L. It does nothing while the log is hidden (under an overlay).
func toggle_window() -> void:
	visibility_toggled.emit()
