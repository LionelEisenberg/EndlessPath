class_name LacquerCountSeal
extends Control

## The kit's cinnabar count seal with a number on it (lacquer kit §4.2): a
## buff's stacks on the vitals cabinet, a dock button's notifications, a
## consumable's count on the technique dock. The seal's worn bites stay in the
## 6 px at each end, so it is a 9-slice whose plain middle stretches: a count
## that needs more room widens the seal, from the edge its user keeps, and is
## never cut off. It is 24 px wide at least, the seal's own size, and it never
## takes the pointer.

## True keeps the right edge where the scene puts it, so the seal widens to the
## left; false keeps the left edge.
@export var grows_left: bool = true

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The seal art's own width, its narrowest.
const MIN_WIDTH: float = 24.0
## The room around a count: 4 px on each side.
const PADDING: float = 8.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _label: Label = %CountLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The edges the scene put the seal at, which a widened seal keeps.
var _home_left: float = 0.0
var _home_right: float = 0.0
## A count shown before the seal was ready, or -1.
var _pending_count: int = -1

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_home_left = position.x
	_home_right = position.x + size.x
	if _pending_count >= 0:
		show_count(_pending_count)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Puts count on the seal and fits the seal's width to it.
func show_count(count: int) -> void:
	if not is_node_ready():
		_pending_count = count
		return
	_pending_count = -1
	_label.text = str(count)
	var width: float = width_for(_label.get_minimum_size().x)
	size.x = width
	position.x = _home_right - width if grows_left else _home_left

## Returns the seal's width for a count text_width px wide: the text and its
## padding, rounded up to even, and never under the seal's own 24 px.
static func width_for(text_width: float) -> float:
	return maxf(MIN_WIDTH, ceilf((text_width + PADDING) / 2.0) * 2.0)
