## Grey Background orchestrator.
##
## Owns the grey backdrop panel shown behind modal views (AbilitiesView, PathTreeView).
## Drives a synchronized fade-in/fade-out animation on itself, and triggers the
## panel's own open/close animation in parallel so the grey backdrop and the
## panel move as one unit.
##
## Panels should implement:
##   - animate_open() -> void
##   - animate_close() -> void  (should emit a close-finished signal when done,
##     but GreyBackground uses the local AnimationPlayer's timing as the source
##     of truth for when hiding completes)
##
## Panels without these methods fall back to plain visibility toggles.
class_name GreyBackground
extends Panel

## Emitted after hide_with_panel completes and both nodes are hidden.
signal panel_hidden

@onready var _animation_player: AnimationPlayer = %GreyBackgroundAnimationPlayer

var _panel_pending_hide: Control = null

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
## when the grey fade-out finishes.
func hide_with_panel(panel: Control) -> void:
	_panel_pending_hide = panel

	if not _animation_player.animation_finished.is_connected(_on_hide_animation_finished):
		_animation_player.animation_finished.connect(_on_hide_animation_finished, CONNECT_ONE_SHOT)
	_animation_player.play("grey_fade_out")

	if panel.has_method("animate_close"):
		panel.animate_close()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_hide_animation_finished(_anim_name: StringName) -> void:
	visible = false
	if _panel_pending_hide:
		_panel_pending_hide.visible = false
		_panel_pending_hide = null
	panel_hidden.emit()
