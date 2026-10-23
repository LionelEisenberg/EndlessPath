class_name LacquerFrameOverlay
extends Panel

## A lacquer 9-slice frame laid over a target, with no fill (lacquer kit
## §4.2). The scene draws the brass frame (flashes, pinned map plates); an
## instance can override theme_override_styles/panel with frame_hover.tres for
## the hover frame. It never takes the mouse and starts hidden.
## flash() shows and hides it outright, 300 ms each way: no fade.

const FLASH_PHASE_SECONDS: float = 0.3

var _flash_tween: Tween = null

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the frame for 300 ms then hides it for 300 ms, times times, and ends
## hidden. A new flash restarts from the start.
func flash(times: int) -> void:
	_stop_flash()
	if times <= 0 or not is_inside_tree():
		hide()
		return
	show()
	_flash_tween = create_tween()
	for i: int in times:
		if i > 0:
			_flash_tween.tween_callback(show)
		_flash_tween.tween_interval(FLASH_PHASE_SECONDS)
		_flash_tween.tween_callback(hide)
		_flash_tween.tween_interval(FLASH_PHASE_SECONDS)

## Returns true while a flash is running, its last hidden phase included.
func is_flashing() -> bool:
	return _flash_tween != null and _flash_tween.is_valid() and _flash_tween.is_running()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _stop_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
