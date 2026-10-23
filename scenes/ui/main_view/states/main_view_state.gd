## Abstract base class for Main View States.
class_name MainViewState
extends Node

var scene_root: MainView

## Called when entering this state.
func enter() -> void:
	pass

## Called when exiting this state.
func exit() -> void:
	pass

## Handle input events in this state.
func handle_input(_event: InputEvent) -> void:
	pass

## Keeps the full log shut while a menu book or the cycling board is open, or
## lets it open again, so that Esc reaches the book or the board. The view-state
## tests stand a plain Control in for the log: it has no full log.
func _block_full_log(blocked: bool) -> void:
	var log_window: LogWindow = scene_root.log_window as LogWindow
	if log_window != null:
		log_window.set_full_log_blocked(blocked)
