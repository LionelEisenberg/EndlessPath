class_name ScrollRail
extends Control

## ScrollRail
## Visual rail bound to a host ScrollContainer's vertical scrollbar: a pressed
## groove, 10 px wide, at the host's full height, with a 4 px ink thumb lying
## in the groove's floor. The thumb is as long as the share of the floor the
## host shows (never shorter than its art), and travels the floor as the host
## scrolls, by wheel or from code, on even pixels. Hides the whole rail when
## there is nothing to scroll (content fits), so it never floats beside a short
## list.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The groove's end walls: its floor runs from 2 px under its top to 2 px over
## its foot.
const _WALL: float = 2.0

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var grabber: NinePatchRect = %Grabber

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _bound: VScrollBar = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	resized.connect(_refresh)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Bind to a host scroll container's vertical scrollbar. Safe to call again
## to rebind to a different host; the previous connections are dropped first.
func bind(host: ScrollContainer) -> void:
	if _bound:
		if _bound.value_changed.is_connected(_on_value_changed):
			_bound.value_changed.disconnect(_on_value_changed)
		if _bound.changed.is_connected(_refresh):
			_bound.changed.disconnect(_refresh)
	_bound = host.get_v_scroll_bar()
	# `value_changed` fires on every scroll, by wheel or from code; `changed`
	# fires when the content range changes (items added/removed on rebuild).
	_bound.value_changed.connect(_on_value_changed)
	_bound.changed.connect(_refresh)
	_refresh()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

func _on_value_changed(_value: float) -> void:
	_refresh()

## Sizes and places the thumb for the host's scroll, and hides the whole rail
## when the content fits (nothing to scroll).
func _refresh() -> void:
	if _bound == null:
		return
	var span: float = _bound.max_value - _bound.page
	visible = span > 0.0
	if not visible:
		return
	var floor_length: float = size.y - 2.0 * _WALL
	var shown_share: float = _bound.page / _bound.max_value
	var length: float = minf(maxf(_even(floor_length * shown_share), float(grabber.texture.get_height())), floor_length)
	var travel: float = floor_length - length
	grabber.size.y = length
	grabber.position.y = _WALL + _even(clampf(_bound.value / span, 0.0, 1.0) * travel)

## Rounds `value` to the nearest even number of pixels.
static func _even(value: float) -> float:
	return roundf(value / 2.0) * 2.0
