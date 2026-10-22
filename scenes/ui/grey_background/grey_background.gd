## Grey Background orchestrator.
##
## Owns the grey backdrop panel shown behind modal views (the menu books and
## the merchant shop). Drives a synchronized fade-in/fade-out animation on
## itself, and triggers the panel's own open/close animation in parallel so
## the grey backdrop and the panel move as one unit.
##
## Panels can implement:
##   - animate_open() -> void
##   - animate_close() -> void
##   - signal close_finished: emitted when the panel's own close animation
##     ends. When a panel has it, hiding completes only once both the grey
##     fade-out and the panel's close have finished. Without it, the grey
##     fade-out alone decides when hiding completes.
##
## Panels without these fall back to plain visibility toggles.
class_name GreyBackground
extends Panel

## Emitted after hide_with_panel completes and both nodes are hidden.
signal panel_hidden
## A left click landed on the backdrop itself, outside the panel it backs.
## The menu books close on it.
signal clicked

@onready var _animation_player: AnimationPlayer = %GreyBackgroundAnimationPlayer

var _panel_pending_hide: Control = null
var _is_fading_out: bool = false
var _is_panel_closing: bool = false

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Show the grey backdrop and the given panel together with a fade-in animation.
## Calls panel.animate_open() if the panel has that method.
func show_with_panel(panel: Control) -> void:
	self_modulate.a = 0.0
	visible = true
	panel.visible = true

	_animation_player.play("grey_fade_in")

	if panel.has_method("animate_open"):
		panel.animate_open()

## Hide the grey backdrop and the given panel together with a fade-out animation.
## Calls panel.animate_close() if the panel has that method. Emits panel_hidden
## when the grey fade-out finishes, and also the panel's close when it has a
## close_finished signal.
func hide_with_panel(panel: Control) -> void:
	_panel_pending_hide = panel
	_is_fading_out = true
	_is_panel_closing = panel.has_signal(&"close_finished")
	if _is_panel_closing and not panel.is_connected(&"close_finished", _on_panel_close_finished):
		panel.connect(&"close_finished", _on_panel_close_finished, CONNECT_ONE_SHOT)

	if not _animation_player.animation_finished.is_connected(_on_hide_animation_finished):
		_animation_player.animation_finished.connect(_on_hide_animation_finished, CONNECT_ONE_SHOT)
	_animation_player.play("grey_fade_out")

	if panel.has_method("animate_close"):
		panel.animate_close()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()

func _on_hide_animation_finished(_anim_name: StringName) -> void:
	_is_fading_out = false
	_finish_hide_when_done()

func _on_panel_close_finished() -> void:
	_is_panel_closing = false
	_finish_hide_when_done()

func _finish_hide_when_done() -> void:
	if _is_fading_out or _is_panel_closing:
		return
	visible = false
	if _panel_pending_hide:
		_panel_pending_hide.visible = false
		_panel_pending_hide = null
	panel_hidden.emit()
