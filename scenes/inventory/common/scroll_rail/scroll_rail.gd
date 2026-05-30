class_name ScrollRail
extends Control

## ScrollRail
## Visual rail bound to a host ScrollContainer's vertical scrollbar. Moves the
## grabber as the host scrolls (mirrors the equipment grid's scroll behaviour)
## and hides the whole rail when there is nothing to scroll (content fits), so
## it never floats over a near-empty grid.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SCROLL_MIN_Y: float = 0.025
const SCROLL_MAX_Y: float = 0.90

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var grabber: TextureRect = %Grabber

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
		if _bound.scrolling.is_connected(_refresh):
			_bound.scrolling.disconnect(_refresh)
		if _bound.changed.is_connected(_refresh):
			_bound.changed.disconnect(_refresh)
	_bound = host.get_v_scroll_bar()
	# `scrolling` fires while the player scrolls; `changed` fires when the
	# content range changes (items added/removed on rebuild).
	_bound.scrolling.connect(_refresh)
	_bound.changed.connect(_refresh)
	_refresh()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

## Move the grabber to match the scroll position, and hide the whole rail when
## the content fits (nothing to scroll).
func _refresh() -> void:
	if _bound == null:
		return
	var span: float = _bound.max_value - _bound.page
	visible = span > 0.0
	if not visible:
		return
	var ratio: float = _bound.value / span
	grabber.position.y = clampf(ratio, SCROLL_MIN_Y, SCROLL_MAX_Y) * size.y
