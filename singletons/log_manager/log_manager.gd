extends Node

## specific log types can be handled by the caller constructing the bbcode string
## this keeps the manager simple and flexible

signal message_logged(bbcode_message: String)

## Logs a message to the global log window.
func log_message(bbcode: String) -> void:
	message_logged.emit(bbcode)
