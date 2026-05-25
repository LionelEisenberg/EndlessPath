class_name ScrollRail
extends Control

## ScrollRail
## Visual rail bound to a host ScrollContainer's vertical scrollbar. Hosts
## the grabber TextureRect and moves it as the host scrolls. Logic mirrors
## the EquipmentGrid scroll behaviour but in a reusable scene.

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
# PUBLIC API
#-----------------------------------------------------------------------------

## Bind to a host scroll container's vertical scrollbar. Safe to call again
## to rebind to a different host; the previous connection is dropped first.
func bind(host: ScrollContainer) -> void:
	if _bound and _bound.scrolling.is_connected(_on_scrolling):
		_bound.scrolling.disconnect(_on_scrolling)
	_bound = host.get_v_scroll_bar()
	_bound.scrolling.connect(_on_scrolling)
	_on_scrolling() # initial position

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_scrolling() -> void:
	if _bound == null:
		return
	var page: float = _bound.page
	var span: float = _bound.max_value - page
	var ratio: float = 0.0 if span <= 0.0 else _bound.value / span
	grabber.position.y = clampf(ratio, SCROLL_MIN_Y, SCROLL_MAX_Y) * size.y
