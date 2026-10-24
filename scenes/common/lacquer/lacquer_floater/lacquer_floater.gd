class_name LacquerFloater
extends Control

## LacquerFloater
## A short gain rising on a small lacquer token (kit §0, §6.3): a few words
## such as "+1.5 Madra" in Madra blue, or a foraging haul in cream. The token
## is 28 px tall and even(text width + 28) wide, its 2 px shadow baked into the
## 9-slice. It rises 40 px over 1 s in 2 px steps, then hides outright. It does
## not move itself: the placer positions it each frame and raises it by
## get_rise() (MapMarkers for the map's floater, the cycling view for the
## floater of each zone).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The rise: 40 px over 1 s, 20 steps of 2 px.
const RISE_PX: int = 40
const RISE_SECONDS: float = 1.0
const RISE_STEPS: int = 20
## Absorbs float error at a step boundary.
const _RISE_STEP_EPSILON: float = 0.000001

## The token's height and the room it leaves around the text, without and
## with the 2 px shadow baked into token.tres.
const TOKEN_HEIGHT: int = 28
const TOKEN_TEXT_PADDING: int = 28
const TOKEN_SHADOW: int = 2

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _token: Panel = %Token
@onready var _text: RichTextLabel = %Text

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _plain_text: String = ""
var _color: Color = ThemeConstants.LACQUER_CREAM
var _elapsed: float = 0.0
var _token_width: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	set_process(visible)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= RISE_SECONDS:
		stop()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows text in color on the token and starts its rise from the bottom.
func pop(text: String, color: Color) -> void:
	_plain_text = text
	_color = color
	_text.text = LacquerText.decimal_bbcode(text)
	_text.add_theme_color_override("default_color", color)
	var text_width: int = ceili(_text.get_content_width())
	_token_width = text_width + TOKEN_TEXT_PADDING
	_token_width += _token_width % 2
	_token.size = Vector2(_token_width + TOKEN_SHADOW, TOKEN_HEIGHT + TOKEN_SHADOW)
	_text.size = Vector2(_token_width, _text.size.y)
	size = _token.size
	_elapsed = 0.0
	show()
	set_process(true)

## Hides the floater outright.
func stop() -> void:
	hide()
	set_process(false)

## The text shown, without BBCode.
func get_text() -> String:
	return _plain_text

## The text colour.
func get_color() -> Color:
	return _color

## How far it has risen, in kit px (0-40, 2 px steps).
func get_rise() -> int:
	return rise_at(_elapsed)

## The token's width without its shadow: even(text width + 28).
func get_token_width() -> int:
	return _token_width

## The rise in kit px at elapsed seconds: 2 px a step, 20 steps over 1 s.
static func rise_at(elapsed: float) -> int:
	var step_seconds: float = RISE_SECONDS / RISE_STEPS
	var steps: int = clampi(floori(elapsed / step_seconds + _RISE_STEP_EPSILON), 0, RISE_STEPS)
	@warning_ignore("integer_division")
	return steps * (RISE_PX / RISE_STEPS)
