class_name ViewDissolve
extends TextureRect

## ViewDissolve
## The style guide's 2-step dither dissolve (§8, Show and hide) from one whole
## view to the next. play() lays a still of the screen as it was over the view
## that replaces it, then takes the still away in two dither steps
## (dither_dissolve.gdshader, inverted): half its 2 px art cells at once, three
## quarters after STEP_SECONDS, all of it after two, when it hides. Nothing
## fades and nothing under it waits: the new view runs and takes the pointer
## from the first frame. MainView plays it where the zone view gives way to an
## adventure and back (AdventureViewState).

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The still is gone.
signal finished

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long each of the two dither steps holds (the mock's 200 ms in all).
const STEP_SECONDS: float = 0.1

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _tween: Tween = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_clear()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Takes a still of the screen as it was last drawn and dissolves it away over
## whatever replaces it this frame. Call it just before the views change. Does
## nothing where no frame is drawn (headless, as in the tests).
func play() -> void:
	var still: Texture2D = _take_still()
	if still != null:
		play_over(still)

## Shows still over the views and dissolves it away: half its art cells at
## once, three quarters after STEP_SECONDS, all of it after two. A dissolve
## still playing ends where it is and this one starts.
func play_over(still: Texture2D) -> void:
	if _tween != null:
		_tween.kill()
	texture = still
	_set_step(1)
	visible = true
	_tween = create_tween()
	_tween.tween_interval(STEP_SECONDS)
	_tween.tween_callback(_set_step.bind(2))
	_tween.tween_interval(STEP_SECONDS)
	_tween.tween_callback(_finish)

## Whether a still is up and dissolving.
func is_playing() -> bool:
	return visible

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The root viewport's last drawn frame, or null under the headless display
## server, whose viewports hold no image.
func _take_still() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _set_step(step: int) -> void:
	(material as ShaderMaterial).set_shader_parameter("dissolve_step", step)

func _finish() -> void:
	_tween = null
	_clear()
	finished.emit()

## Hidden, with no still held and the shader back at step 0.
func _clear() -> void:
	visible = false
	texture = null
	_set_step(0)
