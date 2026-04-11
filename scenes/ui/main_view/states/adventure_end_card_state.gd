## State for the Adventure End Card overlay.
class_name AdventureEndCardState
extends MainViewState

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	# show_results is called separately after enter, triggered by adventure_completed

## Called when exiting this state.
func exit() -> void:
	scene_root.adventure_end_card.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(_event: InputEvent) -> void:
	pass
