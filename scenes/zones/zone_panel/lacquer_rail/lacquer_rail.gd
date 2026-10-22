class_name LacquerRail
extends Control

## The brass rail beside the activity list (lacquer kit §4.4, §5.5). It stands
## in for the ScrollContainer's hidden scrollbar: an end cap at each end, lit
## (brass arrow) when the list can scroll that way and carved when it can't,
## a carved track between them, and a thumb whose height shows how much of
## the list is in view. It shows only while the list is taller than its
## viewport.
## A lit cap steps the list by one drawer and its gap; dragging the thumb
## scrolls the list. Scrolls move in six even-px steps over 200 ms, never
## eased.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Height of each end cap; the track runs between them.
const CAP_HEIGHT: float = 14.0
const MIN_THUMB_HEIGHT: float = 32.0
## One drawer (72) and the gap under it (8).
const CAP_STEP: float = 80.0
## A scroll moves in this many steps, STEP_SECONDS apart (200 ms in all).
const SCROLL_STEPS: int = 6
const STEP_SECONDS: float = 0.033
## The list counts as scrolled away from an edge beyond this many px.
const EDGE_SLACK: float = 2.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _up_cap: TextureButton = %UpCap
@onready var _down_cap: TextureButton = %DownCap
@onready var _thumb: Control = %Thumb

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _host: ScrollContainer = null
var _step_tween: Tween = null
var _dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_scroll: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_up_cap.pressed.connect(_on_up_cap_pressed)
	_down_cap.pressed.connect(_on_down_cap_pressed)
	_thumb.gui_input.connect(_on_thumb_gui_input)
	resized.connect(_refresh)
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Follows host's vertical scroll: the rail shows while host's content is
## taller than host, and its caps and thumb scroll host.
func bind(host: ScrollContainer) -> void:
	if _host != null:
		_disconnect_host()
	_host = host
	if _host != null:
		var bar: VScrollBar = _host.get_v_scroll_bar()
		bar.value_changed.connect(_on_scroll_value_changed)
		bar.changed.connect(_refresh)
		_host.resized.connect(_refresh)
	_refresh()

## Scrolls the host to target (px from the top) in six even-px steps over
## 200 ms. A new scroll replaces one still running.
func step_to(target: float) -> void:
	if _host == null:
		return
	_kill_step()
	var from: float = float(_host.scroll_vertical)
	var to: float = clampf(target, 0.0, _get_max_scroll())
	if absf(to - from) < 1.0:
		return
	_step_tween = create_tween()
	for step: int in range(1, SCROLL_STEPS + 1):
		var value: float = to if step == SCROLL_STEPS else _even(from + (to - from) * step / SCROLL_STEPS)
		_step_tween.tween_interval(STEP_SECONDS)
		_step_tween.tween_callback(_set_host_scroll.bind(value))

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Shows the rail only when the content overflows, lights the caps that can
## scroll, and sizes and places the thumb (kit §5.5):
## height = max(32, even((L - 28) × L / content)),
## y = 14 + even((L - 28 - height) × scroll / (content - L)).
func _refresh() -> void:
	if not is_node_ready():
		return
	var view: float = _get_view_height()
	var content: float = _get_content_height()
	visible = _host != null and content > view
	if not visible:
		return
	var scroll: float = float(_host.scroll_vertical)
	_up_cap.disabled = scroll <= EDGE_SLACK
	_down_cap.disabled = scroll + view >= content - EDGE_SLACK
	var track: float = view - 2.0 * CAP_HEIGHT
	var thumb_height: float = maxf(MIN_THUMB_HEIGHT, _even(track * view / content))
	var travel: float = maxf(0.0, track - thumb_height)
	var thumb_y: float = CAP_HEIGHT + _even(travel * scroll / (content - view))
	_thumb.position = Vector2(0.0, thumb_y)
	_thumb.size = Vector2(size.x, thumb_height)

func _get_view_height() -> float:
	return _host.size.y if _host != null else 0.0

func _get_content_height() -> float:
	return _host.get_v_scroll_bar().max_value if _host != null else 0.0

func _get_max_scroll() -> float:
	return maxf(0.0, _get_content_height() - _get_view_height())

func _set_host_scroll(value: float) -> void:
	if _host != null:
		_host.scroll_vertical = roundi(value)

func _kill_step() -> void:
	if _step_tween != null and _step_tween.is_valid():
		_step_tween.kill()
	_step_tween = null

func _disconnect_host() -> void:
	var bar: VScrollBar = _host.get_v_scroll_bar()
	if bar.value_changed.is_connected(_on_scroll_value_changed):
		bar.value_changed.disconnect(_on_scroll_value_changed)
	if bar.changed.is_connected(_refresh):
		bar.changed.disconnect(_refresh)
	if _host.resized.is_connected(_refresh):
		_host.resized.disconnect(_refresh)

## Snaps to the 2 px grid.
func _even(value: float) -> float:
	return 2.0 * roundf(value / 2.0)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_scroll_value_changed(_value: float) -> void:
	_refresh()

func _on_up_cap_pressed() -> void:
	if _host != null:
		step_to(_host.scroll_vertical - CAP_STEP)

func _on_down_cap_pressed() -> void:
	if _host != null:
		step_to(_host.scroll_vertical + CAP_STEP)

## Dragging the thumb scrolls the list as far as the thumb travels along the
## track, as the native scrollbar did.
func _on_thumb_gui_input(event: InputEvent) -> void:
	if _host == null:
		return
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		_dragging = press.pressed
		_drag_start_y = press.global_position.y
		_drag_start_scroll = float(_host.scroll_vertical)
		if _dragging:
			_kill_step()
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not _dragging:
		return
	var travel: float = maxf(1.0, _get_view_height() - 2.0 * CAP_HEIGHT - _thumb.size.y)
	var moved: float = motion.global_position.y - _drag_start_y
	_set_host_scroll(_drag_start_scroll + moved * _get_max_scroll() / travel)
