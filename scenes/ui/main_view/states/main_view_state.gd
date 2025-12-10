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
