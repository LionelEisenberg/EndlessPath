class_name LacquerFloater
extends Control

## LacquerFloater
## A short gain rising on a small lacquer token (kit §0, §6.3): a few words
## such as "+1.5 Madra" in Madra blue (pop), or a foraging haul in cream, each
## count followed by its item's 16 px icon, "+3 [dewdrop]  +4 [fern]"
## (pop_items: the user's review, 2026-10-24, icons over names), a stat's gain
## with its icon before its name, "PERFECT +12 [Control icon] Control"
## (pop_stat), or any icons and text in order, "[arm] capped" (pop_parts). The
## token is 28 px tall and even(content width + 28) wide, its 2 px shadow baked
## into the 9-slice. It rises 40 px over 1 s in 2 px steps, then hides outright.
## It does not move itself: the placer positions it each frame and raises it by
## get_rise() (MapMarkers for the map's floater, the cycling view for the
## floater of each zone and seal node).

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

## A haul's item icons are drawn at 16 px; two spaces stand between its items.
const ITEM_ICON_SIZE: int = 16
const ITEM_SEPARATOR: String = "  "

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _token: Panel = %Token
@onready var _text: RichTextLabel = %Text

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _plain_text: String = ""
## The icons shown, in order: a haul's item icons, a stat's icon or the parts'
## icons; empty for plain text.
var _icons: Array[Texture2D] = []
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
	_icons.clear()
	_text.text = LacquerText.decimal_bbcode(text)
	_start(color)

## Shows a haul in color on the token and starts its rise: each count followed
## by its item's mini icon ("+3 [dewdrop]  +4 [fern]"), in the order given;
## an item with no icon shows its name. items maps each ItemDefinitionData to
## how many came in.
func pop_items(items: Dictionary, color: Color) -> void:
	var counts: Array[String] = []
	_icons.clear()
	_text.clear()
	for item: ItemDefinitionData in items:
		if not counts.is_empty():
			_text.add_text(ITEM_SEPARATOR)
		var count: String = "+%d" % items[item]
		counts.append(count)
		_text.add_text(count + " ")
		var icon: Texture2D = item.get_mini_icon()
		if icon == null:
			_text.add_text(item.item_name)
			continue
		_icons.append(icon)
		_text.add_image(icon, ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	_plain_text = ITEM_SEPARATOR.join(counts)
	_start(color)

## Shows `lead`, a space, `stat`'s 16 px icon, a space and its name in color on
## the token ("PERFECT +12 [Control icon] Control"), and starts its rise. A stat
## with no icon shows its name alone after the lead.
func pop_stat(lead: String, stat: CharacterAttributesData.AttributeType, color: Color) -> void:
	var stat_name: String = StatDisplay.name_of(stat)
	_plain_text = "%s %s" % [lead, stat_name]
	_icons.clear()
	_text.clear()
	_text.append_text(LacquerText.decimal_bbcode(lead + " "))
	var icon: Texture2D = StatDisplay.icon_of(stat)
	if icon != null:
		_icons.append(icon)
		_text.add_image(icon, ITEM_ICON_SIZE, ITEM_ICON_SIZE)
		_text.add_text(" ")
	_text.add_text(stat_name)
	_start(color)

## Shows icons and text in color on the token, in the order given, and starts its
## rise: each part a String, or a Texture2D drawn at ITEM_ICON_SIZE ("[arm]
## capped", the body refining board's line under a rep's tier). get_text() gives
## the text parts joined, get_icons() the icons.
func pop_parts(parts: Array, color: Color) -> void:
	var texts: PackedStringArray = []
	_icons.clear()
	_text.clear()
	for part: Variant in parts:
		if part is Texture2D:
			_icons.append(part as Texture2D)
			_text.add_image(part as Texture2D, ITEM_ICON_SIZE, ITEM_ICON_SIZE)
		else:
			texts.append(str(part))
			_text.add_text(str(part))
	_plain_text = "".join(texts)
	_start(color)

## Hides the floater outright.
func stop() -> void:
	hide()
	set_process(false)

## The text shown, without BBCode; a haul's counts alone ("+3  +4"), a stat's
## gain without its icon ("PERFECT +12 Control"), the parts' text joined.
func get_text() -> String:
	return _plain_text

## The icons shown, in order: a haul's item icons, a stat's icon or the parts'
## icons; empty for plain text.
func get_icons() -> Array[Texture2D]:
	return _icons.duplicate()

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

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Colours the content, sizes the token to it and starts the rise.
func _start(color: Color) -> void:
	_color = color
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
